#!/bin/sh
# Rootless containers that survive logout.
#
# podman rather than docker: rootless by default, no daemon, and each container
# becomes an ordinary systemd user unit. A compromised container is confined to
# this unprivileged account instead of having had root all along.
#
# enable-linger is the line that matters. WITHOUT IT, ROOTLESS CONTAINERS STOP
# WHEN YOU LOG OUT: the systemd user manager exits with your last session and
# takes every user service with it. The server then works perfectly right up
# until you close the ssh connection, which is a miserable thing to debug.
#
# Undo: sudo apt remove podman && loginctl disable-linger "$USER"
set -eu
sudo apt-get update -y
sudo apt-get install -y podman podman-compose uidmap slirp4netns fuse-overlayfs
loginctl enable-linger "$USER"
systemctl --user enable --now podman.socket >/dev/null 2>&1 || true
if podman info >/dev/null 2>&1; then
    echo "podman works rootless, and services will run without a login."
else
    echo "podman installed; log out and back in to finish rootless setup."
fi
