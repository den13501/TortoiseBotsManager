-- TortoiseBotsManager/BotRun.lua
-- Dungeon run window (Preview): drives the server's opt-in run leader
-- (docs/play/commands/commander.md "Run Leader (.bot run)").
--
-- The server appends "dungeon-run" to "TBM:CAPS|..." only while
-- AiPlayerbot.DungeonSelfClear and AiPlayerbot.RemoteCommander are both on.
-- No capability: no button, no window, no sends. Every CAPS line replaces
-- the set, so the gate is re-checked on each one (a restart that drops the
-- feature hides everything again).
--
-- Sends (byte-exact, one per click; Commander.cpp):
--   "commander bind <LeadBot> [<Bot> ...] inparty" (bot-led: up to five
--     bots, you stay in the party)
--   "commander unbind" / "commander status"
--   "cmd enter near" (nearest entrance trigger within ReactDistance)
--   "run list" -> "Dungeon plans: <name> (map <m>, <s> steps[, <u> not
--     supported yet])[, ...]" + TBM:ACTION_ACK|run list|plans|<n>|-
--   "run start [plan] [from leg|step N] [player [tank <Bot>]]" (player:
--     you lead, the start binds your party itself) / pause / resume / skip /
--     "stop [reason]" / status
-- Inbound:
--   TBM:RUN|<plan>|<state>|<step>/<steps>|<leg>|<kind>|<phase>|<note>
--     [|left <K>][|speed <x> (test)]
--   The first 8 fields always exist; later fields are optional extras.
--   "no run" is TBM:RUN|-|none|0/0|-|-|-|no run.
--   TBM:ACTION_ACK/ERR for the commander / cmd / run intents (generic
--   routing in Comms.lua; labels live in C.ACTION_LABELS).
--
-- Bot-led: any player order to the party (.bot action, .bot cmd, whispers)
-- pauses a running run until resume: the window says so, and
-- SendActionIntent warns on the status line when a run is running.
-- Player-led: your orders are obeyed and never pause the run.

local TB = TortoiseBots
local L = TB.L
local C = TB.C or {}
local COL = C.COLOR or {}
local RW = 300
local PROW = 5

local CAP = "dungeon-run"

local function norm(name) return name and TB.NormalizeName(name) or nil end
local function color(name) return COL[name] or { 1, 1, 1 } end

-- ── capability gate ─────────────────────────────────────────────────────
function TB.HasRunCapability()
    return TB.HasServerCapability and TB.HasServerCapability(CAP) or false
end

-- ── model ─────────────────────────────────────────────────────────────────
-- run = { plan, state, step, steps, leg, kind, phase, note, left, speed }
local run = nil

function TB.GetRun()
    return run
end

-- The window's answer line: what was sent, then the server's ACK or ERR.
-- Lives above the parsers: the layout router reports through it.
local feedback = nil

local function setFeedback(text, kind)
    feedback = { text = text, kind = kind }
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
end

function TB.GetRunFeedback()
    return feedback
end

-- layout = { bots, tanks, tankHealers, raidHealers, groups } from
-- TBM:RAID_LAYOUT (what the raid bind applied; tanks list the main first),
-- or { warning } from the TBM:RAID_LAYOUT|warning line.
local layout = nil

function TB.GetRaidLayout()
    return layout
end
-- plans = { { name, map, steps, unsupported } }, from the "run list" reply.
local plans = {}
local plansAt = 0
local plansPending = false

function TB.GetRunPlans()
    return plans
end

function TB.IsRunListPending()
    return plansPending
end

-- Parses one loaded plan: "uldaman (map 70, 41 steps, 2 not supported yet)".
-- Returns name, map, steps, unsupported. The "not supported" tail appears
-- only when some step is unsupported (Commander.cpp:6938-6940).
local function parsePlanEntry(text)
    if not text or text == "" then return nil end
    local _, _, name, map, steps, unsupported = string.find(text,
        "^%s*(.-)%s*%(%s*map%s+(%d+)%s*,%s*(%d+)%s+steps%s*(.-)%)%s*$")
    if not name or name == "" then return nil end
    local unsup = 0
    if unsupported and unsupported ~= "" then
        local _, _, n = string.find(unsupported, "(%d+)%s+not supported yet")
        unsup = tonumber(n) or 0
    end
    return name, tonumber(map), tonumber(steps), unsup
end
TB.ParseRunPlanEntry = parsePlanEntry

-- Parses the "run list" reply: "Dungeon plans: <entry>[, <entry> ...]" or
-- "Dungeon plans: none loaded". Commas split entries, but they also sit
-- inside the "(map …, … steps…)"tails, so split on "), " boundaries.
local function parsePlanList(msg)
    if not msg then return nil end
    local _, _, body = string.find(msg, "^Dungeon plans:%s*(.-)%s*$")
    if not body then return nil end
    if body == "none loaded" then return {} end
    local list = {}
    local rest = body
    while rest and rest ~= "" do
        local cut = string.find(rest, "%)%s*,%s*", 1)
        local entry
        if cut then
            entry = string.sub(rest, 1, cut)
            rest = string.sub(rest, cut + 1)
            rest = string.gsub(rest, "^%s*,%s*", "")
        else
            entry = rest
            rest = ""
        end
        local name, map, steps, unsupported = parsePlanEntry(entry)
        if name then
            table.insert(list, { name = name, map = map, steps = steps,
                unsupported = unsupported or 0 })
        end
    end
    return list
end
TB.ParseRunPlanList = parsePlanList

-- Parses TBM:RAID_LAYOUT|<bots>|<tanks>|<tankHealers>|<raidHealers>|<groups>
-- (the layout the raid bind applied; tanks list the main tank first) and the
-- warning form TBM:RAID_LAYOUT|warning|<text> (a member not where planned).
local function parseRaidLayout(msg)
    if not msg then return nil end
    if string.sub(msg, 1, 16) ~= "TBM:RAID_LAYOUT|" then return nil end
    local rest = string.sub(msg, 17)
    -- The warning rides its own short line (a layout line always carries
    -- all five fields).
    local _, _, warn = string.find(rest, "^warning|(.-)%s*$")
    if warn then return { warning = warn ~= "" and warn or "raid layout changed" } end
    local fields = {}
    while table.getn(fields) < 4 do
        local at = string.find(rest, "|", 1, true)
        if not at then return nil end
        table.insert(fields, string.sub(rest, 1, at - 1))
        rest = string.sub(rest, at + 1)
    end
    table.insert(fields, rest)
    if fields[1] == "" or fields[2] == "" then return nil end
    -- The layout line's tank list: lead (main) tank first, off-tanks after.
    local tankNames = {}
    for name in string.gfind(fields[2] .. ",", "([^,]+),") do
        name = TB.Trim(name)
        if name ~= "" then table.insert(tankNames, name) end
    end
    return {
        bots = tonumber(fields[1]) or 0,
        mainTank = tankNames[1],
        tankCount = table.getn(tankNames),
        tanks = fields[2],
        tankHealers = fields[3] ~= "" and fields[3] or "-",
        raidHealers = fields[4] ~= "" and fields[4] or "-",
        groups = fields[5] ~= "" and fields[5] or "-",
    }
end
TB.ParseRaidLayout = parseRaidLayout

-- "Alpha + 2 off": the main tank named, the rest counted, so the line never
-- wraps onto the plan header whatever the raid's size.
local function shortTanks(lay)
    if not lay or not lay.mainTank then return "-" end
    local extra = (lay.tankCount or 1) - 1
    if extra > 0 then return lay.mainTank .. " + " .. extra .. " off" end
    return lay.mainTank
