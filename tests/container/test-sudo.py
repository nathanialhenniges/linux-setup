"""Verify one terminal sudo authentication reaches piped Ansible commands."""
import os
import pathlib
import pty
import tempfile

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
run_setup_ansible -i inventory.ini {play}
run_setup_ansible -i inventory.ini {play}
'''
    child, fd = pty.fork()
    if child == 0:
        os.execvp('bash', ['bash', '-c', command])
    os.write(fd, b'container-test-only\n')
    output = bytearray()
    while True:
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
    assert os.waitstatus_to_exitcode(status) == 0, 'Ansible could not reuse terminal sudo authentication'
