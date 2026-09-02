---@omw-context player
-- While tweaking the "starting position" or "destination" settings outside
-- the inventory, briefly show the camera at that position so the change is
-- visible without having to open the inventory to check. Ends after
-- PREVIEW_DURATION seconds, or on the next inventory open (see player.lua).

local self = require('openmw.self')
local camera = require('openmw.camera')
local util = require('openmw.util')
local v2 = util.vector2
local I = require('openmw.interfaces')

local settings = require("scripts.InventoryCamera.settings")
local view = require("scripts.InventoryCamera.camera.view")
local pose = require("scripts.InventoryCamera.camera.pose")

local previewTag = "InventoryCameraPreview"
local PREVIEW_DURATION = 0.1

local M = {
    active = false,
    timeLeft = 0,
}

local savedMode, savedYaw, savedPitch, savedRoll, savedDistance

function M.endPreview()
    if not M.active then return end
    M.active = false

    I.Camera.enableModeControl(previewTag)
    I.Camera.enableThirdPersonOffsetControl(previewTag)
    I.Camera.enableZoom(previewTag)
    I.Camera.enableStandingPreview(previewTag)

    camera.setMode(savedMode, true)
    camera.setPreferredThirdPersonDistance(savedDistance)
    camera.instantTransition()
    camera.setYaw(savedYaw)
    camera.setPitch(savedPitch)
    camera.setRoll(savedRoll)
end

function M.start(kind)
    if view.active then return end -- don't fight the real inventory camera

    if not M.active then
        savedMode = camera.getMode()
        savedYaw = camera.getYaw()
        savedPitch = camera.getPitch()
        savedRoll = camera.getRoll()
        savedDistance = camera.getThirdPersonDistance()

        I.Camera.disableModeControl(previewTag)
        I.Camera.disableThirdPersonOffsetControl(previewTag)
        I.Camera.disableZoom(previewTag)
        I.Camera.disableStandingPreview(previewTag)

        camera.setMode(camera.MODE.Static, true)
    end

    M.active = true
    M.timeLeft = PREVIEW_DURATION

    local section = (kind == 'start') and settings.start or settings.finish

    local yaw = self.rotation:getYaw() + math.rad(settings.start.yaw)
    if kind == 'finish' then
        yaw = yaw + math.rad(settings.finish.yaw)
    end

    -- Preview the section's own offset, same as distance/pitch/roll below -
    -- not combined with the other section's offset, mirroring how distance/
    -- pitch/roll are picked directly from `section` rather than summed.
    local offset = v2(section.horizontalOffset, section.verticalOffset)

    pose.apply(yaw, math.rad(section.pitch), math.rad(section.roll), section.distance, offset)
end

function M.update(dt)
    if not M.active then return end
    M.timeLeft = M.timeLeft - dt
    if M.timeLeft <= 0 then
        M.endPreview()
    end
end

return M
