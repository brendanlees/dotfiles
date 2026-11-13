-- Standalone editor config for constrained hosts, such as the Home Assistant
-- SSH add-on. Selected with NVIM_APPNAME=nvim-minimal by the minimal role.
-- Also used on homelab servers. Uses Neovim's built-in plugin manager with
-- mini.nvim, snacks.nvim, fff, indent-blankline, treesitter-context, nui.nvim
-- and noice; each is optional.

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

-- Compose files get their own filetype so the compose server attaches; they
-- still use the YAML parser and server.
vim.filetype.add {
  pattern = {
    [".*/compose[%w%.%-]*%.ya?ml"] = "yaml.docker-compose",
    [".*/docker%-compose[%w%.%-]*%.ya?ml"] = "yaml.docker-compose",
  },
}
vim.treesitter.language.register("yaml", "yaml.docker-compose")

-- Servers come from mise on homelab hosts and from the host's packages
-- elsewhere. Each one starts only if its command is installed.
local servers = {
  yamlls = {
    cmd = { "yaml-language-server", "--stdio" },
    filetypes = { "yaml", "yaml.docker-compose" },
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
  },
  docker_compose = {
    cmd = { "docker-compose-langserver", "--stdio" },
    filetypes = { "yaml.docker-compose" },
    root_markers = { "compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml", ".git" },
  },
  dockerls = { cmd = { "docker-langserver", "--stdio" }, filetypes = { "dockerfile" }, root_markers = { ".git" } },
  bashls = { cmd = { "bash-language-server", "start" }, filetypes = { "sh", "bash" }, root_markers = { ".git" } },
  jsonls = { cmd = { "vscode-json-language-server", "--stdio" }, filetypes = { "json", "jsonc" }, root_markers = { ".git" } },
  taplo = { cmd = { "taplo", "lsp", "stdio" }, filetypes = { "toml" }, root_markers = { ".taplo.toml", ".git" } },
  lua_ls = {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".git" },
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        telemetry = { enable = false },
      },
    },
  },
}
for name, config in pairs(servers) do
  vim.lsp.config(name, config)
  if vim.fn.executable(config.cmd[1]) == 1 then vim.lsp.enable(name) end
end

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

-- fff ships a prebuilt library for each platform. Download it without fff's
-- cargo fallback, since these hosts have no Rust. Its musl build fails to load
-- on Alpine, so musl hosts use the snacks file picker instead.
local function is_musl()
  local ok, result = pcall(function() return vim.system({ "ldd", "--version" }, { text = true }):wait() end)
  return ok and ((result.stdout or "") .. (result.stderr or "")):find "musl" ~= nil
end
local use_fff = not is_musl()
local fff_downloading = false
local function fff_download()
  fff_downloading = true
  pcall(function() require("fff.download").download_binary() end)
end
-- PackChanged and vim.pack need Neovim 0.12; older versions run without plugins.
pcall(vim.api.nvim_create_autocmd, "PackChanged", {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "fff" and (kind == "install" or kind == "update") then
      if not ev.data.active then vim.cmd.packadd "fff" end
      fff_download()
    end
  end,
})

-- Plugins are optional: the editor still works if GitHub is unreachable.
local plugins = {
  { src = "https://github.com/nvim-mini/mini.nvim", version = "stable" },
  "https://github.com/lukas-reineke/indent-blankline.nvim",
  "https://github.com/TheGLander/indent-rainbowline.nvim",
  "https://github.com/folke/snacks.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter-context",
  "https://github.com/MunifTanjim/nui.nvim",
  "https://github.com/folke/noice.nvim",
}
if use_fff then
  -- Follow release tags, which have prebuilt libraries, not untagged commits.
  table.insert(plugins, { src = "https://github.com/dmtrKovalenko/fff", version = vim.version.range "*" })
end
if vim.pack then pcall(vim.pack.add, plugins, { confirm = false }) end

local has_mini = pcall(require, "mini.icons")
local has_snacks, Snacks = pcall(require, "snacks")

-- The library is missing if a previous download was interrupted.
local function has_fff()
  if not use_fff then return false end
  local ok, download = pcall(require, "fff.download")
  return ok and vim.uv.fs_stat(download.get_binary_path()) ~= nil
end
if not fff_downloading and pcall(require, "fff.download") and not has_fff() then fff_download() end

