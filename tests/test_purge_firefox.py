#!/usr/bin/env python3
"""Run the real Firefox purge tasks against stubbed pgrep and pacman in a temporary home."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
# x86-64 emulation on Apple Silicon (Colima, Docker Desktop) runs Ansible far slower than CI.
PLAYBOOK_TIMEOUT = 300
DATA_PATHS = [".mozilla", ".cache/mozilla", ".config/mozilla", ".local/share/mozilla", ".var/app/org.mozilla.firefox"]

STUB = "#!" + sys.executable + "\n" + '''
import json, os, sys
name = os.path.basename(sys.argv[0])
args = sys.argv[1:]
with open(os.environ["PURGE_TEST_LOG"], "a") as log:
    log.write(json.dumps([name] + args) + "\\n")
if name == "pgrep":
    sys.exit(int(os.environ["PGREP_RC"]))
# pacman: report only firefox as an installed, explicitly installed package.
if args[:1] == ["--query"] and args[1:] in ([], ["--explicit"]):
    print("firefox 130.0-1")
elif "--upgrades" in args:
    sys.exit(1)
elif "--remove" in args and "--print-format" in args:
    print("firefox-130.0-1")
'''


class PurgeFirefoxTasks(unittest.TestCase):
    def run_tasks(self, firefox_running=False, link_profile=False):
        with tempfile.TemporaryDirectory(prefix="linux-setup-purge-test-") as temporary:
            folder = Path(temporary)
            stubs = folder / "bin"
            stubs.mkdir()
            for name in ("pgrep", "pacman"):
                (stubs / name).write_text(STUB)
                (stubs / name).chmod(0o755)
            home = folder / "home"
            outside = folder / "keep"
            outside.mkdir()
            (outside / "keep.txt").write_text("must survive")
            for relative in DATA_PATHS:
                path = home / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                if relative == ".mozilla" and link_profile:
                    path.symlink_to(outside, target_is_directory=True)
                else:
                    path.mkdir()
                    (path / "profile.txt").write_text("firefox data")
            # A link inside a real data folder must be removed without touching its target.
            if not link_profile:
                (home / ".mozilla" / "linked-out").symlink_to(outside, target_is_directory=True)

            play = folder / "play.yml"
            play.write_text("- hosts: localhost\n  connection: local\n  gather_facts: false\n  vars:\n"
                            "    ansible_become: false\n    ansible_python_interpreter: " + json.dumps(sys.executable) + "\n"
                            "    workstation_home: " + json.dumps(str(home)) + "\n"
                            "  tasks:\n    - ansible.builtin.import_tasks: " + str(ROOT / "tasks/purge_firefox.yml") + "\n")
            log = folder / "commands.jsonl"
            environment = dict(os.environ, PATH=str(stubs) + os.pathsep + os.environ["PATH"],
                               PURGE_TEST_LOG=str(log), PGREP_RC="0" if firefox_running else "1",
                               ANSIBLE_LOCAL_TEMP=str(folder / "ansible"), ANSIBLE_REMOTE_TEMP=str(folder / "remote"))
            result = subprocess.run(["ansible-playbook", "-i", "localhost,", str(play)],
                                    env=environment, cwd=folder, capture_output=True, text=True, timeout=PLAYBOOK_TIMEOUT)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            remaining = [relative for relative in DATA_PATHS if os.path.lexists(home / relative)]
            outside_intact = (outside / "keep.txt").read_text() == "must survive"
            return result, calls, remaining, outside_intact

    @staticmethod
    def removed_packages(calls):
        return [call for call in calls if call[0] == "pacman" and "--remove" in call]

    def test_running_firefox_stops_before_any_change(self):
        result, calls, remaining, outside_intact = self.run_tasks(firefox_running=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Close Firefox", result.stdout + result.stderr)
        self.assertEqual(remaining, DATA_PATHS)
        self.assertTrue(outside_intact)
        self.assertEqual(self.removed_packages(calls), [])

    def test_linked_profile_is_refused_and_target_kept(self):
        result, calls, remaining, outside_intact = self.run_tasks(link_profile=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to remove a linked Firefox data path", result.stdout + result.stderr)
        self.assertEqual(remaining, DATA_PATHS)
        self.assertTrue(outside_intact)
        self.assertEqual(self.removed_packages(calls), [])

    def test_closed_firefox_is_removed_without_following_links(self):
        result, calls, remaining, outside_intact = self.run_tasks()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(remaining, [])
        self.assertTrue(outside_intact)
        self.assertTrue(any(call[-1] == "firefox" for call in self.removed_packages(calls)), calls)


if __name__ == "__main__":
    unittest.main()
