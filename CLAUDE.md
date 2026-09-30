# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a personal dotfiles repo: **tmux + Neovim**, carbonfox theme, one-command setup for macOS and Linux servers, plus an optional **i3 desktop layer** for Linux workstations. There is no build/test/lint pipeline — the "code" is editor, shell, WM and host configuration.

## Three layers — know which one you are editing

This is the most important structural rule in the repo, and it is a safety
boundary, not a style preference:

| Layer | Script | Touches | Safe to `curl \| bash` anywhere? |
|---|---|---|---|
| Terminal | `bootstrap.sh`, `bootstrap-lite.sh` | `$HOME`, packages | yes |
| Desktop | `bootstrap-desktop.sh` | `$HOME`, packages | yes (guards: Linux + apt, warns without a display) |
| Host | `system/legion.sh` | `/etc`, systemd units, sysfs | **no — one specific laptop** |

`system/legion.sh` must never be invoked from a bootstrap script. It disables
suspend, adds udev rules and masks services; correct for the one laptop it names,
actively harmful on a server. It requires an interactive confirmation and
supports `--dry-run`. Every step in it is idempotent, skippable via
`SKIP_<STEP>=1`, and has its reversal written in the comment directly above it —
preserve that convention when adding steps.

Anything genuinely one-time and interactive does **not** belong in these scripts.
Tailscale is the worked example: `sudo tailscale up --ssh` once, by hand. A script
that wraps it either prints the command back at you or demands an auth key in a
file, both worse than just running it.

`system/sudoers.d/10-fred-ops` is a NOPASSWD allowlist where **every entry must be
genuinely limited**. Before adding one, check it cannot execute an arbitrary
command or write an arbitrary path as root — that rule is what keeps `apt`,
`systemctl`, `tee` and `turbostat` out, and why `rfcomm` is restricted to
`bind`/`release`/`show`/`connect` (its `listen` and `watch` subcommands run a
command as root) and `dmidecode` pinned to two arguments (so `--dump-bin` cannot
be appended). Install only via `visudo -cf` validation before the file reaches
`/etc`, then `install -m 0440`, then `visudo -c` with rollback. Reasoning lives in
the sudoers file's own header and `system/README.md`.

Script output goes in the docs, not the terminal. `legion.sh` prints two lines at
the end and points at `system/README.md` for verification commands — resist
growing that back into a wall of text.

## Validating changes

There is no test suite. After editing a Lua config, check it parses and that plugins still resolve:

```sh
luac -p init.lua              # syntax-check the full config
luac -p lite/init.lua         # syntax-check the lite config
nvim --headless "+Lazy! sync" +qa   # install/update plugins (uses whichever init.lua is symlinked)
```

Reload tmux config without restarting: `Ctrl-a r` (or `tmux source-file ~/.config/tmux/tmux.conf`).

Shell scripts: `bash -n <file>` to syntax-check, and `./system/legion.sh --dry-run`
prints every command it would run without running any. i3: `i3 -C -c i3/config`
validates the config without a running WM; `i3-msg reload` applies it live.

## Workflow: commit, push, then pull back via curl

After making a change, commit and push it, then apply it on the machine by re-running the installer over curl (it pulls the latest and re-syncs):

```sh
git add -A && git commit -m "…" && git push
# full machine:
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap.sh | bash
# tiny/lite box:
curl -fsSL https://raw.githubusercontent.com/freddygaffey/configs/main/bootstrap-lite.sh | bash
```

The bootstrap scripts are idempotent: they `git pull --ff-only` the existing checkout, re-link configs (backing up to `*.bak`), and run `nvim --headless +Lazy! sync`. This curl re-run is the intended way to roll a committed change onto a box.

## Two parallel Neovim configs — keep them in sync

The single most important thing to understand: there are **two** Neovim configs that intentionally share the same options, keymaps, and look:

- `init.lua` — the **full** config (treesitter, mason/LSP, telescope + fzf-native, nvim-cmp). Symlinked by `bootstrap.sh` as the repo root → `~/.config/nvim`, so Neovim loads `init.lua`.
- `lite/init.lua` — a **no-compile** subset for tiny boxes (512 MB / 1 vCPU). Drops every plugin that builds a C parser, runs `make`, or downloads a language server (treesitter, fzf-native, LuaSnip, nvim-cmp, mason/lspconfig). Symlinked by `bootstrap-lite.sh` as the `lite/` dir → `~/.config/nvim`.

When you change shared behavior (options, keymaps, theme, statusline, the tmux theme-sync block), apply it to **both** files. Changes that touch dropped plugins (LSP servers, treesitter parsers, completion) belong only in `init.lua`. The header comment in `lite/init.lua` lists exactly what was dropped and why.

## Theme is the cross-cutting concern

The colorscheme is set once via the `theme` local near the top of each `init.lua` (any nightfox variant). lualine and telescope follow it. A `ColorScheme` autocmd (`sync_tmux_theme`) reads highlight groups from the active scheme and pushes matching colors into the running tmux session live — so the `<leader>th` theme picker re-themes the tmux status bar and borders too. `tmux/tmux.conf` holds a static carbonfox baseline used when Neovim isn't running. If you change the theme or statusline colors, expect to touch both the nvim sync function and the tmux baseline.

