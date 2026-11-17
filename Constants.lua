-- TortoiseBotsManager/Constants.lua
-- Single source of truth for dimensions, colors, timings, and UX strings.
-- Vanilla 1.12 safe.

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
local L = TB.L
TB.C = TB.C or {}

TB.C.VERSION = "2.3.2"

-- Author credit shown in the window header, the load message and /tbm help.
-- Forks and repacks must keep it (see README "Credit").
TB.C.AUTHOR = "Sagiroth"
TB.C.SOURCE_URL = "https://github.com/Sagiroth/TortoiseBotsManager"

-- Addon/module protocol levels, separate from release numbers. PROTOCOL is
-- the level this addon understands; MIN_MODULE_PROTOCOL is the oldest module
-- level it works with (modules without TBM:PROTO count as 0). Raise them only
-- when a change truly needs the other side updated.
TB.C.PROTOCOL = 1
TB.C.MIN_MODULE_PROTOCOL = 0

-- Panel geometry — compact Vanilla-safe control plane.
TB.C.PANEL_W = 500
TB.C.PANEL_H = 460
TB.C.ROW_H   = 28
TB.C.ROW_N   = 8
TB.C.PAD     = 10  -- outer margin
TB.C.GAP_S   = 8   -- section gap
TB.C.GAP_BTN = 4   -- button gap

-- Column widths for the snapshot roster. The last-location column is allowed
-- to collapse in UI.lua when a server row has no location metadata.
TB.C.ROSTER_NAME_W = 112
TB.C.ROSTER_CLASS_W = 70
TB.C.ROSTER_STATUS_W = 138

TB.C.CLASS_NAMES = {
    [1] = L["Warrior"],
    [2] = L["Paladin"],
    [3] = L["Hunter"],
    [4] = L["Rogue"],
    [5] = L["Priest"],
    [6] = L["Death Knight"],
    [7] = L["Shaman"],
    [8] = L["Mage"],
    [9] = L["Warlock"],
    [11] = L["Druid"],
}

TB.C.CLASS_COLORS = {
    [1]  = { 0.78, 0.61, 0.43, hex = "ffc79c6e" }, -- Warrior (Tan)
    [2]  = { 0.96, 0.55, 0.73, hex = "fff58cba" }, -- Paladin (Pink)
    [3]  = { 0.67, 0.83, 0.45, hex = "ffabd473" }, -- Hunter (Green)
    [4]  = { 1.00, 0.96, 0.41, hex = "fffff569" }, -- Rogue (Yellow)
    [5]  = { 1.00, 1.00, 1.00, hex = "ffffffff" }, -- Priest (White)
    [6]  = { 0.77, 0.12, 0.23, hex = "ffc41f3b" }, -- Death Knight (Red)
    [7]  = { 0.00, 0.44, 0.87, hex = "ff0070de" }, -- Shaman (Blue)
    [8]  = { 0.41, 0.80, 0.94, hex = "ff69ccf0" }, -- Mage (Light Blue)
    [9]  = { 0.58, 0.51, 0.79, hex = "ff9482c9" }, -- Warlock (Purple)
    [11] = { 1.00, 0.49, 0.04, hex = "ffff7d0a" }, -- Druid (Orange)
}

-- Class icons from the character-creation art (4x4 grid), by class id.
TB.C.CLASS_ICON_FILE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
TB.C.CLASS_ICON_TCOORDS = {
    [1]  = { 0, 0.25, 0, 0.25 },                -- Warrior
    [2]  = { 0, 0.25, 0.5, 0.75 },              -- Paladin
    [3]  = { 0, 0.25, 0.25, 0.5 },              -- Hunter
    [4]  = { 0.49609375, 0.7421875, 0, 0.25 },  -- Rogue
    [5]  = { 0.49609375, 0.7421875, 0.25, 0.5 },-- Priest
    [7]  = { 0.25, 0.49609375, 0.25, 0.5 },     -- Shaman
    [8]  = { 0.25, 0.49609375, 0, 0.25 },       -- Mage
    [9]  = { 0.7421875, 0.98828125, 0.25, 0.5 },-- Warlock
    [11] = { 0.7421875, 0.98828125, 0, 0.25 },  -- Druid
}

