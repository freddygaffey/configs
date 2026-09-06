--[[ lite/init.lua — no-compile Neovim config for tiny boxes
  Same options/keymaps and look as the full config, but every plugin here is
  pure Lua: nothing builds a C parser, runs `make`, or downloads a language
  server. That means no build-essential, no OOM on a 512 MB / 1 vCPU box, and
  `nvim --headless +Lazy! sync` finishes in seconds.

  Dropped vs the full config (all of these compile or download binaries):
    • nvim-treesitter        (build = ':TSUpdate' compiles a parser per lang)
    • telescope-fzf-native   (build = 'make')
    • LuaSnip                (build = 'make install_jsregexp')
    • nvim-cmp               (only useful with LSP/snippets, dropped with them)
    • mason + nvim-lspconfig (downloads/builds language servers)

  Syntax highlighting falls back to Neovim's built-in regex syntax (no compile).
  Theme: carbonfox.  Pairs with tmux (Ctrl-h/j/k/l navigation).
--]]

-- Leader must be set before plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ─────────────────────────────── Theme ───────────────────────────────
-- Single place to change the colorscheme. Any nightfox variant works
-- (carbonfox, nightfox, duskfox, nordfox, terafox, dayfox, dawnfox). The
-- statusline (lualine) and the fuzzy finder (telescope) both follow this.
local theme = 'carbonfox'

-- ─── Keep tmux's colours in sync with the nvim theme ──────────────────
-- When running inside tmux, push the active colorscheme's colours into tmux on
-- every ColorScheme event — so switching theme (incl. the <leader>th live
-- preview) re-themes the status bar and borders too. tmux.conf holds a static
-- carbonfox baseline for when nvim isn't running.
local function hl(name, attr)
  local ok, c = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and c and c[attr] then return string.format('#%06x', c[attr]) end
end
local function sync_tmux_theme()
  if not vim.env.TMUX then return end
  local bg      = hl('Normal', 'bg')           or '#161616'
  local fg      = hl('Normal', 'fg')           or '#f2f4f8'
  local accent  = hl('Function', 'fg')         or '#78a9ff'
  local accent2 = hl('Constant', 'fg')         or accent
  local red     = hl('DiagnosticError', 'fg')  or '#ee5396'
  local dim     = hl('Comment', 'fg')          or '#6b6b6b'
  local panel   = hl('CursorLine', 'bg')       or '#2a2a2a'
  -- tmux-continuum arms its auto-save by prepending a hidden
  -- #(continuum_save.sh) to status-right at tmux startup. We overwrite
  -- status-right below, so re-prepend that hook (when the plugin is present)
  -- or auto-save silently dies the first time nvim themes tmux — sessions
  -- then never save (see @continuum-restore in tmux.conf). Emits nothing, so
  -- it stays invisible in the bar.
  local save_hook = vim.fn.expand('~/.tmux/plugins/tmux-continuum/scripts/continuum_save.sh')
  local cont = (vim.uv or vim.loop).fs_stat(save_hook) and ('#(%s)'):format(save_hook) or ''
  local opts = {
    { 'status-style',                 ('bg=%s,fg=%s'):format(bg, fg) },
    { 'status-left',                  ('#[bg=%s,fg=%s,bold] #S #[bg=%s]'):format(accent, bg, bg) },
    { 'status-right',                 (cont .. '#{?client_prefix,#[fg=%s]PREFIX ,}#[fg=%s]%%a %%d %%b #[fg=%s]%%H:%%M '):format(red, accent2, accent) },
    { 'window-status-format',         ('#[fg=%s] #I #W '):format(dim) },
    { 'window-status-current-format', ('#[bg=%s,fg=%s,bold] #I #W '):format(panel, accent) },
    { 'pane-border-style',            ('fg=%s'):format(panel) },
    { 'pane-active-border-style',     ('fg=%s'):format(accent) },
    { 'message-style',                ('bg=%s,fg=%s'):format(panel, fg) },
    { 'mode-style',                   ('bg=%s,fg=%s'):format(accent, bg) },
    -- No window-style/window-active-style: dimming inactive panes flattens
    -- full-screen TUIs (nvim, Claude) to a grey wash. Border accent shows focus.
  }
  local args = { 'tmux' }
  for i, o in ipairs(opts) do
    if i > 1 then table.insert(args, ';') end
    vim.list_extend(args, { 'set', '-g', o[1], o[2] })
  end
  vim.fn.system(args)
