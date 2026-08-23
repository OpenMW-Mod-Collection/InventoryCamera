---@omw-context player
local self = require('openmw.self')
local camera = require('openmw.camera')
local storage = require('openmw.storage')
local async = require('openmw.async')
local util = require('openmw.util')
local v2 = util.vector2
local I = require('openmw.interfaces')

local settingsCache = require("scripts.InventoryCamera.utils.settingsCache")

local namespace = "InventoryCamera"
local settings = {
    cam = settingsCache.new(
        storage.playerSection("SettingsInventoryCamera_camera"),
        async
    ),
    start = settingsCache.new(
        storage.playerSection("SettingsInventoryCamera_startingPosition"),
        async
    ),
    finish = settingsCache.new(
        storage.playerSection("SettingsInventoryCamera_destination"),
        async
    ),
}

----------------------------------------------------------------------
-- Camera logic
----------------------------------------------------------------------

local active = false
local savedMode = camera.getMode()
local savedYaw = camera.getYaw()
local savedPitch = camera.getPitch()
local savedRoll = camera.getRoll()
local savedOffset = camera.getFocalPreferredOffset()

-- Yaw/pitch/roll tween state, advanced from onUpdate
local pan = {
    running = false,
    elapsed = 0,
    duration = 0,
    fromYaw = 0,
    toYaw = 0,
    fromPitch = 0,
    toPitch = 0,
    fromRoll = 0,
    toRoll = 0,
}

-- Shortest signed angular distance from a to b, wrapped to [-pi, pi]
local function angleDelta(a, b)
    return ((b - a + math.pi) % (2 * math.pi)) - math.pi
end

-- Angular distance from a to b honoring YAW_PAN_DIRECTION: "Auto (shortest)"
-- behaves like angleDelta above; "Clockwise"/"Counter-clockwise" force the
-- sweep to always go that way around, even if it's the long way round.
local function yawDelta(a, b)
    if a == b then
        return 0
    end

    local direction = settings.cam.yawPanDirection == "yawPanDirection_random"
        and ({ "yawPanDirection_CW", "yawPanDirection_CCW" })[math.random(2)]
        or settings.cam.yawPanDirection

    if direction == "yawPanDirection_CW" then
        return (b - a) % (2 * math.pi)                 -- always in [0, 2*pi)
    elseif direction == "yawPanDirection_CCW" then
        return ((b - a) % (2 * math.pi)) - 2 * math.pi -- always in (-2*pi, 0]
    else
        return angleDelta(a, b)
    end
end

local function startPan(toYaw, toPitch, toRoll)
    pan.running = true
    pan.elapsed = 0
    pan.duration = math.max(settings.cam.panDuration, 0.001)
    pan.fromYaw = camera.getYaw()
    pan.fromPitch = camera.getPitch()
    pan.fromRoll = camera.getRoll()
    pan.toYaw = toYaw
    pan.toPitch = toPitch
    pan.toRoll = toRoll
end

local function onUpdate(dt)
    if not pan.running then return end

    pan.elapsed = pan.elapsed + dt
    local t = math.min(pan.elapsed / pan.duration, 1)
    local eased = t * t * (3 - 2 * t) -- smoothstep

    local yD = yawDelta(pan.fromYaw, pan.toYaw)
    camera.setYaw(pan.fromYaw + yD * eased)
    camera.setPitch(pan.fromPitch + (pan.toPitch - pan.fromPitch) * eased)
    camera.setRoll(pan.fromRoll + (pan.toRoll - pan.fromRoll) * eased)

    if t >= 1 then
        pan.running = false
    end
end

local function enterInventoryView()
    if active then return end

    local person = camera.getMode()
    local firstPersonCheck = person == camera.MODE.FirstPerson and settings.cam.person.first
    local thirdPersonCheck = person == camera.MODE.ThirdPerson and settings.cam.person.third
    if not firstPersonCheck and not thirdPersonCheck then
        return
    end

    active = true
    savedMode = camera.getMode()
    savedYaw = camera.getYaw()
    savedPitch = camera.getPitch()
    savedRoll = camera.getRoll()
    savedOffset = camera.getFocalPreferredOffset()

    -- Stop the built-in camera script from fighting us while the menu is open
    I.Camera.disableModeControl(namespace)
    I.Camera.disableThirdPersonOffsetControl(namespace)
    I.Camera.disableZoom(namespace)
    I.Camera.disableStandingPreview(namespace)

    camera.setMode(camera.MODE.Preview, true)
    camera.setPreferredThirdPersonDistance(settings.start.distance)
    camera.setFocalPreferredOffset(v2(
        settings.start.horizontalOffset,
        settings.start.verticalOffset
    ))

    local targetYaw = math.rad(settings.finish.yaw)
    local targetPitch = math.rad(settings.finish.pitch)
    local targetRoll = math.rad(settings.finish.roll)

    if settings.cam.smoothPanning then
        startPan(targetYaw, targetPitch, targetRoll)
    else
        pan.running = false
        camera.setYaw(targetYaw)
        camera.setPitch(targetPitch)
        camera.setRoll(targetRoll)
    end
end

local function exitInventoryView()
    if not active then return end
    active = false

    I.Camera.enableModeControl(namespace)
    I.Camera.enableThirdPersonOffsetControl(namespace)
    I.Camera.enableZoom(namespace)
    I.Camera.enableStandingPreview(namespace)

    if settings.cam.restoreOnClose then
        camera.setMode(savedMode, true)
        camera.setFocalPreferredOffset(savedOffset)
        local instant = savedMode == camera.MODE.FirstPerson
        if settings.cam.smoothPanning and not instant then
            startPan(savedYaw, savedPitch, savedRoll)
        else
            pan.running = false
            camera.setYaw(savedYaw)
            camera.setPitch(savedPitch)
            camera.setRoll(savedRoll)
        end
    else
        pan.running = false
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local function onUiModeChanged(data)
    local enteringInventory = data.newMode == 'Interface' and data.oldMode ~= 'Interface'
    local leavingInventory = data.oldMode == 'Interface' and data.newMode ~= 'Interface'

    if enteringInventory then
        for window, required in pairs(settings.cam.requiredWindows) do
            if required and not I.UI.isWindowVisible(window) then
                return
            end
        end
        enterInventoryView()
    elseif leavingInventory then
        exitInventoryView()
    elseif active then
        exitInventoryView()
    end
end

return {
    eventHandlers = {
        UiModeChanged = onUiModeChanged,
    },
    engineHandlers = {
        onUpdate = onUpdate,
    },
}