TB.C.CLASS_NAME_TO_ID = {
    Warrior = 1, WARRIOR = 1,
    Paladin = 2, PALADIN = 2,
    Hunter = 3, HUNTER = 3,
    Rogue = 4, ROGUE = 4,
    Priest = 5, PRIEST = 5,
    ["Death Knight"] = 6, DEATHKNIGHT = 6,
    Shaman = 7, SHAMAN = 7,
    Mage = 8, MAGE = 8,
    Warlock = 9, WARLOCK = 9,
    Druid = 11, DRUID = 11,
}

-- Single authoritative action definition table driving Actions tab and MiniBar.
TB.C.ACTION_DEFINITIONS = {
    -- Engage
    {
        id = "attack",
        intent = "attack",
        label = L["Attack"],
        section = "engage",
        needsEnemy = true,
        icon = "Interface\\Icons\\Ability_SteelMelee",
        tip = L["Send your bots to attack your target (or you, if none selected)."],
        mini = 1,
    },
    {
        id = "stop",
        intent = "stop",
        label = L["Stop"],
        section = "engage",
        icon = "Interface\\Icons\\Ability_Defend",
        tip = L["Stop attacking, clear targets and return to formation."],
        mini = 2,
    },
    {
        id = "interrupt",
        intent = "interrupt",
        label = L["Interrupt"],
        section = "engage",
        needsEnemy = true,
        icon = "Interface\\Icons\\Ability_Kick",
        tip = L["Order capable bots (Rogue Kick, Warrior Pummel, Mage Counterspell, etc.) to interrupt the target's current cast."],
        mini = 3,
    },
    {
        id = "flee",
        intent = "flee",
        label = L["Flee"],
        section = "engage",
        cap = "flee",
        icon = "Interface\\Icons\\Ability_Rogue_Sprint",
        tip = L["Disengage immediately and run behind you, dropping combat priorities until commanded again."],
        mini = 4,
    },

    -- Pull & Focus
    {
        id = "pull",
        intent = "pull",
        label = L["Pull"],
        section = "pull",
        needsEnemy = true,
        pull = true,
        icon = "Interface\\Icons\\Ability_TrueShot",
        tip = L["Tank body-pulls your target while other bots hold back."],
        mini = 5,
    },
    {
        id = "engage",
        intent = "engage",
        label = L["My pull"],
        section = "pull",
        cap = "engage",
        icon = "Interface\\Icons\\Ability_Warrior_Charge",
        tip = L["Bots hold fire until your pull reaches them (or a few seconds after you enter combat): you tank, they join."],
    },
    {
        id = "pullback",
        intent = "pullback",
        label = L["Pullback"],
        section = "pull",
        needsEnemy = true,
        pull = true,
        icon = "Interface\\Icons\\Ability_Hunter_AimedShot",
        tip = L["Tank pulls your target and runs back to you before the party engages."],
        mini = 6,
    },
    {
        id = "focusSkull",
        intent = "focus skull",
        label = L["Focus Skull"],
        section = "pull",
        raidIcon = 8,
        tip = L["All bots switch to and burn down the target marked with Skull."],
        mini = 7,
    },
    {
        id = "ccMoon",
        intent = "cc moon",
        label = L["CC Mark"],
        section = "pull",
        raidIcon = 5,
        custom = true,
        tip = L["Assign crowd-control raid marks (Moon, Circle, Square, etc.) to specific bots by name."],
    },
    {
        id = "endPull",
        intent = "end pull",
        label = L["End pull"],
        section = "pull",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        tip = L["Call off the current pull. The tank stops pulling and the party stands down."],
    },
    {
        id = "follow",
        intent = "follow",
        label = L["Follow"],
        section = "move",
        icon = "Interface\\Icons\\Ability_Tracking",
        tip = L["Bots follow you in formation."],
        mini = 8,
    },
    {
        id = "stay",
        intent = "stay",
        label = L["Stay"],
        section = "move",
        icon = "Interface\\Icons\\Spell_Nature_TimeStop",
        tip = L["Bots hold their current positions until ordered to move."],
        mini = 9,
    },
    {
        id = "come",
        intent = "come",
        label = L["Come"],
        section = "move",
        icon = "Interface\\Icons\\Spell_Arcane_PortalIronForge",
        tip = L["Bots rush to your position and hold there."],
        mini = 10,
    },
    {
        id = "guard",
        intent = "guard",
        label = L["Guard"],
        section = "move",
        icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        tip = L["Bots plant themselves where they stand and fight anything close."],
    },
    {
        id = "free",
        intent = "free",
        label = L["Free"],
        section = "move",
        icon = "Interface\\Icons\\Spell_Nature_Swiftness",
        tip = L["Bots leave their guard posts and move freely again."],
    },

    -- Combat stances (Fight MOVE card pills)
    {
        id = "stanceNear",
        intent = "stance near",
        label = L["Near"],
        section = "stance",
        tip = L["Default scrum: melee crowds close around the target."],
    },
    {
        id = "stanceTank",
        intent = "stance tank",
        label = L["Tank"],
        section = "stance",
        tip = L["Tank goes toe-to-toe, turning the target away from the party."],
    },
    {
        id = "stanceTurnback",
        intent = "stance turnback",
        label = L["Turnback"],
        section = "stance",
        tip = L["Melee holds the far side of the target, away from your casters."],
    },
    {
        id = "stanceBehind",
        intent = "stance behind",
        label = L["Behind"],
        section = "stance",
        tip = L["Melee works the target's rear, clear of frontal cleaves."],
    },

    -- Party Switches
    {
        id = "aoe",
        intent = "aoe",
        label = L["AoE"],
        section = "switch",
        toggle = "aoe",
        icon = "Interface\\Icons\\Spell_Fire_FlameBlades",
        tip = L["Area-of-effect spells for DPS bots. They still hold AoE next to a crowd-controlled mob."],
        mini = 11,
    },
    {
        id = "autocc",
        intent = "auto cc",
        label = L["Auto CC"],
        section = "switch",
        toggle = "autocc",
        icon = "Interface\\Icons\\Spell_Nature_Polymorph",
        tip = L["Bots sheep/sap a loose add that hits your healer, on their own. Your CC marks always win."],
    },
    {
        id = "sap",
        intent = "sap",
        label = L["Sap"],
        section = "switch",
        toggle = "sap",
        icon = "Interface\\Icons\\Ability_Sap",
        tip = L["Rogues open with Sap on the pull target while everyone else holds back. Needs a rogue in the party."],
    },
    {
        id = "spread",
        intent = "behavior spread",
        label = L["Spread"],
        section = "switch",
        toggle = "spread",
        send = "behavior",
        icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
        tip = L["Bots keep their distance from each other to dodge enemy area damage."],
    },
    {
        id = "loot",
        intent = "loot",
        label = L["Loot"],
        section = "switch",
        toggle = "loot",
        icon = "Interface\\Icons\\INV_Misc_Bag_10",
        tip = L["Bots loot corpses after a fight."],
    },

    -- Combat tactics (one-shot strategy orders)
    {
        id = "tacticKite",
        intent = "strategy ~kite",
        label = L["Kite"],
        section = "tactic",
        strategy = "~kite",
        icon = "Interface\\Icons\\Ability_Rogue_FleetFooted",
        tip = L["Bots keep their distance from enemies while fighting."],
    },
    {
        id = "tacticMark",
        intent = "strategy ~mark rti",
        label = L["Auto Mark"],
        section = "tactic",
        strategy = "~mark rti",
        icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
        tip = L["Bots mark the next target with Skull on their own when the fight starts."],
    },
    {
        id = "tacticFocus",
        intent = "strategy ~focus",
        label = L["Focus Fire"],
        section = "tactic",
        strategy = "~focus",
        icon = "Interface\\Icons\\Ability_Hunter_AimedShot",
        tip = L["Every DPS bot burns down one target instead of spreading damage."],
    },
    {
        id = "tacticAoeFear",
        intent = "strategy ~aoe fear",
        label = L["AoE Fear"],
        section = "tactic",
        strategy = "~aoe fear",
        icon = "Interface\\Icons\\Spell_Shadow_DeathScream",
        tip = L["Bots may use fear effects against groups. Held back inside instances."],
    },
    -- Rest, Repair & Train (Camp)
    {
        id = "rest",
        intent = "rest",
        label = L["Rest"],
        section = "rest",
        icon = "Interface\\Icons\\INV_Drink_07",
        tip = L["Order bots to eat and drink until full."],
    },
    {
        id = "ready",
        intent = "ready",
        label = L["Ready Check"],
        section = "rest",
        icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
        tip = L["Check if bots have sufficient health, mana, and no critical debuffs."],
    },
    {
        id = "repair",
        intent = "repair",
        label = L["Repair"],
        section = "rest",
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        tip = L["Bots repair their gear at a nearby vendor."],
    },
    {
        id = "sell",
        intent = "sell",
        label = L["Sell junk"],
        section = "rest",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        tip = L["Bots vendor grey quality items and junk in their bags."],
    },
    {
        id = "learn",
        intent = "learn",
        label = L["Train"],
        section = "rest",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        tip = L["Bots learn available class spells and skills from your targeted trainer."],
    },
    {
        id = "downtime",
        intent = "downtime",
        label = L["Downtime"],
        section = "rest",
        cap = "downtime",
        icon = "Interface\\Icons\\INV_Misc_Rune_01",
        tip = L["Send this alt to its class trainer, vendor and repair, then back to you."],
    },
    {
        id = "release",
        intent = "release",
        label = L["Release"],
        section = "rest",
        death = true,
        icon = "Interface\\Icons\\Spell_Holy_Resurrection",
        tip = L["Order dead bots to release spirit, or ghosts to run back to their corpses."],
    },
    {
        id = "rebuff",
        intent = "rebuff",
        label = L["Rebuff"],
        section = "rest",
        icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
        tip = L["Bots re-cast missing group buffs out of combat."],
    },
    {
        id = "resetTactics",
        intent = "strategy reset",
        label = L["Reset tactics"],
        section = "rest",
        strategy = true,
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        tip = L["Clear custom combat and non-combat strategy changes back to defaults."],
    },
    {
        id = "totem",
        intent = "totem party drop",
        label = L["Drop totems"],
        section = "rest",
        totem = true,
        icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
        tip = L["Shaman bots drop their configured totems now."],
    },
    {
        id = "grind",
        intent = "strategy +grind",
        label = L["Grind"],
        section = "quests",
        strategy = true,
        icon = "Interface\\Icons\\Ability_MeleeDamage",
        tip = L["Bots roam and grind mobs on their own. Click again to stop."],
    },
}

