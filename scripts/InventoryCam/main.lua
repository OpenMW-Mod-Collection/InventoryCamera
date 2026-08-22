-- InventoryCam
-- Switches to a third-person "look at yourself" camera whenever the inventory menu is opened.

local core = require('openmw.core')
local self = require('openmw.self')
local camera = require('openmw.camera')
local storage = require('openmw.storage')
local async = require('openmw.async')
local util = require('openmw.util')
local I = require('openmw.interfaces')

local MODNAME = "InventoryCam"

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------

I.Settings.registerPage {
    key = MODNAME,
    l10n = "none",
    name = "Inventory Camera",
    description = "Switches to a third-person camera facing your character whenever you open the inventory.",
}

I.Settings.registerGroup {
    key = 'Settings' .. MODNAME,
    page = MODNAME,
    l10n = "none",
    name = "Options",
    permanentStorage = true,
    settings = {
        {
            key = "ENABLED",
            name = "Enable mod",
            description = "Turn the inventory camera behavior on or off.",
            renderer = "checkbox",
            default = true,
        },
        {
            key = "ONLY_IN_FIRST_PERSON",
            name = "Only trigger from first person",
            description = "If enabled, the camera will only switch when you open the inventory while in first person view. If disabled, it will always rotate to face you, even if you were already in third person.",
            renderer = "checkbox",
            default = false,
        },
        {
            key = "ROTATE_TO_FACE",
            name = "Rotate camera to face character",
            description = "Turn the camera around so it looks at the front of your character instead of keeping the current facing.",
            renderer = "checkbox",
            default = true,
        },
        {
            key = "DISTANCE",
            name = "Camera distance",
            description = "How far the camera sits from your character while the inventory is open.",
            renderer = "number",
            default = 150,
        },
        {
            key = "PITCH",
            name = "Camera pitch (degrees)",
            description = "Vertical camera angle while the inventory is open. Positive values look down at yourself, negative values look up.",
            renderer = "number",
            default = 5,
            argument = { min = -180, max = 180 },
        },
        {
            key = "YAW_OFFSET",
            name = "Yaw offset (degrees)",
            description = "Fine-tune the horizontal facing, added on top of 'Rotate camera to face character' (or your current facing, if that's off). Positive turns right, negative turns left.",
            renderer = "number",
            default = 0,
            argument = { min = -180, max = 180 },
        },
        {
            key = "YAW_PAN_DIRECTION",
            name = "Rotation direction (pan)",
            description = "Which way the camera swings around your character while panning to face it (only matters if 'Smoothly pan camera' is on). Auto picks whichever side is the shorter way round.",
            renderer = "select",
            default = "Auto (shortest)",
            argument = {
                disabled = false,
                l10n = "none",
                items = { "Auto (shortest)", "Clockwise", "Counter-clockwise" },
            },
        },
        {
            key = "ROLL",
            name = "Camera roll (degrees)",
            description = "Tilt the camera around its forward axis. Magnitude only; use 'Roll direction' below for the direction.",
            renderer = "number",
            default = 0,
            argument = { min = -180, max = 180 },
        },
        {
            key = "HORIZONTAL_OFFSET",
            name = "Horizontal offset",
            description = "Shift the focal point left/right relative to your character. Positive moves it to the right.",
            renderer = "number",
            default = 0,
        },
        {
            key = "VERTICAL_OFFSET",
            name = "Vertical offset",
            description = "Shift the focal point up/down relative to your character. Positive moves it up.",
            renderer = "number",
            default = 0,
        },
        {
            key = "RESTORE_ON_CLOSE",
            name = "Restore previous camera on close",
            description = "When closing the inventory, return the camera to whatever mode/angle it had before (e.g. back to first person).",
            renderer = "checkbox",
            default = true,
        },
        {
            key = "SMOOTH_PAN",
            name = "Smoothly pan camera",
            description = "Ease the camera into position instead of snapping instantly. Applies both when opening and (if restoring) when closing the inventory.",
            renderer = "checkbox",
            default = true,
        },
        {
            key = "PAN_DURATION",
            name = "Pan duration (seconds)",
            description = "How long the smooth camera pan takes.",
            renderer = "number",
            default = 0.4,
            argument = { min = 0 },
        },
    },
}

local settingsSection = storage.playerSection('Settings' .. MODNAME)

