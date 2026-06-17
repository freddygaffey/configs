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

# ── 1. Install packages ────────────────────────────────────────────────
PKGS="git tmux neovim fzf ripgrep"
install_pkgs() {
  if [ "$(uname)" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      info "Installing Homebrew…"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi
    info "Installing packages via brew…"
    brew install $PKGS
  elif command -v apt-get >/dev/null 2>&1; then
    info "Installing packages via apt…"
    sudo apt-get update -y
    sudo apt-get install -y $PKGS build-essential curl
  elif command -v dnf >/dev/null 2>&1; then
    info "Installing packages via dnf…"
    sudo dnf install -y $PKGS gcc make curl
  elif command -v pacman >/dev/null 2>&1; then
    info "Installing packages via pacman…"
    sudo pacman -Sy --noconfirm $PKGS base-devel curl
  else
    warn "Unknown package manager — install these yourself: $PKGS"
  fi
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
DONE