end

-- TBM:RUN|<plan>|<state>|<step>/<steps>|<leg>|<kind>|<phase>|<note>
-- [|left <K>][|speed <x> (test)]
-- The note never holds a "|" (the server turns them into spaces), so split
-- the first 8 fields and treat the rest as optional extras.
local function parseRunLine(msg)
    if not msg then return nil end
    local prefix = "TBM:RUN|"
    if string.sub(msg, 1, string.len(prefix)) ~= prefix then return nil end
    -- Plan, state, step/steps, leg, kind: the first five separators. The
    -- tail (phase, note, extras) holds no "|" of its own — the server
    -- turns them into spaces — so it splits at its first two separators.
    local fields = {}
    local rest = string.sub(msg, string.len(prefix) + 1)
    while table.getn(fields) < 5 do
        local at = string.find(rest, "|", 1, true)
        if not at then return nil end
        table.insert(fields, string.sub(rest, 1, at - 1))
        rest = string.sub(rest, at + 1)
    end
    local at = string.find(rest, "|", 1, true)
    if not at then return nil end
    table.insert(fields, string.sub(rest, 1, at - 1)) -- phase
    rest = string.sub(rest, at + 1)
    local note, extras
    at = string.find(rest, "|", 1, true)
    if at then
        note = string.sub(rest, 1, at - 1)
        extras = string.sub(rest, at + 1)
    else
        note = rest
    end
    local plan, state, frac, leg, kind, phase = fields[1], fields[2],
        fields[3], fields[4], fields[5], fields[6]
    if plan == "" or state == "" or frac == "" or leg == "" or kind == ""
        or phase == "" then
        return nil
    end
    local _, _, step, steps = string.find(frac, "^(%d+)/(%d+)$")
    if not step then return nil end
    if note == "" then note = "-" end
    local out = {
        plan = plan,
        state = state,
        step = tonumber(step),
        steps = tonumber(steps),
        leg = leg,
        kind = kind,
        phase = phase,
        note = note,
        left = nil,
        speed = nil,
        untilStop = nil,
    }
    -- Optional extras: "|left <K>" (packs deferred), "|speed <x> (test)",
    -- "|until <clause> (step N)" (a start's stop before that step).
    if extras and extras ~= "" then
        -- The speed and until labels share one field joined with "; " on a
        -- test-speed run ("speed 3.0 (test); until boss (step 38)"), so split
        -- each extra on ";" before matching.
        for extra in string.gfind(extras, "[^|]+") do
            for chunk in string.gfind(extra .. ";", "([^;]*);") do
                local _, _, left = string.find(chunk, "^%s*left%s+(%d+)%s*$")
                if left then out.left = tonumber(left) end
                local _, _, speed = string.find(chunk, "^%s*speed%s+(.-)%s*$")
                if speed and speed ~= "" then out.speed = speed end
                local _, _, stop = string.find(chunk, "^%s*(until%s+.+%s+%(step%s+%d+%))%s*$")
                if stop and stop ~= "" then out.untilStop = stop end
            end
        end
    end
    return out
end
TB.ParseRunLine = parseRunLine

-- Inbound router hook (called from Comms OnSystemMessage): the TBM:RUN
-- status line and the "run list" plan reply.
function TB.ParseRunMessage(msg)
    if not msg or msg == "" then return false end
    local _, _, here = string.find(msg, "^TBM:RUN_HERE|([^|]+)|")
    if here then
        if TB.NoteRunHere then TB.NoteRunHere(here ~= "-" and here or nil) end
        return true, "here", here
    end
    if string.sub(msg, 1, 8) == "TBM:RUN|" then
        local parsed = parseRunLine(msg)
        if not parsed then return false end
        run = parsed
        if TB.RefreshRunWindow then TB.RefreshRunWindow() end
        -- The bots wait at a locked door for the player: say what opens it on the status line.
        local _, _, ask = string.find(parsed.note, "the way is locked.-open it with ([^;]+)")
        if parsed.state == "paused" and ask and TB.SetStatus then
            TB.SetStatus(string.format(L["Paused at a locked door: open it with %s, then Resume."], ask), "warn")
        end
        return true, "run", parsed
    end
    if string.sub(msg, 1, 16) == "TBM:RAID_LAYOUT|" then
        local parsed = parseRaidLayout(msg)
        if not parsed then return false end
        if parsed.warning then
            layout = layout or {}
            layout.warning = parsed.warning
            if TB.SetStatus then TB.SetStatus(L["Raid layout:"] .. " " .. parsed.warning, "warn") end
            setFeedback("|cffffb040Layout:|r " .. parsed.warning, "warn")
        else
            -- A clean layout clears the old warning: it described the
            -- previous bind's placement, not this one.
            layout = parsed
            if TB.SetStatus then
                TB.SetStatus(string.format(L["Raid layout: %s bots, main tank %s."], tostring(parsed.bots), parsed.tanks), "ok")
            end
        end
        if TB.RefreshRunWindow then TB.RefreshRunWindow() end
        return true, "layout", layout
    end
    local list = parsePlanList(msg)
    if list then
        plans = list
        plansAt = (GetTime and GetTime()) or 0
        plansPending = false
        if TB.RefreshRunWindow then TB.RefreshRunWindow() end
        if TB.SetStatus then
            if table.getn(list) == 0 then
                TB.SetStatus(L["No dungeon plans loaded."], "warn")
            else
                TB.SetStatus(L["Dungeon plans"] .. " · " .. table.getn(list), "ok")
            end
        end
        return true, "plans", list
    end
    return false
end

-- ── feedback ──────────────────────────────────────────────────────────────
-- The state lives above the parsers; labels for the run intents follow.

local FEEDBACK_LABEL = {
    ["commander bind"] = L["Bind"], ["commander unbind"] = L["Unbind"], ["commander status"] = L["Party status"],
    ["cmd enter"] = L["Enter"], ["run list"] = L["Plans"], ["run start"] = L["Start"], ["run pause"] = L["Pause"],
    ["run resume"] = L["Resume"], ["run skip"] = L["Skip"], ["run stop"] = L["Stop"], ["run status"] = L["Status"],
}

local function feedbackLabel(intent)
    for prefix, label in pairs(FEEDBACK_LABEL) do
        if string.sub(intent or "", 1, string.len(prefix)) == prefix then return label end
    end
    return nil
end

local function sent(cmd, ok)
    local label = feedbackLabel(cmd)
    if ok and label then setFeedback(string.format(L["%s sent, waiting for the server..."], label), "pending") end
    return ok
end

function TB.OnRunError(packet)
    local label = packet and feedbackLabel(packet.intent)
    if not label then return false end
    -- The window's own status ask with no run is no refusal: just no run.
    if packet.intent == "run status" and packet.code == "not-bound" then
        run = { plan = "-", state = "none", step = 0, steps = 0, leg = "-",
            kind = "-", phase = "-", note = "no run" }
        if TB.RefreshRunWindow then TB.RefreshRunWindow() end
        return false
    end
    local message = TB.ServerText(packet.message ~= "" and packet.message or packet.code)
    if string.len(message) > 80 then message = TB.Utf8Cut(message, 77) .. "..." end
    setFeedback("|cffff5050" .. string.format(L["%s refused:"], label) .. "|r " .. message, "err")
    return false
end

-- ACK/ERR routing for the run intents (called from ParseActionMessage):
-- "run status" with no run answers "no run" plus this ACK, so clear the
-- model; every other ACK/ERR keeps the generic status text.
function TB.OnRunAck(packet)
    if not packet then return false end
    local intent = packet.intent or ""
    local label = feedbackLabel(intent)
    if label then
        local text = "|cff40ff40" .. string.format(L["%s done."], label) .. "|r"
        if intent == "run list" then text = "|cff40ff40" .. string.format(L["%s plans loaded."], tostring(packet.count)) .. "|r"
        -- A raid bind ACKs scope "raid" (a party bind "party"): both name the lead bot.
        elseif intent == "commander bind" and packet.scope == "raid" and packet.executor ~= "-" then
            text = "|cff40ff40" .. string.format(L["%s done:"], L["Bind"]) .. "|r " .. packet.executor .. " (" .. L["raid"] .. ")"
            elseif packet.executor ~= "-" then text = "|cff40ff40" .. string.format(L["%s done:"], label) .. "|r " .. packet.executor end
        setFeedback(text, "ok")
    end
    if intent == "run status" and packet.executor == "-"
        and (packet.count or 0) == 0 then
        run = { plan = "-", state = "none", step = 0, steps = 0, leg = "-",
            kind = "-", phase = "-", note = "no run" }
        if TB.RefreshRunWindow then TB.RefreshRunWindow() end
    end
    return false
end

-- ── sends ─────────────────────────────────────────────────────────────────
-- All gated on the capability: without it nothing goes out.
local function sendRun(cmd)
    if not TB.HasRunCapability() then return false end
    cmd = TB.Trim(cmd or "")
    if cmd == "" then return false end
    return sent(cmd, TB.SendBotCommand(cmd))
end

-- Binds the targeted bot plus up to four grouped owned bots as its party.
-- "inparty": you stay in the party (it needs you to lead it) and the lead
-- bot takes the lead from you while the binding stands.
function TB.SendRunBind()
    local lead
    if TB.GetTargetScope then
        local _, bot = TB.GetTargetScope()
        lead = bot
    end
    if not lead then
        if TB.SetStatus then
            TB.SetStatus(L["Target a bot first: it leads the bound party."], "warn")
        end
        setFeedback("|cffff5050" .. L["Bind:"] .. "|r " .. L["target your tank bot first; it leads the party."], "err")
        return false
    end
    -- Every bot of the party must be named: the roster's own bots and the
    -- party members the server reports as controllable bots (hires too).
    local names = { lead }
    local seen = { [string.lower(lead)] = true }
    local function add(name)
        if name and name ~= "" and not seen[string.lower(name)] and table.getn(names) < 5 then
            seen[string.lower(name)] = true
            table.insert(names, name)
        end
    end
    for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
        local name = UnitName and UnitName("party" .. i)
        if name and TB.GetBotState and TB.GetBotState(name) then add(name) end
    end
    for _, name in ipairs(TB.GetGroupedBotNames and TB.GetGroupedBotNames() or {}) do add(name) end
    -- A party bind leaves the raid behind: drop its layout with it.
    layout = nil
    return sendRun("commander bind " .. table.concat(names, " ") .. " inparty")
end
-- Binds the targeted bot as the main tank of your raid (it must be a tank in
-- your raid group): the word "raid" takes the whole raid, you leave it.
function TB.SendRunBindRaid()
    local lead
    if TB.GetTargetScope then
        local _, bot = TB.GetTargetScope()
        lead = bot
    end
    if not lead then
        if TB.SetStatus then
            TB.SetStatus(L["Target a bot first: it leads the bound raid."], "warn")
        end
        setFeedback("|cffff5050" .. L["Bind:"] .. "|r " .. L["target your main tank first; it leads the raid."], "err")
        return false
    end
    setFeedback(nil)
    layout = nil
    return sendRun("commander bind " .. lead .. " raid")
end

function TB.SendRunUnbind()
    layout = nil
    return sendRun("commander unbind")
end

function TB.SendRunCommanderStatus()
    return sendRun("commander status")
end

-- The party walks through the nearest dungeon entrance (the server picks
-- the trigger within ReactDistance).
function TB.SendRunEnter()
    return sendRun("cmd enter near")
end

function TB.SendRunList()
    if not TB.HasRunCapability() then return false end
    plansPending = true
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
    return sent("run list", TB.SendBotCommand("run list"))
end

function TB.SendRunStart(plan, fromKind, fromValue)
    if not TB.HasRunCapability() then return false end
    plan = TB.Trim(plan or "")
    local cmd = "run start"
    if plan ~= "" and plan ~= "-" then cmd = cmd .. " " .. plan end
    fromKind = TB.Trim(fromKind or "")
    fromValue = TB.Trim(fromValue or "")
    if (fromKind == "leg" or fromKind == "step") and fromValue ~= "" then
        cmd = cmd .. " from " .. fromKind .. " " .. fromValue
    end
    -- "Stop before the boss": a trash walk ends at the boss stand instead.
    -- The server refuses it for player-led runs, so only bot-led runs add it.
    if TB.GetRunStopBeforeBoss and TB.GetRunStopBeforeBoss() and TB.GetRunMode() ~= "player" then
        cmd = cmd .. " until boss"
    end
    if TB.GetRunMode() == "player" then
        cmd = cmd .. " player"
        -- A targeted bot is the run's puller; else the server takes the
        -- party's first tank bot (a player tank needs one named).
        if TB.GetTargetScope then
            local _, bot = TB.GetTargetScope()
            if bot then cmd = cmd .. " tank " .. bot end
        end
    end
    return sent(cmd, TB.SendBotCommand(cmd))
end

function TB.SendRunPause()
    return sendRun("run pause")
end

function TB.SendRunResume()
    return sendRun("run resume")
end

function TB.SendRunSkip()
    return sendRun("run skip")
end

function TB.SendRunStop(reason)
    if not TB.HasRunCapability() then return false end
    reason = TB.Trim(reason or "")
    -- The server keeps 80 printable characters (RunStopNote).
    reason = string.gsub(reason, "[%c|]", "")
    if string.len(reason) > 80 then reason = string.sub(reason, 1, 80) end
    reason = TB.Trim(reason)
    if reason == "" then return sent("run stop", TB.SendBotCommand("run stop")) end
    return sent("run stop", TB.SendBotCommand("run stop " .. reason))
end

function TB.SendRunStatus()
    return sendRun("run status")
end

-- The combat/move warn: any player order pauses a running run, so a click
-- on a gameplay action while a run is running says so on the status line.
-- Returns true when a running run was warned about.
function TB.WarnRunPause()
    if run and run.state == "running" and TB.GetRunMode() ~= "player" then
        if TB.SetStatus then
            TB.SetStatus(L["That order pauses the dungeon run (Resume to go on)."], "warn")
        end
        return true
    end
    return false
end

-- ── window ────────────────────────────────────────────────────────────────
local win
local selectedPlan = nil
local planPage = 1
local planSearch = ""
local planZone = nil
-- In a dungeon with one plan per wing the zone name cannot tell the wing;
-- the server answers "run here" with the plan nearest the player.
local herePlan = nil
local hereAsked = false

function TB.NoteRunHere(plan)
    herePlan = plan
    if plan then selectedPlan = plan end
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
end
-- The search list is open (Change) or closed (the zone's plan only).
local planPicker = false
local stopReason = ""
-- "Stop before the boss": run start carries "until boss" (bot-led only).
local stopBeforeBoss = false

function TB.GetRunStopBeforeBoss()
    return stopBeforeBoss
end

function TB.SetRunStopBeforeBoss(on)
    stopBeforeBoss = on and true or false
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
end
local runMode = "bot"

function TB.GetRunMode()
    return runMode
end

function TB.SetRunMode(mode)
    runMode = (mode == "player") and "player" or "bot"
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
end

function TB.GetRunWindowOpen()
    return win and win:IsVisible() or false
end

function TB.GetRunSelectedPlan()
    return selectedPlan
end

function TB.SetRunSelectedPlan(name)
    selectedPlan = (name and name ~= "") and name or nil
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
end

function TB.SetRunStopReason(text)
    stopReason = text or ""
end

local function setTooltip(button, title, lines)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        for _, line in ipairs(lines) do GameTooltip:AddLine(line, 0.9, 0.9, 0.9, 1) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function smallButton(parent, label, width, x, y, tipTitle, tip, onClick)
    local b = TB.StyleButton(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"))
    b:SetWidth(width); b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    setTooltip(b, tipTitle, { tip })
    return b
end

local function lampColor(state)
    if state == "running" then return 0.30, 0.90, 0.45 end
    if state == "paused" then return 1.00, 0.82, 0.10 end
    if state == "done" then return 0.62, 0.60, 0.56 end
    return 0.45, 0.45, 0.45
end

local function createWindow()
    win = CreateFrame("Frame", "TortoiseBotsManagerRunWindow", TB.frame or UIParent)
    win:SetWidth(RW); win:SetHeight(500)
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function() win:StartMoving() end)
    win:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        -- 1.12-safe: StopMovingOrSizing detaches the anchor from the
        -- logical parent (see UI.lua drag header), so re-anchor with
        -- GetLeft/GetTop instead of ever calling GetPoint() after a drag.
        local left, top = win:GetLeft(), win:GetTop()
        if left and top then
            win:ClearAllPoints()
            win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "TortoiseBotsManagerRunWindow") end
    TB.ApplySurface(win, "window")
    TB.AddWindowHeader(win, 30)

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -9)
    TB.StyleTitle(title, 14)
    title:SetWidth(RW - 50); title:SetJustifyH("LEFT")
    title:SetText(L["Dungeon run"] .. "  |cff9d9d9d" .. L["Preview"] .. "|r")
    TB.SetTextColor(title, color("title"))

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    TB.StyleCloseButton(close, -7, -6)
    close:SetScript("OnClick", function() TB.CloseRunWindow() end)

    local head = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    head:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -36)
    head:SetWidth(RW - 24); head:SetJustifyH("LEFT")
    head:SetText(L["Your bots clear a dungeon plan by themselves."])
    TB.SetTextColor(head, color("muted"))

    -- Mode: who leads the run (tooltips say which role each one suits).
    local mode = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mode:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -56)
    mode:SetText(L["MODE"])
    TB.SetTextColor(mode, color("title"))
    win.modeBot = TB.StyleButton(CreateFrame("Button", nil, win, "UIPanelButtonTemplate"))
    -- A segmented switch: the two halves touch, the picked one is filled.
    win.modeBot:SetWidth(139); win.modeBot:SetHeight(24)
    win.modeBot:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -73)
    win.modeBot:SetScript("OnClick", function() TB.SetRunMode("bot") end)
    setTooltip(win.modeBot, L["Bots lead"], {
        L["Suggested when you play healer or DPS."],
        L["A bot tank leads the way and pulls; you stay in the party and follow."],
        L["Bind first (target the tank bot), then Start."],
        L["Your own orders to the bots pause the run until Resume."],
    })
    win.modeYou = TB.StyleButton(CreateFrame("Button", nil, win, "UIPanelButtonTemplate"))
    win.modeYou:SetWidth(139); win.modeYou:SetHeight(24)
    win.modeYou:SetPoint("TOPLEFT", win, "TOPLEFT", 149, -73)
    win.modeYou:SetScript("OnClick", function() TB.SetRunMode("player") end)
    setTooltip(win.modeYou, L["I lead"], {
        L["Suggested when you play the tank."],
        L["You walk where you like; the bots pull the plan's packs near you,"],
        L["mark, crowd-control, rest and revive. Your orders never pause it."],
        L["No Bind needed: Start binds your party. Target a bot to make it"],
        L["the puller (needed when no bot in your party is a tank)."],
    })
    win.modeHint = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.modeHint:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -100)
    win.modeHint:SetWidth(RW - 24); win.modeHint:SetJustifyH("LEFT")
    TB.SetTextColor(win.modeHint, color("muted"))

    -- Party: bind a lead bot + its group (or the whole raid), enter, status.
    local party = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    party:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -122)
    party:SetText(L["PARTY"])
    TB.SetTextColor(party, color("title"))
    win.bind = smallButton(win, L["Bind"], 88, 12, -140,
        L["Bind"], L["Bind your target as the lead bot, with its group beside it."],
        function() TB.SendRunBind() end)
    -- Raid: the same target as main tank takes the whole raid (you leave it).
    win.bindRaid = smallButton(win, L["Bind raid"], 88, 104, -140,
        L["Bind raid"], L["Bind your target as the main tank of your raid. The line below names the main tank (the full tank and healer lists stay in the chat)."],
        function() TB.SendRunBindRaid() end)
    win.unbind = smallButton(win, L["Unbind"], 88, 196, -140,
        L["Unbind"], L["Release the bound party or raid (this ends a run)."],
        function() TB.SendRunUnbind() end)
    win.enter = smallButton(win, L["Enter"], 88, 12, -166,
        L["Enter"], L["Walk through the nearest dungeon or raid entrance."],
        function() TB.SendRunEnter() end)
    win.cmdStatus = smallButton(win, L["Status"], 88, 104, -166,
        L["Party status"], L["Ask who the bound group is."],
        function() TB.SendRunCommanderStatus() end)
    win.bindHint = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.bindHint:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -192)
    win.bindHint:SetWidth(RW - 24); win.bindHint:SetJustifyH("LEFT")
    win.bindHint:SetText(L["Target the main tank, then Bind raid. Party Bind takes its group."])
    TB.SetTextColor(win.bindHint, color("muted"))
    -- The raid bind's layout: main tank first, then its support lines.
    win.layout = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.layout:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -204)
    win.layout:SetWidth(RW - 24); win.layout:SetJustifyH("LEFT")
    win.layout:SetText("")
    TB.SetTextColor(win.layout, color("muted"))
    -- Plan: the dungeon the player stands in picks its plan (or lists its
    -- wings); Change opens a search over every plan. Start takes the pick.
    local plan = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plan:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -210)
    plan:SetText(L["PLAN"])
    TB.SetTextColor(plan, color("title"))
    win.planPick = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.planPick:SetPoint("TOPLEFT", win, "TOPLEFT", 52, -209)
    win.planPick:SetWidth(156); win.planPick:SetJustifyH("LEFT")
    win.planToggle = smallButton(win, L["Change"], 76, 212, -204,
        L["Change plan"], L["Search every plan and pick another one."],
        function() TB.SetRunPlanPicker(not planPicker) end)
    win.planHint = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.planHint:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -230)
    win.planHint:SetWidth(RW - 24); win.planHint:SetJustifyH("LEFT")
    TB.SetTextColor(win.planHint, color("muted"))
    win.planSearch = CreateFrame("EditBox", "TortoiseBotsManagerRunPlanSearch", win, "InputBoxTemplate")
    TB.StyleEditBox(win.planSearch, L["Search plans"])
    win.planSearch:SetWidth(RW - 34); win.planSearch:SetHeight(20)
    win.planSearch:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -246)
    win.planSearch:SetAutoFocus(false)
    win.planSearch:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    win.planSearch:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    win.planSearch:SetScript("OnTextChanged", function()
        planSearch = this:GetText() or ""
        planPage = 1
        TB.RefreshRunWindow()
    end)
    setTooltip(win.planSearch, L["Search plans"], { L["Type part of a dungeon name, e.g. scarlet or kraul."] })
    win.planRows = {}
    for i = 1, PROW do
        local row = TB.StyleButton(CreateFrame("Button", nil, win, "UIPanelButtonTemplate"))
        row:SetWidth(RW - 24); row:SetHeight(20)
        row:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -272 - (i - 1) * 22)
        row:SetScript("OnClick", function()
            if this.planName then
                planPicker = false
                TB.SetRunSelectedPlan(this.planName)
            end
        end)
        table.insert(win.planRows, row)
    end
    win.planEmpty = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.planEmpty:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -296)
    win.planEmpty:SetWidth(RW - 24); win.planEmpty:SetJustifyH("CENTER")
    TB.SetTextColor(win.planEmpty, color("muted"))
    win.plans = smallButton(win, L["Reload"], 88, 12, -274 - PROW * 22,
        L["Reload plans"], L["Load the dungeon plans from the server again."],
        function() TB.SendRunList() end)
    win.planPrev = TB.StyleButton(CreateFrame("Button", nil, win, "UIPanelButtonTemplate"))
    win.planPrev:SetWidth(26); win.planPrev:SetHeight(22)
    win.planPrev:SetPoint("TOPLEFT", win, "TOPLEFT", 104, -274 - PROW * 22)
    win.planPrev:SetText("<")
    win.planPrev:SetScript("OnClick", function() planPage = planPage - 1; TB.RefreshRunWindow() end)
    win.planNext = TB.StyleButton(CreateFrame("Button", nil, win, "UIPanelButtonTemplate"))
    win.planNext:SetWidth(26); win.planNext:SetHeight(22)
    win.planNext:SetPoint("TOPLEFT", win, "TOPLEFT", 212, -274 - PROW * 22)
    win.planNext:SetText(">")
    win.planNext:SetScript("OnClick", function() planPage = planPage + 1; TB.RefreshRunWindow() end)
    win.planPageText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.planPageText:SetPoint("TOPLEFT", win, "TOPLEFT", 132, -278 - PROW * 22)
    win.planPageText:SetWidth(78); win.planPageText:SetJustifyH("CENTER")
    TB.SetTextColor(win.planPageText, color("muted"))
    win:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    win:SetScript("OnEvent", function()
        herePlan = nil
        hereAsked = false
        TB.RefreshRunWindow()
    end)

    -- Controls: Start / Pause-Resume / Skip / Stop + reason.
    -- Everything below the plan hangs off win.lower, which the plan section
    -- moves down when it opens its list (layoutPlanSection).
    win.lower = CreateFrame("Frame", nil, win)
    win.lower:SetWidth(RW); win.lower:SetHeight(1)
    local lower = win.lower
    win.lower:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -240)
    local ctlY = 0
    local ctl = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ctl:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, ctlY)
    ctl:SetText(L["CONTROLS"])
    TB.SetTextColor(ctl, color("title"))
    win.start = smallButton(lower, L["Start"], 88, 12, ctlY - 18,
        L["Start"], L["Start the picked plan (or the plan of the lead bot's map)."],
        function() TB.SendRunStart(selectedPlan) end)
    win.pause = smallButton(lower, L["Pause"], 88, 104, ctlY - 18,
        L["Pause"], L["Pause the run; the bots hold what they do."],
        function() TB.SendRunPause() end)
    win.resume = smallButton(lower, L["Resume"], 88, 104, ctlY - 18,
        L["Resume"], L["Go on with the paused run (regroups first)."],
        function() TB.SendRunResume() end)
    win.skip = smallButton(lower, L["Skip"], 88, 196, ctlY - 18,
        L["Skip"], L["Leave out the current step and go on."],
        function() TB.SendRunSkip() end)
    win.stop = smallButton(lower, L["Stop"], 88, 12, ctlY - 44,
        L["Stop"], L["End the run; the bots stay where they are, still bound."],
        function() TB.SendRunStop(stopReason) end)
    -- Stop-before-boss: the next Start carries "until boss" (bot-led only).
    win.untilBoss = CreateFrame("CheckButton", "TortoiseBotsManagerRunUntilBoss", lower, "UICheckButtonTemplate")
    TB.StyleCheckButton(win.untilBoss)
    win.untilBoss:SetWidth(20); win.untilBoss:SetHeight(20)
    win.untilBoss:SetPoint("TOPLEFT", lower, "TOPLEFT", 108, ctlY - 44)
    win.untilBoss:SetScript("OnClick", function()
        TB.SetRunStopBeforeBoss(this:GetChecked() and true or false)
    end)
    setTooltip(win.untilBoss, L["Stop before the boss"], {
        L["The next Start ends the run before the first boss step,"],
        L["so a trash walk stops at the boss stand."],
        L["Bots lead only: a player-led Start never carries it."],
    })
    win.untilLabel = lower:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.untilLabel:SetPoint("LEFT", win.untilBoss, "RIGHT", 2, 0)
    win.untilLabel:SetWidth(70); win.untilLabel:SetJustifyH("LEFT")
    win.untilLabel:SetText(L["No boss"])
    TB.SetTextColor(win.untilLabel, color("muted"))
    win.stopBox = CreateFrame("EditBox", "TortoiseBotsManagerRunStopBox", win, "InputBoxTemplate")
    TB.StyleEditBox(win.stopBox)
    win.stopBox:SetWidth(RW - 24); win.stopBox:SetHeight(20)
    win.stopBox:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, ctlY - 70)
    win.stopBox:SetAutoFocus(false)
    win.stopBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    win.stopBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    win.stopBox:SetScript("OnTextChanged", function()
        stopReason = this:GetText() or ""
    end)
    setTooltip(win.stopBox, L["Stop reason"], { L["Optional: why the run ends (shown in the note)."] })
    -- What the last click did: sent, then the server's answer.
    win.feedback = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.feedback:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, ctlY - 94)
    win.feedback:SetText("")

    -- Status: plan, state lamp, step x/y progress, leg, phase, note.
    local stY = ctlY - 126
    local st = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    st:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY)
    st:SetText(L["STATUS"])
    TB.SetTextColor(st, color("title"))
    win.runLamp = win:CreateTexture(nil, "OVERLAY")
    win.runLamp:SetWidth(8); win.runLamp:SetHeight(8)
    win.runLamp:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 22)
    win.runState = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.runState:SetPoint("LEFT", win.runLamp, "RIGHT", 4, 0)
    win.runState:SetWidth(112); win.runState:SetJustifyH("LEFT")
    win.runStep = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.runStep:SetPoint("TOPLEFT", lower, "TOPLEFT", 140, stY - 21)
    win.runStep:SetWidth(RW - 152); win.runStep:SetJustifyH("RIGHT")
    win.runBar = CreateFrame("Frame", nil, win)
    win.runBar:SetWidth(RW - 24); win.runBar:SetHeight(10)
    win.runBar:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 38)
    -- A 10px bar is thinner than the 11px tooltip border edgeSize, so a
    -- plain dark backing replaces the tooltip backdrop here.
    local barBg = win.runBar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(win.runBar)
    win.runFill = win.runBar:CreateTexture(nil, "ARTWORK")
    win.runFill:SetHeight(6)
    win.runLeg = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.runLeg:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 52)
    win.runLeg:SetWidth(RW - 24); win.runLeg:SetJustifyH("LEFT")
    win.runPhase = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.runPhase:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 66)
    win.runPhase:SetWidth(RW - 24); win.runPhase:SetJustifyH("LEFT")
    win.runNote = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.runNote:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 80)
    win.runNote:SetWidth(RW - 24); win.runNote:SetJustifyH("LEFT")
    TB.SetTextColor(win.runNote, color("muted"))
    -- The stop-before-boss label gets its own line: it never wraps the
    -- phase line onto the note.
    win.runStop = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.runStop:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 94)
    win.runStop:SetWidth(RW - 24); win.runStop:SetJustifyH("LEFT")
    win.runStop:SetText("")
    win.warn = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.warn:SetPoint("TOPLEFT", lower, "TOPLEFT", 12, stY - 122)
    win.warn:SetWidth(RW - 24); win.warn:SetJustifyH("LEFT")
    win.warn:SetText(L["Your orders pause the run until Resume."])
    TB.SetTextColor(win.warn, color("muted"))

    win:Hide()
    TB.runWindow = win
