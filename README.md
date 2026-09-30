# configs

My terminal environment: **tmux + Neovim**, vim bindings throughout, carbonfox
theme, one-command setup. Works on macOS and Linux servers — plus an optional
**i3** desktop layer for Linux workstations.

## Setup on a new machine

Pick one. Both install deps + a current Neovim, clone this repo, symlink the
configs, and set up plugins. Re-running is safe — existing configs get backed up
to `*.bak`. Works as root or with sudo.

**Full** — the works: treesitter, LSP (mason), telescope + fzf-native. Best on a
normal machine.

```sh
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh | bash
```

**Desktop** — everything in Full, plus i3, Ghostty and the programs a bare WM
needs (launcher, locker, notifications, network/Bluetooth applets, polkit agent).
Linux + apt only; refuses to run on a server without a display.

```sh
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap-desktop.sh | bash
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
| [`bootstrap-desktop.sh`](bootstrap-desktop.sh) | i3 desktop layer (Linux/apt)     |
| `i3/config`         | i3 — upstream default as a base, Super as mod, hjkl nav |
| `i3/i3status.conf`  | i3 bar — power profile, temp, load, battery draw in W   |
| `i3/scripts/`       | terminal resolver, refresh-rate-on-power, profile cycle |
| `ghostty/config`    | Ghostty — shared by the Mac and the Linux box           |
| [`system/`](system/) | Host-level config. **Not** run by any bootstrap        |

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

## Three layers, deliberately separate

| Layer | Script | Touches | Safe to `curl | bash` anywhere? |
|---|---|---|---|
| Terminal | `bootstrap.sh` / `bootstrap-lite.sh` | `$HOME`, packages | yes |
| Desktop | `bootstrap-desktop.sh` | `$HOME`, packages | yes (refuses non-desktop) |
| Host | `system/*.sh` | `/etc`, systemd units, sysfs | **no — one specific laptop** |

The split is the point. The first two only ever symlink into `$HOME` and install
packages, so they are safe on any box. The `system/` scripts disable suspend, add
udev rules and mask services — correct for one laptop, actively wrong on a server.
They are never invoked by a bootstrap script: one script per change, each short
enough to read before you run it.

## i3 notes

Based on i3's upstream default config, with the deviations documented at the top
of `i3/config`. The short version:

| | Upstream | Here | Why |
|---|---|---|---|
| `$mod` | Alt | **Super** | Alt belongs to nvim |
| Direction keys | `j k l ;` | **`h j k l`** | matches tmux and nvim |
| Launcher | dmenu | **rofi** | also does window switching |
| Compositor | none | none | costs battery on a hybrid GPU for unused transparency |

**Cheat sheet:** the official [i3 reference card](https://i3wm.org/docs/refcard.html)
and [user guide](https://i3wm.org/docs/userguide.html). Read it with two
substitutions: where it shows the modifier, use **Super** (the card itself notes
Mod4 as "a popular alternative"), and where it shows `j k l ;` for directions, use
`h j k l`.

Bindings not on the card:

| Key | Action |
|---|---|
| `Super+Tab` | window switcher (rofi) |
| `Super+p` | cycle power profile |
| `Super+Ctrl+q` | lock |
| `Super+bar` / `Super+backslash` | split h / v (tmux-style aliases for `b` / `v`) |
| `Print` | flameshot — whole screen to clipboard |
| `Shift+Print` | flameshot — drag a region, annotate, copy or save |
| `F9` | Lyrebird dictation, start/stop |
| `F12` | calculator |

i3 installs alongside GNOME as a login-screen option; GNOME stays the default
until you pick otherwise. Everything GNOME did implicitly is wired up explicitly
in `i3/config` — brightness, locking, notifications, network and Bluetooth
applets, a polkit agent — because i3 provides none of it.
