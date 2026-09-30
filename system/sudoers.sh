#!/bin/sh
# Install the NOPASSWD allowlist. Validated before it goes near /etc, because a
# malformed sudoers file locks you out of sudo and recovery is a live USB.
# Undo: sudo rm /etc/sudoers.d/10-fred-ops
set -eu
SRC="$(dirname "$0")/sudoers.d/10-fred-ops"
visudo -cf "$SRC"
sudo install -o root -g root -m 0440 "$SRC" /etc/sudoers.d/10-fred-ops
sudo visudo -c >/dev/null || { sudo rm -f /etc/sudoers.d/10-fred-ops; echo "tree invalid, removed"; exit 1; }
echo "installed. check the rfcomm limit held:"
echo "  sudo -l | grep rfcomm"
echo "  sudo rfcomm listen 0 1 /bin/sh   # must be REFUSED"
