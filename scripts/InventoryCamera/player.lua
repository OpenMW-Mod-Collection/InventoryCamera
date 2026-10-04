---@omw-context player
local input = require("openmw.input")
local I = require("openmw.interfaces")

local settings = require("scripts.InventoryCamera.settingsManager")
local pan = require("scripts.InventoryCamera.camera.pan")
local view = require("scripts.InventoryCamera.camera.view")
local preview = require("scripts.InventoryCamera.camera.preview")
local save = require("scripts.InventoryCamera.camera.save")
local orbit = require("scripts.InventoryCamera.camera.orbit")
local spotlight = require("scripts.InventoryCamera.shaders.spotlight")
local dof = require("scripts.InventoryCamera.shaders.dof")
local combatTracker = require("scripts.InventoryCamera.utils.combatTracker")

settings.onPreviewCallbacks(
    function() preview.start('start') end,
    function() preview.start('finish') end
)

local function antiPreviewKeyPressed(key)
    if key == "shift" then
        return input.isShiftPressed()
    elseif key == "ctrl" then
        return input.isCtrlPressed()
    elseif key == "alt" then
        return input.isAltPressed()
    else
        return false
    end
end

local function onUpdate(dt)
    preview.update(dt)
end

-- onFrame runs even while the world is paused (unlike onUpdate's dt, which
-- is always 0 on pause), so panning is driven from here to allow smooth
-- offset/yaw/pitch/roll/distance transitions while paused.
local function onFrame(dt)
    pan.update(settings.cam.yawPanDirection)
    orbit.update()
    spotlight.update()
    dof.update()
end

local function enterView()
    view.enter()
    -- enter() bails out when the current perspective is switched off
    if not view.active then return end
    orbit.start()
    spotlight.enter()
    dof.enter()
end

-- Orbit first: exit() pans out from the pose the orbit last applied.
local function exitView()
    orbit.stop()
    spotlight.exit()
    dof.exit()
    view.exit()
end

local function onUiModeChanged(data)
    local enteringInventory = data.newMode == 'Interface'
        and data.oldMode ~= 'Interface'
        and (I.UI.isWindowVisible(I.UI.WINDOW.Inventory) or not settings.cam.requireInvWindow)
    local leavingInventory = data.oldMode == 'Interface'
        and data.newMode ~= 'Interface'
    local skipPreview = antiPreviewKeyPressed(settings.cam.antiPreviewKey)
        or (combatTracker.inCombat and settings.cam.skipDuringCombat)

    if enteringInventory and not skipPreview then
        preview.endPreview()
        enterView()
    elseif leavingInventory then
        exitView()
    elseif view.active then
        exitView()
    end
end

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onFrame = onFrame,
        onMouseWheel = orbit.onMouseWheel,
        onInit = save.onLoad,
        onSave = save.onSave,
        onLoad = save.onLoad,
    },
    eventHandlers = {
        UiModeChanged = onUiModeChanged,
        OMWMusicCombatTargetsChanged = combatTracker.OMWMusicCombatTargetsChanged,
        InventoryCamera_unpauseDynamicCamera = function()
            I.DynamicCamera.setCameraControlSuspended(false, "InventoryCamera")
        end,
    },
}
