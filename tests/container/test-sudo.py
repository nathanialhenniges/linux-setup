"""Verify one terminal sudo authentication caches a ticket and reaches piped Ansible commands."""
import os
import pathlib
import pty
import select
import signal
import tempfile
import time

# A second sudo or BECOME prompt would wait forever for input; fail instead.
DEADLINE_SECONDS = 300

with tempfile.TemporaryDirectory() as directory:
    play = pathlib.Path(directory) / 'sudo.yml'
    play.write_text('''- hosts: workstation
  gather_facts: false
  tasks:
    - name: Verify privilege escalation
      become: true
      ansible.builtin.command: id -u
      register: uid
      changed_when: false
    - ansible.builtin.assert:
        that: uid.stdout == '0'
''')
    command = f'''set -e
source scripts/sudo-session.sh
authenticate_setup_sudo
# pacman, yay, and the keepalive rely on the cached ticket, not the password.
sudo -n true
run_setup_ansible -i inventory.ini {play}
run_setup_ansible -i inventory.ini {play}
'''
    child, fd = pty.fork()
    if child == 0:
        os.execvp('bash', ['bash', '-c', command])
    os.write(fd, b'container-test-only\n')
    output = bytearray()
    deadline = time.monotonic() + DEADLINE_SECONDS
    while True:
        ready, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
        if not ready:
            os.killpg(child, signal.SIGKILL)
            os.waitpid(child, 0)
            os.close(fd)
            raise SystemExit('Timed out: setup likely asked for a second sudo password instead of reusing '
                             'the terminal authentication.\n' + output.decode(errors='replace'))
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        output.extend(chunk)
    os.close(fd)
    _, status = os.waitpid(child, 0)
    print(output.decode(errors='replace'))
    assert os.waitstatus_to_exitcode(status) == 0, 'setup sudo authentication was not cached or Ansible could not reuse it'