end
vim.api.nvim_create_autocmd('ColorScheme', { callback = sync_tmux_theme })

-- ────────────────────────────── Options ──────────────────────────────
local o = vim.opt
o.number = true
o.relativenumber = true
o.mouse = 'a'
o.showmode = false            -- lualine already shows the mode
o.clipboard = 'unnamedplus'   -- yank/delete go to the system clipboard

-- When working over SSH, route the clipboard through OSC 52 escape sequences so
-- yanking (y) lands in the *local* machine's clipboard (needs nvim 0.10+).
if os.getenv('SSH_TTY') then
  local ok, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
  if ok then
    vim.g.clipboard = {
      name = 'OSC 52',
      copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
      paste = { ['+'] = osc52.paste('+'), ['*'] = osc52.paste('*') },
    }
  end
end
o.breakindent = true
o.undofile = true             -- persistent undo
o.ignorecase = true
o.smartcase = true
o.signcolumn = 'yes'
o.updatetime = 250
o.timeoutlen = 400
o.splitright = true
o.splitbelow = true
o.list = true
o.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
o.inccommand = 'split'        -- live preview of :substitute
o.cursorline = true
o.scrolloff = 8
o.termguicolors = true
o.tabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.swapfile = false

-- Built-in syntax highlighting (no treesitter on the lite build).
vim.cmd('syntax enable')

-- ────────────────────────────── Keymaps ──────────────────────────────
local map = vim.keymap.set
map('i', 'jk', '<Esc>', { desc = 'Exit insert mode' })
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- Splits (same scheme as tmux)
map('n', '<leader>sv', '<C-w>v', { desc = '[S]plit [V]ertical' })
map('n', '<leader>sh', '<C-w>s', { desc = '[S]plit [H]orizontal' })
map('n', '<leader>se', '<C-w>=', { desc = '[S]plit [E]qual size' })
map('n', '<leader>sx', '<cmd>close<CR>', { desc = '[S]plit close' })

-- Move selected lines (visual mode)
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Indent the selection in / out and keep it selected, so > > > walks a block
-- right one shiftwidth at a time instead of dropping back to normal mode after
-- the first press. A count still multiplies: 3> shifts three levels at once.
-- Tab / Shift-Tab do the same thing for muscle memory from other editors.
map('v', '>', '>gv', { desc = 'Indent selection right' })
map('v', '<', '<gv', { desc = 'Indent selection left' })
map('v', '<Tab>', '>gv', { desc = 'Indent selection right' })
map('v', '<S-Tab>', '<gv', { desc = 'Indent selection left' })

-- dd on a blank/whitespace-only line goes to the black-hole register, so
-- deleting empty lines doesn't clobber whatever you last yanked. A dd on a
-- line with content still cuts to the normal register as usual.
map('n', 'dd', function()
  return vim.api.nvim_get_current_line():match('^%s*$') and '"_dd' or 'dd'
end, { expr = true, desc = 'Delete line (blank → black hole)' })

