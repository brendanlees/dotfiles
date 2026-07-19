-- Adapted from vim-herdr-navigation at the commit pinned in .chezmoidata/herdr.yml.
-- Loaded after plugins so these mappings override vim-tmux-navigator.
local function navigate(wincmd, dir)
  local previous = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= previous then return end

  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
    local herdr = vim.env.HERDR_BIN_PATH
    if not herdr or herdr == "" then herdr = "herdr" end
    vim.fn.system { herdr, "pane", "focus", "--direction", dir, "--current" }
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux_direction = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux_direction[dir])
  end
end

local function map(lhs, wincmd, dir)
  vim.keymap.set("n", lhs, function() navigate(wincmd, dir) end, {
    silent = true,
    noremap = true,
    desc = "Navigate " .. dir .. " (vim/herdr)",
  })
end

map("<C-h>", "h", "left")
map("<C-j>", "j", "down")
map("<C-k>", "k", "up")
map("<C-l>", "l", "right")