TB.C.ACTIONS_BY_ID = {}
TB.C.ACTIONS_BY_INTENT = {}
for _, def in ipairs(TB.C.ACTION_DEFINITIONS) do
    TB.C.ACTIONS_BY_ID[def.id] = def
    TB.C.ACTIONS_BY_INTENT[def.intent] = def
end

function TB.GetActionDefinition(idOrIntent)
    return (TB.C and TB.C.ACTIONS_BY_ID and TB.C.ACTIONS_BY_ID[idOrIntent])
        or (TB.C and TB.C.ACTIONS_BY_INTENT and TB.C.ACTIONS_BY_INTENT[idOrIntent])
end


-- Derived tables for backwards compatibility with tests and external callers.
-- All data is driven directly by TB.C.ACTION_DEFINITIONS above.
TB.C.ACTION_ICONS = {}
for _, def in ipairs(TB.C.ACTION_DEFINITIONS) do
    if def.icon then
        TB.C.ACTION_ICONS[def.intent] = def.icon
    elseif def.raidIcon then
        TB.C.ACTION_ICONS[def.intent] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. def.raidIcon
    end
end
TB.C.ACTION_ICONS.hold = "Interface\\Icons\\Spell_Nature_Slow"

TB.C.ACTION_LABELS = {
    ["corpse run"]         = L["Corpse run"],
    ["focus"]              = L["Focus mark"],
    ["focus status"]       = L["Focus mark"],
    ["raid status"]        = L["Raid status"],
    ["raid tankface"]      = L["Tank face"],
    ["raid douse"]         = L["Douse runes"],
    ["raid custom status"] = L["Custom tactics"],
    ["raid custom on"]     = L["Custom tactics on"],
    ["raid custom off"]    = L["Custom tactics off"],
    ["item equip"]         = L["Equip"],
    ["item unequip"]       = L["Unequip"],
    ["item give"]          = L["Give"],
    ["item trade"]         = L["Trade"],
    ["service portal"]     = L["Portal"],
    ["blessing"]           = L["Blessing"],
    ["blessing status"]    = L["Blessings"],
    ["cast Disenchant"]    = L["Disenchant"],
    ["sendmail"]           = L["Send by mail"],
    ["bank"]               = L["Put to bank"],
    ["destroy"]            = L["Destroy"],
    inv                    = L["Bags"],
    lootlog                = L["Loot history"],
    order                  = L["Order"],
    stance                 = L["Stance"],
    hold                   = L["Come"],
    ["strategy +grind"]    = L["Grind"],
    ["strategy -grind"]    = L["Grind"],
    ["strategy reset"]     = L["Reset tactics"],
    ["commander bind"]     = L["Bind party"],
    ["commander unbind"]   = L["Unbind party"],
    ["commander status"]   = L["Party status"],
    ["cmd enter"]          = L["Enter dungeon"],
    ["run list"]           = L["Dungeon plans"],
    ["run start"]          = L["Run start"],
    ["run pause"]          = L["Run pause"],
    ["run resume"]         = L["Run resume"],
    ["run skip"]           = L["Run skip"],
    ["run stop"]           = L["Run stop"],
    ["run status"]         = L["Run status"],
}
for _, def in ipairs(TB.C.ACTION_DEFINITIONS) do
    TB.C.ACTION_LABELS[def.intent] = def.label
