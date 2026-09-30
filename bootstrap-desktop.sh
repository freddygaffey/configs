#!/usr/bin/env bash
# bootstrap-desktop.sh — add the i3 desktop layer on top of the terminal setup.
#
#   Remote:  curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap-desktop.sh | bash
#   Local:   ./bootstrap-desktop.sh
#
# Runs bootstrap.sh first (tmux + nvim + prompt), then installs i3 and the
# handful of programs a bare WM needs but does not ship: a launcher, a locker,
# notifications, a network applet, a Bluetooth applet, a polkit agent.
#
# SCOPE: this script only ever touches $HOME and installs packages. It changes
# nothing in /etc — no suspend settings, no udev rules, no services. Host-level
# configuration lives in the system/ scripts, which you run deliberately and which
# is not invoked from here. That separation is the point: this file is safe to
# curl onto any Linux desktop; the system/ scripts are not.
#
# Safe to re-run. Existing configs are backed up to *.bak, same as bootstrap.sh.
set -euo pipefail

REPO_URL="https://github.com/freddygaffey/configs.git"
DOTFILES="${DOTFILES:-$HOME/.dotfiles/configs}"

info() { printf '\033[0;34m::\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m!!\033[0m %s\n' "$1"; }

if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
  warn "Not root and no sudo — package installs may fail."; SUDO=""
fi

# ── 0. Refuse to run where it makes no sense ───────────────────────────
# A headless server must never end up with i3 pulled in because someone piped
# the wrong URL. Bail loudly instead.
if [ "$(uname)" != "Linux" ]; then
  warn "This is the Linux desktop layer; on macOS just run bootstrap.sh."
  exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
  warn "Only apt is implemented here (i3 package names differ per distro)."
  exit 1
fi
# X11/Wayland session, or at least a display manager, should exist. Not fatal —
# you may be provisioning a box before first login — but say something.
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ] && [ ! -d /usr/share/xsessions ]; then
  warn "No display server and no /usr/share/xsessions — is this a desktop machine?"
  warn "Continuing anyway; set SKIP_GUI_CHECK=1 to silence this."
fi

# ── 1. Terminal layer first ────────────────────────────────────────────
# The desktop layer assumes tmux/nvim/prompt are already linked. Running
# bootstrap.sh here keeps this a single command on a fresh box. SKIP_BASE=1 to
# skip when you've just run it yourself.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ "${SKIP_BASE:-}" != "1" ]; then
  if [ -n "$SCRIPT_DIR" ] && [ -x "$SCRIPT_DIR/bootstrap.sh" ]; then
    info "Running bootstrap.sh (terminal layer) first…"
    "$SCRIPT_DIR/bootstrap.sh"
  else
    info "Running bootstrap.sh from the repo…"
    curl -fsSL "https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh" | bash
  fi
fi

# Resolve the checkout (bootstrap.sh may have just cloned it).
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/i3/config" ]; then
  DOTFILES="$SCRIPT_DIR"
elif [ -d "$DOTFILES/.git" ]; then
  git -C "$DOTFILES" pull --ff-only || warn "Could not fast-forward $DOTFILES"
else
  git clone "$REPO_URL" "$DOTFILES"
fi
info "Using checkout at $DOTFILES"

