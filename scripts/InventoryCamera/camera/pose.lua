---@omw-context player
-- Static mode doesn't track the player, so there's no built-in notion of
-- "distance from actor" or "offset from actor" the way Preview/ThirdPerson
-- have. This module reproduces that behavior manually: given yaw/pitch,
-- a distance, and a horizontal/vertical offset, it computes the world
-- position the camera should sit at (relative to the actor's tracked head
-- position) and applies it via camera.setStaticPosition.

local camera = require('openmw.camera')
local util = require('openmw.util')

local M = {}

-- View direction for a given yaw/pitch (matches the engine's own convention).
local function direction(yaw, pitch)
    local cosPitch = math.cos(pitch)
    return util.vector3(
        math.sin(yaw) * cosPitch,
        math.cos(yaw) * cosPitch,
        -math.sin(pitch)
    )
end

-- Horizontal "right" vector at a given yaw, used to interpret offset.x the
-- same way the built-in third-person camera does (positive = right of the
-- character). Offset.y is applied along world-up.
local function rightVector(yaw)
    return util.vector3(math.cos(yaw), -math.sin(yaw), 0)
end

local UP = util.vector3(0, 0, 1)

--- Computes where a Static-mode camera should sit for the given
--- yaw/pitch/distance/offset, anchored to the actor's current tracked
--- (head) position.
function M.computePosition(yaw, pitch, distance, offset)
    local tracked = camera.getTrackedPosition()
    return tracked - direction(yaw, pitch) * distance
        + rightVector(yaw) * offset.x
        + UP * offset.y
end

--- Applies a full pose to a Static-mode camera: orientation via the usual
--- setYaw/setPitch/setRoll, and position via setStaticPosition. Must only
--- be called while camera.getMode() == camera.MODE.Static.
function M.apply(yaw, pitch, roll, distance, offset)
    camera.setYaw(yaw)
    camera.setPitch(pitch)
    camera.setRoll(roll)
    camera.setStaticPosition(M.computePosition(yaw, pitch, distance, offset))
end

return M