end

TB.C.PARTY_TOGGLES = {}
for _, def in ipairs(TB.C.ACTION_DEFINITIONS) do
    if def.toggle then
        table.insert(TB.C.PARTY_TOGGLES, {
            key    = def.toggle,
            intent = def.intent,
            label  = def.label,
            tip    = def.tip,
            send   = def.send,
        })
    end
end

-- Per-bot behaviour toggles in the bot panel (`.bot behavior <bot> <key>`).
-- `mana` limits a toggle to classes that use mana, `class` to one class id.
-- `optional` hides it until the server reports the key (older servers do not).
-- `spec` shows it only while the bot fights in that kind of spec ("heal" or
-- "dps", read from the BOTSTATE specs; see TB.BotSpecKind).
TB.C.BEHAVIORS = {
    { key = "loot",     label = L["Loot corpses"], tip = L["Loot corpses after a fight."] },
    { key = "aoe",      label = L["AoE spells"],   tip = L["Use area-of-effect abilities (held back next to crowd-controlled mobs)."] },
    { key = "autocc",   label = L["Auto CC"],      tip = L["Crowd-control a loose add that hits your healer, on its own. Your CC marks always win."] },
    { key = "savemana", label = L["Save mana"],    tip = L["Wait longer between repeated casts to stretch mana on long fights."], mana = true },
    { key = "boost",    label = L["Cooldowns"],    tip = L["Use big offensive cooldowns during fights."] },
    { key = "threat",   label = L["Watch threat"], tip = L["Ease off damage when close to pulling aggro from the tank."] },
    { key = "potions",  label = L["Potions"],    tip = L["Drink healing and mana potions when low."] },
    { key = "mimic",    label = L["Mimic"],      tip = L["Copy your consumable use (food, drink, potions) on this bot."] },
    { key = "spread",   label = L["Spread out"], tip = L["Keep distance from nearby party members instead of stacking."] },
    { key = "hold",     label = L["Hold position"], tip = L["Keep following and fighting, but never run from enemies on its own: no fleeing, kiting or stepping back for casting room. Still steps out of ground effects."], optional = true },
    { key = "offheal",  label = L["Off-heal"], tip = L["Damage spec: stop attacking and heal an ally who drops low. A spec change sets the spec's default again."], optional = true, spec = "dps" },
    { key = "offdps",   label = L["Off-DPS"],  tip = L["Healer: attack while nobody needs healing; healing always wins. A spec change sets the spec's default again."], optional = true, spec = "heal" },
    { key = "noblink",  label = L["No dungeon Blink"], tip = L["Never cast Blink inside dungeons and raids, where it can land in the next pack. Blink still works outdoors."], optional = true, class = 8 },
}
TB.C.NO_MANA_CLASSES = { [1] = true, [4] = true } -- Warrior, Rogue

