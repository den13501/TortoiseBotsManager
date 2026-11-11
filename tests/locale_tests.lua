-- tests/locale_tests.lua
-- Loads the locale files under each shipped language and checks the lookup
-- rules: a translated key returns the translation, an unknown key returns
-- the English text, and every translation keeps the English placeholders.
-- Run: lua5.1 tests/locale_tests.lua .

local root = arg and arg[1] or "."

local function placeholders(text)
    local list = {}
    for p in string.gmatch(text, "%%[-+ #0]*%d*%.?%d*[sdifgxXc]") do
        table.insert(list, p)
    end
    return table.concat(list, " ")
end

local function load_locale(locale)
    TortoiseBots = nil
    GetLocale = function() return locale end
    dofile(root .. "/Locales/Locale.lua")
    local entries = {}
    local register = TortoiseBots.RegisterLocale
    TortoiseBots.RegisterLocale = function(name, t)
        if name == locale then entries = t end
        return register(name, t)
    end
    for _, file in ipairs({ "zhTW", "zhCN" }) do
        dofile(root .. "/Locales/" .. file .. ".lua")
    end
    return TortoiseBots, entries
end

-- English client: everything falls back to the key.
local TB = load_locale("enUS")
assert(TB.L["Attack"] == "Attack", "enUS must return the English key")
assert(TB.L["No such key"] == "No such key", "unknown key must return itself")
assert(TB.LOCALES.zhTW and TB.LOCALES.zhCN, "language files must register")

local checked = 0
for _, locale in ipairs({ "zhTW", "zhCN" }) do
    local TB, entries = load_locale(locale)
    assert(TB.LOCALE == locale)
    assert(TB.L["Attack"] ~= "Attack", locale .. ": Attack must be translated")
    assert(TB.L["No such key"] == "No such key", locale .. ": unknown key must fall back to English")
    for key, text in pairs(entries) do
        assert(type(text) == "string" and text ~= "", locale .. ": empty translation for " .. key)
        assert(placeholders(key) == placeholders(text),
            locale .. ": placeholders differ for '" .. key .. "' -> '" .. text .. "'")
        assert(TB.L[key] == text, locale .. ": lookup mismatch for " .. key)
        checked = checked + 1
    end
end

print(string.format("PASS: locale checks, %d translations verified", checked))
