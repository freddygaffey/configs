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
# This writes the file and stops. It does NOT restart systemd-logind, which is
# the obvious way to apply it and also destroys your desktop session: logind
# loses track of the existing session's device leases ("Session enumeration
# failed" in the journal), the compositor loses DRM master, and you get a black
# screen with everything still running behind it. Recovering needs the display
# manager restarted, which loses the session anyway. logind has no ExecReload on
# Ubuntu 24.04, so there is no gentler option — the setting simply applies at the
# next boot.
#
# Undo: sudo rm /etc/systemd/logind.conf.d/10-lid.conf   (also next boot)
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
cat <<'DONE'
Written: /etc/systemd/logind.conf.d/10-lid.conf

  on AC      lid shut -> stays awake, reachable over ssh
  on battery lid shut -> suspends; open the lid to wake it

Takes effect at the next boot. Nothing was restarted on purpose: restarting
systemd-logind applies it immediately and blacks out the desktop session, and
logind has no reload on Ubuntu 24.04.

Two things worth knowing:
  - An i9-14900HX running 24 threads with the lid shut is a heat trap. Fine for
    ssh and light work; prop it open for long builds.
  - Under GNOME, gsd-power can override logind's lid handling. Under i3 nothing
    overrides it, so this governs.
DONE
