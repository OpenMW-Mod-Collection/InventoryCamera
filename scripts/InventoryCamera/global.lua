---@omw-context global
-- Hangs a light in front of and above the character while the inventory
-- camera is up (spotlight.lua works out where). Only global scripts can
-- create objects, so spotlight.lua asks for it by event.
-- Works with the world paused too: global events are still delivered then,
-- and object changes are applied every frame regardless.

local types = require('openmw.types')
local world = require('openmw.world')

-- Light records made so far, keyed by their look. Records created at runtime
-- go into the save, so they are reused instead of minting one per visit.
local records = {}
local light = nil

local function recordFor(radius, color)
    radius = math.floor(radius)
    local key = radius .. "|" .. color:asHex()
    local id = records[key]
    if id and types.Light.records[id] then return id end

    -- No model: the engine still attaches the light itself (see
    -- MWClass::Light::insertObjectRendering), so nothing is drawn.
    id = world.createRecord(types.Light.createRecordDraft {
        name = "Inventory Camera Spotlight",
        radius = radius,
        color = color,
        isDynamic = true,
    }).id
    records[key] = id
    return id
end

local function removeLight()
    if light and light:isValid() and light.count > 0 then
        light:remove()
    end
    light = nil
end

local function spawnLight(data)
    removeLight()
    local actor = data.actor
    if not (actor and actor:isValid() and actor.cell) then return end

    light = world.createObject(recordFor(data.radius, data.color), 1)
    light:teleport(actor.cell, data.position)
end

return {
    engineHandlers = {
        onSave = function()
            return {
                records = records,
                light = light
            }
        end,
        onLoad = function(data)
            data = data or {}
            records = data.records or {}
            light = data.light
            removeLight()
        end,
    },
    eventHandlers = {
        InventoryCamera_SpawnLight = spawnLight,
        InventoryCamera_RemoveLight = removeLight,
    },
}