end

-- Plan names are lower_snake ("scarlet_library"); the client's zone text is
-- "Scarlet Monastery". Both compare as lower-case letters and digits with a
-- leading "the" dropped; a zone whose name differs from its plans' names
-- maps to their common prefix here.
local ZONE_PLAN_PREFIX = {
    stockade = "stormwindstockade",
    templeofatalhakkar = "sunkentemple",
    blackrockspire = "lowerblackrockspire",
    scarletmonastery = "scarlet",
}
local PLAN_TITLE = { zulfarrak = "Zul'Farrak" }

local function planKey(text)
    local key = string.lower(text or "")
    key = string.gsub(key, "^the[%s_]+", "")
    return (string.gsub(key, "[^%l%d]", ""))
end

function TB.RunPlanTitle(name)
    local shown = TB.PLAN_TITLES and name and TB.PLAN_TITLES[name]
    if shown then return shown end
    if PLAN_TITLE[name] then return PLAN_TITLE[name] end
    local title = string.gsub(name or "", "_", " ")
    return (string.gsub(title, "(%a)(%w*)", function(a, b) return string.upper(a) .. b end))
end

-- The run status line: the raw plan name (as before), or its title in
-- the client language when the locale file names the plan.
function TB.RunPlanShort(name)
    if not name or name == "-" then return "-" end
    return (TB.PLAN_TITLES and TB.PLAN_TITLES[name]) or name
