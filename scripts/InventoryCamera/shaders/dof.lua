---@omw-context player
-- Depth-of-field pass for the inventory camera, built on the same
-- enable/fade lifecycle as spotlight.lua, driving hexDoFProgrammable.omwfx
-- instead of inventoryCameraSpotlight.omwfx.
--
-- hexDoFProgrammable expects uDepth in the same units get_depth() /
-- omw_GetLinearDepth() return (world-space distance from the camera), so
-- focusMode picks how that distance is produced each frame; everything
-- else is a straight uniform mirror of settings.dof.*.

local camera = require('openmw.camera')
local postprocessing = require('openmw.postprocessing')
local self = require('openmw.self')
local core = require("openmw.core")

local settings = require("scripts.InventoryCamera.settingsManager")

local SHADER = "hexDoFProgrammable"

local M = {}

-- Same reasoning as spotlight.lua: postprocessing.load throws if post
-- processing is off or the shader fails to compile. Losing the blur is
-- fine; losing the whole script is not.
local shader
do
    local ok, result = pcall(postprocessing.load, SHADER)
    if ok then
        shader = result
    else
        print("DoF shader unavailable: " .. tostring(result))
    end
end

local active = false
local strength = 0
local sentAperture = nil -- last uAperture handed to the shader; nil forces a first write
local shaderOn = shader ~= nil and shader:isEnabled()

-- Enabling a shader rebuilds the whole post-processing chain, which hitches.
-- So it stays in the chain for as long as the feature is switched on, idling
-- at uStrength = 0 (and uAperture = 0, which the shader also short-circuits
-- on) rather than being added/removed on every camera toggle.
local function syncShaderEnabled()
    if not shader then return end
    local wanted = settings.dof.enabled
    if wanted == shaderOn then return end
    if wanted then
        shader:setFloat("uStrength", 0)
        shader:setFloat("uAperture", 0)
        shader:enable()
    else
        shader:disable()
    end
    shaderOn = wanted
end

function M.enter()
    active = true
end

function M.exit()
    active = false
end

--- Call every frame (onFrame - it keeps running while the world is paused).
function M.update()
    syncShaderEnabled()
    if not shaderOn then return end

    local goal = (active and settings.dof.enabled) and 1 or 0
    local dt = core.getRealFrameDuration()
    local fadeIn = settings.dof.fadeIn
    local fadeOut = settings.dof.fadeOut
    if strength < goal then
        strength = math.min(goal, strength + dt / fadeIn)
    elseif strength > goal then
        strength = math.max(goal, strength - dt / fadeOut)
    end

    local effectiveAperture = settings.dof.aperture * strength

    if effectiveAperture == 0 and sentAperture == 0 then return end
    sentAperture = effectiveAperture

    local focusDepth = (self.position - camera.getPosition()):length()
    shader:setFloat("uDepth", focusDepth)
    shader:setFloat("uAperture", effectiveAperture)
end

return M
