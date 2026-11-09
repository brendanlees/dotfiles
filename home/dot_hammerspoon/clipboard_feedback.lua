local feedback = {}

local function dispatch()
    if feedback.task or not feedback.pending then
        return
    end

    local arguments = feedback.pending
    feedback.pending = nil
    feedback.task = hs.task.new("/opt/homebrew/bin/sketchybar", function()
        feedback.task = nil
        dispatch()
    end, arguments)
    if feedback.task and not feedback.task:start() then
        feedback.task = nil
    end
end

local function setItem(label, drawing)
    -- Serialize processes, keeping only the latest complete state while one runs.
    feedback.pending = {
        "--set", "clipboard_feedback", "label=" .. label, "drawing=" .. drawing,
        "--set", "clipboard_balance", "drawing=" .. drawing,
    }
    dispatch()
end

-- Reloading discards the old hide timer, so clear any lingering feedback.
setItem("", "off")

local function show(label)
    if feedback.hideTimer then
        feedback.hideTimer:stop()
    end
    setItem(label, "on")
    feedback.hideTimer = hs.timer.doAfter(1, function()
        setItem("", "off")
        feedback.hideTimer = nil
    end)
end

feedback.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0
        or not event:getFlags():containExactly({ "cmd" }) then
        return false
    end

    local key = event:getKeyCode()
    local label
    if key == hs.keycodes.map.x then
        label = "Cut"
    elseif key == hs.keycodes.map.c then
        label = "Copied"
    elseif key == hs.keycodes.map.v then
        label = "Pasted"
    else
        return false
    end

    -- A newer action supersedes any pending clipboard confirmation.
    if feedback.pollTimer then
        feedback.pollTimer:stop()
        feedback.pollTimer = nil
    end

    if label == "Pasted" then
        show(label)
    else
        local count = hs.pasteboard.changeCount()
        local checks = 0
        feedback.pollTimer = hs.timer.doEvery(0.05, function()
            checks = checks + 1
            local changed = hs.pasteboard.changeCount() ~= count
            if changed or checks >= 12 then
                feedback.pollTimer:stop()
                feedback.pollTimer = nil
                if changed then
                    show(label)
                end
            end
        end)
    end
    return false
end):start()

-- macOS can disable a tap after a timeout.
feedback.watchdog = hs.timer.doEvery(5, function()
    if not feedback.tap:isEnabled() then
        feedback.tap:start()
    end
end)

return feedback