end

-- Run state words; an unknown state shows capitalised, as sent.
local RUN_STATE_LABEL = { running = L["Running"], paused = L["Paused"], done = L["Done"] }
function TB.RunStateLabel(state)
    return RUN_STATE_LABEL[state or ""] or (string.gsub(state or "", "^%l", string.upper))
end

-- The plans of the zone the player stands in (a dungeon with one plan per
-- wing gives several), in the server's order.
function TB.GetZoneRunPlans()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local key = planKey(zone)
    if key == "" then return {}, zone end
    local prefix = ZONE_PLAN_PREFIX[key] or key
    local out = {}
    for _, plan in ipairs(plans) do
        if string.sub(planKey(plan.name), 1, string.len(prefix)) == prefix then table.insert(out, plan) end
    end
    return out, zone
end

-- The raid plans the server ships (the ten migrations plus UBRS and Onyxia,
-- whose rows the world data references): same "run list" reply, shown after
-- the dungeon plans so a player finds them. Anything else over 200 steps
-- groups with them: a raid-length plan by size alone.
local RAID_PLAN_NAMES = {
    molten_core = true, blackwing_lair = true, ruins_of_ahnqiraj = true,
    temple_of_ahnqiraj = true, naxxramas = true, zul_gurub = true,
    emerald_sanctum = true, timbermaw_hold = true, lower_karazhan_halls = true,
    upper_karazhan_halls = true, upper_blackrock_spire = true,
    onyxias_lair = true,
}

