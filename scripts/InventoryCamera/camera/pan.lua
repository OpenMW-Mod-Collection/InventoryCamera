---@omw-context player
-- Smoothly tweens the camera between two poses over time. Advanced every
-- frame from player.lua's onUpdate. Knows nothing about inventory/preview
-- state or settings storage - callers pass in whatever it needs.

local camera = require('openmw.camera')

local state = {
    running = false,
    elapsed = 0,
    duration = 0,
    fromYaw = 0,
    toYaw = 0,
    fromPitch = 0,
    toPitch = 0,
    fromRoll = 0,
    toRoll = 0,
    fromDistance = 0,
    toDistance = 0,
    fromOffset = nil,
    toOffset = nil,
}

local M = {}

-- Shortest signed angular distance from a to b, wrapped to [-pi, pi]
local function angleDelta(a, b)
    return ((b - a + math.pi) % (2 * math.pi)) - math.pi
end

-- Angular distance from a to b honoring yawPanDirection: "Auto (shortest)"
-- behaves like angleDelta above; "Clockwise"/"Counter-clockwise" force the
-- sweep to always go that way around, even if it's the long way round.
local function yawDelta(a, b, yawPanDirection)
    if a == b then
        return 0
    end

    local direction = yawPanDirection == "yawPanDirection_random"
        and ({ "yawPanDirection_CW", "yawPanDirection_CCW" })[math.random(2)]
        or yawPanDirection

    if direction == "yawPanDirection_CW" then
        return (b - a) % (2 * math.pi)                 -- always in [0, 2*pi)
    elseif direction == "yawPanDirection_CCW" then
        return ((b - a) % (2 * math.pi)) - 2 * math.pi -- always in (-2*pi, 0]
    else
        return angleDelta(a, b)
    end
end

--- Starts a pan from the camera's current yaw/pitch/roll to the given
--- target pose. fromDistance/fromOffset are passed explicitly rather than
--- queried from the camera: getThirdPersonDistance()/getFocalPreferredOffset()
--- return the actual, simulated value, which can lag a frame or more behind
--- what was just set (e.g. reading back near-0 right after a mode switch).
function M.start(toYaw, toPitch, toRoll, fromDistance, toDistance, fromOffset, toOffset, duration)
    state.running = true
    state.elapsed = 0
    state.duration = math.max(duration, 0.001)
    state.fromYaw = camera.getYaw()
    state.fromPitch = camera.getPitch()
    state.fromRoll = camera.getRoll()
    state.fromDistance = fromDistance
    state.fromOffset = fromOffset
    state.toYaw = toYaw
    state.toPitch = toPitch
    state.toRoll = toRoll
    state.toDistance = toDistance
    state.toOffset = toOffset
end

function M.stop()
    state.running = false
end

function M.isRunning()
    return state.running
end

function M.update(dt, yawPanDirection)
    if not state.running then return end

    state.elapsed = state.elapsed + dt
    local t = math.min(state.elapsed / state.duration, 1)
    local eased = t * t * (3 - 2 * t) -- smoothstep

    local yD = yawDelta(state.fromYaw, state.toYaw, yawPanDirection)
    camera.setYaw(state.fromYaw + yD * eased)
    camera.setPitch(state.fromPitch + (state.toPitch - state.fromPitch) * eased)
    camera.setRoll(state.fromRoll + (state.toRoll - state.fromRoll) * eased)
    camera.setPreferredThirdPersonDistance(state.fromDistance + (state.toDistance - state.fromDistance) * eased)
    camera.setFocalPreferredOffset(state.fromOffset + (state.toOffset - state.fromOffset) * eased)
    -- Drive the offset ourselves rather than relying on the engine's own
    -- built-in smoothing (which appears to stall while the game is paused).
    camera.instantTransition()

    if t >= 1 then
        state.running = false
    end
end

return M
