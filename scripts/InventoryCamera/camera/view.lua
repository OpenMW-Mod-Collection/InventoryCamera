---@diagnostic disable: param-type-mismatch
---@omw-context player

local self = require('openmw.self')
local camera = require('openmw.camera')
local util = require('openmw.util')
local v2 = util.vector2
local I = require('openmw.interfaces')
local pan = require("scripts.InventoryCamera.camera.pan")
local pose = require("scripts.InventoryCamera.camera.pose")
local settings = require("scripts.InventoryCamera.settings")

local namespace = "InventoryCamera"

local M = {
    active = false,
}

-- Snapshot of the camera as it was right before we took it over, so it can
-- be restored on exit. Also persisted via save.lua.
local savedMode = camera.getMode()
local savedYaw = camera.getYaw()
local savedPitch = camera.getPitch()
local savedRoll = camera.getRoll()
local savedOffset = camera.getFocalPreferredOffset()
local savedDistance = camera.getThirdPersonDistance()

local function computeStartState(firstPerson)
    if firstPerson then
        return {
            yaw = self.rotation:getYaw() + math.rad(settings.start.yaw),
            pitch = math.rad(settings.start.pitch),
            roll = math.rad(settings.start.roll),
            distance = settings.start.distance,
            offset = v2(settings.start.horizontalOffset, settings.start.verticalOffset),
        }
    else
        -- Third person: start exactly where the camera already is
        return {
            yaw = savedYaw,
            pitch = savedPitch,
            roll = savedRoll,
            distance = savedDistance,
            offset = savedOffset,
        }
    end
end

local function computeTargetState()
    -- Finish state is always actor-relative, so first/third person converge
    -- on the same final pose regardless of where they started.
    return {
        yaw = self.rotation:getYaw() + math.rad(settings.finish.yaw),
        pitch = math.rad(settings.finish.pitch),
        roll = math.rad(settings.finish.roll),
        distance = settings.finish.distance,
        offset = v2(settings.finish.horizontalOffset, settings.finish.verticalOffset),
    }
end

-- Applies a pose instantly (used for the initial snap and the non-smooth
-- fallback paths on entry). Must only be called while the camera is in
-- Static mode.
local function applyCameraState(state)
    pose.apply(state.yaw, state.pitch, state.roll, state.distance, state.offset)
end

-- Applies a pose to a normal tracked (First/ThirdPerson) camera, the same
-- way the original Preview-based implementation always did. Used for the
-- outward pan/snap in M.exit(), which runs *after* the camera has already
-- been switched back out of Static mode - pose.apply/setStaticPosition
-- would error here.
local function applyTrackedState(yaw, pitch, roll, distance, offset)
    camera.setFocalPreferredOffset(offset)
    camera.setPreferredThirdPersonDistance(distance)
    camera.setYaw(yaw)
    camera.setPitch(pitch)
    camera.setRoll(roll)
    camera.instantTransition()
end

function M.enter()
    if M.active then return end

    local currCamMode = camera.getMode()
    local firstPersonCheck = currCamMode == camera.MODE.FirstPerson and settings.cam.person.first
    local thirdPersonCheck = currCamMode ~= camera.MODE.FirstPerson and settings.cam.person.third
    if not firstPersonCheck and not thirdPersonCheck then
        return
    end

    M.active = true
    savedMode = currCamMode
    savedYaw = camera.getYaw()
    savedPitch = camera.getPitch()
    savedRoll = camera.getRoll()
    savedOffset = camera.getFocalPreferredOffset()
    savedDistance = camera.getThirdPersonDistance()

    -- Stop the built-in camera script from fighting us while the menu is
    -- open. Static mode ignores the built-in third-person offset/zoom
    -- logic entirely, but it can still fight us over *mode* (e.g. trying
    -- to switch back to First/ThirdPerson), so mode control still needs
    -- to be disabled.
    I.Camera.disableModeControl(namespace)
    I.Camera.disableThirdPersonOffsetControl(namespace)
    I.Camera.disableZoom(namespace)
    I.Camera.disableStandingPreview(namespace)

    camera.setMode(camera.MODE.Static, true)

    local startState = computeStartState(firstPersonCheck)
    local targetState = computeTargetState()

    if firstPersonCheck then
        -- Third person doesn't need this: the camera is already sitting at
        -- startState by definition, so there's nothing to snap to.
        applyCameraState(startState)
    end

    local smooth = firstPersonCheck and settings.cam.smoothPanning.firstIn
        or settings.cam.smoothPanning.thirdIn

    if smooth then
        pan.start(
            pose.apply,
            targetState.yaw, targetState.pitch, targetState.roll,
            startState.distance, targetState.distance,
            startState.offset, targetState.offset,
            settings.cam.panDuration
        )
    else
        pan.stop()
        applyCameraState(targetState)
    end