-- 200 steps: below every shipped plan, so only unlisted future raid-length
-- plans group by size (known dungeons stay dungeon plans whatever the size).
local RAID_PLAN_STEPS = 200

function TB.IsRaidRunPlan(name, steps)
    if RAID_PLAN_NAMES[name] then return true end
    return (tonumber(steps) or 0) > RAID_PLAN_STEPS
end
-- What the list shows: the search's matches, else the zone's plans first,
-- raid plans after dungeon plans.
local function visiblePlans()
    local here, zone = TB.GetZoneRunPlans()
    local query = planKey(planSearch)
    local raw = TB.Trim(planSearch or "")
    local out = {}
    if query ~= "" or (raw ~= "" and TB.PLAN_TITLES) then
        for _, plan in ipairs(plans) do
            -- English letters match the plan name; other text (a translated
            -- title typed in the client language) matches the shown title.
            if (query ~= "" and string.find(planKey(plan.name), query, 1, true))
                or (TB.PLAN_TITLES and string.find(TB.RunPlanTitle(plan.name), raw, 1, true)) then
                table.insert(out, plan)
            end
        end
        return out, here, zone
    end
    local seen = {}
    for _, plan in ipairs(here) do table.insert(out, plan); seen[plan.name] = true end
    local raids = {}
    for _, plan in ipairs(plans) do
        if not seen[plan.name] then
            if TB.IsRaidRunPlan(plan.name, plan.steps) then table.insert(raids, plan)
            else table.insert(out, plan) end
            seen[plan.name] = true
        end
    end
    for _, plan in ipairs(raids) do table.insert(out, plan) end
    return out, here, zone