local ENABLED
local ONLY_IN_FIRST_PERSON
local ROTATE_TO_FACE
local DISTANCE
local PITCH
local YAW_OFFSET
local YAW_PAN_DIRECTION
local ROLL
local HORIZONTAL_OFFSET
local VERTICAL_OFFSET
local RESTORE_ON_CLOSE
local SMOOTH_PAN
local PAN_DURATION

local function readSettings()
    ENABLED = settingsSection:get("ENABLED")
    ONLY_IN_FIRST_PERSON = settingsSection:get("ONLY_IN_FIRST_PERSON")
    ROTATE_TO_FACE = settingsSection:get("ROTATE_TO_FACE")
    DISTANCE = settingsSection:get("DISTANCE")
    PITCH = settingsSection:get("PITCH")
    YAW_OFFSET = settingsSection:get("YAW_OFFSET")
    YAW_PAN_DIRECTION = settingsSection:get("YAW_PAN_DIRECTION")
    ROLL = settingsSection:get("ROLL")
    HORIZONTAL_OFFSET = settingsSection:get("HORIZONTAL_OFFSET")
    VERTICAL_OFFSET = settingsSection:get("VERTICAL_OFFSET")
    RESTORE_ON_CLOSE = settingsSection:get("RESTORE_ON_CLOSE")
    SMOOTH_PAN = settingsSection:get("SMOOTH_PAN")
    PAN_DURATION = settingsSection:get("PAN_DURATION")
end
readSettings()

settingsSection:subscribe(async:callback(function()
    readSettings()
end))

----------------------------------------------------------------------
-- Camera logic
----------------------------------------------------------------------

local active = false          -- whether we are currently overriding the camera
local savedMode = nil
local savedYaw = nil
local savedPitch = nil
local savedRoll = nil
local savedOffset = nil

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
    elseif YAW_PAN_DIRECTION == "Clockwise" then
        return (b - a) % (2 * math.pi)          -- always in [0, 2*pi)
    elseif YAW_PAN_DIRECTION == "Counter-clockwise" then
        return ((b - a) % (2 * math.pi)) - 2 * math.pi -- always in (-2*pi, 0]
    else
        return angleDelta(a, b)
    end
end

local function startPan(toYaw, toPitch, toRoll)
    pan.running = true
    pan.elapsed = 0
    pan.duration = math.max(PAN_DURATION, 0.001)
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

    local wasFirstPerson = camera.getMode() == camera.MODE.FirstPerson
    if ONLY_IN_FIRST_PERSON and not wasFirstPerson then
        return
    end

    active = true
    savedMode = camera.getMode()
    savedYaw = camera.getYaw()
    savedPitch = camera.getPitch()
    savedRoll = camera.getRoll()
    savedOffset = camera.getFocalPreferredOffset()

    -- Stop the built-in camera script from fighting us while the menu is open
    I.Camera.disableModeControl(MODNAME)
    I.Camera.disableThirdPersonOffsetControl(MODNAME)
    I.Camera.disableZoom(MODNAME)
    I.Camera.disableStandingPreview(MODNAME)

    camera.setMode(camera.MODE.Preview, true)
    camera.setPreferredThirdPersonDistance(DISTANCE)
    camera.setFocalPreferredOffset(util.vector2(HORIZONTAL_OFFSET, VERTICAL_OFFSET))

    local baseYaw = ROTATE_TO_FACE and (self.rotation:getYaw() + math.pi) or camera.getYaw()
    local targetYaw = baseYaw + math.rad(YAW_OFFSET)
    local targetPitch = math.rad(PITCH)
    local targetRoll = math.rad(ROLL)

    if SMOOTH_PAN then
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

    I.Camera.enableModeControl(MODNAME)
    I.Camera.enableThirdPersonOffsetControl(MODNAME)
    I.Camera.enableZoom(MODNAME)
    I.Camera.enableStandingPreview(MODNAME)

    if RESTORE_ON_CLOSE then
        camera.setMode(savedMode, true)
        camera.setFocalPreferredOffset(savedOffset)
        local instant = savedMode == camera.MODE.FirstPerson
        if SMOOTH_PAN and not instant then
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
    if not ENABLED then
        if active then exitInventoryView() end
        return
    end

    local enteringInventory = data.newMode == 'Interface' and data.oldMode ~= 'Interface'
    local leavingInventory = data.oldMode == 'Interface' and data.newMode ~= 'Interface'

    if enteringInventory then
        enterInventoryView()
    elseif leavingInventory then
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