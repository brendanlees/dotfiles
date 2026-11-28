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

-- Herdr
rex.bind("ctrl+b>r", "client.config.reload")
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>,", "client.tab.rename")
rex.bind("ctrl+b>p", "client.tab.previous")
rex.bind("ctrl+shift+h", "client.tab.previous")
rex.bind("ctrl+b>n", "client.tab.next")
rex.bind("ctrl+shift+l", "client.tab.next")
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
rex.bind("shift+enter", "pane.send_key", { key = "alt+enter" })
