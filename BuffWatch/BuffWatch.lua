-- BuffWatch: shows your active buffs and missing (watched) buffs in a movable frame.
-- Written for the Midnight-era API (12.x) that WoW: Forever uses.
-- Some aura fields can be "secret" in combat: they can be handed to widgets
-- (textures, cooldowns, font strings) but not read or compared in Lua.
-- The code below checks for that and degrades gracefully.

local ADDON_NAME, ns = ...

local issecret = issecretvalue or function() return false end
local QUESTION_MARK = 134400

ns.defaults = {
    point     = { "CENTER", "UIParent", "CENTER", 0, -150 },
    size      = 32,     -- icon size in pixels
    spacing   = 4,
    perRow    = 10,
    maxActive = 20,
    mode      = "all",  -- "all" = every buff on you, "mine" = only buffs you cast
    locked    = false,
    watched   = {},     -- list of { name = "...", id = 123, icon = 456 }
}
local defaults = ns.defaults

local db
local activeIcons, missingIcons = {}, {}
local lastMissing = {}

function ns.GetDB() return db end

local function Print(msg)
    print("|cff33aaffBuffWatch:|r " .. msg)
end
ns.Print = Print

-- Called whenever a setting changes, so an open options window can refresh
local function Notify()
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "BuffWatchFrame", UIParent, "BackdropTemplate")
frame:SetSize(200, 40)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
frame:SetBackdropColor(0, 0, 0, 0)

frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
frame.label:SetText("BuffWatch - drag to move")

frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.point = { p, "UIParent", rp, x, y }
end)

local function ApplyLock()
    if db.locked then
        frame:EnableMouse(false)
        frame:SetBackdropColor(0, 0, 0, 0)
        frame.label:Hide()
    else
        frame:EnableMouse(true)
        frame:SetBackdropColor(0, 0.4, 1, 0.25)
        frame.label:Show()
    end
end

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------
local function Icon_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if self.auraInstanceID then
        GameTooltip:SetUnitBuffByAuraInstanceID("player", self.auraInstanceID, self.filter)
    elseif self.spellID then
        GameTooltip:SetSpellByID(self.spellID)
        GameTooltip:AddLine("Missing", 1, 0.3, 0.3)
    elseif self.spellName then
        GameTooltip:SetText(self.spellName)
        GameTooltip:AddLine("Missing", 1, 0.3, 0.3)
    end
    GameTooltip:Show()
end

