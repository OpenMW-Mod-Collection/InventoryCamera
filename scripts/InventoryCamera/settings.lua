---@omw-context player

local storage = require('openmw.storage')
local async = require('openmw.async')

local settingsCache = require("scripts.InventoryCamera.utils.settingsCache")

-- Assigned via M.onPreviewCallbacks() by player.lua, once the preview
-- module exists. Kept as an indirection here (rather than requiring
-- preview.lua directly) so this module has no dependency on camera code.
local onStartChanged
local onFinishChanged

local M = {}

M.cam = settingsCache.new(
    storage.playerSection("SettingsInventoryCamera_camera"),
    async
)
M.start = settingsCache.new(
    storage.playerSection("SettingsInventoryCamera_startingPosition"),
    async,
    function()
        if onStartChanged then onStartChanged() end
    end
)
M.finish = settingsCache.new(
    storage.playerSection("SettingsInventoryCamera_destination"),
    async,
    function()
        if onFinishChanged then onFinishChanged() end
    end
)

--- Registers callbacks fired when the starting-position / destination
--- settings change, used to drive the outside-of-inventory preview.
function M.onPreviewCallbacks(startCb, finishCb)
    onStartChanged = startCb
    onFinishChanged = finishCb
end

return M