-- Shaman totems (`.bot totem <bot> <slot> <totem>`): the slots, each slot's
-- totems in the server's order, and the drop modes.
TB.C.TOTEM_SLOTS = { "earth", "fire", "water", "air" }
TB.C.TOTEM_SLOT_LABELS = { earth = L["Earth"], fire = L["Fire"], water = L["Water"], air = L["Air"] }
TB.C.TOTEMS = {
    earth = { "stoneclaw totem", "stoneskin totem", "earthbind totem", "strength of earth totem", "tremor totem" },
    fire  = { "searing totem", "magma totem", "fire nova totem", "flametongue totem", "fire resistance totem",
              "frost resistance totem" },
    water = { "healing stream totem", "mana spring totem", "mana tide totem", "poison cleansing totem",
              "disease cleansing totem", "fire resistance totem" },
    air   = { "windfury totem", "grace of air totem", "tranquil air totem", "grounding totem", "windwall totem",
              "nature resistance totem" },
}
TB.C.TOTEM_MODES = { "auto", "prepull", "manual" }
TB.C.TOTEM_MODE_LABELS = { auto = L["Auto"], prepull = L["Before the pull"], manual = L["Only on order"] }
-- Presets a fresh install starts with; the player can overwrite or delete them.
TB.C.TOTEM_PRESETS_DEFAULT = {
    { name = "Melee group", earth = "strength of earth totem", fire = "searing totem",
      water = "mana spring totem", air = "windfury totem" },
    { name = "Caster group", earth = "stoneskin totem", fire = "searing totem",
      water = "mana spring totem", air = "grace of air totem" },
}

