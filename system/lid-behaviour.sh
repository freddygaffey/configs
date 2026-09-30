#!/bin/sh
# Lid behaviour: stay up on AC, suspend on battery.
#
#   plugged in  + lid shut  ->  stays awake, still reachable over ssh
#   on battery  + lid shut  ->  suspends, so it does not flatten the pack
#
# Open the lid to get it back; lid-open wakes it from suspend. That is the whole
# trade: reachable when it costs nothing, asleep when it costs battery.
#
# systemd-logind does this natively — HandleLidSwitch covers battery and
# HandleLidSwitchExternalPower covers AC. Both default to `suspend` on current
# systemd, so setting only the AC one is the actual change.
#
# NB the sleep targets are deliberately NOT masked. Masking them would block the
# battery case too, which is the half worth keeping.
#
# Undo: sudo rm /etc/systemd/logind.conf.d/10-lid.conf
#       sudo systemctl restart systemd-logind
set -eu
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-lid.conf >/dev/null <<'CONF'
[Login]
# On battery: suspend (systemd's default; stated explicitly so the intent is
# readable rather than inherited).
HandleLidSwitch=suspend
# On AC: stay up, so the box is reachable over ssh with the lid shut.
HandleLidSwitchExternalPower=ignore
# Docked (external monitor attached): stay up.
HandleLidSwitchDocked=ignore
CONF
sudo systemctl restart systemd-logind
echo "lid: suspends on battery, stays up on AC."
echo
echo "NB an i9-14900HX running 24 threads with the lid shut is a heat trap."
echo "   Fine for ssh and light work; prop it open for long builds."
echo
echo "Under GNOME, gsd-power can override logind's lid handling. Under i3 there"
echo "is no such override, so this governs."
