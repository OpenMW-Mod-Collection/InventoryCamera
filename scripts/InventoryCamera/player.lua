---@omw-context player

local settings = require("scripts.InventoryCamera.settings")
local pan = require("scripts.InventoryCamera.camera.pan")
local view = require("scripts.InventoryCamera.camera.view")
local preview = require("scripts.InventoryCamera.camera.preview")
local save = require("scripts.InventoryCamera.camera.save")

-- Wire settings changes to the outside-of-inventory preview. Done here
-- (rather than settings.lua requiring preview.lua directly) to avoid a
-- circular require between settings <-> preview <-> view.
settings.onPreviewCallbacks(
    function() preview.start('start') end,
    function() preview.start('finish') end
)

local function onUpdate(dt)
    preview.update(dt)
    pan.update(dt, settings.cam.yawPanDirection)
end

local function onUiModeChanged(data)
    local enteringInventory = data.newMode == 'Interface' and data.oldMode ~= 'Interface'
    local leavingInventory = data.oldMode == 'Interface' and data.newMode ~= 'Interface'

    if enteringInventory then
        preview.endPreview()
        view.enter()
    elseif leavingInventory then
        view.exit()
    elseif view.active then
        view.exit()
    end
end

return {
    eventHandlers = {
        UiModeChanged = onUiModeChanged,
    },
    engineHandlers = {
        onUpdate = onUpdate,
        onInit = save.onLoad,
        onSave = save.onSave,
        onLoad = save.onLoad,
    },
}