#!/usr/bin/env bash
# system/legion.sh — host-level configuration for the Legion 5 16IRX9.
#
#   ./system/legion.sh --dry-run     show every change without making it
#   ./system/legion.sh               apply (asks first)
#
# This is NOT run by any bootstrap script, on purpose. bootstrap.sh and
# bootstrap-desktop.sh only touch $HOME and install packages, so they are safe to
# curl onto any machine. This file writes to /etc, masks systemd units and
# changes firmware-adjacent settings — it is specific to ONE laptop and would be
# actively wrong on a server or another machine.
#
# Every step is idempotent, individually skippable (SKIP_<STEP>=1), and has its
# reversal documented in the comment above it.
#
# Hardware context this is tuned for:
#   i9-14900HX (8 P-cores + 16 E-cores), RTX 4070 Mobile + Intel iGPU (hybrid),
#   2560x1600 @ 165 Hz panel, 74.5 Wh battery (80 Wh design, 93% health),
#   battery is BAT1 (not BAT0), ideapad_acpi at VPC2004:00.
set -euo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

info() { printf '\033[0;34m::\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m!!\033[0m %s\n' "$1"; }
step() { printf '\n\033[1;37m── %s\033[0m\n' "$1"; }

run() {
  if [ "$DRY" = "1" ]; then printf '   \033[0;90m$ %s\033[0m\n' "$*"; else eval "$@"; fi
}

if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
  warn "Needs root or sudo."; exit 1
fi
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Optional per-machine preferences (which steps to skip, conservation mode).
# Copy local.env.example → local.env if you want to pin any of them.
# shellcheck disable=SC1091
[ -r "$HERE/local.env" ] && . "$HERE/local.env"

if [ "$DRY" = "0" ]; then
  cat <<'WARNING'
This changes system state on THIS machine:
  • disables suspend entirely (lid close will no longer sleep the machine)
  • adds a udev rule that switches the power profile on AC/battery
  • masks nvidia-persistenced
  • caps snap revision retention
  • optionally enables battery conservation mode (caps charge at ~60%)
Each step prints what it does and how to reverse it. Run with --dry-run first.
WARNING
  printf 'Proceed? [y/N] '
  read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) info "Aborted."; exit 0 ;; esac
fi

# ── 1. Never suspend ───────────────────────────────────────────────────
# This laptop is a workhorse reached over ssh from a Mac. If it suspends on lid
# close it becomes unreachable, and it cannot be woken over WiFi — so suspend is
# not a power saving here, it is an outage.
#
# Two halves are needed. logind's HandleLidSwitch stops the lid triggering it;
# masking the sleep targets stops anything else (GNOME idle, `systemctl
# suspend`, a stray dbus call) from getting there either.
#
# REVERSE: remove the drop-in file, then
#   sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
#   sudo systemctl restart systemd-logind
#
# NB thermals: an i9-14900HX running 24-thread jobs with the lid shut is a heat
# trap. Leave the lid open and let the screen blank instead, or keep loads light
# when it's closed.
if [ "${SKIP_SUSPEND:-}" != "1" ]; then
  step "1. Disable suspend (lid close keeps the machine up)"
  run "$SUDO mkdir -p /etc/systemd/logind.conf.d"
  run "$SUDO tee /etc/systemd/logind.conf.d/10-no-suspend.conf >/dev/null <<'EOF'
# Managed by configs/system/legion.sh — this box must stay reachable over ssh.
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
EOF"
  run "$SUDO systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target"
  run "$SUDO systemctl restart systemd-logind"
  info "suspend disabled"
fi

# ── 2. Power profile follows the power source ───────────────────────────
# power-profiles-daemon is already installed and already drives both the ACPI
# platform_profile and the intel_pstate EPP. What it does NOT do is switch on
# unplug — GNOME only auto-switches at LOW battery (~20%), far too late.
#
# Measured on this machine: EPP=performance vs EPP=power is worth roughly 5-8 W,
# on a light-use budget of about 20 W. Worth automating.
#
# Deliberately a udev rule rather than TLP: TLP conflicts with
# power-profiles-daemon and would have to mask it, which removes the GNOME power
# menu and the Fn+Q integration. This keeps both and gets most of the benefit.
#
# REVERSE: rm /etc/udev/rules.d/99-power-profile.rules && sudo udevadm control --reload
if [ "${SKIP_UDEV_POWER:-}" != "1" ]; then
  step "2. udev rule: performance on AC, power-saver on battery"
  run "$SUDO tee /etc/udev/rules.d/99-power-profile.rules >/dev/null <<'EOF'
# Managed by configs/system/legion.sh
# Switch power-profiles-daemon with the power source. PPD sets both the ACPI
# platform profile and the intel_pstate energy_performance_preference, which is
# the knob that decides whether work lands on P-cores or E-cores.
SUBSYSTEM==\"power_supply\", ATTR{type}==\"Mains\", ATTR{online}==\"1\", RUN+=\"/usr/bin/powerprofilesctl set performance\"
SUBSYSTEM==\"power_supply\", ATTR{type}==\"Mains\", ATTR{online}==\"0\", RUN+=\"/usr/bin/powerprofilesctl set power-saver\"
EOF"
  run "$SUDO udevadm control --reload"
  info "udev power rule installed"
