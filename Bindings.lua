local TB = TortoiseBots
local L = TB.L

-- Key Bindings screen labels; Locales load before this file.
BINDING_HEADER_TBM = L["TortoiseBots Manager"]
BINDING_NAME_TBM_ATTACK = L["Attack target"]
BINDING_NAME_TBM_STOP = L["Stop combat"]
BINDING_NAME_TBM_INTERRUPT = L["Interrupt target"]
BINDING_NAME_TBM_FLEE = L["Flee"]
BINDING_NAME_TBM_PULL = L["Pull target"]
BINDING_NAME_TBM_PULLBACK = L["Pull target back"]
BINDING_NAME_TBM_FOCUS_SKULL = L["Focus skull"]
BINDING_NAME_TBM_FOLLOW = L["Follow"]
BINDING_NAME_TBM_STAY = L["Stay"]
BINDING_NAME_TBM_COME = L["Come and hold"]
BINDING_NAME_TBM_FAV1 = string.format(L["Mini favourite %d"], 1)
BINDING_NAME_TBM_FAV2 = string.format(L["Mini favourite %d"], 2)
BINDING_NAME_TBM_FAV3 = string.format(L["Mini favourite %d"], 3)
BINDING_NAME_TBM_FAV4 = string.format(L["Mini favourite %d"], 4)
BINDING_NAME_TBM_FAV5 = string.format(L["Mini favourite %d"], 5)
BINDING_NAME_TBM_FAV6 = string.format(L["Mini favourite %d"], 6)
BINDING_NAME_TBM_FAV7 = string.format(L["Mini favourite %d"], 7)
BINDING_NAME_TBM_FAV8 = string.format(L["Mini favourite %d"], 8)
BINDING_NAME_TBM_FAV9 = string.format(L["Mini favourite %d"], 9)
BINDING_NAME_TBM_FAV10 = string.format(L["Mini favourite %d"], 10)
BINDING_NAME_TBM_FAV11 = string.format(L["Mini favourite %d"], 11)
BINDING_NAME_TBM_FAV12 = string.format(L["Mini favourite %d"], 12)
BINDING_NAME_TBM_TOGGLE_WINDOW = L["Toggle window"]
BINDING_NAME_TBM_MINI_MODE = L["Toggle mini bar"]


-- Keybinding handlers: one gameplay intent each, same path as the Fight tab.
function TB.SendKeyIntent(intent)
    intent = TB.Trim(intent or "")
    if intent == "" then return false end
    if intent == "flee" then
        if TB.HasServerCapability and not TB.HasServerCapability("flee") then return false end
        return TB.SendBotCommand("action " .. intent)
    end
    if intent == "pull" or intent == "pullback" then
        if TB.PullIntent then intent = TB.PullIntent(intent) end
        return TB.SendBotCommand("action " .. intent)
    end
    return TB.SendActionIntent(intent)
end

-- One binding name per gameplay intent the bindings above cover. The action
-- tooltips (Fight tab, mini bar) name the bound key in the title.
TB.BINDING_BY_INTENT = {
    attack = "TBM_ATTACK",
    stop = "TBM_STOP",
    interrupt = "TBM_INTERRUPT",
    flee = "TBM_FLEE",
    pull = "TBM_PULL",
    pullback = "TBM_PULLBACK",
    ["focus skull"] = "TBM_FOCUS_SKULL",
    follow = "TBM_FOLLOW",
    stay = "TBM_STAY",
    come = "TBM_COME",
    hold = "TBM_COME",
}

-- The player's bound key for an intent ("SHIFT-1"), or nil when unbound.
-- GetBindingText is FrameXML; without it the raw key still reads fine.
function TB.BindingText(intent)
    if not intent then return nil end
    local binding = TB.BINDING_BY_INTENT and TB.BINDING_BY_INTENT[intent] or nil
    if not binding or type(GetBindingKey) ~= "function" then return nil end
    local key1, key2 = GetBindingKey(binding)
    if not key1 then return nil end
    local function keyText(key)
        if type(GetBindingText) == "function" then
            return GetBindingText(key, "KEY_")
        end
        return key
    end
    if key2 then return keyText(key1) .. ", " .. keyText(key2) end
    return keyText(key1)
end
