#!/bin/sh
# Cap snap revisions at 2 (default 3). Old revisions had grown to ~65 GB here,
# which is also why lsblk shows fifty-odd loop devices.
# This only changes policy. Removing existing revisions is destructive, so it's
# printed for you to do by hand.
# Undo: sudo snap set system refresh.retain=3
set -eu
sudo snap set system refresh.retain=2
echo "retention capped. to reclaim ~30-45 GB now, review and remove old revisions:"
snap list --all | awk '/disabled/{printf "  sudo snap remove %s --revision=%s\n", $1, $3}'