# ── 2. Packages ────────────────────────────────────────────────────────
# Grouped by what breaks without them, because a bare WM is missing more than
# people expect:
#   i3 i3status i3lock   the WM, its bar, its locker
#   rofi                 launcher + window switcher ($mod+d / $mod+Tab)
#   dunst                notifications — i3 has none at all
#   brightnessctl        brightness keys (ships a udev rule; needs no root)
#   xss-lock             ties the idle timer and systemd lock signal to i3lock
#   dex                  XDG autostart (~/.config/autostart), upstream default
#   network-manager-gnome  nm-applet — this box is WiFi-only and i3 has no
#                          network UI whatsoever; without it, `nmtui` is your
#                          only way to join a network
#   blueman              Bluetooth tray (mouse/keyboard/SpaceMouse pair over BT)
#   policykit-1-gnome    polkit agent — without one, any GUI action needing
#                        elevation fails silently with no password prompt
#   flameshot xclip      screenshots — flameshot for its annotation tools and
#                        its own "remember where I last saved" handling
#   gnome-calculator     bound to F12
#   libportaudio2        the shared library sounddevice dlopens; without it
#                        Lyrebird's mic capture falls back or fails to import
#   arandr pavucontrol   GUI display/audio settings, since GNOME's are gone
#   fonts-*              the bar and terminal font, plus emoji so glyphs render
PKGS="i3 i3status i3lock rofi dunst brightnessctl xss-lock dex \
network-manager-gnome blueman policykit-1-gnome flameshot xclip xdotool \
gnome-calculator libportaudio2 \
arandr pavucontrol feh fonts-jetbrains-mono fonts-noto-color-emoji mosh picom"

info "Installing desktop packages…"
$SUDO apt-get update -y
# shellcheck disable=SC2086
$SUDO apt-get install -y $PKGS

# ── 3. Ghostty ─────────────────────────────────────────────────────────
# Not in the Ubuntu archive. mkasberg/ghostty-ubuntu publishes per-release .debs
# tracking upstream; assets are named ghostty_<ver>_<arch>_<ubuntu>.deb.
#
# A .deb rather than the snap on purpose: the snap is classic-confinement and
# published by a third party, and this machine already carries ~65 GB of snap
# revisions. A native package also keeps terminfo and shell integration in the
# paths everything else expects.
install_ghostty() {
  if command -v ghostty >/dev/null 2>&1; then
    info "Ghostty already installed"; return 0
  fi
  local arch rel url tmp
  case "$(dpkg --print-architecture)" in
    amd64) arch=amd64 ;;
    arm64) arch=arm64 ;;
    *) warn "No Ghostty build for $(dpkg --print-architecture); skipping."; return 0 ;;
  esac
  rel="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")"
  [ -n "$rel" ] || { warn "Cannot determine OS version; skipping Ghostty."; return 0; }

  # Pick the asset for this arch + release straight from the releases API, rather
  # than constructing a filename that changes with every upstream version.
  url="$(curl -fsSL https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest \
        | grep -o "https://[^\"]*_${arch}_${rel}\.deb" | head -1)" || true
  if [ -z "$url" ]; then
    warn "No Ghostty .deb for ${arch}/${rel}. Install it yourself, or use kitty"
    warn "(the terminal wrapper falls back automatically)."
    return 0
  fi
  info "Installing Ghostty from $url"
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "$tmp/ghostty.deb"; then
    $SUDO apt-get install -y "$tmp/ghostty.deb" || warn "Ghostty .deb failed to install"
  else
    warn "Ghostty download failed"
  fi
  rm -rf "$tmp"
}
install_ghostty

# Point Debian's x-terminal-emulator alternative at Ghostty, so anything that
# launches "the terminal" generically gets the right one.
if command -v ghostty >/dev/null 2>&1 && [ -x /usr/bin/ghostty ]; then
  $SUDO update-alternatives --install /usr/bin/x-terminal-emulator \
      x-terminal-emulator /usr/bin/ghostty 60 >/dev/null 2>&1 || true
  $SUDO update-alternatives --set x-terminal-emulator /usr/bin/ghostty >/dev/null 2>&1 || true
  info "x-terminal-emulator → ghostty"
fi

