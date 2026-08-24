---@omw-context player

-- Persists the pre-inventory camera snapshot so a save made while the
-- inventory camera override is active restores correctly on load, and so a
-- script reload (e.g. after updating the mod) doesn't lose track of it.

local camera = require('openmw.camera')
local util = require('openmw.util')
local v2 = util.vector2

local view = require("scripts.InventoryCamera.camera.view")
local preview = require("scripts.InventoryCamera.camera.preview")
local pan = require("scripts.InventoryCamera.camera.pan")

local M = {}

local function modeToName(mode)
    for name, value in pairs(camera.MODE) do
        if value == mode then return name end
    end
    return nil
end

function M.onSave()
    if preview.active then preview.endPreview() end

    if not view.active then
        return { active = false }
    end

    local mode, yaw, pitch, roll, offset, distance = view.getSavedState()
    return {
        active = true,
        mode = modeToName(mode),
        yaw = yaw,
        pitch = pitch,
        roll = roll,
        offsetX = offset.x,
        offsetY = offset.y,
        distance = distance,
    }
end

function M.onLoad(data)
    data = data or {}
    pan.stop()
    preview.active = false

    view.active = data.active or false
    if view.active then
        view.setSavedState(
            (data.mode and camera.MODE[data.mode]) or camera.MODE.FirstPerson,
            data.yaw or 0,
            data.pitch or 0,
            data.roll or 0,
            v2(data.offsetX or 0, data.offsetY or 0),
            data.distance or camera.getThirdPersonDistance()
        )
    else
        view.setSavedState(
            camera.getMode(),
            camera.getYaw(),
            camera.getPitch(),
            camera.getRoll(),
            camera.getFocalPreferredOffset(),
            camera.getThirdPersonDistance()
        )
    end
end

return M
