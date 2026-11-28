-- Migrated from tmux, Herdr and Ghostty. Prefix is ctrl+b.

-- Let programs that use ctrl+b themselves still receive it.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux (Herdr wins on keys both bind, by decision)
rex.bind("ctrl+b>j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+b>k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+b>l", "pane.resize", { amount = 5, direction = "right" })
rex.bind("ctrl+b>h", "pane.resize", { amount = 5, direction = "left" })

-- tmux bind -r: repeatable resize mode, ctrl+b ctrl+r to enter, enter or escape to leave
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+b>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")
rex.bind("repeat/j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("repeat/l", "pane.resize", { amount = 5, direction = "right" })
rex.bind("repeat/h", "pane.resize", { amount = 5, direction = "left" })

-- tmux swap-window, which Rex has as moving the tab
rex.bind("ctrl+alt+shift+h", "client.tab.move.backward")
rex.bind("ctrl+alt+shift+l", "client.tab.move.forward")

-- ctrl+h/j/k/l move between panes unless the pane's foreground program uses
-- the key, as Herdr's pi-navigation.sh and vim-herdr-navigation did. nvim
-- hands off to Rex itself at the edge of its own splits; pi uses ctrl+j/k
-- for its lists.
local nav_keys = { left = "ctrl+h", down = "ctrl+j", up = "ctrl+k", right = "ctrl+l" }
local nav_owners = {
  left = { nvim = true },
  right = { nvim = true },
  down = { nvim = true, pi = true },
  up = { nvim = true, pi = true },
}
rex.action{
  name = "smart_focus",
  title = "Focus Pane or Pass Key",
  args = { direction = "string" },
  run = function(ctx, args)
    local proc = ctx.block_id and rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
    local name = proc and proc.foreground and proc.foreground.name
    if name and nav_owners[args.direction][name] then
      rex.client.queue("pane.send_key", { key = nav_keys[args.direction] })
    else
      rex.client.queue("pane.focus", { direction = args.direction })
    end
  end,
}
for direction, key in pairs(nav_keys) do
  rex.bind(key, "smart_focus", { direction = direction })
end

-- Herdr
rex.bind("ctrl+b>r", "client.config.reload")
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>,", "client.tab.rename")
rex.bind("ctrl+b>p", "client.tab.previous")
rex.bind("ctrl+shift+h", "client.tab.previous")
rex.bind("ctrl+b>n", "client.tab.next")
rex.bind("ctrl+shift+l", "client.tab.next")
-- Herdr's prefix+L toggled the last workspace; Rex has no last-used toggle.
rex.bind("ctrl+b>shift+l", "client.tab.previous")
-- Stands in for Herdr's prefix+t "jump to anything".
rex.bind("ctrl+b>g", "pane.go_to")
rex.bind("ctrl+b>b", "client.sidebar.toggle")
rex.bind("ctrl+b>shift+n", "session.new")
-- Rex's copy mode already uses vi keys (v selects, y yanks).
rex.bind("ctrl+b>[", "pane.copy_mode.enter")
-- Stand-ins for tmux's agent-next.sh and the sesh/herdr-plus project pickers.
rex.bind("ctrl+b>shift+a", "pane.view_activity")
rex.bind("ctrl+b>shift+k", "pane.go_to_directory")
rex.bind("ctrl+b>1", "client.tab.goto", { index = 1 })
rex.bind("ctrl+b>2", "client.tab.goto", { index = 2 })
rex.bind("ctrl+b>3", "client.tab.goto", { index = 3 })
rex.bind("ctrl+b>4", "client.tab.goto", { index = 4 })
rex.bind("ctrl+b>5", "client.tab.goto", { index = 5 })
rex.bind("ctrl+b>6", "client.tab.goto", { index = 6 })
rex.bind("ctrl+b>7", "client.tab.goto", { index = 7 })
rex.bind("ctrl+b>8", "client.tab.goto", { index = 8 })
rex.bind("ctrl+b>9", "client.tab.goto", { index = 9 })
rex.bind("ctrl+b>shift+7", "client.tab.close")
rex.bind("ctrl+b>shift+5", "pane.split", { direction = "right" })
rex.bind("ctrl+b>shift+'", "pane.split", { direction = "down" })
rex.bind("ctrl+b>x", "pane.close")
rex.bind("ctrl+b>z", "pane.zoom")
rex.bind("ctrl+f", "pane.zoom")

-- Ghostty
rex.bind("shift+cmd+,", "client.config.reload")