-- Paladin blessings (`.bot blessing <bot> <class> <blessing|auto>`): the
-- blessings, their icons, and the class words in grid order.
TB.C.BLESSINGS = { "might", "wisdom", "kings", "salvation", "sanctuary", "light" }
TB.C.BLESSING_LABELS = { might = L["Might"], wisdom = L["Wisdom"], kings = L["Kings"], salvation = L["Salvation"],
    sanctuary = L["Sanctuary"], light = L["Light"] }
TB.C.BLESSING_ICONS = {
    might = "Interface\\Icons\\Spell_Holy_FistOfJustice",
    wisdom = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    kings = "Interface\\Icons\\Spell_Magic_MageArmor",
    salvation = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    sanctuary = "Interface\\Icons\\Spell_Nature_LightningShield",
    light = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
}
TB.C.BLESSING_CLASSES = {
    { word = "warrior", id = 1 }, { word = "paladin", id = 2 }, { word = "hunter", id = 3 },
    { word = "rogue", id = 4 }, { word = "priest", id = 5 }, { word = "shaman", id = 7 },
    { word = "mage", id = 8 }, { word = "warlock", id = 9 }, { word = "druid", id = 11 },
}

-- Movement labels for the TBM:BOTSTATE "move" field.
TB.C.MOVEMENT_LABELS = {
    follow = L["Following"],
    stay = L["Staying"],
    guard = L["Guarding"],
    free = L["Free"],
    flee = L["Fleeing (passive)"],
}

