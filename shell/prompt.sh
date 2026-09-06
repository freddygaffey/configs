# prompt.sh — git-aware shell prompt for zsh and bash.
#
# Symlinked to ~/.config/shell/prompt.sh by bootstrap.sh / bootstrap-lite.sh,
# which also append a guarded `. ~/.config/shell/prompt.sh` line to ~/.zshrc and
# ~/.bashrc — so a fresh `curl | bash` box comes up with the prompt already on.
#
# The shape is Debian's stock bash prompt — user@host, colon, path — with the
# git branch appended, so every machine reads the same:
#
#   fred@freds-mac:~/configs (main)%        clean
#   fred@deb:~/.dotfiles/configs (main*)$   * = tracked files modified
#
# user@host is shown ALWAYS, not just over SSH: inside tmux a pane often has no
# SSH_CONNECTION in its environment, so gating on it made the host vanish on
# exactly the remote boxes where you need to know which machine you're on.
#
# On xterm-like terminals the window/tab title is also set to "user@host: dir",
# which is what Debian's own ~/.bashrc does (its `case "$TERM" in xterm*|rxvt*)`
# block). Inside tmux, TERM is tmux-256color/screen* — Debian skips the title
# there and so do we, leaving tmux's own window naming alone.
#
# Colours keep Debian's roles (green user@host, blue path) in the carbonfox
# palette used by nvim and tmux, as 256-colour codes so it survives terminals
# without truecolor. A detached HEAD shows the short commit hash instead of a
# branch name.
#
# Toggles, both settable per-shell or in your rc file above the source line:
#   export GIT_PROMPT_HOST=0    drop the user@host prefix on this machine
#   export GIT_PROMPT_DIRTY=0   skip the dirty check — the slow part in a huge
#                               repo — and keep just the branch name

# Interactive shells only — sourcing this from a script must be a no-op.
case $- in *i*) ;; *) return 0 ;; esac

# Prints "branch" (or "branch*" when dirty); prints nothing outside a work tree.
__git_prompt_info() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local b d=''
  b=$(git symbolic-ref --short -q HEAD 2>/dev/null) \
    || b=$(git rev-parse --short HEAD 2>/dev/null) \
    || return 0                       # brand-new repo, no commits yet
  # The branch name is interpolated into PS1/PROMPT, which both shells expand
  # again at draw time — strip anything that could be an expansion or a prompt
  # escape rather than trusting a branch name from a repo someone else wrote.
  b=${b//[^A-Za-z0-9._\/+@-]/}
  if [ "${GIT_PROMPT_DIRTY:-1}" != "0" ]; then
    # --no-optional-locks: never write .git/index.lock just to draw a prompt
    # (it races with a real git command running in another pane).
    # -uno: skip untracked files — that's what keeps this quick on big trees.
    [ -n "$(git --no-optional-locks status --porcelain -uno 2>/dev/null | head -1)" ] && d='*'
  fi
  printf '%s%s' "$b" "$d"
}

# Same terminal test Debian's ~/.bashrc uses to decide whether to set the title.
case "$TERM" in
  xterm*|rxvt*) __prompt_title=1 ;;
  *)            __prompt_title='' ;;
esac

if [ -n "${ZSH_VERSION-}" ]; then
  # Rebuild PROMPT in precmd rather than using PROMPT_SUBST: prompt escapes
  # (%F, %~) are only interpreted in PROMPT itself, not in the result of a
  # substitution, so building the coloured string here keeps zsh's width
  # tracking correct — which is what stops long lines wrapping wrongly.
  autoload -Uz add-zsh-hook
  __prompt_precmd() {
    local git star='' seg='' host='' chroot=''
    git=$(__git_prompt_info)
    case $git in *\*) star='*'; git=${git%\*} ;; esac
    [ -n "$git" ] && seg=" %F{75}(${git}%F{204}${star}%F{75})%f"
    [ "${GIT_PROMPT_HOST:-1}" != "0" ] && host='%F{78}%n@%m%f:'
    [ -n "${debian_chroot-}" ] && chroot="(${debian_chroot})"
    PROMPT="${chroot}${host}%F{111}%~%f${seg}%# "
    [ -n "$__prompt_title" ] && print -Pn '\e]0;%n@%m: %~\a'
  }
  add-zsh-hook precmd __prompt_precmd

elif [ -n "${BASH_VERSION-}" ]; then
  __prompt_command() {
    local git star='' seg='' host='' title=''
    git=$(__git_prompt_info)
    case $git in *\*) star='*'; git=${git%\*} ;; esac
    [ -n "$git" ] && seg=" \[\e[38;5;75m\](${git}\[\e[38;5;204m\]${star}\[\e[38;5;75m\])\[\e[0m\]"
    [ "${GIT_PROMPT_HOST:-1}" != "0" ] && host='\[\e[38;5;78m\]\u@\h\[\e[0m\]:'
    [ -n "$__prompt_title" ] && title='\[\e]0;\u@\h: \w\a\]'
    # debian_chroot stays single-quoted so bash expands it when the prompt is
    # drawn, exactly as the stock Debian PS1 does.
    PS1="${title}"'${debian_chroot:+($debian_chroot)}'"${host}\[\e[38;5;111m\]\w\[\e[0m\]${seg}\\\$ "
  }
  # Keep any PROMPT_COMMAND the distro already set (Debian uses it for the
  # xterm title); just add ours to it, and only once.
  case "${PROMPT_COMMAND-}" in
    *__prompt_command*) ;;
    '') PROMPT_COMMAND=__prompt_command ;;
    *)  PROMPT_COMMAND="${PROMPT_COMMAND%;};__prompt_command" ;;
  esac
fi
