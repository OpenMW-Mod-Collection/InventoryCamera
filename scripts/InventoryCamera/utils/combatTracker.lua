---@omw-context local
-- =============================================
-- USAGE (in any local script)
-- =============================================
-- local combatTracker = require("scripts.MyMod.utils.combatTracker")
-- 
-- return {
--     engineHandlers = {
--         OMWMusicCombatTargetsChanged = combatTracker.OMWMusicCombatTargetsChanged,
--     },
-- }
-- =============================================
-- And then poll anything you want anytime you want

local self = require("openmw.self")

local M = {}

local selfId = self.id
local targetAddedHandlers = {}
local targetRemovedHandlers = {}

---@type table<openmw.GObject, true>
M.targetedBy = {}
M.inCombat = false

---@param func function<openmw.GObject>
M.addTargetAddedHandler = function(func)
    targetAddedHandlers[#targetAddedHandlers + 1] = func
end

---@param func function<openmw.GObject>
M.addTargetRemovedHandler = function(func)
    targetRemovedHandlers[#targetRemovedHandlers + 1] = func
end

---@class CombatTargetsChangedData
---@field actor openmw.GObject      Attacker
---@field targets openmw.GObject[]  List of attacker's targets

---@param data CombatTargetsChangedData
M.OMWMusicCombatTargetsChanged = function(data)
    local selfTargeted = false
    local hasTargets = false
    for _, target in ipairs(data.targets) do
        hasTargets = true
        if target.id == selfId then
            selfTargeted = true
            break
        end
    end

    if selfTargeted then
        M.targetedBy[data.actor.id] = true
        M.inCombat = true
        for _, handler in ipairs(targetAddedHandlers) do
            handler(data.actor)
        end
    elseif not hasTargets then
        M.targetedBy[data.actor.id] = nil
        M.inCombat = next(M.targetedBy)
        for _, handler in ipairs(targetRemovedHandlers) do
            handler(data.actor)
        end
    end

end

return M
