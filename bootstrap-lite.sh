#!/usr/bin/env bash
# bootstrap-lite.sh — no-compile tmux + neovim setup for tiny boxes.
#
#   Remote (fresh box):
#     curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap-lite.sh | bash
#   Local (already cloned):
#     ./bootstrap-lite.sh
#
# Same idea as bootstrap.sh, trimmed for 512 MB / 1 vCPU machines:
#   • No build toolchain (build-essential / gcc / make) is installed.
#   • Links the pure-Lua lite/ Neovim config — no treesitter parsers, no
#     telescope-fzf-native, no LuaSnip, no mason/LSP. Nothing compiles and
#     nothing downloads a language server, so plugin sync is quick and safe.
#   • Neovim itself comes from the official prebuilt tarball (no compile).
# Safe to re-run.
set -euo pipefail

REPO_URL="https://github.com/freddygaffey/configs.git"
DOTFILES="${DOTFILES:-$HOME/.dotfiles/configs}"
GIT_NAME="${GIT_NAME:-freddygaffey}"
GIT_EMAIL="${GIT_EMAIL:-fredgaffey08@gmail.com}"

info() { printf '\033[0;34m::\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m!!\033[0m %s\n' "$1"; }

# Use sudo only if we're not already root and sudo exists (blank servers run as root).
if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
  warn "Not root and no sudo — package installs may fail."; SUDO=""
fi

# ── 0. Ensure swap exists ──────────────────────────────────────────────
# Even without compiles, a 512 MB box with no swap can OOM-kill sshd under any
# load and drop your session. A little swap turns "killed" into "merely slow".
# We never create it silently, though: prompt for confirmation first. Under
# `curl | bash` stdin is the script, so ask on /dev/tty; with no terminal at
# all (truly unattended), skip unless CREATE_SWAP is set to opt back in.
confirm_swap() {
  case "${CREATE_SWAP:-}" in
    y|Y|yes|YES|1|true) return 0 ;;
    n|N|no|NO|0|false)  return 1 ;;
  esac
  if [ ! -e /dev/tty ]; then
    warn "No terminal to prompt on — skipping swap (set CREATE_SWAP=1 to force)."
    return 1
  fi
  local ans
  printf '\033[0;33m??\033[0m No swap found. Create a 2G /swapfile? Low-memory boxes OOM without it. [y/N] ' > /dev/tty
  read -r ans < /dev/tty || return 1
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
ensure_swap() {
  [ "$(uname)" = "Darwin" ] && return 0
  if command -v swapon >/dev/null 2>&1 && [ -n "$(swapon --show=NAME --noheadings 2>/dev/null)" ]; then
    info "Swap already present"; return 0
  fi
  if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
    warn "No swap and no root — can't add it."; return 0
  fi
  if ! confirm_swap; then
    info "Skipping swapfile creation."; return 0
  fi
  info "Creating 2G /swapfile…"
  if $SUDO fallocate -l 2G /swapfile 2>/dev/null \
     || $SUDO dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none 2>/dev/null; then
    $SUDO chmod 600 /swapfile
    $SUDO mkswap /swapfile >/dev/null 2>&1
    $SUDO swapon /swapfile && info "2G swap enabled"
    grep -q '/swapfile' /etc/fstab 2>/dev/null \
      || echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab >/dev/null
  else
    warn "Could not create swapfile (low disk?)."
  fi
}
ensure_swap

# ── 1. Install packages (no build toolchain) ───────────────────────────
# chafa renders images in the terminal (the tmux prefix+i popup, and as a plain
# CLI viewer) — pure C, no compile here. Full-res on Ghostty via the Kitty
# graphics protocol, Unicode-block fallback elsewhere. (No imagemagick / nvim
# inline images on lite, same as treesitter/LSP — see lite/init.lua header.)
PKGS="git tmux fzf ripgrep curl chafa"
install_pkgs() {
  if [ "$(uname)" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      info "Installing Homebrew…"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi
    info "Installing packages via brew…"
    brew install $PKGS neovim
  elif command -v apt-get >/dev/null 2>&1; then
    # No `apt-get upgrade` (can clobber sshd_config over SSH) and no
    # build-essential (the lite config never compiles anything).
    info "Installing packages via apt…"
    $SUDO apt-get update -y
    $SUDO apt-get install -y $PKGS ca-certificates
    install_neovim_linux
  elif command -v dnf >/dev/null 2>&1; then
    info "Installing packages via dnf…"
    $SUDO dnf install -y $PKGS tar
    install_neovim_linux
  elif command -v pacman >/dev/null 2>&1; then
    info "Installing packages via pacman…"
    $SUDO pacman -Sy --noconfirm $PKGS neovim
  else
    warn "Unknown package manager — install these yourself: $PKGS neovim"
  fi
}

# Install the latest stable Neovim from the official prebuilt tarball into /opt.
# This is a download + untar — no compilation.
install_neovim_linux() {
  local arch tmp tarball dir
  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) warn "Unsupported arch $(uname -m); install neovim manually."; return 0 ;;
  esac
  tarball="nvim-linux-${arch}.tar.gz"
  info "Installing latest Neovim ($arch) from GitHub release…"
  tmp="$(mktemp -d)"
  if ! curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${tarball}" -o "$tmp/$tarball"; then
    warn "Neovim download failed — check network."; rm -rf "$tmp"; return 1
  fi
  $SUDO rm -rf /opt/nvim
  $SUDO tar -C /opt -xzf "$tmp/$tarball"
  dir="$(find /opt -maxdepth 1 -name 'nvim-linux*' -type d | head -1)"
  [ "$dir" != "/opt/nvim" ] && $SUDO mv "$dir" /opt/nvim
  $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
}
install_pkgs

