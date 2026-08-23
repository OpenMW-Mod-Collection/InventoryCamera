---@diagnostic disable: missing-fields
---@omw-context menu
local I = require('openmw.interfaces')
local core = require("openmw.core")
local auxUtil = require("openmw_aux.util")

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
                buttonWidth = 100,
            }
        },
        {
            key = "disableInCombat",
            name = "disableInCombat_name",
            renderer = "checkbox",
            default = false,
        },
        {
            key = "smoothPanning",
            name = "smoothPanning_name",
            description = "smoothPanning_desc",
            renderer = "checkbox",
            default = true,
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
            renderer = "select",
            default = "yawPanDirection_auto",
            argument = {
                l10n = "InventoryCamera",
                items = {
                    "yawPanDirection_auto",
                    "yawPanDirection_CW",
                    "yawPanDirection_CCW",
                    "yawPanDirection_random",
                },
            },
        },
        {
            key = "restoreOnClose",
            name = "restoreOnClose_name",
            description = "restoreOnClose_desc",
            renderer = "checkbox",
            default = true,
        },
    },
}

local positionSettings = {
    {
        key = "distance",
        name = "distance_name",
        renderer = "SuperSlider6",
        default = 250,
        argument = {
            min = 0,
            max = 750,
            step = 1,
            stepAffectsTextInput = false,
            default = 250,
            bottomRow = false,
        },
    },
    {
        key = "pitch",
        name = "pitch_name",
        description = "pitch_desc",
        renderer = "SuperSlider6",
        default = 0,
        argument = {
            min = -180,
            max = 180,
            step = 1,
            stepAffectsTextInput = false,
            default = 0,
            bottomRow = false,
            minLabel = l10n("pitch_up"),
            maxLabel = l10n("pitch_down"),
            unit = "°",
        },
    },
    {
        key = "yaw",
        name = "yaw_name",
        description = "yaw_desc",
        renderer = "SuperSlider6",
        default = 0,
        argument = {
            min = -180,
            max = 180,
            step = 1,
            stepAffectsTextInput = false,
            default = 0,
            bottomRow = false,
            minLabel = l10n("yaw_left"),
            maxLabel = l10n("yaw_right"),
            unit = "°",
        },
    },
    {
        key = "roll",
        name = "roll_name",
        renderer = "SuperSlider6",
        default = 0,
        argument = {
            min = -180,
            max = 180,
            step = 1,
            stepAffectsTextInput = false,
            default = 0,
            bottomRow = false,
            minLabel = l10n("roll_CW"),
            maxLabel = l10n("roll_CCW"),
            unit = "°",
        },
    },
    {
        key = "horizontalOffset",
        name = "horizontalOffset_name",
        renderer = "SuperSlider6",
        default = 0,
        argument = {
            min = -250,
            max = 250,
            step = 1,
            stepAffectsTextInput = false,
            default = 0,
            bottomRow = false,
            minLabel = l10n("horizontalOffset_left"),
            maxLabel = l10n("horizontalOffset_right"),
        },
    },
    {
        key = "verticalOffset",
        name = "verticalOffset_name",
        renderer = "SuperSlider6",
        default = 0,
        argument = {
            min = -250,
            max = 250,
            step = 1,
            stepAffectsTextInput = false,
            default = 0,
            bottomRow = false,
            minLabel = l10n("verticalOffset_down"),
            maxLabel = l10n("verticalOffset_up"),
        },
    },
}

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_startingPosition',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "startingPosition_name",
    description = "startingPosition_desc",
    order = 10,
    permanentStorage = true,
    settings = auxUtil.shallowCopy(positionSettings)
}

I.Settings.registerGroup {
    key = 'SettingsInventoryCamera_destination',
    page = 'InventoryCamera',
    l10n = "InventoryCamera",
    name = "destination_name",
    order = 11,
    permanentStorage = true,
    settings = auxUtil.shallowCopy(positionSettings)
}