fi

# ── 3. Mask nvidia-persistenced ────────────────────────────────────────
# Keeps the NVIDIA driver state initialised, which can hold the dGPU out of
# runtime suspend. The dGPU draws ~12 W awake — on this machine that is about
# 40% of total draw, and it is the single biggest battery win available.
# Only useful if you run headless CUDA jobs; nothing here does.
#
# REVERSE: sudo systemctl unmask --now nvidia-persistenced
if [ "${SKIP_NVIDIA_PERSIST:-}" != "1" ]; then
  step "3. Mask nvidia-persistenced (lets the dGPU stay asleep)"
  run "$SUDO systemctl mask --now nvidia-persistenced"
  info "nvidia-persistenced masked"
fi

# ── 4. Hardware video decode ───────────────────────────────────────────
# With a browser always open this is the largest single lever: without VA-API,
# video decodes on CPU at 10-20 W; with it, on the iGPU at 3-5 W.
# vainfo is the verification tool, not a runtime dependency.
#
# Verify after: vainfo | grep -E 'VAProfileH264High|VAProfileHEVCMain|VAProfileAV1'
# Then in Firefox set media.ffmpeg.vaapi.enabled=true and confirm on
# about:support; in Chrome pass --enable-features=VaapiVideoDecoder and check
# chrome://gpu.
#
# REVERSE: sudo apt remove intel-media-va-driver-non-free vainfo
if [ "${SKIP_VAAPI:-}" != "1" ]; then
  step "4. VA-API hardware video decode"
  run "$SUDO apt-get install -y vainfo intel-media-va-driver-non-free linux-tools-generic"
  info "VA-API tools installed — run 'vainfo' to verify"
fi

# ── 5. Cap snap revision retention ─────────────────────────────────────
# snapd keeps 3 revisions of every snap by default. On this machine ~/snap and
# /var/lib/snapd came to about 65 GB, most of it disabled old revisions — which
# is also why lsblk shows fifty-odd loop devices. Two is the minimum snapd
# allows and still lets you roll back one step.
#
# This only changes the policy; it does not delete anything. Removing the
# already-disabled revisions is a separate, explicit step (printed below)
# because it IS destructive.
#
# REVERSE: sudo snap set system refresh.retain=3
if [ "${SKIP_SNAP_RETAIN:-}" != "1" ] && command -v snap >/dev/null 2>&1; then
  step "5. Cap snap retention at 2 revisions"
  run "$SUDO snap set system refresh.retain=2"
  info "snap retention capped"
  warn "Old revisions are NOT removed by this script. To reclaim ~30-45 GB, review:"
  warn "  snap list --all | awk '/disabled/{print \$1, \$3}'"
  warn "then for each:  sudo snap remove <name> --revision=<rev>"
fi

# ── 6. Battery conservation mode (OPT-IN) ──────────────────────────────
# Caps charge at ~60% via ideapad_acpi. Right for a machine that lives plugged
# in — this pack is at 93% health / 246 cycles and calendar wear at 100% charge
# is what degrades it further.
#
# OFF by default because the trade-off is real: while enabled you only ever have
# ~60% capacity available, so the laptop stops being usefully portable. Set
# ENABLE_CONSERVATION=1 (or put it in local.env) to turn it on.
#
# REVERSE: echo 0 | sudo tee /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
CONS=/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
if [ ! -e "$CONS" ]; then
  info "6. No ideapad conservation_mode on this host — skipping"
elif [ "${ENABLE_CONSERVATION:-0}" = "1" ]; then
  step "6. Battery conservation mode (cap charge ~60%)"
  run "echo 1 | $SUDO tee $CONS >/dev/null"
  info "conservation mode ON — battery will hold ~60%"
else
  info "6. Conservation mode left OFF (ENABLE_CONSERVATION=1 to enable)"
fi

# ── 7. Stop tracker indexing the bulk archives (user-level) ────────────
# tracker-miner-fs indexes all of $HOME, including several hundred GB of drone
# mission frames and decompilation corpora, and had been re-extracting one
# unreadable file for months. The index itself is small; the CPU churn is not.
#
# gsettings, so this is per-user rather than system state.
# REVERSE: gsettings reset org.freedesktop.Tracker3.Miner.Files index-recursive-directories
if [ "${SKIP_TRACKER:-}" != "1" ] && command -v gsettings >/dev/null 2>&1; then
  step "7. Limit tracker indexing to real documents (user-level)"
  # These values contain both single quotes and $HOME, which cannot survive a
  # round trip through run()'s eval without either losing the expansion or the
  # quoting. Call gsettings directly instead, so --dry-run also prints the real
  # expanded value rather than a variable name.
  rec="['$HOME/Documents', '$HOME/Downloads']"
  single="['$HOME']"
  gs=org.freedesktop.Tracker3.Miner.Files
  if [ "$DRY" = "1" ]; then
    printf '   \033[0;90m$ gsettings set %s index-recursive-directories "%s"\033[0m\n' "$gs" "$rec"
    printf '   \033[0;90m$ gsettings set %s index-single-directories "%s"\033[0m\n' "$gs" "$single"
  else
    gsettings set "$gs" index-recursive-directories "$rec"
    gsettings set "$gs" index-single-directories "$single"
  fi
  info "tracker scope reduced (run 'tracker3 reset --filesystem' to rebuild)"