end
-- Height of everything hung off win.lower (controls, answer, status).
local LOWER_H = 274

local function placeRows(top, count)
    for i, row in ipairs(win.planRows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", win, "TOPLEFT", 12, top - (i - 1) * 22)
        if i > count then
            row.planName = nil
            row:Hide()
        end
    end
end

local function fillRow(row, plan)
    row.planName = plan.name
    -- One line per row: name + steps (+ unsupported tail). The map
    -- lives in the tooltip: even the longest plan name must fit.
    local text = TB.RunPlanTitle(plan.name) .. " · " .. string.format(L["%s steps"], tostring(plan.steps or 0))
    if (plan.unsupported or 0) > 0 then
        text = text .. " · " .. string.format(L["%s unsupported"], plan.unsupported)
    end
    if plan.name == selectedPlan then text = "|cffffd200" .. text .. "|r" end
    row:SetText(text)
    setTooltip(row, TB.RunPlanTitle(plan.name), {
        string.format(L["%s · map %s · %s steps."], plan.name, tostring(plan.map or "?"), tostring(plan.steps or 0)),
        L["Click: pick this plan for Start."],
    })
    row:Show()
    row:Enable()
end

local function findPlan(name)
    for _, plan in ipairs(plans) do
        if plan.name == name then return plan end
    end
    return nil
end

local function renderPlans()
    local shown, here, zone = visiblePlans()
    -- On entering a zone with plans: its one plan is picked, or a pick from
    -- elsewhere is dropped so Start never runs another dungeon's plan.
    if zone ~= planZone then
        herePlan = nil
        hereAsked = false
    end
    -- Inside an instance (or with several plans for the zone: wings) the
    -- server says which plan the player stands in; the zone name may not
    -- match a plan name, and one zone can hold several wings.
    local inInstance = IsInInstance and IsInInstance()
    if (inInstance or table.getn(here) > 1) and table.getn(plans) > 0 and not herePlan and not hereAsked
        and TB.HasRunCapability() then
        hereAsked = true
        TB.SendBotCommand("run here")
    end
    if herePlan then
        local one = findPlan(herePlan)
        if one then here = { one } end
    end
    if zone ~= planZone and table.getn(here) > 0 then
        local keep = false
        for _, plan in ipairs(here) do
            if plan.name == selectedPlan then keep = true end
        end
        if not keep then selectedPlan = table.getn(here) == 1 and here[1].name or nil end
    end
    if table.getn(plans) > 0 then planZone = zone end

    local nHere = table.getn(here)
    local picked = selectedPlan and findPlan(selectedPlan)
    win.planPick:SetText(picked and TB.RunPlanTitle(picked.name) or "|cffff5050" .. L["none"] .. "|r")
    win.planToggle:SetText(planPicker and L["Done"] or L["Change"])
    local listTop, bottom
    if planPicker then
        win.planSearch:Show()
        listTop = -272
        local count = table.getn(shown)
        local pages = math.max(1, math.ceil(count / PROW))
        if planPage > pages then planPage = pages end
        if planPage < 1 then planPage = 1 end
        placeRows(listTop, PROW)
        for i, row in ipairs(win.planRows) do
            local plan = shown[(planPage - 1) * PROW + i]
            if plan then fillRow(row, plan) else row.planName = nil; row:SetText(""); row:Hide() end
        end
        win.planPageText:SetText(planPage .. " / " .. pages)
        win.planPageText:Show(); win.planPrev:Show(); win.planNext:Show(); win.plans:Show()
        if planPage > 1 then win.planPrev:Enable() else win.planPrev:Disable() end
        if planPage < pages then win.planNext:Enable() else win.planNext:Disable() end
        if plansPending then
            win.plans:SetText(L["Asking…"])
            win.plans:Disable()
        else
            win.plans:SetText(L["Reload"])
            win.plans:Enable()
        end
        if table.getn(plans) == 0 then
            win.planEmpty:SetText(L["No plans yet: Reload asks the server."])
            win.planEmpty:Show()
        elseif count == 0 then
            win.planEmpty:SetText(L["No plan matches the search."])
            win.planEmpty:Show()
        else
            win.planEmpty:Hide()
        end
        if planKey(planSearch) ~= "" or (TB.PLAN_TITLES and TB.Trim(planSearch or "") ~= "") then
            win.planHint:SetText(string.format(L["%s of %s plans match."], tostring(count), tostring(table.getn(plans))))
        else
            win.planHint:SetText(L["Type part of a name, then click a plan."])
        end
        bottom = listTop - PROW * 22 - 26
    else
        win.planSearch:Hide()
        win.planPageText:Hide(); win.planPrev:Hide(); win.planNext:Hide(); win.plans:Hide()
        win.planEmpty:Hide()
        listTop = -246
        -- A dungeon with wings lists just its plans to pick from.
        local wings = nHere > 1 and nHere or 0
        if wings > PROW then wings = PROW end
        placeRows(listTop, wings)
        for i = 1, wings do fillRow(win.planRows[i], here[i]) end
        if table.getn(plans) == 0 then
            win.planHint:SetText(plansPending and L["Loading the plans..."] or L["No plans loaded: Change, then Reload."])
        elseif nHere == 1 and herePlan then
            win.planHint:SetText("|cff40ff40" .. L["Detected from where you stand."] .. "|r " .. L["Wrong? Change."])
        elseif nHere == 1 then
            win.planHint:SetText("|cff40ff40" .. string.format(L["In %s."], zone) .. "|r " .. L["Wrong plan? Change."])
        elseif nHere > 1 then
            win.planHint:SetText("|cff40ff40" .. string.format(L["In %s:"], zone) .. "|r " .. (hereAsked and L["pick a wing (asking the server...)"] or L["pick a wing."]))
        elseif picked then
            win.planHint:SetText(L["Picked from the list. Change to pick another."])
        else
            win.planHint:SetText(L["No dungeon here: Start uses the lead bot's dungeon."])
        end
        bottom = wings > 0 and (listTop - wings * 22 - 4) or -242
    end
    win.lower:ClearAllPoints()
    win.lower:SetPoint("TOPLEFT", win, "TOPLEFT", 0, bottom - 10)
    -- At least as tall as the main window, so it reads as its extension.
    local mainH = TB.frame and TB.frame.GetHeight and TB.frame:GetHeight() or 0
    win:SetHeight(math.max(-(bottom - 10) + LOWER_H, mainH or 0))
end

function TB.SetRunPlanPicker(open)
    planPicker = open and true or false
    if TB.RefreshRunWindow then TB.RefreshRunWindow() end
end

-- ── Dungeon tab (main window): what the modes are, the run at a glance and
-- the way into the run window, which is too tall for the tab itself.
local tab

function TB.CreateRunTab(parent)
    tab = CreateFrame("Frame", nil, parent)
    tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local tw = (C.PANEL_W or 500) - (C.PAD or 10) * 2
    tab:SetWidth(tw); tab:SetHeight(325)
    local w = tw - 12
    local function line(font, y, text, col)
        local fs = tab:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, y)
        fs:SetWidth(w); fs:SetJustifyH("LEFT")
        fs:SetText(text or "")
        if col then TB.SetTextColor(fs, color(col)) end
        return fs
    end
    line("GameFontNormal", -6, L["Dungeon run"], "gold")
    line("GameFontHighlightSmall", -26, L["Your bots clear a whole dungeon by its plan: pulls, crowd control, boss tactics, rests and revives."], "muted")
    line("GameFontNormalSmall", -62, L["BOTS LEAD"], "gold")
    line("GameFontHighlightSmall", -78, L["A bot tank leads and pulls; you stay in the party. Best when you heal or deal damage."])
    line("GameFontNormalSmall", -106, L["I LEAD"], "gold")
    line("GameFontHighlightSmall", -122, L["You walk where you like; the bots pull the packs near you. Best when you tank."])
    line("GameFontNormalSmall", -158, L["RUN"], "gold")
    tab.state = line("GameFontHighlightSmall", -174, L["No run."])
    tab.note = line("GameFontHighlightSmall", -190, "", "muted")
    tab.open = TB.StyleButton(CreateFrame("Button", nil, tab, "UIPanelButtonTemplate"))
    tab.open:SetWidth(160); tab.open:SetHeight(22)
    tab.open:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -222)
    tab.open:SetText(L["Open run window"])
    tab.open:SetScript("OnClick", function() TB.OpenRunWindow() end)
    tab:Hide()
    return tab
