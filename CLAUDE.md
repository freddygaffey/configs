# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a personal dotfiles repo: **tmux + Neovim**, carbonfox theme, one-command setup for macOS and Linux servers. There is no build/test/lint pipeline — the "code" is editor and shell configuration.

## Validating changes

There is no test suite. After editing a Lua config, check it parses and that plugins still resolve:

```sh
luac -p init.lua              # syntax-check the full config
luac -p lite/init.lua         # syntax-check the lite config
nvim --headless "+Lazy! sync" +qa   # install/update plugins (uses whichever init.lua is symlinked)
```

Reload tmux config without restarting: `Ctrl-a r` (or `tmux source-file ~/.config/tmux/tmux.conf`).

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

## Plugins

`init.lua` uses lazy.nvim (self-bootstrapping on first launch). LSP servers and tools are declared in the `mason-lspconfig` `ensure_installed` list inside the `nvim-lspconfig` block; mason-lspconfig (v2) auto-enables installed servers, so adding a server name there is usually all that's needed. Treesitter parsers live in the `langs` list passed to `ts.install(...)` in the `nvim-treesitter` block. That block is pinned to the plugin's `main` branch because the old `master` branch does not support Neovim 0.12 and crashes on parse (`attempt to call method 'range' (a nil value)`); on `main`, nvim-treesitter only installs parsers, and Neovim's built-in `vim.treesitter.start()` does highlighting. `main` compiles parsers with the `tree-sitter` CLI (installed by `bootstrap.sh`), not cc directly — so the CLI must be on `PATH` or `:TSUpdate` fails.
