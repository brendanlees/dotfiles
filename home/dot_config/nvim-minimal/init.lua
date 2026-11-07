-- Standalone editor config for constrained hosts, such as the Home Assistant
-- SSH add-on. Selected with NVIM_APPNAME=nvim-minimal by the minimal role.
-- Uses Neovim's built-in plugin manager and one plugin, mini.nvim.

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
-- is compiled here. Filetypes without a parser keep regex highlighting.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args) pcall(vim.treesitter.start, args.buf) end,
})

-- ------------------------------------------
-- indent guides
-- ------------------------------------------

-- Draw a guide at every indent level with 'listchars', sized to each buffer's
-- shiftwidth. mini.indentscope highlights the current block on top.
local function set_indent_guides()
  local width = math.max(vim.fn.shiftwidth(), 1)
  vim.opt_local.listchars = {
    tab = "│ ",
    trail = "·",
    nbsp = "␣",
    leadmultispace = "│" .. string.rep(" ", width - 1),
  }
end
o.list = true
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, { callback = set_indent_guides })
vim.api.nvim_create_autocmd("OptionSet", { pattern = { "shiftwidth", "tabstop" }, callback = set_indent_guides })

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
local has_mini = pcall(vim.pack.add, {
  { src = "https://github.com/nvim-mini/mini.nvim", version = "stable" },
}, { confirm = false })
has_mini = has_mini and pcall(require, "mini.pick")

if has_mini then
  require("mini.icons").setup { style = "ascii" }
  require("mini.pick").setup()
  require("mini.files").setup()
  require("mini.statusline").setup()
  local indentscope = require "mini.indentscope"
  indentscope.setup { symbol = "│", draw = { animation = indentscope.gen_animation.none() } }

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
  map("n", "<Leader>e", function()
    local files = require "mini.files"
    local path = vim.api.nvim_buf_get_name(0)
    if not files.close() then files.open(vim.uv.fs_stat(path) and path or nil) end
  end, { desc = "Toggle file explorer" })
else
  -- Built-in fallbacks: netrw and :find.
  o.path:append "**"
  map("n", "<Leader>ff", ":find ", { desc = "Find files" })
  map("n", "<Leader>e", "<Cmd>Explore<CR>", { desc = "File explorer" })
end
