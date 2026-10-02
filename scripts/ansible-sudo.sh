#!/usr/bin/env bash
set -euo pipefail
# Ansible launches sudo with pipes. Use the controlling terminal so sudo can
# reuse the same terminal-scoped timestamp created by setup.sh's sudo -v.
# Module pipelining must stay disabled because stdin is reserved for the TTY.
exec sudo "$@" </dev/tty