fi

# ── 8. Narrow NOPASSWD sudo allowlist ──────────────────────────────────
# A short list of commands that may run without a password, chosen so that every
# entry is genuinely limited — see the header of sudoers.d/10-fred-ops for what
# was rejected and why (apt, systemctl, tee and turbostat all amount to full
# root, so they are absent and this script still prompts once).
#
# Installed via a validated copy, never by editing /etc/sudoers directly: the
# file is syntax-checked with `visudo -cf` BEFORE it is put in place, and the
# whole tree is re-checked afterwards with automatic rollback. A malformed
# sudoers file locks you out of sudo entirely, and recovery is a root shell or a
# live USB.
#
# REVERSE: sudo rm /etc/sudoers.d/10-fred-ops
if [ "${SKIP_SUDOERS:-}" != "1" ]; then
  step "8. Narrow NOPASSWD sudo allowlist"
  SRC="$HERE/sudoers.d/10-fred-ops"
  if [ ! -r "$SRC" ]; then
    warn "$SRC missing — skipping"
  elif ! visudo -cf "$SRC" >/dev/null 2>&1; then
    warn "$SRC FAILED validation — refusing to install it"
    visudo -cf "$SRC" || true
  else
    info "validated $SRC"
    # install(1) sets owner and mode atomically. 0440 root:root is mandatory,
    # not cosmetic: sudo ignores any sudoers.d file that is group/world-writable.
    run "$SUDO install -o root -g root -m 0440 \"$SRC\" /etc/sudoers.d/10-fred-ops"
    if [ "$DRY" = "0" ]; then
      if $SUDO visudo -c >/dev/null 2>&1; then
        info "sudoers tree valid"
        info "check the rfcomm restriction held:  sudo -l | grep rfcomm"
        info "  and that this is REFUSED:  sudo rfcomm listen 0 1 /bin/sh"
      else
        warn "sudoers tree INVALID after install — removing our file"
        $SUDO rm -f /etc/sudoers.d/10-fred-ops
        $SUDO visudo -c || true
      fi
    fi
  fi
fi

# ── 9. Make RAPL power counters readable without root ──────────────────
# /sys/class/powercap/intel-rapl:*/energy_uj is the package power counter — the
# only way to attribute draw to CPU vs GPU vs rest. It ships 0400 root, so
# anything that wants it (a status bar, a logging script) has to go through
# turbostat as root, and turbostat cannot be allowlisted safely because
# `turbostat -- <cmd>` runs <cmd> as root.
#
# Granting group read to 'adm' (which fred is already in) removes the need for
# either. Battery draw at /sys/class/power_supply/BAT1/power_now is already
# world-readable; this adds the CPU-side detail.
#
# SECURITY NOTE, because this is a deliberate loosening: these counters were
# restricted to root in response to PLATYPUS (CVE-2020-8694), where fine-grained
# RAPL readings leak enough timing information to recover AES keys from another
# process. On a single-user laptop where you are the only member of 'adm' the
# practical risk is negligible — but it is not zero, and on a multi-user or
# shared machine you should leave this alone (SKIP_RAPL=1).
#
# REVERSE: rm /etc/udev/rules.d/99-rapl-readable.rules
#          then reboot (or re-trigger: sudo udevadm trigger --subsystem-match=powercap)
if [ "${SKIP_RAPL:-}" != "1" ]; then
  step "9. RAPL power counters readable by group 'adm'"
  run "$SUDO tee /etc/udev/rules.d/99-rapl-readable.rules >/dev/null <<'EOF'
# Managed by configs/system/legion.sh
# Let group 'adm' read the RAPL energy counters, so power measurement does not
# need root. See CVE-2020-8694 (PLATYPUS) — this is a deliberate trade-off,
# acceptable on a single-user machine only.
SUBSYSTEM==\"powercap\", KERNEL==\"intel-rapl:*\", ACTION==\"add\", \\
  RUN+=\"/bin/sh -c 'chgrp adm /sys%p/energy_uj 2>/dev/null; chmod g+r /sys%p/energy_uj 2>/dev/null'\"
EOF"
  run "$SUDO udevadm control --reload"
  run "$SUDO udevadm trigger --subsystem-match=powercap"
  info "RAPL counters group-readable — verify: cat /sys/class/powercap/intel-rapl:0/energy_uj"
fi

step "Done"
cat <<'DONE'
Reversal for each step is in the comment above it in this file.
Verification commands and the Bluetooth MAVLink recipe: system/README.md
DONE