-- Paper-doll layout for the bot panel. Numbers are server equipment slots
-- (EQUIPMENT_SLOT_*); `empty` is the client's empty-slot texture name.
TB.C.GEAR_LEFT = {
    { slot = 0,  label = L["Head"],      empty = "Head" },
    { slot = 1,  label = L["Neck"],      empty = "Neck" },
    { slot = 2,  label = L["Shoulder"],  empty = "Shoulder" },
    { slot = 14, label = L["Back"],      empty = "Chest" },
    { slot = 4,  label = L["Chest"],     empty = "Chest" },
    { slot = 3,  label = L["Shirt"],     empty = "Shirt" },
    { slot = 18, label = L["Tabard"],    empty = "Tabard" },
    { slot = 8,  label = L["Wrist"],     empty = "Wrists" },
}
TB.C.GEAR_RIGHT = {
    { slot = 9,  label = L["Hands"],     empty = "Hands" },
    { slot = 5,  label = L["Waist"],     empty = "Waist" },
    { slot = 6,  label = L["Legs"],      empty = "Legs" },
    { slot = 7,  label = L["Feet"],      empty = "Feet" },
    { slot = 10, label = L["Ring"],      empty = "Finger" },
    { slot = 11, label = L["Ring"],      empty = "Finger" },
    { slot = 12, label = L["Trinket"],   empty = "Trinket" },
    { slot = 13, label = L["Trinket"],   empty = "Trinket" },
}
TB.C.GEAR_BOTTOM = {
    { slot = 15, label = L["Main hand"], empty = "MainHand" },
    { slot = 16, label = L["Off hand"],  empty = "SecondaryHand" },
    { slot = 17, label = L["Ranged"],    empty = "Ranged" },
}

-- Raid icons use the client's 1-based texture numbering. The server stores
-- the matching lowercase name as each bot's CC preference.
TB.C.CC_MARKS = {
    { id = "moon",    label = L["Moon"],    icon = 5 },
    { id = "circle",  label = L["Circle"],  icon = 2 },
    { id = "square",  label = L["Square"],  icon = 6 },
    { id = "cross",   label = L["Cross"],   icon = 7 },
    { id = "triangle",label = L["Triangle"],icon = 4 },
    { id = "diamond", label = L["Diamond"], icon = 3 },
    { id = "star",    label = L["Star"],    icon = 1 },
    { id = "skull",   label = L["Skull"],   icon = 8 },
}
TB.C.CC_MARK_LABELS = {}
TB.C.CC_MARK_ICONS = {}
for _, mark in ipairs(TB.C.CC_MARKS or {}) do
    TB.C.CC_MARK_LABELS[mark.id] = mark.label
    TB.C.CC_MARK_ICONS[mark.id] = mark.icon
end

TB.C.FORMATIONS = {
    { id = "shield", label = L["Shield"], tip = L["Dungeon standard: tank in front, melee on the flanks, healers behind."] },
    { id = "near",   label = L["Near"],   tip = L["Tight stack close to you, for narrow corridors and sneaking past patrols."] },
    { id = "queue",  label = L["Queue"],  tip = L["Single file behind you, for bridges and ledges."] },
    { id = "arrow",  label = L["Arrow"],  tip = L["V-shaped wedge pointing forward, for open ground."] },
    { id = "circle", label = L["Circle"], tip = L["Ring around you, facing out."] },
    { id = "line",    label = L["Line"],    tip = L["Side by side in one line with you in the middle, for open ground."] },
    { id = "far",     label = L["Far"],     tip = L["Loose spread at maximum leash range, for open-world pulling."] },
    { id = "melee",   label = L["Melee"],   tip = L["Melee stack on the tank's target, ranged hang back."] },
    { id = "chaos",   label = L["Chaos"],   tip = L["Scattered skirmish spread with no fixed shape."] },
    { id = "default", label = L["Default"], tip = L["Server default spacing, before any formation order."] },
}

-- Addon command transport (server side: host/BotAddonAdapter.cpp).
-- The prefix carries both directions; the channel is what SendAddonMessage
-- takes while the server advertises TBM:TRANSPORT|party.
TB.C.ADDON_PREFIX    = "TBM"
TB.C.ADDON_TRANSPORT = "PARTY"

-- Throttle / poll
TB.C.SEND_DELAY      = 0.35  -- min seconds between requests ("addon" or ".bot …")
TB.C.LIST_THROTTLE   = 5     -- hard throttle for .bot roster
TB.C.ROSTER_THROTTLE = TB.C.LIST_THROTTLE
TB.C.POLL_PANEL_IV   = 8     -- poll every N sec while panel open
TB.C.POLL_HIDDEN_IV  = 20    -- while hidden, if autoPoll
TB.C.POLL_AFTER_CMD  = 1.4   -- poll soon after any lifecycle command
TB.C.POLL_AFTER_ADD  = 2.0
TB.C.ADD_TIMEOUT     = 30    -- seconds without login confirmation
TB.C.REMOVE_TIMEOUT  = 15    -- seconds without removal confirmation
TB.C.ACTION_TIMEOUT  = 8     -- seconds for a named action acknowledgement
TB.C.ACTION_FLASH    = 1.2   -- seconds a green/red answer flash stays on a button