-- Rainbow indent guides, matching the full AstroNvim config.
if pcall(require, "ibl") and pcall(require, "indent-rainbowline") then
  require("ibl").setup(require("indent-rainbowline").make_opts {
    indent = { char = "│" },
    scope = { enabled = false },
    whitespace = { remove_blankline_trail = true },
  })
end

if has_snacks then
  Snacks.setup {
    bigfile = { enabled = true },
    picker = {
      enabled = true,
      layout = { preset = "ivy" },
      sources = {
        buffers = {
          focus = "list",
          actions = {
            buffer_visit = {
              action = function(picker, item)
                if item then vim.api.nvim_win_set_buf(picker.main, item.buf) end
              end,
              desc = "Show buffer without closing picker",
            },
          },
          win = {
            input = { keys = { d = "bufdelete", g = "buffer_visit", gg = false } },
            list = { keys = { d = "bufdelete", dd = false, g = "buffer_visit", gg = false } },
          },
        },
        explorer = {
          hidden = true,
          ignored = true,
          layout = { layout = { position = "right" } },
        },
      },
      win = {
        input = {
          keys = {
            ["<c-;>"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["<c-l>"] = { "preview_scroll_down", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["<c-l>"] = "preview_scroll_up",
            ["<c-;>"] = "preview_scroll_down",
          },
        },
      },
    },
    lazygit = { enabled = true },
    terminal = { enabled = true },
  }
end

local has_treesitter_context, treesitter_context = pcall(require, "treesitter-context")
if has_treesitter_context then pcall(treesitter_context.setup) end

local has_noice, noice = pcall(require, "noice")
if has_noice then
  pcall(noice.setup, {
    cmdline = {
      format = {
        search_down = { view = "cmdline_popup", opts = { position = { row = "50%", col = "50%" } } },
        search_up = { view = "cmdline_popup", opts = { position = { row = "50%", col = "50%" } } },
      },
    },
    messages = { enabled = true, view = "mini", view_error = "mini", view_warn = "mini" },
    notify = { enabled = false },
    popupmenu = { enabled = false },
    lsp = {
      progress = { enabled = false },
      hover = { enabled = false },
      signature = { enabled = false },
      message = { enabled = false },
    },
    presets = {
      bottom_search = false,
      command_palette = true,
      long_message_to_split = false,
      lsp_doc_border = false,
      inc_rename = false,
    },
  })
end

if has_mini then
  -- Glyph icons need a Nerd Font in the local terminal.
  require("mini.icons").setup()
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
      { mode = "n", keys = "<Leader>g", desc = "+Git" },
      { mode = "n", keys = "<Leader>l", desc = "+LSP" },
      { mode = "n", keys = "<Leader>t", desc = "+Terminal" },
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

-- Files use fff when its library is present, then the snacks picker, then :find.
local function find_files()
  if has_fff() then
    require("fff").find_files()
  elseif has_snacks then
    Snacks.picker.files()
  else
    vim.api.nvim_feedkeys(":find ", "n", false)
  end
end
if not has_snacks then o.path:append "**" end
map("n", "<Leader>ff", find_files, { desc = "Find files" })

if has_snacks then
  map("n", "gb", function() Snacks.picker.buffers() end, { desc = "Manage buffers" })
  map("n", "<Leader>fw", function() Snacks.picker.grep() end, { desc = "Find words" })
  map("n", "<Leader>fb", function() Snacks.picker.buffers() end, { desc = "Find buffers" })
  map("n", "<Leader>fo", function() Snacks.picker.recent() end, { desc = "Find recent files" })
  map("n", "<Leader>fh", function() Snacks.picker.help() end, { desc = "Find help" })
  map("n", "<Leader>fr", function() Snacks.picker.resume() end, { desc = "Resume last picker" })
  map("n", "<Leader>ls", function() Snacks.picker.lsp_symbols() end, { desc = "Document symbols" })
  if vim.fn.executable "lazygit" == 1 then
    map("n", "<Leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
  end
  if vim.fn.executable "lazydocker" == 1 then
    map("n", "<Leader>td", function() Snacks.terminal "lazydocker" end, { desc = "Lazydocker" })
  end
  map("n", "<Leader>tf", function() Snacks.terminal() end, { desc = "Floating terminal" })
end

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
    vim.schedule(find_files)
  end,
})
if has_snacks then
  map("n", "<Leader>e", function() Snacks.picker.explorer() end, { desc = "File explorer" })
else
  map("n", "<Leader>e", "<Cmd>Explore<CR>", { desc = "File explorer (netrw)" })
end
