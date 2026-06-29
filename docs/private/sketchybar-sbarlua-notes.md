# SketchyBar / SbarLua Notes

## Context

I am likely to do a lot more customization in `dot_config/sketchybar/executable_sketchybarrc` and related `dot_config/sketchybar/items/*.sh` / `plugins/*` files. SbarLua could be a useful future project both for improving the config structure and for getting more comfortable with Lua.

SbarLua: <https://github.com/FelixKratz/SbarLua>

## Short recommendation

Do not do a big-bang rewrite yet. Keep the current shell-based SketchyBar config working, but consider migrating incrementally to SbarLua as new customizations become more stateful, repetitive, or event-driven.

A hybrid approach is probably best at first: keep shell scripts where they are simple, and use Lua for new or complex items where callbacks, shared helpers, async command execution, and state management would make the config clearer.

## Why SbarLua may be worth using

SbarLua wraps the SketchyBar API in Lua using IPC, without requiring changes to SketchyBar itself. It gives a more structured API around the same SketchyBar concepts:

```lua
local item = sbar.add("item", "front_app", {
  icon = { drawing = false },
  label = { string = "" },
})

item:subscribe("front_app_switched", function(env)
  item:set({ label = { string = env.INFO } })
end)
```

Potential benefits:

- **Cleaner structure:** Lua tables map naturally to SketchyBar's nested properties, avoiding long shell commands with lots of quoting.
- **Better event locality:** item creation, configuration, and event callbacks can live together.
- **Stateful logic is easier:** Lua is more comfortable than shell for shared state, helper functions, branching logic, and reusable modules.
- **Async command execution:** SbarLua recommends `sbar.exec(...)` instead of blocking shell calls like `os.execute` / `io.popen`, which matters for event-handler responsiveness.
- **Good learning project:** It is practical Lua, tied to a real config I use daily.

## Downsides / cautions

- The upstream README describes SbarLua as **early development**, so there may be churn or rough edges.
- It adds a dependency and setup step: building/installing the Lua module, then ensuring Lua can find it via `package.cpath`.
- Shell will not disappear entirely. Existing plugins call tools like Aerospace, Tailscale, AppleScript/Spotify, backup/sync scripts, etc. Lua can orchestrate these, but external commands remain part of the system.
- Plain shell config is still first-class SketchyBar usage: SketchyBar expects `~/.config/sketchybar/sketchybarrc` to be a regular executable script.

## Current config fit

The current root config is already fairly tidy:

- `dot_config/sketchybar/executable_sketchybarrc` is modular and sources `items/*.sh`.
- Most complexity appears to live in item/plugin scripts, not the root config.
- This means an incremental migration is low-risk: port one item at a time rather than rewriting everything.

Good candidates for early migration:

1. Bar/default settings.
2. Shared helpers such as spacers/pill styling.
3. Simple items like `front_app`, `battery`, or `tailscale`.
4. More complex/stateful items later, such as `spaces`, `calendar`, `spotify`, sync/backup status.

## Possible migration path

1. Create a Lua sketchybarrc experiment in a branch/worktree.
2. Reproduce only the bar/default styling first.
3. Port one simple item and verify reload behavior.
4. Keep plugin shell scripts callable via `sbar.exec` where appropriate.
5. Move shared colors/icons/settings into Lua modules.
6. Once comfortable, port event-heavy items and reduce shell glue.

## Source references

- SbarLua repository and README: <https://github.com/FelixKratz/SbarLua>
- SbarLua example config: <https://github.com/FelixKratz/SbarLua/tree/main/example>
- SketchyBar bar configuration docs: <https://felixkratz.github.io/SketchyBar/config/bar>
- SketchyBar item configuration docs: <https://felixkratz.github.io/SketchyBar/config/items>
