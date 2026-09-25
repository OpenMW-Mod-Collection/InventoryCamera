---@diagnostic disable: undefined-field
---@omw-context player
-- Bridge to Inventory Extender's drag and drop, for the inventory camera's
-- catcher widget (camera/orbit.lua).
--
-- IE does the world side of dragging - tooltips for items lying around,
-- picking them up, dropping the carried item into the world - through a
-- full-screen widget on its DragBlocker layer, which the catcher covers. So
-- the catcher hands that widget the mouse events it would have had, and only
-- keeps the ones that are its own: orbiting, and a carried item let go over
-- the character, which gets used on them (equipped, drunk, read...).
--
-- Only getContext() is IE's published API; the rest reaches into its
-- drag-and-drop state. Every access is guarded, so if an IE update changes
-- it, the bridge just goes quiet.

local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')

local M = {}

local function dragAndDrop()
    local ie = I.InventoryExtender
    local ctx = ie and ie.getContext and ie.getContext()
    return ctx and ctx.dragAndDrop
end

--- The item IE has on the cursor, if any.
function M.carried()
    local dnd = dragAndDrop()
    return dnd and dnd.draggingObject
end

--- A carriable item lying in the world under the cursor, as of the last
--- forwarded mouse move (IE finds it with an async ray, so a frame late).
function M.hoveredItem()
    local dnd = dragAndDrop()
    local obj = dnd and dnd.hoveredObject
    if obj and obj:isValid() and types.Item.objectIsInstance(obj) and types.Item.isCarriable(obj) then
        return obj
    end
end

--- Passes a UI mouse event on to IE's DragBlocker widget, as if it had gone
--- there. Skipped while that widget is switched off (IE shrinks it to nothing
--- outside its drag modes, and in its tooltip compatibility mode), so this
--- never does more than IE itself would.
function M.forward(name, e)
    local dnd = dragAndDrop()
    local layout = dnd and dnd.wrapper and dnd.wrapper.layout
    local size = layout and layout.props and layout.props.relativeSize
    local callback = layout and layout.events and layout.events[name]
    if callback and size and size.x > 0 then
        callback(e)
    end
end

--- Uses the carried item on the character and ends the drag. Goes the way
--- IE's own Use button does: its IE_UseItem event wraps the built-in UseItem
--- (the same action as dropping an item on the vanilla paper doll) and
--- refreshes IE's windows.
function M.useCarried()
    local dnd = dragAndDrop()
    local item = dnd and dnd.draggingObject
    if not item then return false end
    core.sendGlobalEvent('IE_UseItem', { object = item, actor = self.object })
    dnd:stopDrag()
    return true
end

return M