end

function TB.RefreshRunTab()
    if not tab then return end
    local st = run
    if not st or st.state == "none" then
        tab.state:SetText(L["No run."])
        tab.note:SetText(L["Pick a mode and a plan in the run window, then Start."])
        return
    end
    tab.state:SetText(TB.RunPlanTitle(st.plan) .. " · " .. TB.RunStateLabel(st.state)
        .. " · " .. string.format(L["step %s of %s"], tostring(st.step or 0), tostring(st.steps or 0)))
    tab.note:SetText(st.note or "")
end

function TB.RefreshRunWindow()
    TB.RefreshRunTab()
    if not win or not win:IsVisible() then return end
    renderPlans()
    local st = run or { state = "none", plan = "-", step = 0, steps = 0,
        leg = "-", kind = "-", phase = "-", note = "no run" }
    local r, g, b = lampColor(st.state)
    win.runLamp:SetTexture(r, g, b, 1)
    local stateWord = st.state == "none" and L["No run"]
        or TB.RunStateLabel(st.state or "none")
    win.runState:SetText(TB.RunPlanShort(st.plan) .. " · " .. stateWord)
    if (st.steps or 0) > 0 then
        win.runStep:SetText(string.format(L["Step %s of %s"], tostring(st.step or 0), tostring(st.steps)))
        local frac = (st.step or 0) / st.steps
        if frac < 0 then frac = 0 end
        if frac > 1 then frac = 1 end
        win.runFill:SetWidth(math.floor((RW - 28) * frac + 0.5))
        win.runFill:SetPoint("LEFT", win.runBar, "LEFT", 2, 0)
        win.runFill:SetTexture(r, g, b, 1)
        win.runFill:Show()
    else
        win.runStep:SetText("-")
        win.runFill:Hide()
    end
    win.runLeg:SetText(string.format(L["Leg: %s   Step: %s"], st.leg or "-", st.kind or "-"))
    local phase = string.format(L["Phase: %s"], st.phase or "-")
    if st.left then phase = phase .. "   " .. string.format(L["Left: %s"], tostring(st.left)) end
    if st.speed then phase = phase .. "   " .. string.format(L["Speed: %s"], tostring(st.speed)) end
    win.runPhase:SetText(phase)
    win.runStop:SetText(st.untilStop and string.format(L["Stop: %s"], st.untilStop) or "")
    win.runNote:SetText(L[st.note or "-"])
    -- Controls follow the state: Start only with no run, Pause only while
    -- running, Resume/Skip only with a live run, Stop while one goes.
    local live = st.state == "running" or st.state == "paused"
    local running = st.state == "running"
    if live then win.start:Disable() else win.start:Enable() end
    if running then
        win.pause:Show()
        win.resume:Hide()
        win.pause:Enable()
    else
        win.pause:Hide()
        win.resume:Show()
        if st.state == "paused" then win.resume:Enable() else win.resume:Disable() end
    end
    if live then win.skip:Enable() else win.skip:Disable() end
    win.feedback:SetText(feedback and feedback.text or ("|cff9d9d9d" .. L["Click a button: the server's answer shows here."] .. "|r"))
    -- The raid bind's layout: one compact line once the server applied it.
    -- (A FontString takes no tooltip: the Bind-raid button explains the line.)
    if layout and layout.warning and not layout.tanks then
        win.layout:SetText("|cffffb040" .. layout.warning .. "|r")
    elseif layout and layout.tanks then
        local text = L["Main"] .. " " .. shortTanks(layout)
        if layout.warning then text = text .. " · |cffffb040" .. layout.warning .. "|r" end
        win.layout:SetText(text)
    else
        win.layout:SetText("")
    end
    local playerLed = runMode == "player"
    -- Switch look: the picked mode is framed and lit, the other one dimmed.
    win.modeBot:SetText((playerLed and "|cff8a8a8a" or "|cffffffff") .. L["Bots lead"] .. "|r")
    win.modeYou:SetText((playerLed and "|cffffffff" or "|cff8a8a8a") .. L["I lead"] .. "|r")
    TB.SetButtonActive(win.modeBot, not playerLed)
    TB.SetButtonActive(win.modeYou, playerLed)
    if live then win.modeBot:Disable(); win.modeYou:Disable()
    else win.modeBot:Enable(); win.modeYou:Enable() end
    if playerLed then
        win.modeHint:SetText(L["You lead; bots pull near you. Best for tanks."])
        win.bindHint:SetText(L["Start binds your party. Target = puller."])
        win.bind:Disable()
        win.bindRaid:Disable()
        win.warn:SetText(L["Your orders never pause the run."])
    else
        win.modeHint:SetText(L["A bot tank leads. Best for healers and DPS."])
        win.bindHint:SetText(L["Bind: party. Bind raid: main tank."])
        win.bind:Enable()
        win.bindRaid:Enable()
        win.warn:SetText(L["Your orders pause the run until Resume."])
    end
    -- The checkbox mirrors the flag Start reads; a live run and the player
    -- mode both lock it (the server refuses until on player-led starts).
    if win.untilBoss.SetChecked then win.untilBoss:SetChecked(stopBeforeBoss) end
    if live or playerLed then
        win.untilBoss:Disable()
        win.untilLabel:SetText("|cff8a8a8a" .. L["No boss"] .. "|r")
    else
        win.untilBoss:Enable()
        win.untilLabel:SetText(stopBeforeBoss and L["No boss: on"] or L["No boss"])
    end
    if live then win.stop:Enable() else win.stop:Disable() end
