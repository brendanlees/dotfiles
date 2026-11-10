-- Drives SketchyBar's microphone indicator: on while any non-virtual input
-- device is in use. A plugged-in USB mic counts as live even before an app
-- opens it.
local microphone = { devices = {} }
local trigger = require("sketchybar").queue()

local function isActive()
    for _, device in ipairs(hs.audiodevice.allInputDevices()) do
        local transport = device:transportType()
        if transport == "USB" or (transport ~= "Virtual" and device:inUse()) then
            return true
        end
    end
    return false
end

local function publish(force)
    local active = isActive()
    if force or active ~= microphone.active then
        microphone.active = active
        trigger({ "--trigger", "microphone_change", "MIC_ACTIVE=" .. (active and "1" or "0") })
    end
end

-- Device IDs change when devices come and go or the Mac wakes, so rewatch all.
local function watchDevices()
    for _, device in ipairs(microphone.devices) do
        device:watcherStop()
    end
    microphone.devices = hs.audiodevice.allInputDevices()
    for _, device in ipairs(microphone.devices) do
        device:watcherCallback(function(_, event)
            if event == "gone" then
                publish()
            end
        end):watcherStart()
    end
    publish()
end

hs.audiodevice.watcher.setCallback(function(event)
    if event == "dev#" then
        watchDevices()
    end
end)
hs.audiodevice.watcher.start()

microphone.wake = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        watchDevices()
    end
end):start()

-- The SketchyBar plugin opens this URL after the bar loads to get the state.
hs.urlevent.bind("microphone-refresh", function()
    publish(true)
end)

watchDevices()

return microphone
