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
local previewTag = namespace .. "Preview"

----------------------------------------------------------------------
-- Preview (declared before settings so the subscribe callbacks below
-- can reference startPreview)
----------------------------------------------------------------------

local PREVIEW_DURATION = 0.1

-- Forward-declared; assigned further down once camera helpers exist.
local startPreview
local endPreview
local preview

local settings = {
    cam = settingsCache.new(
        storage.playerSection("SettingsInventoryCamera_camera"),
        async
    ),
    start = settingsCache.new(
        storage.playerSection("SettingsInventoryCamera_startingPosition"),
        async,
        function()
            if startPreview then startPreview('start') end
        end
    ),
    finish = settingsCache.new(
        storage.playerSection("SettingsInventoryCamera_destination"),
        async,
        function()
            if startPreview then startPreview('finish') end
        end
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
local savedDistance = camera.getThirdPersonDistance()

-- Yaw/pitch/roll/distance/offset tween state, advanced from onUpdate
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
    fromDistance = 0,
    toDistance = 0,
    fromOffset = nil,
    toOffset = nil,
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

local function startPan(toYaw, toPitch, toRoll, fromDistance, toDistance, fromOffset, toOffset)
    pan.running = true
    pan.elapsed = 0
    pan.duration = math.max(settings.cam.panDuration, 0.001)
    pan.fromYaw = camera.getYaw()
    pan.fromPitch = camera.getPitch()
    pan.fromRoll = camera.getRoll()
    -- Explicit from-values for distance/offset instead of querying the
    -- camera: getThirdPersonDistance()/getFocalPreferredOffset() return the
    -- actual, simulated value, which can lag a frame or more behind what we
    -- just set (e.g. reading back near-0 right after a mode switch).
    pan.fromDistance = fromDistance
    pan.fromOffset = fromOffset
    pan.toYaw = toYaw
    pan.toPitch = toPitch
    pan.toRoll = toRoll
    pan.toDistance = toDistance
    pan.toOffset = toOffset
end

local function onUpdate(dt)
    if preview.active then
        preview.timeLeft = preview.timeLeft - dt
        if preview.timeLeft <= 0 then
            endPreview()
        end
    end

    if not pan.running then return end

    pan.elapsed = pan.elapsed + dt
    local t = math.min(pan.elapsed / pan.duration, 1)
    local eased = t * t * (3 - 2 * t) -- smoothstep

    local yD = yawDelta(pan.fromYaw, pan.toYaw)
    camera.setYaw(pan.fromYaw + yD * eased)
    camera.setPitch(pan.fromPitch + (pan.toPitch - pan.fromPitch) * eased)
    camera.setRoll(pan.fromRoll + (pan.toRoll - pan.fromRoll) * eased)
    camera.setPreferredThirdPersonDistance(pan.fromDistance + (pan.toDistance - pan.fromDistance) * eased)
    camera.setFocalPreferredOffset(pan.fromOffset + (pan.toOffset - pan.fromOffset) * eased)
    -- Drive the offset ourselves rather than relying on the engine's own
    -- built-in smoothing (which appears to stall while the game is paused).
    camera.instantTransition()

    if t >= 1 then
        pan.running = false
    end
end

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

local function enterInventoryView()
    if active then return end
    if preview.active then endPreview() end

    local currCamMode = camera.getMode()
    local firstPersonCheck = currCamMode == camera.MODE.FirstPerson and settings.cam.person.first
    local thirdPersonCheck = currCamMode == camera.MODE.Preview and settings.cam.person.third
    if not firstPersonCheck and not thirdPersonCheck then
        return
    end

    active = true
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

    if settings.cam.smoothPanning then
        startPan(
            targetState.yaw, targetState.pitch, targetState.roll,
            startState.distance, targetState.distance,
            startState.offset, targetState.offset
        )
    else
        pan.running = false
        applyCameraState(targetState)
        camera.instantTransition()
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
        camera.setPreferredThirdPersonDistance(savedDistance)
        camera.instantTransition()
        local instant = savedMode == camera.MODE.FirstPerson
        if settings.cam.smoothPanning and not instant then
            startPan(savedYaw, savedPitch, savedRoll, savedDistance, savedDistance, savedOffset, savedOffset)
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
-- Preview
----------------------------------------------------------------------
-- While tweaking the "starting position" or "destination" settings outside
-- the inventory, briefly show the camera at that position so the change is
-- visible without having to open the inventory to check. Ends after
-- PREVIEW_DURATION seconds, or immediately on a mouse click.

preview = {
    active = false,
    timeLeft = 0,
    savedMode = nil,
    savedYaw = nil,
    savedPitch = nil,
    savedRoll = nil,
    savedDistance = nil,
}

endPreview = function()
    if not preview.active then return end
    preview.active = false

    I.Camera.enableModeControl(previewTag)
    I.Camera.enableThirdPersonOffsetControl(previewTag)
    I.Camera.enableZoom(previewTag)
    I.Camera.enableStandingPreview(previewTag)

    camera.setMode(preview.savedMode, true)
    camera.setPreferredThirdPersonDistance(preview.savedDistance)
    camera.instantTransition()
    camera.setYaw(preview.savedYaw)
    camera.setPitch(preview.savedPitch)
    camera.setRoll(preview.savedRoll)
end

startPreview = function(kind)
    if active then return end -- don't fight the real inventory camera

    if not preview.active then
        preview.savedMode = camera.getMode()
        preview.savedYaw = camera.getYaw()
        preview.savedPitch = camera.getPitch()
        preview.savedRoll = camera.getRoll()
        preview.savedDistance = camera.getThirdPersonDistance()

        I.Camera.disableModeControl(previewTag)
        I.Camera.disableThirdPersonOffsetControl(previewTag)
        I.Camera.disableZoom(previewTag)
        I.Camera.disableStandingPreview(previewTag)

        camera.setMode(camera.MODE.Preview, true)
    end

    preview.active = true
    preview.timeLeft = PREVIEW_DURATION

    local section = (kind == 'start') and settings.start or settings.finish

    local yaw = self.rotation:getYaw() + math.rad(settings.start.yaw)
    if kind == 'finish' then
        yaw = yaw + math.rad(settings.finish.yaw)
    end

    -- Offsets are intentionally not previewed.
    camera.setPreferredThirdPersonDistance(section.distance)
    camera.instantTransition()
    camera.setYaw(yaw)
    camera.setPitch(math.rad(section.pitch))
    camera.setRoll(math.rad(section.roll))
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local function onUiModeChanged(data)
    local enteringInventory = data.newMode == 'Interface' and data.oldMode ~= 'Interface'
    local leavingInventory = data.oldMode == 'Interface' and data.newMode ~= 'Interface'

    if enteringInventory then
        enterInventoryView()
    elseif leavingInventory then
        exitInventoryView()
    elseif active then
        exitInventoryView()
    end
end

----------------------------------------------------------------------
-- Save/load
----------------------------------------------------------------------
-- Persists the pre-inventory camera snapshot so a save made while the
-- inventory camera override is active restores correctly on load, and so a
-- script reload (e.g. after updating the mod) doesn't lose track of it.

local function modeToName(mode)
    for name, value in pairs(camera.MODE) do
        if value == mode then return name end
    end
    return nil
end

local function onSave()
    if preview.active then endPreview() end

    if not active then
        return { active = false }
    end

    return {
        active = true,
        mode = modeToName(savedMode),
        yaw = savedYaw,
        pitch = savedPitch,
        roll = savedRoll,
        offsetX = savedOffset.x,
        offsetY = savedOffset.y,
        distance = savedDistance,
    }
end

local function onLoad(data)
    data = data or {}
    pan.running = false
    preview.active = false

    active = data.active or false
    if active then
        savedMode = (data.mode and camera.MODE[data.mode]) or camera.MODE.FirstPerson
        savedYaw = data.yaw or 0
        savedPitch = data.pitch or 0
        savedRoll = data.roll or 0
        savedOffset = v2(data.offsetX or 0, data.offsetY or 0)
        savedDistance = data.distance or camera.getThirdPersonDistance()
    else
        savedMode = camera.getMode()
        savedYaw = camera.getYaw()
        savedPitch = camera.getPitch()
        savedRoll = camera.getRoll()
        savedOffset = camera.getFocalPreferredOffset()
        savedDistance = camera.getThirdPersonDistance()
    end
end

return {
    eventHandlers = {
        UiModeChanged = onUiModeChanged,
    },
    engineHandlers = {
        onUpdate = onUpdate,
        onInit = onLoad,
        onSave = onSave,
        onLoad = onLoad,
    },
}