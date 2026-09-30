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
| `kitty/kitty.conf`  | kitty — the terminal, shared with the Mac               |
| `ghostty/config`    | Ghostty — kept as the fallback terminal                 |
| `themes/*.env`      | Colour palettes. Each one defined **once**              |
| `templates/*.template` | Per-app configs rendered from a palette              |
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
| `Super+Shift+/` | open this reference card (`man i3` offline) |
| `Super+Tab` | window switcher (rofi) |
| `Super+p` | cycle power profile |
| `Super+Ctrl+q` | lock |
| `Super+bar` / `Super+backslash` | split h / v (tmux-style aliases for `b` / `v`) |
| `Print` | flameshot — whole screen to clipboard and `~/Pictures/Screenshots` |
| `Shift+Print` | flameshot — drag a region, annotate, copy or save |
| `F9` | Lyrebird dictation, start/stop |
| `F12` | calculator |

i3 installs alongside GNOME as a login-screen option; GNOME stays the default
until you pick otherwise. Everything GNOME did implicitly is wired up explicitly
in `i3/config` — brightness, locking, notifications, network and Bluetooth
applets, a polkit agent — because i3 provides none of it.

## UI modes

`Super+Shift+t` cycles dark → light → fly.

| Mode | GTK apps, browsers | Terminal, nvim, i3, dunst |
|---|---|---|
| `dark` | dark | dark |
| `light` | light | dark |
| `fly` | light | light — for glare outdoors |

`light` is why this exists: GTK and the terminal have to disagree, so "follow the
system colour scheme" cannot express it.

**Colours are defined once.** Each palette lives in `themes/<name>.env` and
nothing else contains a hex value — `i3/scripts/ui-mode` renders every app's
config from it through `templates/*.template`. Adding a theme is one new `.env`
file; adding an app is one template plus a line in `render_all()`.

nvim is the exception: it loads a colorscheme by name rather than being handed
colours, so the palette's `name=` is passed through, and both nvim configs read
`~/.config/ui-theme` at startup.

Everything updates live: gsettings for GTK, `kitty @ set-colors` for open
terminals, `:colorscheme` pushed to running nvim over its RPC socket, dunst
killed so D-Bus activation restarts it, and `i3-msg restart` (which keeps your
layout).

### Wallpaper

Images go in `dark/` and `light/` under the first of these that exists:
`$WALLPAPER_DIR`, `~/Pictures/Wallpapers` (the default), or
`~/.local/share/wallpapers`. Which set is used follows the UI mode — `dark` mode uses
`dark/`, `light` and `fly` use `light/`, since what matters is what the wallpaper
sits behind.

| | |
|---|---|
| `Super+Shift+i` | next wallpaper |
| `Super+Shift+u` | previous wallpaper |
| `Super+Ctrl+i` | random |
| systemd user timer | every 30 min — `systemctl --user enable --now wallpaper.timer` |

Images are shown **whole**, letterboxed in the palette's background colour where
the aspect does not match the screen. Your photos are 4:3 and 3:2; the screen is
16:10, so filling it would crop roughly a quarter of the height off each one.
`WALLPAPER_FIT=fill` opts into cropping instead, if you prefer no borders.

With no images present it falls back to a flat fill of the palette's background,
so this never needs setting up before i3 is usable.

**Not stored in this repo, deliberately.** git keeps every version of a binary
forever, so a few photos become permanent weight on every clone — including the
`curl | bash` path onto small servers that will never show a wallpaper — and this
repo is public.

### Browsers following the mode

Firefox, Chrome and Electron read the XDG portal's `org.freedesktop.appearance`,
not gsettings. Under GNOME `xdg-desktop-portal-gnome` serves that; under i3
nothing claims the interface, so apps ignore the switch. Fixed with
`~/.config/xdg-desktop-portal/portals.conf`:

```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.Settings=gtk
```

Restart both `xdg-desktop-portal.service` and `xdg-desktop-portal-gtk.service`
after changing it — the GTK backend caches at startup, so restarting only the
front-end leaves it reporting a stale value.

**Firefox needs its own setting too.** It caches the portal value at startup, and
more importantly it ignores the system scheme entirely if its theme is pinned:
check `extensions.activeThemeID` isn't `firefox-compact-light`. Set
Settings → General → Website appearance → *Automatic*, and
Add-ons → Themes → *System theme — auto*. Chrome and Electron re-read the portal
live and need nothing.

### Two i3 constraints worth knowing

i3 variables do **not** cross an `include` boundary — `set $bg` in an included
file leaves every colour as `Could not parse color: $bg`. Literal hex does cross,
which is why the colours are generated from a template rather than swapped as a
variables file.

`colors` must sit inside the `bar` block and i3 cannot include a fragment into an
existing block, so the whole bar block lives in the generated file.
