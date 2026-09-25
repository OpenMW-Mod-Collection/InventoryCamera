---@diagnostic disable: missing-fields
---@omw-context menu
local I = require('openmw.interfaces')
local core = require("openmw.core")
local util = require("openmw.util")

local l10n = core.l10n("InventoryCamera")
local presetColors = {
    "d4edfc", -- thirst
    "bfd4bc", -- hunger
    "cfbddb", -- sleep
    "81cded", -- fav color of blue
    "caa560", -- fontColor_color_normal
    "d4b77f", -- goldenMix
    "dfc99f", -- FontColor_color_normal_over
    "eee2c9", -- lightText
    "253170", -- fontColor_color_journal_link
    "3a4daf", -- fontColor_color_journal_link_over
    "707ecf", -- fontColor_color_journal_link_pressed
}

I.Settings.registerPage {
    key = "InventoryCamera",
    l10n = "InventoryCamera",
    name = "page_name",
    description = "page_desc",
}

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_camera',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "cameraSettings_name",
    order = 0,
    permanentStorage = true,
    settings = {
        {
            key = "person",
            name = "person_name",
            renderer = "multiCheckbox",
            default = {
                first = true,
                third = true,
            },
            argument = {
                l10n = "InventoryCamera",
                keys = {
                    "first",
                    "third",
                },
                colorful = true,
            },
        },
        {
            key = "smoothPanning",
            name = "smoothPanning_name",
            description = "smoothPanning_desc",
            renderer = "multiCheckbox",
            default = {
                firstIn  = true,
                thirdIn  = true,
                thirdOut = true,
            },
            argument = {
                l10n = "InventoryCamera",
                keys = {
                    "firstIn",
                    "thirdIn",
                    "thirdOut",
                },
                colorful = true,
            },
        },
        {
            key = "panDuration",
            name = "panDuration_name",
            renderer = "number",
            default = 1,
            argument = {
                min = 0
            },
        },
        {
            key = "yawPanDirection",
            name = "yawPanDirection_name",
            description = "yawPanDirection_desc",
            renderer = "SuperSelect3",
            default = "yawPanDirection_auto",
            argument = {
                l10n = "InventoryCamera",
                items = {
                    "yawPanDirection_auto",
                    "yawPanDirection_CW",
                    "yawPanDirection_CCW",
                    "yawPanDirection_random",
                },
                width = 150,
            },
        },
        {
            key = "antiPreviewKey",
            name = "antiPreviewKey_name",
            description = "antiPreviewKey_desc",
            renderer = "SuperSelect3",
            default = "shift",
            argument = {
                l10n = "InventoryCamera",
                items = {
                    "shift",
                    "ctrl",
                    "alt",
                    "none",
                },
                width = 80,
            }
        },
        {
            key = "skipDuringCombat",
            name = "skipDuringCombat_name",
            renderer = "checkbox",
            default = true,
        },
        {
            key = "requireInvWindow",
            name = "requireInvWindow_name",
            description = "requireInvWindow_desc",
            renderer = "checkbox",
            default = true,
        },
    },
}

---@class PositionDefaults
---@field distance number | nil
---@field pitch number | nil
---@field yaw number | nil
---@field roll number | nil
---@field vOffset number | nil
---@field hOffset number | nil

---@param defaults PositionDefaults
---@return table
local function newPosSettings(defaults)
    return {
        {
            key = "distance",
            name = "distance_name",
            renderer = "SuperSlider6",
            default = defaults.distance or 250,
            argument = {
                min = 0,
                max = 750,
                step = 1,
                stepAffectsTextInput = false,
                default = defaults.distance or 250,
                bottomRow = true,
                showResetButton = true,
            },
        },
        {
            key = "pitch",
            name = "pitch_name",
            description = "pitch_desc",
            renderer = "SuperSlider6",
            default = defaults.pitch or 0,
            argument = {
                min = -180,
                max = 180,
                step = 1,
                stepAffectsTextInput = false,
                default = defaults.pitch or 0,
                bottomRow = true,
                unit = "°",
                showResetButton = true,
            },
        },
        {
            key = "yaw",
            name = "yaw_name",
            description = "yaw_desc",
            renderer = "SuperSlider6",
            default = defaults.yaw or 0,
            argument = {
                min = -180,
                max = 180,
                step = 1,
                stepAffectsTextInput = false,
                default = defaults.yaw or 0,
                bottomRow = true,
                unit = "°",
                showResetButton = true,
            },
        },
        {
            key = "roll",
            name = "roll_name",
            renderer = "SuperSlider6",
            default = defaults.roll or 0,
            argument = {
                min = -180,
                max = 180,
                step = 1,
                stepAffectsTextInput = false,
                default = defaults.roll or 0,
                bottomRow = true,
                unit = "°",
                showResetButton = true,
            },
        },
        {
            key = "horizontalOffset",
            name = "horizontalOffset_name",
            renderer = "SuperSlider6",
            default = defaults.hOffset or 0,
            argument = {
                min = -250,
                max = 250,
                step = 1,
                stepAffectsTextInput = false,
                default = defaults.hOffset or 0,
                bottomRow = true,
                minLabel = l10n("horizontalOffset_left"),
                maxLabel = l10n("horizontalOffset_right"),
                showResetButton = true,
            },
        },
        {
            key = "verticalOffset",
            name = "verticalOffset_name",
            renderer = "SuperSlider6",
            default = defaults.vOffset or 0,
            argument = {
                min = -250,
                max = 250,
                step = 1,
                stepAffectsTextInput = false,
                default = defaults.vOffset or 0,
                bottomRow = true,
                minLabel = l10n("verticalOffset_down"),
                maxLabel = l10n("verticalOffset_up"),
                showResetButton = true,
            },
        },
    }
