# configs

My terminal environment: **tmux + Neovim**, vim bindings throughout, carbonfox
theme, one-command setup. Works on macOS and Linux servers.

## Setup on a new machine

One command does everything (installs deps + a current Neovim, clones this repo,
symlinks, sets up plugins). Works as root or with sudo:

```sh
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh | bash
```

On a bare Debian/Ubuntu box that has neither `curl` nor `git` yet:

```sh
apt-get update && apt-get install -y curl    # (prefix with sudo if not root)
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh | bash
```

Already have the repo cloned? Just run it:

```sh
./bootstrap.sh
```

Re-running is safe — existing configs get backed up to `*.bak`.

## What you get

| Path             | What                                                   |
|------------------|--------------------------------------------------------|
| `bootstrap.sh`   | The installer (macOS/apt/dnf/pacman)                    |
| `uninstall.sh`   | Reverse it (`--purge` also removes repo + nvim binary) |
| `init.lua`       | Neovim — kickstart-flavored, lazy.nvim, LSP, telescope |
| `tmux/tmux.conf` | tmux — vim bindings, carbonfox statusline              |

## Removing it

```sh
./uninstall.sh           # remove symlinks, restore backups, clear nvim data
./uninstall.sh --purge   # also delete the cloned repo and the /opt nvim binary
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
| `H` / `L`                | nvim: previous / next buffer          |
| `jk`                     | nvim: exit insert mode                |

Linux clipboard needs `xclip` (X11) or `wl-clipboard` (Wayland); macOS uses the
built-in `pbcopy`. tmux auto-detects which.
