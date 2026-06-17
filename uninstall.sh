#!/usr/bin/env bash
# uninstall.sh — reverse bootstrap.sh / bootstrap-lite.sh.
#
#   Remote (nothing cloned, or just want one command):
#     curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/uninstall.sh | bash
#     curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/uninstall.sh | bash -s -- --purge
#   Local (already cloned):
#     ./uninstall.sh           remove symlinks, restore *.bak, clear nvim data
#     ./uninstall.sh --purge   also delete the cloned repo and the nvim binary
#                              installed into /opt by bootstrap.sh
#
# It does NOT uninstall packages (tmux/fzf/ripgrep) or touch your git identity.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles/configs}"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

info() { printf '\033[0;34m::\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m!!\033[0m %s\n' "$1"; }
if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else SUDO=""; fi

# Remove a symlink we created; if a *.bak backup exists, restore it.
unlink_restore() {
  local link="$1"
  if [ -L "$link" ]; then
    rm -f "$link"; info "removed symlink $link"
  elif [ -e "$link" ]; then
    warn "$link exists but isn't our symlink — leaving it"
  fi
  if [ -e "$link.bak" ]; then
    mv "$link.bak" "$link"; info "restored backup $link"
  fi
}

unlink_restore "$HOME/.config/nvim"
unlink_restore "$HOME/.config/tmux/tmux.conf"

# Remove the in-tmux prompt hook (marker line + the source line after it).
remove_prompt_hook() {
  local marker='# configs: in-tmux prompt'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -e "$rc" ] && grep -qF "$marker" "$rc" || continue
    awk -v m="$marker" '$0==m {skip=2} skip>0 {skip--; next} {print}' "$rc" > "$rc.tmp" \
      && mv "$rc.tmp" "$rc" && info "removed prompt hook from $rc"
  done
}
remove_prompt_hook

# Neovim plugin / state / cache data (safe to delete — regenerated on next run)
for d in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
  [ -e "$d" ] && { rm -rf "$d"; info "removed $d"; }
done

if [ "$PURGE" -eq 1 ]; then
  if [ -d "$DOTFILES" ]; then
    rm -rf "$DOTFILES"; info "removed repo $DOTFILES"
  fi
  if [ -L /usr/local/bin/nvim ] || [ -d /opt/nvim ]; then
    $SUDO rm -f /usr/local/bin/nvim
    $SUDO rm -rf /opt/nvim
    info "removed Neovim installed in /opt"
  fi
  warn "Packages (tmux, fzf, ripgrep) were left installed — remove with your package manager if you want."
fi

info "Done."
