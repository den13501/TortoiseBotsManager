-- TortoiseBotsManager/Locales/Locale.lua
-- Translation table. The English text is the key: L["Attack"] returns the
-- client language's text, or the English key itself when no translation
-- exists, so a missing entry never breaks a label.
-- Only player-facing text goes through L. Commands sent to the server, TBM:
-- protocol fields and patterns that parse server replies stay English.
-- Vanilla 1.12 safe (Lua 5.0).

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots

TB.LOCALE = (GetLocale and GetLocale()) or "enUS"
TB.LOCALES = TB.LOCALES or {}

local strings = {}

TB.L = setmetatable({}, {
    __index = function(_, key)
        local text = strings[key]
        if text == nil or text == "" then return key end
        return text
    end,
    __newindex = function() end,
})

-- Each language file registers its table; only the client's language is kept.
function TB.RegisterLocale(locale, entries)
    TB.LOCALES[locale] = true
    if locale ~= TB.LOCALE or type(entries) ~= "table" then return end
    for key, text in pairs(entries) do
        strings[key] = text
    end
end

-- Dungeon-run plan titles (plan name -> shown title) for the client's
-- language. Without a table the run window builds English titles itself.
function TB.RegisterPlanTitles(locale, titles)
    if locale ~= TB.LOCALE or type(titles) ~= "table" then return end
    TB.PLAN_TITLES = titles
end

-- Server reply texts (ACTION_ERR codes and messages, which the server sends
-- in English) for the client's language, as { english, shown } pairs. Kept
-- apart from L: the keys are not literals in the code, so the locale checker
-- would report them as stale.
local serverTexts = {}
function TB.RegisterServerTexts(locale, texts)
    if locale ~= TB.LOCALE or type(texts) ~= "table" then return end
    for _, pair in ipairs(texts) do
        if type(pair) == "table" and pair[1] and pair[2] then serverTexts[pair[1]] = pair[2] end
    end
end

-- The translated server text, or the text itself (English stays as sent).
function TB.ServerText(text)
    if text == nil then return text end
    local shown = serverTexts[text]
    if shown == nil or shown == "" then return text end
    return shown
end

-- Cut a string to at most `limit` bytes without splitting a UTF-8 character.
function TB.Utf8Cut(text, limit)
    if string.len(text or "") <= limit then return text end
    local cut = limit
    while cut > 0 do
        local b = string.byte(text, cut + 1)
        if not b or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    return string.sub(text, 1, cut)
end

-- Untranslated key lookups for tests and tools: true when `key` has a text.
function TB.HasTranslation(key)
    return strings[key] ~= nil and strings[key] ~= ""
end
