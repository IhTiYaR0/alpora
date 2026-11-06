-- Live trackpad callbacks. Native socket2 events: no shell/process per frame.
-- Return independent callbacks for each directional registration.
return function(direction)
    assert(direction == "up" or direction == "down")
    local sign = direction == "up" and 1 or -1
    local sequence, distance, ident = 0, 0, nil
    local nonce = tostring({}):gsub("[^%w]", "")
    local function send(phase, e)
        if not ident then return end
        hl.dispatch(hl.dsp.event(string.format(
            "poly-overview-swipe,v1,%s,%s,%d,%.3f,%d,%d",
            ident, phase, sign, distance, e.time_ms or 0, e.cancelled and 1 or 0)))
    end
    local function accumulate(e)
        distance = math.max(-360, math.min(360, distance - ((e.delta and e.delta.y) or 0)))
    end
    return {
        start = function(e)
            sequence = sequence + 1
            ident = nonce .. "-" .. sequence
            distance = 0
            accumulate(e)
            send("start", e)
        end,
        update = function(e)
            if not ident then return end
            accumulate(e)
            send("update", e)
        end,
        finish = function(e)
            send("finish", e)
            ident = nil
        end,
    }
end
