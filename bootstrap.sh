#!/usr/bin/env bash
# bootstrap.sh — set up tmux + neovim on any machine with one command.
#
#   Remote (fresh box):
#     curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh | bash
#   Local (already cloned):
#     ./bootstrap.sh
#
# Installs: git tmux neovim fzf ripgrep + build tools, clones this repo,
# symlinks the configs, and sets a basic git identity. Safe to re-run.
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

# ── 1. Install packages ────────────────────────────────────────────────
# Neovim is installed separately (below) from the official release on Linux,
# because distro packages are usually too old for this config.
PKGS="git tmux fzf ripgrep curl"
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
    # No `apt-get upgrade` here on purpose: a full upgrade can pull a new
    # openssh-server, and dpkg then prompts about the cloud-init-modified
    # sshd_config. Piped via `curl | bash` there's no TTY to answer, so it
    # hangs or silently replaces sshd_config and locks you out over SSH.
    # Run `sudo apt-get update && sudo apt-get upgrade` yourself if you want it.
    info "Installing packages via apt…"
    $SUDO apt-get update -y
    $SUDO apt-get install -y $PKGS build-essential ca-certificates
    install_neovim_linux
  elif command -v dnf >/dev/null 2>&1; then
    info "Installing packages via dnf…"
    $SUDO dnf install -y $PKGS gcc make tar
    install_neovim_linux
  elif command -v pacman >/dev/null 2>&1; then
    info "Installing packages via pacman…"
    $SUDO pacman -Sy --noconfirm $PKGS base-devel neovim
  else
    warn "Unknown package manager — install these yourself: $PKGS neovim"
  fi
}

# Install the latest stable Neovim from the official GitHub tarball into /opt.
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
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/init.lua" ]; then
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
# Ghostty advertises TERM=xterm-ghostty, but most boxes have never heard of it,
# so clear/tmux/nvim break over SSH with "unknown terminal type". Compile the
# bundled entry into the local terminfo db (idempotent; skips if already known).
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
link "$DOTFILES"                 "$HOME/.config/nvim"
link "$DOTFILES/tmux/tmux.conf"  "$HOME/.config/tmux/tmux.conf"

# ── 4. Basic git identity (only if unset) ──────────────────────────────
[ -z "$(git config --global user.name  || true)" ] && git config --global user.name  "$GIT_NAME"
[ -z "$(git config --global user.email || true)" ] && git config --global user.email "$GIT_EMAIL"
info "git identity: $(git config --global user.name) <$(git config --global user.email)>"

# ── 5. Pre-install nvim plugins headlessly so first launch is instant ──
if command -v nvim >/dev/null 2>&1; then
  info "Installing Neovim plugins…"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Run nvim once to finish plugin setup."
fi

cat <<'DONE'

✓ Done. Start a session with:   tmux
  Prefix is Ctrl-a.  Editor: nvim.  Move with Ctrl-h/j/k/l.

  Tip: this script does NOT run a system upgrade (it can clobber sshd_config
  over SSH). To update the box yourself:  sudo apt-get update && sudo apt-get upgrade
DONE
