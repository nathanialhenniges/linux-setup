#!/usr/bin/env python3
"""Run the real Flatpak tasks against an isolated command fixture."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
APPS = ["org.example.First", "org.example.Second", "org.example.Third"]


class FlatpakTasks(unittest.TestCase):
    def run_tasks(self, installed, inventory_error=False, remote_error=False, origin="flathub"):
        with tempfile.TemporaryDirectory(prefix="linux-setup-flatpak-test-") as temporary:
            folder = Path(temporary)
            command = folder / "flatpak"
            command.write_text("#!" + sys.executable + "\n" + '''
import json, os, sys
args = sys.argv[1:]
with open(os.environ["FLATPAK_TEST_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[0] == "remotes":
    print("flathub\\thttps://unreviewed.example/" if os.environ["REMOTE_ERROR"] == "1" else "flathub\\thttps://dl.flathub.org/repo/")
elif args[0] == "list":
    if os.environ["INVENTORY_ERROR"] == "1":
        print("inventory fixture failed", file=sys.stderr)
        sys.exit(1)
    print("\\n".join(json.loads(os.environ["INSTALLED_APPS"])))
elif args[0] == "info":
    print(os.environ["TEST_ORIGIN"])
''')
            command.chmod(0o755)
            play = folder / "play.yml"
            play.write_text("- hosts: localhost\n  connection: local\n  gather_facts: false\n  vars:\n"
                            "    ansible_become: false\n    ansible_python_interpreter: " + json.dumps(sys.executable) + "\n"
                            "    core_flatpak_remote: {name: flathub, url: 'https://dl.flathub.org/repo/'}\n"
                            "    core_flatpak_packages: " + json.dumps(APPS) + "\n"
                            "  tasks:\n    - ansible.builtin.import_tasks: " + str(ROOT / "tasks/flatpak_apps.yml") + "\n")
            log = folder / "commands.jsonl"
            environment = dict(os.environ, PATH=str(folder) + os.pathsep + os.environ["PATH"],
                               FLATPAK_TEST_LOG=str(log), INSTALLED_APPS=json.dumps(installed),
                               INVENTORY_ERROR=str(int(inventory_error)), REMOTE_ERROR=str(int(remote_error)),
                               TEST_ORIGIN=origin, ANSIBLE_LOCAL_TEMP=str(folder / "ansible"),
                               ANSIBLE_REMOTE_TEMP=str(folder / "remote"))
            result = subprocess.run(["ansible-playbook", "-i", "localhost,", str(play)],
                                    env=environment, cwd=folder, capture_output=True, text=True, timeout=60)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_missing_apps_share_one_transaction(self):
        result, calls = self.run_tasks([APPS[1]])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([call for call in calls if call[0] == "install"],
                         [["install", "--system", "--noninteractive", "flathub", APPS[0], APPS[2]]])
        self.assertEqual(len([call for call in calls if call[0] == "info"]), len(APPS))

    def test_installed_apps_skip_installation(self):
        result, calls = self.run_tasks(APPS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(any(call[0] == "install" for call in calls))

    def test_empty_inventory_installs_all_in_order(self):
        result, calls = self.run_tasks([])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([call for call in calls if call[0] == "install"],
                         [["install", "--system", "--noninteractive", "flathub"] + APPS])

    def test_inventory_error_stops_before_installation(self):
        result, calls = self.run_tasks([], inventory_error=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("inventory fixture failed", result.stdout + result.stderr)
        self.assertFalse(any(call[0] in ("install", "info") for call in calls))

    def test_wrong_remote_stops_before_installation(self):
        result, calls = self.run_tasks([], remote_error=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unreviewed URL", result.stdout + result.stderr)
        self.assertFalse(any(call[0] in ("install", "list") for call in calls))

    def test_wrong_origin_still_fails(self):
        result, calls = self.run_tasks(APPS, origin="unreviewed")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len([call for call in calls if call[0] == "info"]), len(APPS))


if __name__ == "__main__":
    unittest.main()
