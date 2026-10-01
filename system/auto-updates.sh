#!/bin/sh
# Install security updates automatically.
#
# Worth it on a machine you rarely log into — that is exactly the one that goes
# unpatched. Security updates only, not every package, so it will not pull a
# surprise into a running service.
#
# Undo: sudo rm /etc/apt/apt.conf.d/20auto-upgrades
set -eu
sudo apt-get install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
echo "security updates will install automatically."
