local sketchybar = {}

-- Each queue runs one sketchybar process at a time and keeps only the latest
-- pending arguments, so updates never land out of order.
function sketchybar.queue()
    local running, pending

    local function dispatch()
        if running or not pending then
            return
        end

        local arguments = pending
        pending = nil
        running = hs.task.new("/opt/homebrew/bin/sketchybar", function()
            running = nil
            dispatch()
        end, arguments)
        if running and not running:start() then
            running = nil
        end
    end

    return function(arguments)
        pending = arguments
        dispatch()
    end
end

return sketchybar