local function CreateIcon()
    local b = CreateFrame("Frame", nil, frame)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b.cd:SetDrawEdge(false)
    b.cd:SetReverse(true)

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Tooltips on hover, but let clicks pass through so the frame can be dragged
    if b.SetMouseMotionEnabled then
        b:SetMouseMotionEnabled(true)
        b:SetMouseClickEnabled(false)
    else
        b:EnableMouse(true)
    end
    b:SetScript("OnEnter", Icon_OnEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function GetIcon(pool, i)
    pool[i] = pool[i] or CreateIcon()
    return pool[i]
end

local function SetAuraCooldown(b, aura)
    b.cd:Clear()
    local dur, exp = aura.duration, aura.expirationTime
    if not issecret(dur) and not issecret(exp) then
        if dur and dur > 0 and exp then
            b.cd:SetCooldown(exp - dur, dur)
        end
    elseif C_UnitAuras.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
        local ok, d = pcall(C_UnitAuras.GetAuraDuration, "player", aura.auraInstanceID)
        if ok and d then b.cd:SetCooldownFromDurationObject(d) end
    end
end

local function SetAuraCount(b, aura)
    local apps = aura.applications
    if issecret(apps) then
        if C_UnitAuras.GetAuraApplicationDisplayCount then
            local ok, txt = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", aura.auraInstanceID, 2, 99)
            b.count:SetText(ok and txt or "")
        else
            b.count:SetText("")
        end
    else
        b.count:SetText((apps and apps > 1) and apps or "")
    end
end

local function PlaceIcon(b, index, yOffset)
    local s, sp = db.size, db.spacing
    local col = (index - 1) % db.perRow
    local row = math.floor((index - 1) / db.perRow)
    b:SetSize(s, s)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", sp + col * (s + sp), -(yOffset + sp + row * (s + sp)))
    b:Show()
end

local function RowsHeight(count)
    if count == 0 then return 0 end
    local rows = math.ceil(count / db.perRow)
    return rows * (db.size + db.spacing)
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------
local function Update()
    if not db then return end
    local filter = (db.mode == "mine") and "HELPFUL|PLAYER" or "HELPFUL"

    local presentNames, presentIds = {}, {}
    local namesKnown = true
    local shown = 0

    -- Scan ALL helpful buffs for the missing-check
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        if issecret(aura.name) or issecret(aura.spellId) then
            namesKnown = false
        else
            presentNames[aura.name] = true
            presentIds[aura.spellId] = true
        end
        i = i + 1
    end

    -- Active row, according to mode
    i = 1
    while shown < db.maxActive do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
        if not aura then break end
        shown = shown + 1
        local b = GetIcon(activeIcons, shown)
        b.tex:SetTexture(aura.icon)      -- works even if the value is secret
        b.tex:SetDesaturated(false)
        b.tex:SetVertexColor(1, 1, 1)
        b.auraInstanceID, b.filter = aura.auraInstanceID, filter
        b.spellID, b.spellName = nil, nil
        SetAuraCooldown(b, aura)
        SetAuraCount(b, aura)
        PlaceIcon(b, shown, 0)
        i = i + 1
    end
    for j = shown + 1, #activeIcons do activeIcons[j]:Hide() end

    -- Missing buffs. If names are secret (in combat), keep the last known result.
    if namesKnown then
        wipe(lastMissing)
        for _, e in ipairs(db.watched) do
            local present = presentNames[e.name] or (e.id and presentIds[e.id])
            if not present and e.alt then
                -- e.g. Arcane Brilliance also counts for Arcane Intellect
                for _, altName in ipairs(e.alt) do
                    if presentNames[altName] then present = true; break end
                end
            end
            if not present then table.insert(lastMissing, e) end
        end
    end

    local yMissing = RowsHeight(shown) + ((shown > 0 and #lastMissing > 0) and db.spacing * 2 or 0)
    for n, e in ipairs(lastMissing) do
        local b = GetIcon(missingIcons, n)
        b.tex:SetTexture(e.icon or QUESTION_MARK)
        b.tex:SetDesaturated(true)
        b.tex:SetVertexColor(1, 0.45, 0.45)
        b.cd:Clear()
        b.count:SetText("")
        b.auraInstanceID, b.filter = nil, nil
        b.spellID, b.spellName = e.id, e.name
        PlaceIcon(b, n, yMissing)
    end
    for j = #lastMissing + 1, #missingIcons do missingIcons[j]:Hide() end

    local cols = math.max(1, math.min(db.perRow, math.max(shown, #lastMissing)))
    frame:SetWidth(db.spacing + cols * (db.size + db.spacing))
    frame:SetHeight(math.max(db.size + db.spacing * 2, yMissing + RowsHeight(#lastMissing) + db.spacing))
end

-- Coalesce bursts of UNIT_AURA into one update per frame
local pending = false
local function RequestUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; Update() end)
end

---------------------------------------------------------------------------
-- Public API (used by slash commands and the options window)
---------------------------------------------------------------------------
local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function ns.SetLocked(v)
    db.locked = v and true or false
    ApplyLock(); Notify()
end

function ns.SetIconSize(v)  db.size = Clamp(v, 12, 80);      Update(); Notify() end
function ns.SetPerRow(v)    db.perRow = Clamp(v, 1, 40);     Update(); Notify() end
function ns.SetMaxActive(v) db.maxActive = Clamp(v, 1, 40);  Update(); Notify() end

function ns.SetMode(mode)
    if mode ~= "all" and mode ~= "mine" then return end
    db.mode = mode; Update(); Notify()
end

function ns.ResetPosition()
    db.point = CopyTable(defaults.point)
    frame:ClearAllPoints()
    frame:SetPoint(unpack(db.point))
end

local function ResolveSpell(input)
    -- Accept spell links (shift-clicked), spell IDs, or names
    local linkId = input:match("|Hspell:(%d+)")
    local id = tonumber(linkId or input)
    if id then
        return C_Spell.GetSpellName(id), C_Spell.GetSpellTexture(id), id
    end
    local info = C_Spell.GetSpellInfo(input)
    if info then
        return info.name, info.iconID, info.spellID
    end
    return input, nil, nil
end

-- Returns ok (boolean), message (string)
function ns.AddWatched(input)
    input = input and strtrim(input) or ""
    if input == "" then return false, "Enter a spell name or ID." end
    local name, icon, id = ResolveSpell(input)
    if not name then
        return false, "Couldn't find spell " .. input .. " (spell data may still be loading, try again)."
    end
    for _, e in ipairs(db.watched) do
        if e.name == name then return false, name .. " is already watched." end
    end
    table.insert(db.watched, { name = name, icon = icon, id = id })
    Update(); Notify()
    return true, "Watching " .. name .. (icon and "" or " (no icon found - add by spell ID for an icon)")
end

-- Used by the class buff picker. entry = { name=, id=, icon=, alt={names} }
function ns.IsWatched(name)
    for n, e in ipairs(db.watched) do
        if e.name == name then return n end
    end
end

function ns.AddWatchedEntry(entry)
    if ns.IsWatched(entry.name) then return end
    table.insert(db.watched, {
        name = entry.name, id = entry.id, icon = entry.icon,
        alt = entry.alt and CopyTable(entry.alt) or nil,
    })
    Update(); Notify()
end

function ns.RemoveWatchedName(name)
    local n = ns.IsWatched(name)
    if n then ns.RemoveWatchedIndex(n) end
end

function ns.ClearWatched()
    wipe(db.watched)
    Update(); Notify()
end

function ns.RemoveWatchedIndex(index)
    local e = table.remove(db.watched, index)
    Update(); Notify()
    return e and e.name
end

function ns.FindWatched(text)
    local key = text:lower()
    for n, e in ipairs(db.watched) do
        if e.name:lower() == key or tostring(e.id) == text then return n end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_BUFFWATCH1 = "/buffwatch"
SLASH_BUFFWATCH2 = "/bw"
SLASH_BUFFWATCH3 = "/buffw"
SlashCmdList.BUFFWATCH = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if not db then
        Print("Saved settings didn't load - check for Lua errors (/console scriptErrors 1, then /reload).")
        return
    end

    if cmd == "" or cmd == "options" or cmd == "config" then
        if ns.OpenOptions then
            ns.OpenOptions()
        else
            Print("The options window failed to load: " .. (ns.optionsError or "unknown error"))
            Print("Slash commands still work - type /bw help.")
        end
    elseif cmd == "lock" then
        ns.SetLocked(true); Print("Locked.")
    elseif cmd == "unlock" then
        ns.SetLocked(false); Print("Unlocked - drag the blue box.")
    elseif cmd == "add" then
        local _, m = ns.AddWatched(rest); Print(m)
    elseif cmd == "remove" and rest ~= "" then
        local n = ns.FindWatched(rest)
        if n then Print("Removed " .. ns.RemoveWatchedIndex(n)) else Print("Not in watch list: " .. rest) end
    elseif cmd == "list" then
        if #db.watched == 0 then Print("Watch list is empty."); return end
        for _, e in ipairs(db.watched) do
            Print(" - " .. e.name .. (e.id and (" (" .. e.id .. ")") or ""))
        end
    elseif cmd == "size" and tonumber(rest) then
        ns.SetIconSize(tonumber(rest))
    elseif cmd == "perrow" and tonumber(rest) then
        ns.SetPerRow(tonumber(rest))
    elseif cmd == "mode" and (rest == "all" or rest == "mine") then
        ns.SetMode(rest); Print("Active row shows: " .. rest)
    elseif cmd == "reset" then
        ns.ResetPosition(); Print("Position reset.")
    else
        Print("Type /bw to open the options window. Commands:")
        Print("/bw unlock | lock | reset")
        Print("/bw add <spell> | remove <spell> | list")
        Print("/bw size <px> | perrow <n> | mode all|mine")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BuffWatchDB = BuffWatchDB or {}
        db = BuffWatchDB
        for k, v in pairs(defaults) do
            if db[k] == nil then
                db[k] = type(v) == "table" and CopyTable(v) or v
            end
        end
        self:ClearAllPoints()
        self:SetPoint(unpack(db.point))
        ApplyLock()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Tell the user which command is really ours (another addon may own /bw)
        local owner = hash_SlashCmdList and hash_SlashCmdList["/BW"]
        if owner and owner ~= SlashCmdList.BUFFWATCH then
            Print("Loaded. /bw is taken by another addon - use /buffwatch or /buffw.")
        else
            Print("Loaded. Type /bw or /buffwatch for options.")
        end
        RequestUpdate()
    else
        RequestUpdate()
    end
end)
