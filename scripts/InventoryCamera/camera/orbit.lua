---@diagnostic disable: need-check-nil, inject-field, undefined-field, missing-fields
---@omw-context player
-- Lets the player swing the inventory camera around their character by
-- holding the left mouse button over empty screen space and dragging, pan
-- the camera's offset by holding the middle mouse button and dragging, and
-- zoom in/out by scrolling there. With Inventory Extender, an item carried
-- on the cursor and let go over the character is used on them (equipped...).
--
-- "Empty screen space" is decided by MyGUI, not by us: a full-screen catcher
-- widget sits on its own layer right under the Windows layer. Windows
-- (inventory, map, stats...) still get their clicks first; whatever falls
-- through lands on the catcher instead of the HUD's world-click handler or
-- Inventory Extender's full-screen DragBlocker widget. The latter gets its
-- events handed on (see utils/inventoryExtender.lua), so IE's world
-- tooltips, pickups and drops keep working under the catcher.
--
-- Input only nudges a target pose; update() eases the real pose towards it
-- every frame, so wheel notches and jittery drags come out smooth.

local ui = require('openmw.ui')
local async = require('openmw.async')
local camera = require('openmw.camera')
local core = require('openmw.core')
local input = require('openmw.input')
local nearby = require('openmw.nearby')
local self = require('openmw.self')
local util = require('openmw.util')
local I = require('openmw.interfaces')

local pan = require("scripts.InventoryCamera.camera.pan")
local pose = require("scripts.InventoryCamera.camera.pose")
local settings = require("scripts.InventoryCamera.settingsManager")
local ie = require("scripts.InventoryCamera.utils.inventoryExtender")

local LAYER = "InventoryCameraOrbit"
local LMB = 1                       -- SDL button index, as UI mouse events report it
local MMB = 2
local RAD_PER_PIXEL = math.rad(0.3) -- at Rotation Speed 100%
local OFFSET_PER_PIXEL = 0.6        -- world units per pixel at distance 250, at Pan Speed 100%
local ZOOM_STEP = 0.12              -- fraction of the distance per wheel notch, at Zoom Speed 100%
local PITCH_LIMIT = math.rad(85)
local SMOOTHING = 14                -- 1/s, how fast the camera catches up with the target
local SETTLED = 1e-4
local RAY_LENGTH = 2000             -- the camera never gets further than 750 from the character
local TOOLTIP_OFFSET = util.vector2(40, 8)

local M = {}

local tooltip = ui.create {
    layer = "Windows",
    template = I.MWUI.templates.boxSolid,
    props = {
        visible = false,
    },
    content = ui.content {
        {
            template = I.MWUI.templates.padding,
            content = ui.content {
                {
                    template = I.MWUI.templates.padding,
                    content = ui.content {
                        {
                            template = I.MWUI.templates.textNormal,
                            props = { text = "Use" },
                        },
                    },
                },
            },
        },
    },
}

---@type openmw.ui.Element|nil
local catcher = nil
local dragButton = nil -- LMB, MMB, or nil
local hovered = false
local lastPos = nil
local overCharacter = false -- cursor on the character's body, as of the last move

-- Both nil until the player first touches the controls during an inventory
-- visit. From then on the orbit owns the camera until stop().
local target = nil  -- { yaw, pitch, distance, offset }
local current = nil -- { yaw, pitch, roll, distance, offset }

local function clamp(x, lo, hi)
    return math.max(lo, math.min(hi, x))
end

-- Takes over from wherever the camera is right now, cutting short the
-- pan-in if it is still running.
local function takeControl()
    if target then return end
    local yaw, pitch, roll, distance, offset = pan.getPose()
    pan.stop()
    current = { yaw = yaw, pitch = pitch, roll = roll, distance = distance, offset = offset }
    target = { yaw = yaw, pitch = pitch, distance = distance, offset = offset }
end

local function rotate(delta)
    takeControl()
    local speed = RAD_PER_PIXEL * settings.controls.speed.speed_rotate / 100
    -- Same sense as mouse look: drag right turns the view right, drag down
    -- looks further down (camera rises).
    target.yaw = target.yaw + delta.x * speed
    target.pitch = clamp(target.pitch + delta.y * speed, -PITCH_LIMIT, PITCH_LIMIT)
end

-- Pans the offset: drag right moves the framing right, drag down moves it
-- down - like grabbing the shot and dragging it, same sense as the rotate
-- drag. Scaled by the current distance so a pixel of drag feels the same
-- whether zoomed in or out.
local function move(delta)
    takeControl()
    local speed = OFFSET_PER_PIXEL * (settings.controls.speed.speed_pan / 100) * (target.distance / 250)
    target.offset = util.vector2(
        target.offset.x - delta.x * speed,
        target.offset.y + delta.y * speed
    )
end

-- Inventory Extender also inserts its DragBlocker layer before Windows, but
-- when its script loads - before the first inventory visit creates this one,
-- so this lands above it.
local function ensureLayer()
    if not ui.layers.indexOf(LAYER) then
        ui.layers.insertBefore('Windows', LAYER, { interactive = true })
    end
end

local function hideTooltip()
    tooltip.layout.props.visible = false
    tooltip:update()
end

--- Shows/moves the "Use" tooltip near the cursor, used to hint that letting
--- go of a carried item over the character will use/equip it.
local function showTooltip(position)
    local pos = position + TOOLTIP_OFFSET
    tooltip.layout.props.visible = true
    tooltip.layout.props.position = pos
    tooltip:update()
end

-- A rendering ray, so it follows the actual body and gear rather than the
-- collision capsule. Async, as UI callbacks may not cast synchronously; the
-- answer lands a frame later, well before the click that needs it.
local onCharacterRay = async:callback(function(result)
    overCharacter = result.hitObject ~= nil and result.hitObject.id == self.id
end)

