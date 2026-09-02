---@omw-context player
local input = require("openmw.input")
local I = require("openmw.interfaces")

local settings = require("scripts.InventoryCamera.settings")
local pan = require("scripts.InventoryCamera.camera.pan")
local view = require("scripts.InventoryCamera.camera.view")
local preview = require("scripts.InventoryCamera.camera.preview")
local save = require("scripts.InventoryCamera.camera.save")
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
        view.enter()
    elseif leavingInventory then
        view.exit()
    elseif view.active then
        view.exit()
    end
end

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onFrame = onFrame,
        onInit = save.onLoad,
        onSave = save.onSave,
        onLoad = save.onLoad,
    },
    eventHandlers = {
        UiModeChanged = onUiModeChanged,
        OMWMusicCombatTargetsChanged = combatTracker.OMWMusicCombatTargetsChanged,
    },
}