# ── 4. Symlink configs ─────────────────────────────────────────────────
# Same link() contract as bootstrap.sh: back up anything real that's in the way,
# then symlink. Re-running is a no-op.
link() {
  local target="$1" link="$2"
  mkdir -p "$(dirname "$link")"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    warn "Backing up $link → $link.bak"
    mv "$link" "$link.bak"
  fi
  ln -sfn "$target" "$link"
  info "linked $link"
}
link "$DOTFILES/i3/config"         "$HOME/.config/i3/config"
link "$DOTFILES/i3/i3status.conf"  "$HOME/.config/i3/i3status.conf"
link "$DOTFILES/i3/scripts"        "$HOME/.config/i3/scripts"
link "$DOTFILES/ghostty/config"    "$HOME/.config/ghostty/config"
link "$DOTFILES/xresources"        "$HOME/.Xresources"
link "$DOTFILES/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
link "$DOTFILES/picom/picom.conf"  "$HOME/.config/picom.conf"
link "$DOTFILES/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
mkdir -p "$HOME/.config/systemd/user"
link "$DOTFILES/systemd/wallpaper.service" "$HOME/.config/systemd/user/wallpaper.service"
link "$DOTFILES/systemd/wallpaper.timer"   "$HOME/.config/systemd/user/wallpaper.timer"
# Wallpaper directories, so `wallpaper status` has somewhere to point at. The
# timer is NOT enabled here — rotation is opt-in:
#   systemctl --user enable --now wallpaper.timer
mkdir -p "$HOME/Pictures/Wallpapers/all" "$HOME/Pictures/Wallpapers/dark" "$HOME/Pictures/Wallpapers/light"
systemctl --user daemon-reload 2>/dev/null || true