end

function M.exit()
    if not M.active then return end
    M.active = false

    I.Camera.enableModeControl(namespace)
    I.Camera.enableThirdPersonOffsetControl(namespace)
    I.Camera.enableZoom(namespace)
    I.Camera.enableStandingPreview(namespace)

    local isFirstPerson = savedMode == camera.MODE.FirstPerson
    local smooth = isFirstPerson and settings.cam.smoothPanning.firstOut
        or settings.cam.smoothPanning.thirdOut

    -- Capture where the camera actually is *right now* (yaw/pitch/roll are
    -- always readable regardless of mode; distance/offset only exist as
    -- our own tracked pan state under Static mode) before setMode() snaps
    -- us back to First/ThirdPerson - so we always pan from the real
    -- current pose, never from whatever default that switch lands on.
    local curYaw = camera.getYaw()
    local curPitch = camera.getPitch()
    local curRoll = camera.getRoll()
    local _, _, _, curDistance, curOffset = pan.getPose()

    camera.setMode(savedMode, true)

    if smooth and not isFirstPerson then
        -- Re-assert the real current pose (setMode may have reset it),
        -- then pan from there to the saved pose. We're back in a tracked
        -- mode now, so this goes through the normal third-person setters.
        camera.setFocalPreferredOffset(curOffset)
        camera.setPreferredThirdPersonDistance(curDistance)
        camera.setYaw(curYaw)
        camera.setPitch(curPitch)
        camera.setRoll(curRoll)
        camera.instantTransition()

        pan.start(applyTrackedState, savedYaw, savedPitch, savedRoll, curDistance, savedDistance, curOffset,
            savedOffset, settings.cam.panDuration)
    else
        pan.stop()
        camera.setFocalPreferredOffset(savedOffset)
        camera.setPreferredThirdPersonDistance(savedDistance)
        camera.setYaw(savedYaw)
        camera.setPitch(savedPitch)
        camera.setRoll(savedRoll)
        camera.instantTransition()
    end
end

--- Call every frame (e.g. from player.lua's onUpdate) while the menu
--- camera might be active. Unlike Preview mode, Static mode never follows
--- the actor on its own, so this either advances an in-progress pan or
--- re-anchors the held pose to the actor's current position.
---
--- Note: once M.exit() has handed control back to a tracked mode (and,
--- if smooth, kicked off the outward pan via pan.start above), the
--- outward pan is *not* driven through here - it's a normal third-person
--- pan and should continue to be advanced the same way this mod already
--- drives player.lua's outward-pan updates today (i.e. via pan.update
--- directly, honoring pan.isRunning()), since the camera is no longer in
--- Static mode at that point.
function M.update(yawPanDirection)
    if not M.active then return end

    if pan.isRunning() then
        pan.update(yawPanDirection)
    else
        pan.reapply()
    end
end

-- Accessors used by save.lua, which persists this snapshot across saves.
function M.getSavedState()
    return savedMode, savedYaw, savedPitch, savedRoll, savedOffset, savedDistance
end

function M.setSavedState(mode, yaw, pitch, roll, offset, distance)
    savedMode = mode
    savedYaw = yaw
    savedPitch = pitch
    savedRoll = roll
    savedOffset = offset
    savedDistance = distance
end

return M
