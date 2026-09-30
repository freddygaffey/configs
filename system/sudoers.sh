#!/bin/sh
# Install the NOPASSWD allowlist.
#
# Validated before it goes near /etc, because a malformed sudoers file locks you
# out of sudo and recovery is a root shell or a live USB.
# Undo: sudo rm /etc/sudoers.d/10-fred-ops
set -eu
SRC="$(dirname "$0")/sudoers.d/10-fred-ops"

visudo -cf "$SRC"

# Check the EXISTING tree first. Without this, a pre-existing problem in some
# other drop-in makes the post-install check fail, and the rollback below then
# removes our file as if it were the cause — which is exactly what happened with
# /etc/sudoers.d/fred-docker sitting at mode 0644 instead of 0440.
#
# Note that sudo IGNORES a drop-in with bad permissions, so such a file is not
# merely untidy: its rules are not in effect.
if ! sudo visudo -c >/dev/null 2>&1; then
    echo "The existing sudoers tree is already invalid. Fix that first:" >&2
    sudo visudo -c 2>&1 | grep -v ': parsed OK' >&2
    echo >&2
    echo "Drop-ins must be mode 0440, owned root:root. Usually:" >&2
    echo "  sudo chmod 0440 /etc/sudoers.d/<file>" >&2
    exit 1
fi

sudo install -o root -g root -m 0440 "$SRC" /etc/sudoers.d/10-fred-ops
if sudo visudo -c >/dev/null 2>&1; then
    echo "installed. check the rfcomm limit held:"
    echo "  sudo -l | grep rfcomm"
    echo "  sudo rfcomm listen 0 1 /bin/sh   # must be REFUSED"
else
    sudo rm -f /etc/sudoers.d/10-fred-ops
    echo "tree invalid after install, removed ours" >&2
    exit 1
fi