## Bootstrap scripts — server-safety constraints

`bootstrap.sh` (full) and `bootstrap-lite.sh` (lite) are designed to run unattended on fresh boxes via `curl | bash`, including 512 MB droplets. Several non-obvious constraints are deliberate — preserve them when editing:

- `MAKEFLAGS=-j1` — never parallelize compiles; tiny boxes OOM otherwise.
- **No `apt-get upgrade`** — a full upgrade can pull a new openssh-server and dpkg prompts about the cloud-init `sshd_config`; with no TTY (piped) it hangs or silently locks you out over SSH.
- Creates a 2 GB swapfile on Linux if none exists (OOM-kills otherwise drop the SSH session).
- Installs Neovim from the official GitHub release tarball into `/opt` on Linux (distro packages are too old); uses brew/pacman packages on macOS/Arch.
- `link()` backs up any existing non-symlink config to `*.bak` before symlinking — re-running is safe. `uninstall.sh` reverses it (`--purge` also removes the clone and `/opt` nvim).
- Compiles the bundled `ghostty.terminfo` so SSH sessions from Ghostty don't break with "unknown terminal type".
- `shell/prompt.sh` (git branch in the prompt) is linked to `~/.config/shell/prompt.sh` and enabled by appending a marker-guarded source line to the **login shell's** rc file only (`$SHELL`, not both rc files — writing both created a `~/.bashrc` on a Mac that never had one). That `enable_prompt` block is duplicated verbatim in **both** bootstrap scripts, and `uninstall.sh` strips the same lines back out by exact text — so if you reword the appended comment or source line, change it in all three places. The file deliberately *adds to* the existing prompt rather than replacing it: on bash the distro prompt (colours, title escape, `PROMPT_COMMAND`) must be left untouched.

## Plugins

`init.lua` uses lazy.nvim (self-bootstrapping on first launch). LSP servers and tools are declared in the `mason-lspconfig` `ensure_installed` list inside the `nvim-lspconfig` block; mason-lspconfig (v2) auto-enables installed servers, so adding a server name there is usually all that's needed. Treesitter parsers live in the `langs` list passed to `ts.install(...)` in the `nvim-treesitter` block. That block is pinned to the plugin's `main` branch because the old `master` branch does not support Neovim 0.12 and crashes on parse (`attempt to call method 'range' (a nil value)`); on `main`, nvim-treesitter only installs parsers, and Neovim's built-in `vim.treesitter.start()` does highlighting. `main` compiles parsers with the `tree-sitter` CLI (installed by `bootstrap.sh`), not cc directly — so the CLI must be on `PATH` or `:TSUpdate` fails.

## i3 layer

`i3/config` is based on i3's **upstream default** (`i3/etc/config`), not written
from scratch — start from upstream when reworking it. The deviations are listed
in a `DEVIATIONS FROM UPSTREAM DEFAULT` block at the top of the file; keep that
block accurate, since it is the only record of why the bindings differ. Summary:
`$mod` is Super not Alt (Alt belongs to nvim), direction keys are `hjkl` not
`jkl;` (matches tmux and nvim), rofi not dmenu, and no compositor.

A bare WM is missing more than people expect. `i3/config` explicitly starts a
notification daemon, a network applet, a Bluetooth applet, a polkit agent, XDG
autostart and a screen locker — GNOME provided all of these implicitly, and
without them you get, respectively: no notifications, no way to join a WiFi
network, no way to reconnect BT peripherals, GUI privilege prompts that fail
silently, and no locking. Every one of those `exec` lines is guarded with
`command -v` so a missing package cannot leave a half-started session.

Machine-specific values that bit once and will again:

- The battery is **BAT1**, not BAT0. i3status's default `battery 0` renders nothing.
- CPU temperature uses the `thermal_zone` path, not `coretemp`/hwmon: coretemp's
  hwmon index is not stable across boots and i3status does not glob paths.
- `i3/scripts/terminal` resolves the terminal at runtime (ghostty → kitty → …)
  rather than hardcoding one, so `$mod+Return` cannot become a key that silently
  does nothing on a box where the terminal isn't installed.
- `i3/scripts/refresh-rate-daemon` runs from `exec_always`, so it kills previous
  instances of itself — otherwise every i3 reload accumulates another daemon.

## Ghostty

`ghostty/config` is shared by the Mac and the Linux box — the terminal is the one
program running on both ends of every ssh session, so it is tracked rather than
hand-configured. Keybindings there are deliberately sparse: tmux owns splits,
tabs and navigation, and duplicating them in the terminal means two layers
competing for the same chords, where only the tmux ones survive an ssh hop.

`clipboard-write = allow` is load-bearing — it is what lets OSC 52 from nvim and
tmux inside an ssh session reach the *local* clipboard, which is the whole reason
`tmux.conf` sets `set-clipboard on` and `allow-passthrough on`. `clipboard-read`
stays `ask`: a remote process silently reading your clipboard is an exfiltration
path.

`tmux.conf` declares Ghostty's capabilities via `terminal-features`, not the older
`terminal-overrides` list — `xterm-ghostty` matched none of those patterns, so
true colour and undercurl were silently lost on the one terminal this repo ships
a terminfo for.
