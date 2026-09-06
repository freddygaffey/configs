# configs

My terminal environment: **tmux + Neovim**, vim bindings throughout, carbonfox
theme, one-command setup. Works on macOS and Linux servers.

## Setup on a new machine

Pick one. Both install deps + a current Neovim, clone this repo, symlink the
configs, and set up plugins. Re-running is safe — existing configs get backed up
to `*.bak`. Works as root or with sudo.

**Full** — the works: treesitter, LSP (mason), telescope + fzf-native. Best on a
normal machine.

```sh
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh | bash
```

**Lite** — for tiny boxes (512 MB / 1 vCPU). Skips the build toolchain and links
a pure-Lua Neovim config (built-in syntax, telescope without fzf-native, no
treesitter/LSP) so **nothing compiles or downloads a language server** — no OOM,
quick plugin sync. Same tmux config and keybindings.

```sh
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap-lite.sh | bash
```

Already have the repo cloned? Run the script directly instead:

```sh
./bootstrap.sh        # full
./bootstrap-lite.sh   # lite
```

## What you get

| Path                | What                                                   |
|---------------------|--------------------------------------------------------|
| [`bootstrap.sh`](bootstrap.sh)           | The installer (macOS/apt/dnf/pacman)        |
| [`bootstrap-lite.sh`](bootstrap-lite.sh) | No-compile installer for tiny boxes         |
| `uninstall.sh`      | Reverse it (`--purge` also removes repo + nvim binary) |
| `init.lua`          | Neovim — kickstart-flavored, lazy.nvim, LSP, telescope |
| `lite/init.lua`     | Neovim — pure-Lua subset, no treesitter/LSP, no builds |
| `tmux/tmux.conf`    | tmux — vim bindings, carbonfox statusline              |
| `shell/prompt.sh`   | zsh/bash prompt — user@host, path, git branch           |

## Removing it

Reverses either installer (full or lite). One command, no clone needed:

```sh
# remove symlinks, restore *.bak backups, clear nvim data
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/uninstall.sh | bash

# ...and also delete the cloned repo + the /opt nvim binary
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/uninstall.sh | bash -s -- --purge
```

Or from a local checkout:

```sh
./uninstall.sh           # remove symlinks, restore backups, clear nvim data
./uninstall.sh --purge   # also delete the cloned repo and the /opt nvim binary
```

## Shell prompt

Debian's stock prompt shape — user@host, colon, path — with the git branch of
whatever directory you're in appended, and a `*` when tracked files are
modified. Same on every machine, zsh and bash alike:

```
fred@freds-mac:~/configs (main)%        clean
fred@freds-mac:~/configs (main*)%       uncommitted changes
fred@deb:~/.dotfiles/configs (main*)$   a server, over SSH
```

user@host is always shown, not only over SSH: inside tmux a pane often has no
`SSH_CONNECTION` in its environment, so gating on it hid the host on exactly the
remote boxes where you want it. A detached HEAD shows the short commit hash. On
xterm-like terminals the window title is set to `user@host: dir` too, the same
way Debian's own `~/.bashrc` does it (skipped inside tmux, as Debian skips it).

Both bootstrap scripts link `shell/prompt.sh` to `~/.config/shell/prompt.sh` and
add a source line to `~/.zshrc`/`~/.bashrc`, so it's on after a `curl | bash` —
no manual step. nvim's statusline shows the same branch (lualine, plus
`+`/`~`/`-` counts from gitsigns).

Two toggles, per-shell or set in your rc file above the source line:

```sh
export GIT_PROMPT_HOST=0    # drop the user@host prefix on this machine
export GIT_PROMPT_DIRTY=0   # skip the dirty check (the slow part in a huge repo)
```

## How tabs/panes/files are split

- **tmux windows = tabs** (one per project) — `Ctrl-a c`, jump with `Ctrl-a 1/2/3`
- **panes ↔ nvim splits** — `Ctrl-h/j/k/l` moves across both seamlessly
- **nvim buffers = open files** — `H`/`L` to cycle, shown as tabs by bufferline

## Cheat-sheet

tmux prefix = **`Ctrl-a`**.  nvim leader = **`Space`**.

| Keys                     | Action                                |
|--------------------------|---------------------------------------|
| `Ctrl-a c`               | new tmux window (tab)                 |
| `Ctrl-a |` / `Ctrl-a -`  | split pane vertical / horizontal      |
| `Ctrl-h/j/k/l`           | move between panes **and** nvim splits|
| `Ctrl-a H/J/K/L`         | resize pane                           |
| `Ctrl-a v`, then `v`/`y` | copy mode → select → yank to clipboard|
| `Ctrl-a r`               | reload tmux config                    |
| `<Space>ff` / `<Space>fg`| nvim: find files / grep               |
| `<Space>ft`              | nvim: list TODO/FIXME comments        |
| `ysiw)` / `cs"'` / `ds(` | nvim: add / change / delete surround  |
| `<Space>e` / `<Space>ef` | nvim: file explorer / reveal file     |
| `<Space>th`              | nvim: theme picker (live preview)     |
| `H` / `L`                | nvim: previous / next buffer          |
| `<Space>w` / `<Space>q`  | nvim: save / quit                     |
| `<Space>tn` / `<Space>tc`| nvim: new / close tab page            |
| `<Space>tr` / `<Space>tl`| nvim: tab right / left (next / prev, or `gt`/`gT`) |
| `jk`                     | nvim: exit insert mode                |

Linux clipboard needs `xclip` (X11) or `wl-clipboard` (Wayland); macOS uses the
built-in `pbcopy`. tmux auto-detects which.
