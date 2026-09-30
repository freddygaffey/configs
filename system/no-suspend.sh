#!/bin/sh
# Stop the machine suspending. It's reached over ssh and can't wake over WiFi,
# so lid-close suspend is an outage, not a power saving.
# Undo: sudo rm /etc/systemd/logind.conf.d/10-no-suspend.conf
#       sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
set -eu
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-no-suspend.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
CONF
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo systemctl restart systemd-logind
echo "suspend disabled. NB: lid shut + 24-thread jobs = heat trap."
