# Git branch in the prompt. One function, one line per shell.
#
# zsh (the Mac) — the themed prompt: user@host, path, branch, carbonfox colours.
#
#   fred@freds-mac:~/art_move (master)%
#
# bash (the Debian boxes) — your distro prompt is left exactly as it is. The
# branch is inserted in front of its trailing "$ " and nothing else is touched:
# no colours, no title handling, no PROMPT_COMMAND. Debian's own PS1 keeps doing
# all of that.
#
#   fred@deb:~/.dotfiles/configs (main)$
#
# A Python venv still shows in both: `activate` prepends "(env) " to the prompt
# at activation time, and neither line here disturbs that.
#
# Colours are 256-colour codes, which render the same in and out of tmux. The
# only one worth fiddling with is 29 (#00875f) — the green. 28 (#008700) and
# 22 (#005f00) are darker, 71 (#5faf5f) lighter.
#
# Linked to ~/.config/shell/prompt.sh and sourced from ~/.zshrc / ~/.bashrc by
# bootstrap.sh / bootstrap-lite.sh.

case $- in *i*) ;; *) return 0 ;; esac   # interactive shells only

parse_git_branch() { git branch --show-current 2>/dev/null | sed 's/.*/ (&)/'; }

if [ -n "${ZSH_VERSION-}" ]; then
  setopt PROMPT_SUBST; PROMPT='%F{29}%n@%m%f:%F{111}%~%f%F{75}$(parse_git_branch)%f%# '
else
  PS1="${PS1%'\$ '}"'$(parse_git_branch)\$ '
fi
