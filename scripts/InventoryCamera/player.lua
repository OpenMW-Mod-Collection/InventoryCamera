---@omw-context player
local input = require("openmw.input")
local self = require("openmw.self")

local settings = require("scripts.InventoryCamera.settings")
local pan = require("scripts.InventoryCamera.camera.pan")
local view = require("scripts.InventoryCamera.camera.view")
local preview = require("scripts.InventoryCamera.camera.preview")
local save = require("scripts.InventoryCamera.camera.save")
local combatTracker = require("scripts.InventoryCamera.utils.combatTracker")

local lastSelfRotation

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
    pan.update(dt, settings.cam.yawPanDirection)
end

local function onUiModeChanged(data)
    local enteringInventory = data.newMode == 'Interface' and data.oldMode ~= 'Interface'
    local leavingInventory = data.oldMode == 'Interface' and data.newMode ~= 'Interface'
    local skipPreview = antiPreviewKeyPressed(settings.cam.antiPreviewKey)
        or (combatTracker.inCombat and settings.cam.skipDuringCombat)

    if enteringInventory and not skipPreview then
        preview.endPreview()
        view.enter()
        lastSelfRotation = self.rotation
    elseif leavingInventory then
        view.exit()
    elseif view.active then
        view.exit()
    end
end

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onInit = save.onLoad,
        onSave = save.onSave,
        onLoad = save.onLoad,
    },
    eventHandlers = {
        UiModeChanged = onUiModeChanged,
        OMWMusicCombatTargetsChanged = combatTracker.OMWMusicCombatTargetsChanged,
        InventoryCamera_forceLastRotation = function()
            self.rotation = lastSelfRotation or self.rotation
        end
    },
}
