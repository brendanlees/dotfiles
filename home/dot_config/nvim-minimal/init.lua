-- Standalone editor config for constrained hosts, such as the Home Assistant
-- SSH add-on. Selected with NVIM_APPNAME=nvim-minimal by the minimal role.
-- Uses Neovim's built-in plugin manager with mini.nvim and indent-blankline.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ------------------------------------------
-- options
-- ------------------------------------------

local o = vim.opt
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 8
o.wrap = false
o.mouse = "a"
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.splitright = true
o.splitbelow = true
o.undofile = true
o.confirm = true
o.updatetime = 250
-- tmux and SSH often hide true colour support from detection.
o.termguicolors = true
o.completeopt = "menuone,noselect,popup"

-- ------------------------------------------
-- clipboard
-- ------------------------------------------

-- No display server over SSH. Force OSC 52 because tmux can hide the
-- terminal's support from auto-detection. Copy with <Leader>y; paste from the
-- terminal instead of "+p, which some terminals block.
vim.g.clipboard = "osc52"

-- ------------------------------------------
-- treesitter
-- ------------------------------------------

-- Parsers come from Alpine packages (tree-sitter-yaml and friends), so nothing
-- is compiled here. Those packages install their highlight queries under
-- /usr/share/tree-sitter, outside Neovim's runtime path.
if vim.uv.fs_stat "/usr/share/tree-sitter/queries" then o.runtimepath:append "/usr/share/tree-sitter" end

-- Starting treesitter turns regex syntax off, so only start it when there are
-- highlight queries for the language. Otherwise regex highlighting stays on.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
    if ok and query then pcall(vim.treesitter.start, args.buf, lang) end
  end,
})

-- ------------------------------------------
-- indent guides
-- ------------------------------------------

-- indent-blankline draws rainbow guides (see plugins); mini.indentscope
-- highlights the current block on top. Here, only mark stray whitespace.
o.list = true
o.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }

-- ------------------------------------------
-- lsp
-- ------------------------------------------

-- yaml-language-server comes from npm in the host's setup; skip it if absent.
vim.lsp.config("yamlls", {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml" },
  root_markers = { "configuration.yaml", ".git" },
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      keyOrdering = false,
      -- Home Assistant's YAML tags, so they are not reported as errors.
      customTags = {
        "!include scalar",
        "!include_dir_list scalar",
        "!include_dir_named scalar",
        "!include_dir_merge_list scalar",
        "!include_dir_merge_named scalar",
        "!secret scalar",
        "!env_var scalar",
        "!input scalar",
      },
    },
  },
})
if vim.fn.executable "yaml-language-server" == 1 then vim.lsp.enable "yamlls" end

vim.diagnostic.config { virtual_text = true, severity_sort = true }

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    if client:supports_method "textDocument/completion" then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
  end,
})

-- ------------------------------------------
-- plugins
-- ------------------------------------------

-- Plugins are optional: the editor still works if GitHub is unreachable.
pcall(vim.pack.add, {
  { src = "https://github.com/nvim-mini/mini.nvim", version = "stable" },
  "https://github.com/lukas-reineke/indent-blankline.nvim",
  "https://github.com/TheGLander/indent-rainbowline.nvim",
}, { confirm = false })
local has_mini = pcall(require, "mini.pick")

-- Rainbow indent guides, matching the full AstroNvim config.
if pcall(require, "ibl") and pcall(require, "indent-rainbowline") then
  require("ibl").setup(require("indent-rainbowline").make_opts {
    indent = { char = "│" },
    scope = { enabled = false },
    whitespace = { remove_blankline_trail = true },
  })
end

if has_mini then
  -- Glyph icons need a Nerd Font in the local terminal.
  require("mini.icons").setup()
  require("mini.pick").setup()
  require("mini.statusline").setup()
  local indentscope = require "mini.indentscope"
  indentscope.setup { symbol = "│", draw = { animation = indentscope.gen_animation.none() } }
  -- Smooth scrolling only, as in the full config.
  require("mini.animate").setup {
    cursor = { enable = false },
    resize = { enable = false },
    open = { enable = false },
    close = { enable = false },
  }

  local miniclue = require "mini.clue"
  miniclue.setup {
    triggers = {
      { mode = { "n", "x" }, keys = "<Leader>" },
      { mode = { "n", "x" }, keys = "g" },
      { mode = { "n", "x" }, keys = "z" },
      { mode = { "n", "x" }, keys = '"' },
      { mode = { "i", "c" }, keys = "<C-r>" },
      { mode = "n", keys = "<C-w>" },
    },
    clues = {
      { mode = "n", keys = "<Leader>f", desc = "+Find" },
      { mode = "n", keys = "<Leader>l", desc = "+LSP" },
      miniclue.gen_clues.g(),
      miniclue.gen_clues.z(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.windows(),
    },
  }
end

-- ------------------------------------------
-- mappings
-- ------------------------------------------

-- Leader keys follow the AstroNvim config used on other machines.
local map = vim.keymap.set

map("i", "jj", "<Esc>", { desc = "Exit insert mode" })
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

map("n", "<Leader>w", "<Cmd>write<CR>", { desc = "Save" })
map("n", "<Leader>q", "<Cmd>confirm quit<CR>", { desc = "Quit window" })
map("n", "<Leader>Q", "<Cmd>confirm quitall<CR>", { desc = "Quit all" })
map("n", "<Leader>n", "<Cmd>enew<CR>", { desc = "New file" })
map("n", "<Leader>c", "<Cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "]b", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "[b", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<Leader>/", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<Leader>/", "gc", { remap = true, desc = "Toggle comment" })
map({ "n", "x" }, "<Leader>y", '"+y', { desc = "Copy to system clipboard" })

-- Built-in LSP keys also work: K hover, grn rename, gra code action, grr references.
map("n", "<Leader>ld", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<Leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<Leader>lf", vim.lsp.buf.format, { desc = "Format buffer" })
map("n", "]d", function() vim.diagnostic.jump { count = 1, float = true } end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump { count = -1, float = true } end, { desc = "Previous diagnostic" })

if has_mini then
  local pick = require("mini.pick").builtin
  map("n", "<Leader>ff", pick.files, { desc = "Find files" })
  map("n", "<Leader>fw", pick.grep_live, { desc = "Find words" })
  map("n", "<Leader>fb", pick.buffers, { desc = "Find buffers" })
  map("n", "<Leader>fh", pick.help, { desc = "Find help" })
  map("n", "<Leader>fr", pick.resume, { desc = "Resume last picker" })
  -- `nvim <dir>`: change into the directory and open the file picker.
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      local dir = vim.fn.argv(0)
      if vim.fn.argc() ~= 1 or vim.fn.isdirectory(dir) == 0 then return end
      vim.cmd.cd(vim.fn.fnameescape(dir))
      local dir_buf = vim.api.nvim_get_current_buf()
      vim.cmd.enew()
      pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
      -- Wait until startup ends: files opened inside this autocmd would skip
      -- filetype detection, and so highlighting.
      vim.schedule(pick.files)
    end,
  })
else
  -- Built-in fallback for the picker.
  o.path:append "**"
  map("n", "<Leader>ff", ":find ", { desc = "Find files" })
end
map("n", "<Leader>e", "<Cmd>Explore<CR>", { desc = "File explorer (netrw)" })