-- Buffers act as nvim's "tabs" (tmux windows are the real tabs).
-- H / L cycle buffers; <leader>bd closes the current one.
map('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
map('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
-- Close the current file but keep the window + nvim-tree sidebar: switch to the
-- previous buffer, then delete the one we just left (#). Plain :bdelete closes
-- the edit window, leaving the tree alone to balloon and fill the screen.
map('n', '<leader>bd', '<cmd>bprevious<bar>bdelete #<CR>', { desc = '[B]uffer [D]elete (keep layout)' })

-- File explorer (nvim-tree, configured below): toggle the sidebar / reveal file.
map('n', '<leader>e', '<cmd>NvimTreeToggle<CR>', { desc = 'File [E]xplorer' })
map('n', '<leader>ef', '<cmd>NvimTreeFindFile<CR>', { desc = '[E]xplorer: [F]ind current file' })

-- Save / quit
map('n', '<leader>w', '<cmd>write<CR>', { desc = '[W]rite (save) file' })
-- Quit the current pane: if other splits are open, close just this one;
-- otherwise quit nvim entirely (which frees the tmux pane back to the shell).
-- The nvim-tree sidebar is ignored when deciding if this is the last pane, and
-- `confirm` pops a Save? [Y]es/[N]o/[C]ancel prompt for any unsaved changes
-- instead of silently failing with E37.
map('n', '<leader>q', function()
  local real = vim.tbl_filter(function(w)
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
    return not name:match('NvimTree_')
  end, vim.api.nvim_list_wins())
  vim.cmd(#real > 1 and 'confirm quit' or 'confirm quitall')
end, { desc = '[Q]uit pane (prompt to save)' })
map('n', '<C-s>', '<cmd>write<CR>', { desc = 'Save file' })

-- Real nvim tab pages (separate from buffers/tmux windows).
-- <leader>tr / <leader>tl move right/left between them (gt / gT also work).
map('n', '<leader>tn', '<cmd>tabnew<CR>', { desc = '[T]ab [N]ew' })
map('n', '<leader>tc', '<cmd>tabclose<CR>', { desc = '[T]ab [C]lose' })
map('n', '<leader>tr', '<cmd>tabnext<CR>', { desc = '[T]ab [R]ight (next)' })
map('n', '<leader>tl', '<cmd>tabprevious<CR>', { desc = '[T]ab [L]eft (previous)' })

-- ────────────────────────── Bootstrap lazy.nvim ──────────────────────
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ──────────────────────── Plugins (pure Lua only) ────────────────────
require('lazy').setup({
  -- Theme to match tmux
  {
    'EdenEast/nightfox.nvim',
    priority = 1000,
    config = function()
      -- Enable the telescope integration so the picker matches the theme.
      require('nightfox').setup({ integrations = { telescope = true } })
      vim.cmd.colorscheme(theme)
    end,
  },

  -- Seamless tmux <-> nvim navigation with Ctrl-h/j/k/l
  {
    'christoomey/vim-tmux-navigator',
    cmd = { 'TmuxNavigateLeft', 'TmuxNavigateDown', 'TmuxNavigateUp', 'TmuxNavigateRight' },
    keys = {
      { '<C-h>', '<cmd>TmuxNavigateLeft<cr>' },
      { '<C-j>', '<cmd>TmuxNavigateDown<cr>' },
      { '<C-k>', '<cmd>TmuxNavigateUp<cr>' },
      { '<C-l>', '<cmd>TmuxNavigateRight<cr>' },
    },
  },

  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = { theme = theme, section_separators = '', component_separators = '|' },
      -- Git branch + working-tree changes, right next to the mode:
      --   NORMAL |  main | +3 ~1 -0 | init.lua | 42:7
      -- 'branch' is in lualine's default lualine_b already, but spell the
      -- section out so it can't be lost, and feed 'diff' from gitsigns instead
      -- of lualine's built-in source: gitsigns has already diffed the buffer,
      -- so reading its counts is free, whereas the fallback shells out to
      -- `git diff` on every redraw (noticeable on the lite boxes).
      -- Naming only lualine_b replaces that one section; a/c/x/y/z keep their
      -- defaults (see apply_configuration in lualine's config.lua).
      sections = {
        lualine_b = {
          'branch',
          {
            'diff',
            source = function()
              local gs = vim.b.gitsigns_status_dict
              if gs then
                return { added = gs.added, modified = gs.changed, removed = gs.removed }
              end
            end,
          },
          'diagnostics',
        },
      },
    },
  },

  -- Bufferline: shows open files (buffers) as tabs along the top.
  {
    'akinsho/bufferline.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    opts = { options = { show_buffer_close_icons = false } },
  },

  -- File explorer sidebar. Pure Lua, no build step — safe for the lite build.
  -- Toggle with <leader>e; reveal the current file with <leader>ef.
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      -- nvim-tree wants netrw disabled (do it before it loads).
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      require('nvim-tree').setup({
        view = { width = 30 },
        renderer = { group_empty = true },
        filters = { dotfiles = false },
        -- Bigger repos (or slow/tiny boxes) blow past nvim-tree's 400ms default
        -- git timeout, which makes it disable git integration with a warning.
        git = { timeout = 5000 },
      })
      -- When :q closes the last edit window and only the tree remains, quit
      -- nvim instead of letting the tree balloon to fill the screen.
      vim.api.nvim_create_autocmd('QuitPre', {
        callback = function()
          local tree_wins = {}
          local wins = vim.api.nvim_list_wins()
          for _, w in ipairs(wins) do
            local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
            if name:match('NvimTree_') then table.insert(tree_wins, w) end
          end
          if #tree_wins == #wins - 1 then
            for _, w in ipairs(tree_wins) do
              pcall(vim.api.nvim_win_close, w, true)
            end
          end
        end,
      })
    end,
  },

  -- Git change signs in the gutter
  { 'lewis6991/gitsigns.nvim', opts = {} },

  -- Comment with gcc / gc (visual)
  { 'numToStr/Comment.nvim', opts = {} },

  -- Auto-close brackets/quotes
  { 'windwp/nvim-autopairs', event = 'InsertEnter', opts = {} },

  -- Which-key: shows pending keybinds in a popup
  { 'folke/which-key.nvim', event = 'VeryLazy', opts = {} },

  -- Surround: add/change/delete surrounding pairs — ysiw), cs"', ds(
  { 'kylechui/nvim-surround', version = '*', event = 'VeryLazy', opts = {} },

  -- Indent guides: vertical lines marking each indent level
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl', event = 'VeryLazy', opts = {} },

  -- Highlight & search TODO / FIXME / HACK comments (<leader>ft lists them)
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = 'VeryLazy',
    opts = { signs = false },
    config = function(_, opts)
      require('todo-comments').setup(opts)
      map('n', '<leader>ft', '<cmd>TodoTelescope<CR>', { desc = '[F]ind [T]ODOs' })
    end,
  },

  -- GUI-like find & replace across the whole project. Opens a split where the
  -- search, replace, and file-filter are fields at the top and the live ripgrep
  -- results fill the buffer below — edit the replace field and apply to rewrite
  -- every match at once (with a diff preview). Pure Lua; shells out to the
  -- ripgrep installed by bootstrap-lite.sh.
  --   <leader>sr  open, search prefilled with the word under the cursor
  --   <leader>sr  (visual) operate only within the selected range
  --   inside the buffer: <localleader> shows the action keys; default keymaps
  --   are documented at :help grug-far-actions.
  {
    'MagicDuck/grug-far.nvim',
    cmd = 'GrugFar',
    keys = {
      { '<leader>sr', function() require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } }) end,
        mode = 'n', desc = '[S]earch and [R]eplace (project-wide)' },
      { '<leader>sr', function() require('grug-far').open({ visualSelectionUsage = 'operate-within-range' }) end,
        mode = 'v', desc = '[S]earch and [R]eplace (within selection)' },
    },
    opts = {},
  },

  -- Fuzzy finder. No telescope-fzf-native here (that one needs `make`); the
  -- built-in Lua sorter is plenty fast for a single box, and live_grep still
  -- shells out to the ripgrep installed by bootstrap-lite.sh.
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local t = require('telescope')
      t.setup({})
      local b = require('telescope.builtin')
      map('n', '<leader>ff', b.find_files, { desc = '[F]ind [F]iles' })
      map('n', '<leader>fg', b.live_grep, { desc = '[F]ind by [G]rep' })
      map('n', '<leader>fb', b.buffers, { desc = '[F]ind [B]uffers' })
      map('n', '<leader>fh', b.help_tags, { desc = '[F]ind [H]elp' })
      map('n', '<leader>fr', b.oldfiles, { desc = '[F]ind [R]ecent' })
      -- Searchable "menu" of everything nvim can do: every :command and every
      -- mapped key, fuzzy-filtered. <CR> runs the command / feeds the keys.
      map('n', '<leader>fc', b.commands, { desc = '[F]ind [C]ommand (menu)' })
      map('n', '<leader>fk', b.keymaps, { desc = '[F]ind [K]eymap (menu)' })
      -- Theme picker: scroll the list to preview each colorscheme live,
      -- <CR> applies it for this session. Make it permanent by setting the
      -- `theme` variable near the top of this file.
      map('n', '<leader>th', function() b.colorscheme({ enable_preview = true }) end,
        { desc = '[T]heme picker (live preview)' })
    end,
  },
}, {
  ui = { border = 'rounded' },
  checker = { enabled = false },
})
