---@omw-context player

local self = require('openmw.self')
local camera = require('openmw.camera')
local util = require('openmw.util')
local v2 = util.vector2
local I = require('openmw.interfaces')
local core = require("openmw.core")

local pan = require("scripts.InventoryCamera.camera.pan")
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

local function applyCameraState(state)
    camera.setYaw(state.yaw)
    camera.setPitch(state.pitch)
    camera.setRoll(state.roll)
    camera.setPreferredThirdPersonDistance(state.distance)
    camera.setFocalPreferredOffset(state.offset)
end

function M.enter()
    if M.active then return end

    local currCamMode = camera.getMode()
    local firstPersonCheck = currCamMode == camera.MODE.FirstPerson and settings.cam.person.first
    local thirdPersonCheck = currCamMode ~= camera.MODE.FirstPerson and settings.cam.person.third
    if not firstPersonCheck and not thirdPersonCheck then
        return
    end

    local paused = core.isWorldPaused()
    if paused and settings.cam.ifPaused == "disable" then
        return
    end

    M.active = true
    savedMode = currCamMode
    savedYaw = camera.getYaw()
    savedPitch = camera.getPitch()
    savedRoll = camera.getRoll()
    savedOffset = camera.getFocalPreferredOffset()
    savedDistance = camera.getThirdPersonDistance()

    if firstPersonCheck then
        -- Stop the built-in camera script from fighting us while the menu is open
        I.Camera.disableModeControl(namespace)
        I.Camera.disableThirdPersonOffsetControl(namespace)
        I.Camera.disableZoom(namespace)
        I.Camera.disableStandingPreview(namespace)
    end

    camera.setMode(camera.MODE.Preview, true)

    local startState = computeStartState(firstPersonCheck)
    local targetState = computeTargetState()

    if firstPersonCheck then
        -- Third person doesn't need this: the camera is already sitting at
        -- startState by definition, so there's nothing to snap to.
        applyCameraState(startState)
        camera.instantTransition()
    end

    local smooth = firstPersonCheck and settings.cam.smoothPanning.firstIn
        or settings.cam.smoothPanning.thirdIn
    local snap = paused and settings.cam.ifPaused == "snap"

    if smooth and not snap then
        pan.start(
            targetState.yaw, targetState.pitch, targetState.roll,
            startState.distance, targetState.distance,
            startState.offset, targetState.offset,
            settings.cam.panDuration
        )
    else
        pan.stop()
        applyCameraState(targetState)
        camera.instantTransition()
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

    -- Capture where the camera actually is *right now*, before setMode()
    -- switches us back - setMode can otherwise snap the view to some
    -- default pose (e.g. default third-person distance behind the player)
    -- for a frame before we correct it. Panning from this captured state
    -- means the camera always animates from its real current position back
    -- to the saved one, never from that default.
    local curYaw = camera.getYaw()
    local curPitch = camera.getPitch()
    local curRoll = camera.getRoll()
    local curDistance = camera.getThirdPersonDistance()
    local curOffset = camera.getFocalPreferredOffset()

    camera.setMode(savedMode, true)

    if smooth and not isFirstPerson then
        -- Re-assert the real current pose (setMode may have reset it),
        -- then pan from there to the saved pose.
        camera.setFocalPreferredOffset(curOffset)
        camera.setPreferredThirdPersonDistance(curDistance)
        camera.setYaw(curYaw)
        camera.setPitch(curPitch)
        camera.setRoll(curRoll)
        camera.instantTransition()

        pan.start(savedYaw, savedPitch, savedRoll, curDistance, savedDistance, curOffset, savedOffset,
            settings.cam.panDuration)
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
