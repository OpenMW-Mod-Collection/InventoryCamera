---@omw-context player
-- Stage-spotlight look while the inventory camera is up: a real light is
-- hung in front of the character and above their head (spawned by
-- global.lua - only global scripts can create objects), and a
-- post-processing pass fades everything outside a pool of light around them
-- to (almost) black.
--
-- The shader works in world space: it rebuilds each pixel's position from
-- depth and keeps a soft-edged column around the character lit - a pool on
-- the floor and the character in it, fading out a little above their head -
-- rather than a flat screen vignette. The column is centred on the character,
-- not aimed from the light: at a couple of body widths, a cone from a light
-- out in front would miss the floor around them and clip their head.

local core = require('openmw.core')
local postprocessing = require('openmw.postprocessing')
local self = require('openmw.self')
local types = require('openmw.types')
local util = require('openmw.util')

local settings = require("scripts.InventoryCamera.settingsManager")

local SHADER = "inventoryCameraSpotlight"
local FALLBACK_RADIUS = 30  -- character size if the engine can't tell us
local FALLBACK_HEIGHT = 130
local FADE_IN = 0.6         -- seconds
local FADE_OUT = 0.35

local M = {}

-- postprocessing.load throws if post processing is off or the shader fails
-- to compile. Losing the darkening is fine; losing the whole script is not.
local shader
do
    local ok, result = pcall(postprocessing.load, SHADER)
    if ok then
        shader = result
    else
        print("Spotlight shader unavailable: " .. tostring(result))
    end
end

local active = false
local strength = 0
local sentStrength = nil -- last uStrength handed to the shader; nil forces a first write
local lightRequested = false
local charRadius, charHeight = FALLBACK_RADIUS, FALLBACK_HEIGHT
-- Seeded from the engine: after loading another save the shader can still be
-- in the chain from before, with this script starting over from scratch.
local shaderOn = shader ~= nil and shader:isEnabled()

-- Enabling a shader rebuilds the whole post-processing chain, which hitches.
-- So it stays in the chain for as long as the feature is switched on, idling
-- at uStrength = 0 (its pass is a straight copy then).
local function syncShaderEnabled()
    if not shader then return end
    local wanted = settings.spot.enabled
    if wanted == shaderOn then return end
    if wanted then
        shader:setFloat("uStrength", 0)
        shader:enable()
    else
        shader:disable()
    end
    shaderOn = wanted
end

-- The collision shape rather than the render bounding box: it doesn't swing
-- with the animation, and it follows race and creature size.
local function characterSize()
    local ok, bounds = pcall(types.Actor.getPathfindingAgentBounds, self)
    if ok and bounds and bounds.halfExtents then
        local h = bounds.halfExtents
        return math.max(h.x, h.y), h.z * 2
    end
    return FALLBACK_RADIUS, FALLBACK_HEIGHT
end

local function lightPosition()
    local yaw = self.rotation:getYaw()
    local forward = util.vector3(math.sin(yaw), math.cos(yaw), 0)
    return self.position
        + forward * settings.spot.lightInFront
        + util.vector3(0, 0, charHeight + settings.spot.lightAboveHead)
end

function M.enter()
    active = true
    charRadius, charHeight = characterSize()
    if settings.spot.enabled and settings.spot.light then
        core.sendGlobalEvent("InventoryCamera_SpawnLight", {
            actor = self.object,
            position = lightPosition(),
            radius = settings.spot.lightRadius,
            color = settings.spot.lightColor,
        })
        lightRequested = true
    end
end

function M.exit()
    active = false
    if lightRequested then
        core.sendGlobalEvent("InventoryCamera_RemoveLight", {})
        lightRequested = false
    end
end

--- Call every frame (onFrame - it keeps running while the world is paused).
function M.update()
    syncShaderEnabled()
    if not shaderOn then return end

    local goal = (active and settings.spot.enabled) and 1 or 0
    local dt = core.getRealFrameDuration()
    if strength < goal then
        strength = math.min(goal, strength + dt / FADE_IN)
    elseif strength > goal then
        strength = math.max(goal, strength - dt / FADE_OUT)
    end

    if strength == 0 and sentStrength == 0 then return end
    sentStrength = strength

    -- All of the shader's uniforms are set from here; its own defaults only
    -- matter while idling at uStrength = 0. (The .omwfx can't carry these
    -- notes: its parser only accepts comments inside the GLSL blocks.)
    local s = settings.spot
    shader:setFloat("uStrength", strength)
    shader:setVector3("uCenter", self.position)            -- the character's feet
    shader:setFloat("uRadius", charRadius * s.radiusScale)
    shader:setFloat("uTop", charHeight)                    -- where the column starts fading out
    shader:setFloat("uSoftness", s.softness / 100)
    shader:setFloat("uFloor", math.abs(s.opacity - 100) / 100)
end

return M