end

function TB.OpenRunWindow()
    if not TB.HasRunCapability() then return false end
    if not win then createWindow() end
    if TB.CloseVault then TB.CloseVault() end
    if TB.CloseNpc then TB.CloseNpc() end
    if TB.CloseServerInfo then TB.CloseServerInfo() end
    if TB.CloseOrderWindow then TB.CloseOrderWindow() end
    if TB.SetMode then TB.SetMode("full") end
    win:ClearAllPoints()
    local anchor = (TB.botPanel and TB.botPanel.IsVisible and TB.botPanel:IsVisible()) and TB.botPanel or TB.frame
    if anchor and anchor ~= TB.frame then
        local aRight = anchor.GetRight and anchor:GetRight()
        local fLeft = TB.frame and TB.frame.GetLeft and TB.frame:GetLeft()
        local aLeft = anchor.GetLeft and anchor:GetLeft()
        if aRight and fLeft and aRight <= fLeft then
            -- The panel sits LEFT of main: anchor right of the panel would
            -- land on main, so dock left of the panel (or right of main
            -- when the panel hugs the left screen edge).
            if aLeft and aLeft - RW - 4 >= 0 then
                win:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
            elseif TB.frame then
                win:SetPoint("TOPLEFT", TB.frame, "TOPRIGHT", 4, 0)
            else
                win:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
            end
        else
            local right = anchor.GetRight and anchor:GetRight()
            local screen = GetScreenWidth and GetScreenWidth()
            local scale = (anchor.GetScale and anchor:GetScale()) or 1
            if right and screen and (right + RW + 4) * scale > screen then
                -- The panel sits right of main: anchoring left of the panel
                -- would land on top of main, so dock left of main instead.
                win:SetPoint("TOPRIGHT", TB.frame, "TOPLEFT", -4, 0)
            else
                win:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
            end
        end
    elseif TB.frame then
        local right = TB.frame.GetRight and TB.frame:GetRight()
        local screen = GetScreenWidth and GetScreenWidth()
        local scale = (TB.frame.GetScale and TB.frame:GetScale()) or 1
        if right and screen and (right + RW + 4) * scale > screen then
            win:SetPoint("TOPRIGHT", TB.frame, "TOPLEFT", -4, 0)
        else
            win:SetPoint("TOPLEFT", TB.frame, "TOPRIGHT", 4, 0)
        end
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    win:Show()
    TB.RefreshRunWindow()
    herePlan = nil
    hereAsked = false
    TB.SendRunList()
    TB.SendRunStatus()
    return true
end

function TB.CloseRunWindow()
    plansPending = false
    if win then win:Hide() end
end

-- The capability can disappear mid-session (a restart with the feature
-- off): close the window and drop the model so no stale state lingers.
function TB.NoteRunCaps()
    if TB.UpdateRaidTab then TB.UpdateRaidTab() end
    if TB.HasRunCapability() then
        if TB.RefreshRunWindow then TB.RefreshRunWindow() end
        return
    end
    run = nil
    layout = nil
    plans = {}
    plansPending = false
    selectedPlan = nil
end
