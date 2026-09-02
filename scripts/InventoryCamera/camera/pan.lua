---@omw-context player
-- Smoothly tweens the camera between two poses over time. Advanced every
-- frame from player.lua's onUpdate. Knows nothing about inventory/preview
-- state or settings storage - callers pass in whatever it needs, including
-- *how* each tick's pose should be applied (see applyFn below), since a
-- given pan might run while the camera is in Static mode (needs
-- pose.apply/setStaticPosition) or back in a tracked mode (needs the
-- normal setYaw/setPreferredThirdPersonDistance/etc setters).

local camera = require('openmw.camera')
local core = require('openmw.core')

local state = {
    running = false,
    applyFn = nil,
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
    -- Last pose actually applied, kept around so callers can hold the
    -- camera steady (re-anchored to the actor each frame) when no pan is
    -- running - Static mode won't do that on its own.
    curYaw = 0,
    curPitch = 0,
    curRoll = 0,
    curDistance = 0,
    curOffset = nil,
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
--- target pose, applying each tick via applyFn(yaw, pitch, roll, distance,
--- offset). fromDistance/fromOffset are passed explicitly rather than
--- inferred, since the caller is the one keeping track of what the
--- "current" distance/offset conceptually are (especially under Static
--- mode, where the camera itself has no notion of either).
function M.start(applyFn, toYaw, toPitch, toRoll, fromDistance, toDistance, fromOffset, toOffset, duration)
    state.running = true
    state.applyFn = applyFn
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

    state.curYaw, state.curPitch, state.curRoll = state.fromYaw, state.fromPitch, state.fromRoll
    state.curDistance, state.curOffset = fromDistance, fromOffset
end

function M.stop()
    state.running = false
end

function M.isRunning()
    return state.running
end

--- Current yaw/pitch/roll/distance/offset last applied (whether from an
--- in-progress pan or the pose it last landed on). Use with reapply() to
--- hold the camera steady between explicit pans.
function M.getPose()
    return state.curYaw, state.curPitch, state.curRoll, state.curDistance, state.curOffset
end

--- Reapplies the last known pose via the same applyFn used by the most
--- recent pan. Since Static mode never follows the actor on its own, call
--- this every frame the Static camera is active and no pan is running, so
--- the view stays anchored if the actor moves. No-op if no applyFn has
--- been set yet (i.e. M.start was never called).
function M.reapply()
    if not state.applyFn then return end
    state.applyFn(state.curYaw, state.curPitch, state.curRoll, state.curDistance, state.curOffset)
end

-- Ignores the dt passed in on purpose: this drives a menu-camera effect
-- that must keep animating while the world is paused (e.g. while the
-- inventory is open), and onFrame's simulation dt is forced to 0 whenever
-- core.isWorldPaused() is true. Real frame duration keeps ticking
-- regardless, so the pan uses that instead.
function M.update(yawPanDirection)
    if not state.running then return end

    local dt = core.getRealFrameDuration()
    state.elapsed = state.elapsed + dt
    local t = math.min(state.elapsed / state.duration, 1)
    local eased = t * t * (3 - 2 * t) -- smoothstep

    local yD = yawDelta(state.fromYaw, state.toYaw, yawPanDirection)
    local yaw = state.fromYaw + yD * eased
    local pitch = state.fromPitch + (state.toPitch - state.fromPitch) * eased
    local roll = state.fromRoll + (state.toRoll - state.fromRoll) * eased
    local distance = state.fromDistance + (state.toDistance - state.fromDistance) * eased
    local offset = state.fromOffset + (state.toOffset - state.fromOffset) * eased

    state.applyFn(yaw, pitch, roll, distance, offset)
    state.curYaw, state.curPitch, state.curRoll = yaw, pitch, roll
    state.curDistance, state.curOffset = distance, offset

    if t >= 1 then
        state.running = false
    end
end

return M