local function checkOverCharacter(position)
    local size = ui.layers[ui.layers.indexOf(LAYER)].size
    local from = camera.getPosition()
    local dir = camera.viewportToWorldVector(util.vector2(position.x / size.x, position.y / size.y))
    nearby.asyncCastRenderingRay(onCharacterRay, from, from + dir * RAY_LENGTH)
end

local function onPress(e)
    if e.button == LMB then
        if ie.carried() then
            if overCharacter and settings.controls.dropToEquip and ie.useCarried() then return end
            ie.forward('mousePress', e) -- IE drops it into the world
            return
        end
        if ie.hoveredItem() then
            ie.forward('mousePress', e) -- IE picks it up
            return
        end
        if not settings.controls.enableMouseControls.enableMouseControls_rotate then return end
        dragButton = LMB
        lastPos = e.position
    elseif e.button == MMB then
        if not settings.controls.enableMouseControls.enableMouseControls_move then return end
        if ie.carried() or ie.hoveredItem() then return end -- don't fight IE's drag/drop
        dragButton = MMB
        lastPos = e.position
    end
end

-- Fires for plain hovering and for drags (the engine routes MyGUI's drag
-- event here too, with e.button set).
local function onMove(e)
    hovered = true
    if dragButton == LMB then
        rotate(e.position - lastPos)
        lastPos = e.position
        return
    elseif dragButton == MMB then
        move(e.position - lastPos)
        lastPos = e.position
        return
    end
    ie.forward('mouseMove', e)
    if ie.carried() then
        checkOverCharacter(e.position)
        if settings.controls.dropTooltip and overCharacter then
            showTooltip(e.position)
        else
            hideTooltip()
        end
    else
        overCharacter = false
        hideTooltip()
    end
end

--- Puts up the catcher. Call once the inventory camera has taken over.
function M.start()
    if catcher or not I.InventoryExtender then return end

    local emc = settings.controls.enableMouseControls
    if not (
        emc.enableMouseControls_rotate
        or emc.enableMouseControls_move
        or emc.enableMouseControls_zoom
        or settings.controls.dropToEquip
    ) then
        return
    end

    ensureLayer()
    dragButton, hovered, lastPos, overCharacter = nil, false, nil, false

    catcher = ui.create {
        layer = LAYER,
        type = ui.TYPE.Widget,
        props = { relativeSize = util.vector2(1, 1) },
        events = {
            mousePress = async:callback(onPress),
            mouseRelease = async:callback(function(e)
                if e.button == dragButton then dragButton = nil end
            end),
            mouseMove = async:callback(onMove),
            focusGain = async:callback(function() hovered = true end),
            focusLoss = async:callback(function(e)
                hovered, overCharacter = false, false
                hideTooltip()
                ie.forward('focusLoss', e)
            end),
        },
    }
end

--- Takes the catcher down and hands the camera back. Call before
--- view.exit(), which pans out from pan.getPose() - kept current by update().
function M.stop()
    if catcher then
        catcher:destroy()
        catcher = nil
    end
    hideTooltip()
    dragButton, hovered, lastPos, overCharacter = nil, false, nil, false
    target, current = nil, nil
end

--- onMouseWheel handler. The wheel also reaches MyGUI, so only zoom while
--- the cursor is over the catcher - not while scrolling the item list.
function M.onMouseWheel(vertical)
    if not catcher or not hovered or not settings.controls.enableMouseControls.enableMouseControls_zoom then return end
    takeControl()
    local step = clamp(ZOOM_STEP * settings.controls.speed.speed_zoom / 100, 0, 0.9)
    local lo = settings.controls.distanceCap.distanceCap_min
    local hi = math.max(lo, settings.controls.distanceCap.distanceCap_max)
    local oldDistance = target.distance
    -- Multiplicative, so each notch feels the same close up and far out.
    local newDistance = clamp(oldDistance * (1 - step) ^ vertical, lo, hi)
    target.distance = newDistance

    -- The offset is a fixed world-space displacement of the framing point
    -- away from the character; left alone it wouldn't scale with distance,
    -- so the character would visibly drift across the screen as we zoom.
    -- Scaling it by the same ratio keeps the character anchored in place.
    if oldDistance > 1e-4 then
        local ratio = newDistance / oldDistance
        target.offset = target.offset * ratio
    end
end

--- Call every frame (onFrame - it keeps running while the world is paused).
function M.update()
    if not target then return end

    -- The release can be missed, e.g. if it happens while alt-tabbed.
    if dragButton == LMB and not input.isMouseButtonPressed(LMB) then
        dragButton = nil
    elseif dragButton == MMB and not input.isMouseButtonPressed(MMB) then
        dragButton = nil
    end

    local dYaw = target.yaw - current.yaw
    local dPitch = target.pitch - current.pitch
    local dDistance = target.distance - current.distance
    local dOffset = target.offset - current.offset
    -- Once settled, stop re-applying: pose.apply re-anchors to the head, and
    -- idle animations would make a held camera bob along with it.
    if math.abs(dYaw) < SETTLED and math.abs(dPitch) < SETTLED and math.abs(dDistance) < 0.01
        and dOffset:length() < 0.01 then
        return
    end

    local k = 1 - math.exp(-SMOOTHING * core.getRealFrameDuration())
    current.yaw = current.yaw + dYaw * k
    current.pitch = current.pitch + dPitch * k
    current.distance = current.distance + dDistance * k
    current.offset = current.offset + dOffset * k
    pan.set(pose.apply, current.yaw, current.pitch, current.roll, current.distance, current.offset)
end

return M
