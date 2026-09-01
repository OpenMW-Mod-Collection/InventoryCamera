---@omw-context global
local I = require("openmw.interfaces")
local types = require("openmw.types")

I.ItemUsage.addHandlerForType(types.Item, function (object, actor, options)
    actor:sendEvent("InventoryCamera_forceLastRotation")
end)