# ── 2. Get the repo ────────────────────────────────────────────────────
# If we're already running from inside a clone, use it; otherwise clone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/lite/init.lua" ]; then
  DOTFILES="$SCRIPT_DIR"
  info "Using existing checkout at $DOTFILES"
elif [ -d "$DOTFILES/.git" ]; then
  info "Updating $DOTFILES…"
  git -C "$DOTFILES" pull --ff-only
else
  info "Cloning $REPO_URL → $DOTFILES"
  mkdir -p "$(dirname "$DOTFILES")"
  git clone "$REPO_URL" "$DOTFILES"
fi

# ── 2b. Ghostty terminfo ───────────────────────────────────────────────
# tic compiles a terminfo entry (tiny, no C toolchain) so clear/tmux/nvim work
# over SSH under TERM=xterm-ghostty. Idempotent; skips if already known.
install_ghostty_terminfo() {
  if infocmp xterm-ghostty >/dev/null 2>&1; then
    info "Ghostty terminfo already installed"
    return 0
  fi
  if ! command -v tic >/dev/null 2>&1; then
    warn "tic not found (ncurses) — skipping Ghostty terminfo install"
    return 0
  fi
  if [ -f "$DOTFILES/ghostty.terminfo" ]; then
    info "Installing Ghostty terminfo…"
    tic -x "$DOTFILES/ghostty.terminfo" 2>/dev/null && info "xterm-ghostty terminfo installed" \
      || warn "Could not compile Ghostty terminfo (set TERM=xterm-256color as a fallback)."
  fi
}
install_ghostty_terminfo

# ── 3. Symlink configs (backing up anything in the way) ────────────────
link() {  # link <target> <linkname>
  local target="$1" link="$2"
  mkdir -p "$(dirname "$link")"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    warn "Backing up $link → $link.bak"
    mv "$link" "$link.bak"
  fi
  ln -sfn "$target" "$link"
  info "linked $link"
}
# Link the lite/ Neovim config (not the repo root) so nvim loads lite/init.lua.
link "$DOTFILES/lite"            "$HOME/.config/nvim"
link "$DOTFILES/tmux/tmux.conf"  "$HOME/.config/tmux/tmux.conf"

# ── 3b. tmux plugins via TPM (resurrect/continuum) ─────────────────────
# resurrect/continuum are pure shell — no compile — so they're safe on tiny
# boxes. Clone TPM and install headlessly so session save/restore works without
# a manual `prefix + I`. Guarded so it can never break the unattended run.
if command -v tmux >/dev/null 2>&1; then
  TPM_DIR="$HOME/.tmux/plugins/tpm"
  if [ ! -d "$TPM_DIR" ]; then
    info "Cloning TPM (tmux plugin manager)…"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" 2>/dev/null \
      || warn "Could not clone TPM; run 'prefix + I' inside tmux to finish."
  fi
  if [ -x "$TPM_DIR/bin/install_plugins" ]; then
    info "Installing tmux plugins…"
    # Drive the install on a private socket so a running tmux is untouched.
    # TPM reads the @plugin list from the config file, but needs the install
    # path in the server env and runs `tmux` against the *current* server — so
    # set TMUX_PLUGIN_MANAGER_PATH and invoke it via run-shell on that socket.
    tmux -L tpm_bootstrap -f "$HOME/.config/tmux/tmux.conf" new-session -d 2>/dev/null || true
    tmux -L tpm_bootstrap set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/" 2>/dev/null || true
    tmux -L tpm_bootstrap run-shell "$TPM_DIR/bin/install_plugins" 2>/dev/null \
      || warn "tmux plugin install hit a snag; 'prefix + I' will finish it."
    tmux -L tpm_bootstrap kill-server 2>/dev/null || true
  fi
fi

# ── 4. Basic git identity (only if unset) ──────────────────────────────
[ -z "$(git config --global user.name  || true)" ] && git config --global user.name  "$GIT_NAME"
[ -z "$(git config --global user.email || true)" ] && git config --global user.email "$GIT_EMAIL"
info "git identity: $(git config --global user.name) <$(git config --global user.email)>"

# ── 5. Pre-install nvim plugins headlessly (all pure Lua — nothing builds) ──
if command -v nvim >/dev/null 2>&1; then
  info "Installing Neovim plugins…"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Run nvim once to finish plugin setup."
fi

cat <<'DONE'

✓ Done (lite). Start a session with:   tmux
  Prefix is Ctrl-a.  Editor: nvim.  Move with Ctrl-h/j/k/l.
  Lite build: pure-Lua plugins only — no treesitter/LSP, built-in syntax.

  Tip: this script does NOT run a system upgrade (it can clobber sshd_config
  over SSH). To update the box yourself:  sudo apt-get update && sudo apt-get upgrade
DONE
