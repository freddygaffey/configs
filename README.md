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

The current git branch, in the prompt. One function and one line — it does not
replace a prompt you already have.

On the Mac (zsh) it's the themed version:

```
fred@freds-mac:~/art_move (master)%
```

On a Debian server (bash) your distro prompt is left exactly as it is, with the
branch inserted before the `$`:

```
fred@deb:~/.dotfiles/configs (main)$
```

A Python venv still shows in both — `activate` prepends `(env) ` to the prompt
and nothing here disturbs that. Colours are 256-colour codes, so they render the
same in and out of tmux; the green is `29` (`#00875f`) if you want to change it.

Both bootstrap scripts link `shell/prompt.sh` to `~/.config/shell/prompt.sh` and
add a source line to your login shell's rc file, so it's on after a
`curl | bash`. nvim's statusline shows the same branch via lualine.

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