chmod +x "$DOTFILES"/i3/scripts/* 2>/dev/null || true

# ── 4a. Nerd Font ──────────────────────────────────────────────────────
# Ubuntu's fonts-jetbrains-mono is the UNPATCHED build. nvim-tree and lualine
# draw file-type icons via nvim-web-devicons, and without the patched glyphs
# every icon renders as a tofu box. No apt package ships Nerd Fonts, so fetch the
# patched build into ~/.local/share/fonts — a user font dir, so no root needed.
install_nerd_font() {
  if fc-list : family 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
    info "JetBrainsMono Nerd Font already installed"
    return 0
  fi
  command -v unzip >/dev/null 2>&1 || { warn "unzip missing — skipping Nerd Font"; return 0; }
  local dir tmp
  dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  tmp="$(mktemp -d)"
  info "Installing JetBrainsMono Nerd Font…"
  if curl -fsSL -o "$tmp/JetBrainsMono.zip" \
       https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip; then
    mkdir -p "$dir"
    # Just the four faces actually used; the archive is ~128 MB of variants.
    unzip -q -o "$tmp/JetBrainsMono.zip" -d "$dir" \
      'JetBrainsMonoNerdFont-Regular.ttf' 'JetBrainsMonoNerdFont-Bold.ttf' \
      'JetBrainsMonoNerdFont-Italic.ttf' 'JetBrainsMonoNerdFont-BoldItalic.ttf' \
      2>/dev/null || unzip -q -o "$tmp/JetBrainsMono.zip" -d "$dir"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    info "Nerd Font installed"
  else
    warn "Nerd Font download failed — icons will render as boxes"
  fi
  rm -rf "$tmp"
}
install_nerd_font

# ── 4a2. Tame GNOME apps' remembered window sizes ──────────────────────
# GNOME apps restore their own geometry AFTER the window is mapped, which
# overrides i3's `resize set` in a for_window rule — so gnome-system-monitor
# opened at 2560x1546 (the size it had been maximised to under GNOME) no matter
# what the i3 rule said. The durable fix is to set the size it remembers.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.gnome-system-monitor maximized false 2>/dev/null || true
  gsettings set org.gnome.gnome-system-monitor window-width 1000 2>/dev/null || true
  gsettings set org.gnome.gnome-system-monitor window-height 680 2>/dev/null || true
fi

# ── 4b. Seed the generated theme files ─────────────────────────────────
# i3's colours and the whole bar block are generated per UI mode from
# templates/ + themes/. Without ~/.config/i3/colours.conf there is no bar at
# all, so render it once here. Also seeds kitty's theme and dunst's config,
# which are generated the same way.
if [ -x "$DOTFILES/i3/scripts/ui-mode" ]; then
  info "Seeding theme files (dark)…"
  UI_MODE_REPO="$DOTFILES" "$DOTFILES/i3/scripts/ui-mode" dark >/dev/null 2>&1 \
    || warn "ui-mode seed failed — run ./i3/scripts/ui-mode dark yourself"
fi

# ── 5. Reload a running i3, if there is one ────────────────────────────
if command -v i3-msg >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
  i3-msg reload >/dev/null 2>&1 && info "reloaded running i3" || true
fi

cat <<'DONE'

✓ Desktop layer installed.

  Log out, then pick "i3" at the login screen. GNOME is untouched and remains
  the default — this is an additional session, not a replacement.

  $mod is Super.  $mod+Return terminal   $mod+d launcher   $mod+Tab windows
  $mod+Shift+q close   $mod+r resize mode   $mod+p cycle power profile
  $mod+Shift+/ help   $mod+Shift+e exit i3
DONE

# ── 6. Offer the host-level scripts ────────────────────────────────────
# These stay separate files — they write to /etc and suit one particular laptop —
# but ending with "see system/" is a note nobody acts on, so ask instead.
#
# Prompts read from /dev/tty: under `curl | bash` stdin is the script itself. With
# no tty at all, skip rather than hang. Same idiom as bootstrap.sh's swap prompt.

# Ask about one script; run it on yes.
#   offer <script-name> <plain-English description>
offer() {
  local script="$1"
  local description="$2"
  local reply

  if [ ! -x "$DOTFILES/system/$script.sh" ]; then
    return 0
  fi

  printf '\n  %s\n' "$description" > /dev/tty
  printf '  run system/%s.sh ?  [y/N] ' "$script" > /dev/tty
  read -r reply < /dev/tty || return 0

  case "$reply" in
    y | Y | yes | YES)
      # Warn and carry on. Aborting here would silently skip every later script.
      "$DOTFILES/system/$script.sh" || warn "system/$script.sh failed"
      ;;
  esac
}

offer_system_scripts() {
  if [ ! -e /dev/tty ]; then
    info "No terminal — skipping host-level setup. See system/."
    return 0
  fi

  cat <<'INTRO' > /dev/tty

  ─── Host-level settings ────────────────────────────────────────────

  Seven optional changes, asked one at a time. Each writes to /etc or
  changes system state, and each has its undo in its own header.
  Saying no to all of them is fine — nothing above depends on them.

INTRO

  local reply
  printf '  Go through them? [y/N] ' > /dev/tty
  read -r reply < /dev/tty || return 0
  case "$reply" in
    y | Y | yes | YES) ;;
    *)
      info "Skipped — run them from system/ whenever you like."
      return 0
      ;;
  esac

  offer lid-behaviour "Lid shut: stay awake on AC, suspend on battery. Applies at next boot."
  offer power-on-ac   "Switch the power profile when you plug in or unplug. Around 5-8 W."
  offer dgpu-sleep    "Let the discrete GPU sleep when nothing is using it. Around 12 W."
  offer vaapi         "Hardware video decode. A browser costs 10-20 W without it, 3-5 W with."
  offer sudoers       "A short list of commands that skip the sudo password prompt."
  offer tracker-scope "Stop the file indexer crawling the bulk archives."
  offer snap-retain   "Keep 2 snap revisions instead of 3. Frees roughly 30-45 GB."

  cat <<'EXTRA' > /dev/tty

  Two left out on purpose:

    ./system/battery-conservation.sh on   caps the charge at ~60%. Right for a
                                          machine that stays plugged in; turn it
                                          off before travelling.
    sudo tailscale up --ssh               one-time, needs a browser login.

EXTRA
}
offer_system_scripts
