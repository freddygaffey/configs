# prompt.sh — git-aware shell prompt for zsh and bash.
#
# Symlinked to ~/.config/shell/prompt.sh by bootstrap.sh / bootstrap-lite.sh,
# which also append a guarded `. ~/.config/shell/prompt.sh` line to ~/.zshrc and
# ~/.bashrc — so a fresh `curl | bash` box comes up with the prompt already on.
# Colours are the carbonfox palette used by nvim and tmux, as 256-colour
# approximations (111 blue, 75 cyan, 204 red, 78 green) so it looks right even
# on terminals without truecolor.
#
#   ~/configs (main) %            in a clean repo
#   ~/configs (main*) %           * = tracked files modified
#   fred@deb ~/configs (main) $   user@host prefix appears over SSH only
#
# Detached HEAD shows the short commit hash instead of a branch name.
# In a very large repo the dirty check is the slow part: it is already
# `git status -uno` (untracked files ignored, no index lock taken), but you can
# turn it off entirely with  export GIT_PROMPT_DIRTY=0  and keep the branch name.

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

if [ -n "${ZSH_VERSION-}" ]; then
  # Rebuild PROMPT in precmd rather than using PROMPT_SUBST: prompt escapes
  # (%F, %~) are only interpreted in PROMPT itself, not in the result of a
  # substitution, so building the coloured string here keeps zsh's width
  # tracking correct — which is what stops long lines wrapping wrongly.
  __prompt_host=''
  [ -n "${SSH_CONNECTION-}" ] && __prompt_host='%F{78}%n@%m%f '
  autoload -Uz add-zsh-hook
  __prompt_precmd() {
    local git star='' seg=''
    git=$(__git_prompt_info)
    case $git in *\*) star='*'; git=${git%\*} ;; esac
    [ -n "$git" ] && seg=" %F{75}(${git}%F{204}${star}%F{75})%f"
    PROMPT="${__prompt_host}%F{111}%~%f${seg} %# "
  }
  add-zsh-hook precmd __prompt_precmd

elif [ -n "${BASH_VERSION-}" ]; then
  __prompt_host=''
  [ -n "${SSH_CONNECTION-}" ] && __prompt_host='\[\e[38;5;78m\]\u@\h\[\e[0m\] '
  __prompt_command() {
    local git star='' seg=''
    git=$(__git_prompt_info)
    case $git in *\*) star='*'; git=${git%\*} ;; esac
    [ -n "$git" ] && seg=" \[\e[38;5;75m\](${git}\[\e[38;5;204m\]${star}\[\e[38;5;75m\])\[\e[0m\]"
    PS1="${__prompt_host}\[\e[38;5;111m\]\w\[\e[0m\]${seg} \\\$ "
  }
  # Keep any PROMPT_COMMAND the distro already set (Debian uses it for the
  # xterm title); just add ours to it, and only once.
  case "${PROMPT_COMMAND-}" in
    *__prompt_command*) ;;
    '') PROMPT_COMMAND=__prompt_command ;;
    *)  PROMPT_COMMAND="${PROMPT_COMMAND%;};__prompt_command" ;;
  esac
fi
