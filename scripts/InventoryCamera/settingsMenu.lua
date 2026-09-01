---@diagnostic disable: missing-fields
---@omw-context menu
local I = require('openmw.interfaces')
local core = require("openmw.core")

local l10n = core.l10n("InventoryCamera")

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
            renderer = "multiselect",
            default = {
                first = true,
                third = true,
            },
            argument = {
                keys = {
                    "first",
                    "third",
                },
                aliases = {
                    first = l10n("person_first"),
                    third = l10n("person_third"),
                },
                buttonWidth = 135,
            }
        },
        {
            key = "smoothPanning",
            name = "smoothPanning_name",
            description = "smoothPanning_desc",
            renderer = "multiselect",
            default = {
                firstIn  = true,
                thirdIn  = true,
                thirdOut = true,
            },
            argument = {
                keys = {
                    "firstIn",
                    "thirdIn",
                    "thirdOut",
                },
                aliases = {
                    firstIn  = l10n("smoothPanning_firstIn"),
                    thirdIn  = l10n("smoothPanning_thirdIn"),
                    thirdOut = l10n("smoothPanning_thirdOut"),
                },
                buttonWidth = 135,
            }
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
            key = "ifPaused",
            name = "ifPaused_name",
            description = "ifPaused_desc",
            renderer = "SuperSelect3",
            default = "disable",
            argument = {
                l10n = "InventoryCamera",
                items = {
                    "disable",
                    "snap",
                },
                width = 150,
            }
        },
        -- {
        --     key = "ifPaused",
        --     name = "ifPaused_name",
        --     description = "ifPaused_desc",
        --     renderer = "select",
        --     default = "disable",
        --     argument = {
        --         l10n = "InventoryCamera",
        --         items = {
        --             "disable",
        --             "snap",
        --         },
        --     }
        -- },
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
            description = "horizontalOffset_desc",
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
            description = "verticalOffset_desc",
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
