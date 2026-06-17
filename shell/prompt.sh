# shell/prompt.sh — a nicer prompt, but only inside tmux.
#
# Sourced from ~/.bashrc / ~/.zshrc by the bootstrap script. Outside tmux this
# does nothing, so your normal prompt is left exactly as-is. Inside tmux — where
# the status bar already shows the host and session — it switches to a clean,
# minimal one-line prompt:
#
#     ~/path  branch ❯
#
# (the branch only appears inside a git repo). Supports bash and zsh; the glyph
# is plain UTF-8 so no special font is needed. Colours match the carbonfox
# palette (tmux is configured with RGB passthrough, so truecolor renders).

if [ -n "${TMUX:-}" ]; then
  if [ -n "${BASH_VERSION:-}" ]; then
    __tmux_prompt() {
      local blue='\[\e[38;2;120;169;255m\]'   # carbonfox blue  (#78a9ff)
      local dim='\[\e[38;2;107;107;107m\]'    # muted grey
      local cyan='\[\e[38;2;51;177;255m\]'    # carbonfox cyan  (#33b1ff)
      local reset='\[\e[0m\]'
      local branch
      branch=$(git branch --show-current 2>/dev/null)
      [ -n "$branch" ] && branch=" ${dim}${branch}"
      PS1="${blue}\w${branch}${cyan} ❯ ${reset}"
    }
    # Keep any existing PROMPT_COMMAND; don't clobber it.
    case "${PROMPT_COMMAND:-}" in
      *__tmux_prompt*) ;;
      *) PROMPT_COMMAND="__tmux_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
    esac

  elif [ -n "${ZSH_VERSION:-}" ]; then
    setopt prompt_subst 2>/dev/null
    __tmux_branch() {
      local b
      b=$(git branch --show-current 2>/dev/null) || return
      [ -n "$b" ] && print -n " %F{244}${b}%f"
    }
    PROMPT='%F{75}%~%f$(__tmux_branch) %F{39}❯%f '
  fi
fi
