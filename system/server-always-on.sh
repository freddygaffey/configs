#!/bin/sh
# Keep this machine up with the lid shut. For a laptop acting as a server.
#
# Differs from lid-behaviour.sh, which is for the machine you carry: that one
# locks on AC and suspends on battery. A server has no session worth locking and
# must not suspend at all — closing the lid would take it off the network.
#
# Sleep targets are MASKED, not just configured: a stray `systemctl suspend`, an
# idle timer or a desktop power applet would otherwise still put it to sleep, and
# nothing is there to wake it.
#
# Undo: sudo rm /etc/systemd/logind.conf.d/20-server.conf
#       sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
set -eu
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/20-server.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
CONF
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null
echo "lid and sleep disabled. Applies at next boot — logind cannot reload without"
echo "destroying the running session."
