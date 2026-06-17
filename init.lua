--[[ init.lua — kickstart-flavored Neovim config
  A small, readable, single-file setup. lazy.nvim bootstraps everything on
  first launch, so on a fresh machine you just run `nvim` and wait.
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

-- Buffers act as nvim's "tabs" (tmux windows are the real tabs).
-- H / L cycle buffers; <leader>bd closes the current one.
map('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
map('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
map('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = '[B]uffer [D]elete' })

-- File explorer (nvim-tree, configured below): toggle the sidebar / reveal file.
map('n', '<leader>e', '<cmd>NvimTreeToggle<CR>', { desc = 'File [E]xplorer' })
map('n', '<leader>ef', '<cmd>NvimTreeFindFile<CR>', { desc = '[E]xplorer: [F]ind current file' })

-- Save / quit
map('n', '<leader>w', '<cmd>write<CR>', { desc = '[W]rite (save) file' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = '[Q]uit window' })
map('n', '<C-s>', '<cmd>write<CR>', { desc = 'Save file' })

-- Real nvim tab pages (separate from buffers/tmux windows).
-- Cycle them with the built-in gt / gT.
map('n', '<leader>tn', '<cmd>tabnew<CR>', { desc = '[T]ab [N]ew' })
map('n', '<leader>tc', '<cmd>tabclose<CR>', { desc = '[T]ab [C]lose' })

-- ────────────────────────── Bootstrap lazy.nvim ──────────────────────
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ────────────────────────────── Plugins ──────────────────────────────
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
    opts = { options = { theme = theme, section_separators = '', component_separators = '|' } },
  },

  -- Bufferline: shows open files (buffers) as tabs along the top.
  {
    'akinsho/bufferline.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    opts = { options = { diagnostics = 'nvim_lsp', show_buffer_close_icons = false } },
  },

  -- File explorer sidebar (pure Lua, no build step).
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

  -- Fuzzy finder (uses fzf + ripgrep installed by bootstrap.sh)
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
      local t = require('telescope')
      t.setup({})
      pcall(t.load_extension, 'fzf')
      local b = require('telescope.builtin')
      map('n', '<leader>ff', b.find_files, { desc = '[F]ind [F]iles' })
      map('n', '<leader>fg', b.live_grep, { desc = '[F]ind by [G]rep' })
      map('n', '<leader>fb', b.buffers, { desc = '[F]ind [B]uffers' })
      map('n', '<leader>fh', b.help_tags, { desc = '[F]ind [H]elp' })
      map('n', '<leader>fr', b.oldfiles, { desc = '[F]ind [R]ecent' })
      -- Theme picker: scroll the list to preview each colorscheme live,
      -- <CR> applies it for this session. Make it permanent by setting the
      -- `theme` variable near the top of this file.
      map('n', '<leader>th', function() b.colorscheme({ enable_preview = true }) end,
        { desc = '[T]heme picker (live preview)' })
    end,
  },

  -- Treesitter: better syntax highlighting & indentation
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master', -- stable API; the default 'main' branch dropped .configs
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = {
        'bash', 'c', 'cpp', 'lua', 'markdown', 'markdown_inline', 'vim', 'vimdoc',
        'python', 'json', 'yaml', 'typescript', 'javascript', 'tsx', 'vue', 'html', 'css',
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  -- LSP: language servers managed by mason, configured by lspconfig
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'williamboman/mason.nvim', opts = {} },
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
          local bufmap = function(keys, fn, desc)
            map('n', keys, fn, { buffer = ev.buf, desc = 'LSP: ' .. desc })
          end
          bufmap('gd', require('telescope.builtin').lsp_definitions, 'Goto definition')
          bufmap('gr', require('telescope.builtin').lsp_references, 'Goto references')
          bufmap('K', vim.lsp.buf.hover, 'Hover docs')
          bufmap('<leader>rn', vim.lsp.buf.rename, 'Rename')
          bufmap('<leader>ca', vim.lsp.buf.code_action, 'Code action')
        end,
      })
      require('mason-lspconfig').setup({
        ensure_installed = {
          'lua_ls', 'bashls',
          'pyright',   -- Python
          'clangd',    -- C and C++
          'ts_ls',     -- TypeScript / JavaScript
          'vue_ls',    -- Vue (SFCs)
          'marksman',  -- Markdown
        },
      })
    end,
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      { 'L3MON4D3/LuaSnip', build = 'make install_jsregexp' },
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        snippet = { expand = function(a) require('luasnip').lsp_expand(a.body) end },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping.select_next_item(),
          ['<S-Tab>'] = cmp.mapping.select_prev_item(),
        }),
        sources = {
          { name = 'nvim_lsp' }, { name = 'luasnip' },
          { name = 'buffer' }, { name = 'path' },
        },
      })
    end,
  },
}, {
  ui = { border = 'rounded' },
  checker = { enabled = false },
})