end

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_startingPosition',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "startingPosition_name",
    description = "startingPosition_desc",
    order = 10,
    permanentStorage = true,
    settings = newPosSettings {
        distance = 100,
        pitch = -10,
        yaw = 20,
        roll = -10,
        hOffset = 0,
        vOffset = -80,
    }
}

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_destination',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "destination_name",
    order = 11,
    permanentStorage = true,
    settings = newPosSettings {
        distance = 80,
        pitch = 10,
        yaw = 150,
        roll = -3,
        hOffset = -35,
        vOffset = -25,
    }
}

local function slider(key, default, min, max, unit, step)
    return {
        key = key,
        name = key .. "_name",
        description = key .. "_desc",
        renderer = "SuperSlider6",
        default = default,
        argument = {
            min = min,
            max = max,
            step = step or 1,
            stepAffectsTextInput = false,
            default = default,
            bottomRow = true,
            unit = unit,
            showResetButton = true,
        },
    }
end

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_controls',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "controls_name",
    description = "controls_desc",
    order = 20,
    permanentStorage = true,
    settings = {
        {
            key = "enableMouseControls",
            name = "enableMouseControls_name",
            description = "enableMouseControls_desc",
            renderer = "multiCheckbox",
            default = {
                rotate  = true,
                move  = true,
                zoom = true,
            },
            argument = {
                l10n = "InventoryCamera",
                keys = {
                    "rotate",
                    "move",
                    "zoom",
                },
                colorful = true,
            },
        },
        {
            key = "dropToEquip",
            name = "dropToEquip_name",
            description = "dropToEquip_desc",
            renderer = "checkbox",
            default = true,
        },
        {
            key = "dropTooltip",
            name = "dropTooltip_name",
            description = "dropTooltip_desc",
            renderer = "checkbox",
            default = true,
        },
        slider("rotateSpeed", 100, 10, 300, "%"),
        slider("panSpeed", 100, 10, 300, "%"),
        slider("zoomSpeed", 100, 10, 300, "%"),
        slider("minDistance", 40, 10, 750),
        slider("maxDistance", 350, 10, 750),
    },
}

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_spotlight',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "spotlight_name",
    description = "spotlight_desc",
    order = 30,
    permanentStorage = true,
    settings = {
        {
            key = "enabled",
            name = "spotEnabled_name",
            description = "spotEnabled_desc",
            renderer = "checkbox",
            default = true,
        },
        slider("surroundBrightness", 6, 0, 100, "%"),
        slider("radiusScale", 2, 0, 6, "x", 0.1),
        slider("softness", 35, 0, 100, "%"),
        {
            key = "light",
            name = "light_name",
            description = "light_desc",
            renderer = "checkbox",
            default = true,
        },
        slider("lightInFront", 70, 0, 400),
        slider("lightAboveHead", 80, 0, 300),
        slider("lightRadius", 350, 50, 1000),
        {
            key = "lightColor",
            name = "lightColor_name",
            renderer = "SuperColorPicker2",
            default = util.color.hex("ffe8c8"),
            argument = {
                presetColors = presetColors,
            },
        },
    },
}

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_depthOfField',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "depthOfField_name",
    description = "depthOfField_desc",
    order = 31,
    permanentStorage = true,
    settings = {
        {
            key = "enabled",
            name = "dofEnabled_name",
            description = "dofEnabled_desc",
            renderer = "checkbox",
            default = true,
        },
        slider("aperture", 0.2, 0, 1, nil, 0.01),
        slider("fadeIn", 2, 0, 5, "sec", 0.1),
        slider("fadeOut", 0.3, 0, 5, "sec", 0.1),
    },
}