-- Adjustable pull timers: DPS delay before pull, join delay before
-- pullback. Persisted per character in SavedVariables, 0-60 s step 1.
TB.C.PULL_DELAY_DEFAULT = 10
TB.C.PULLBACK_DELAY_DEFAULT = 3
TB.C.PULL_DELAY_MIN = 0
TB.C.PULL_DELAY_MAX = 60
TB.C.INVITE_ACCEPT_TIMEOUT = 20 -- seconds for a sent native invite to become group membership
TB.C.SUMMON_SETTLE   = 15    -- accepted summon stays visibly pending while teleport completes
TB.C.POLL_WAIT       = 1.2   -- seconds before reconciling a list snapshot
TB.C.POLL_NO_REPLY_LIMIT = 2 -- consecutive silent polls before Unknown

-- Minimap
TB.C.MINIMAP_RADIUS = 80
TB.C.MINIMAP_DEFAULT = { x = 52, y = 52 }

-- Colors (r,g,b) — Tortoise palette
TB.C.COLOR = {
    gold   = { 0.95, 0.72, 0.28 },
    text   = { 0.92, 0.90, 0.84 },
    muted  = { 0.62, 0.60, 0.56 },
    green  = { 0.30, 0.90, 0.45 },
    red    = { 1.00, 0.34, 0.28 },
    yellow = { 1.00, 0.82, 0.10 },
    blue   = { 0.42, 0.76, 1.00 },
    bg     = { 0.025, 0.032, 0.045 },
    accent = { 0.78, 0.53, 0.14 },
    accentHi = { 0.95, 0.72, 0.28 },
    faint  = { 0.42, 0.41, 0.39 },
    title  = { 0.86, 0.69, 0.36 },  -- section titles: a quieter gold
}

-- Shipped glyph textures (white, tinted with SetVertexColor); see tools/make_media.py.
TB.C.MEDIA = "Interface\\AddOns\\TortoiseBotsManager\\Media\\"

-- Surfaces of the flat theme: one 1px frame on a solid fill, a lighter step
-- per depth (window, header band, card, row). { r, g, b, a }.
TB.C.THEME = {
    window     = { 0.051, 0.055, 0.063, 0.97 },
    windowEdge = { 0.22, 0.20, 0.17, 1 },
    header     = { 0.082, 0.086, 0.098, 1 },
    card       = { 0.078, 0.082, 0.094, 0.94 },
    cardEdge   = { 0.155, 0.155, 0.165, 1 },
    row        = { 0.082, 0.086, 0.098, 0.96 },
    rowEdge    = { 0.13, 0.13, 0.14, 1 },
    rowSel     = { 0.20, 0.155, 0.07, 0.96 },
    rowSelEdge = { 0.70, 0.53, 0.20, 1 },
    hairline   = { 1, 1, 1, 0.07 },
    input      = { 0.035, 0.038, 0.045, 1 },
    inputEdge  = { 0.22, 0.22, 0.24, 1 },
}

-- Status
TB.C.STATUS = {
    OFFLINE        = "offline",
    OFFLINE_PENDING= "offline-pending",
    UNKNOWN        = "unknown",
    FAILED         = "failed",
    QUEUED         = "queued",
    STARTING       = "starting",
    ONLINE         = "online",
    COMMANDING     = "commanding",
    SUMMONING      = "summoning",
    INVITING       = "inviting",
    KICKING        = "kicking",
    REMOVING       = "removing",
}

-- Full server-supported formation IDs (the pill row exposes the structured
-- subset above). Kept under a separate key so it never clobbers
-- TB.C.FORMATIONS metadata ({ id, label, tip }).
TB.C.FORMATION_IDS = {
    "default", "melee", "queue", "chaos", "circle",
    "line", "shield", "arrow", "near", "far",
}
