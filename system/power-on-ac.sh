#!/bin/sh
# Switch the power profile with the power source. power-profiles-daemon already
# drives both the ACPI platform profile and the intel_pstate EPP, but it only
# auto-switches at ~20% battery, which is far too late. Worth ~5-8 W.
# Undo: sudo rm /etc/udev/rules.d/99-power-profile.rules && sudo udevadm control --reload
set -eu
sudo tee /etc/udev/rules.d/99-power-profile.rules >/dev/null <<'CONF'
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/powerprofilesctl set performance"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/powerprofilesctl set power-saver"
CONF
sudo udevadm control --reload
echo "done. unplug and check: cat /sys/firmware/acpi/platform_profile"
