-- BuffWatch options window. Open with /bw, or via Esc > Options > AddOns > BuffWatch.

local ADDON_NAME, ns = ...

local function Build()

local WIDTH, HEIGHT = 380, 600
local ROW_HEIGHT = 26

local function DB() return ns.GetDB() end

-- A window using Blizzard's standard template, with a plain fallback
local function CreateWindow(name, parent, w, h, titleText)
    local ok, f = pcall(CreateFrame, "Frame", name, parent, "BasicFrameTemplateWithInset")
    if not ok or not f or not f.CloseButton then
        f = CreateFrame("Frame", name, parent, "BackdropTemplate")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        f.CloseButton = close
    end
    f:SetSize(w, h)
    local t = f.TitleText
    if not t then
        t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("TOP", 0, -6)
    end
    t:SetText(titleText)
    return f
end

local win = CreateWindow("BuffWatchOptions", UIParent, WIDTH, HEIGHT, "BuffWatch Options")
win:SetPoint("CENTER", -180, 0)
win:SetFrameStrata("DIALOG")
win:SetClampedToScreen(true)
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
win:Hide()
tinsert(UISpecialFrames, "BuffWatchOptions") -- close with Esc

local controls = {} -- everything with a :Refresh() method
local refreshers = {} -- extra refresh functions (lists)

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------
local function Header(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function CreateCheck(parent, label, x, y, getter, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(26, 26)
    c:SetPoint("TOPLEFT", x, y)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.label:SetText(label)
    c:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    c.Refresh = function(self) self:SetChecked(getter()) end
    table.insert(controls, c)
    return c
end

local function CreateSlider(parent, label, x, y, minV, maxV, getter, setter)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(WIDTH - 60, 17)
    s:SetPoint("TOPLEFT", x, y)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)

    s.label = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)
    local lo = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, -1); lo:SetText(minV)
    local hi = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, -1); hi:SetText(maxV)

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        self.label:SetText(label .. ": " .. v)
        if not self.refreshing then setter(v) end
    end)
    s.Refresh = function(self)
        self.refreshing = true
        self:SetValue(getter())
        self.label:SetText(label .. ": " .. getter())
        self.refreshing = false
    end
    table.insert(controls, s)
    return s
end

local function CreateButton(parent, text, width, ...)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint(...)
    b:SetText(text)
    return b
end

local function CreateScrollList(parent, ...)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint(...)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    return scroll, content
end

local function AltText(alt)
    if not alt or #alt == 0 then return "" end
    return "  |cff888888(or " .. table.concat(alt, ", ") .. ")|r"
end

---------------------------------------------------------------------------
-- Main options layout
---------------------------------------------------------------------------
local y = -35

Header(win, "Frame", 16, y)
y = y - 20
CreateCheck(win, "Lock frame position", 14, y,
    function() return DB().locked end,
    function(v) ns.SetLocked(v) end)
CreateButton(win, "Reset position", 120, "TOPRIGHT", -16, y - 2)
    :SetScript("OnClick", function() ns.ResetPosition() end)

y = y - 36
Header(win, "Active row shows", 16, y)
y = y - 20
CreateCheck(win, "All my buffs", 14, y,
    function() return DB().mode == "all" end,
    function() ns.SetMode("all") end)
CreateCheck(win, "Only buffs I cast", 180, y,
    function() return DB().mode == "mine" end,
    function() ns.SetMode("mine") end)

y = y - 50
CreateSlider(win, "Icon size (px)", 22, y, 12, 80,
    function() return DB().size end, ns.SetIconSize)
y = y - 50
CreateSlider(win, "Icons per row", 22, y, 1, 40,
    function() return DB().perRow end, ns.SetPerRow)
y = y - 50
CreateSlider(win, "Max active buffs shown", 22, y, 1, 40,
    function() return DB().maxActive end, ns.SetMaxActive)

y = y - 40
Header(win, "Watched buffs (shown when missing)", 16, y)

y = y - 22
local browseBtn = CreateButton(win, "Browse buffs by class", 170, "TOPLEFT", 18, y)
local clearBtn  = CreateButton(win, "Clear all", 90, "LEFT", browseBtn, "RIGHT", 8, 0)

y = y - 30
local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", 16, y)
hint:SetText("Or add any spell by name, ID, or shift-click:")

y = y - 18
local input = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
input:SetSize(WIDTH - 120, 22)
input:SetPoint("TOPLEFT", 22, y)
input:SetAutoFocus(false)

local status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 16, y - 26)
status:SetPoint("RIGHT", -16, 0)
status:SetJustifyH("LEFT")

local function SetStatus(msg, ok)
    status:SetText(msg)
    if ok == nil then status:SetTextColor(1, 0.82, 0)
    elseif ok then status:SetTextColor(0.4, 1, 0.4)
    else status:SetTextColor(1, 0.4, 0.4) end
end

local function DoAdd()
    local ok, msg = ns.AddWatched(input:GetText())
    SetStatus(msg, ok)
    if ok then input:SetText("") end
    input:ClearFocus()
end
input:SetScript("OnEnterPressed", DoAdd)
input:SetScript("OnEscapePressed", input.ClearFocus)
CreateButton(win, "Add", 70, "LEFT", input, "RIGHT", 8, 0):SetScript("OnClick", DoAdd)

-- Let shift-clicked spell links land in our box
if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if link and input:HasFocus() then input:Insert(link) end
    end)
end

StaticPopupDialogs["BUFFWATCH_CLEAR"] = {
    text = "Remove all watched buffs?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() ns.ClearWatched(); SetStatus("Watch list cleared.") end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
clearBtn:SetScript("OnClick", function()
    if #DB().watched > 0 then StaticPopup_Show("BUFFWATCH_CLEAR") end
end)

-- Scrollable watch list
y = y - 48
local scroll, content = CreateScrollList(win, "TOPLEFT", 16, y)
scroll:SetPoint("BOTTOMRIGHT", -34, 14)

local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("TOPLEFT", 4, -6)
emptyText:SetText("No buffs watched yet.")

local rows = {}
local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, content)
    r:SetHeight(ROW_HEIGHT)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    r:SetPoint("RIGHT", content, "RIGHT")

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", -70, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)

    r.remove = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.remove:SetSize(64, 20)
    r.remove:SetPoint("RIGHT", -2, 0)
    r.remove:SetText("Remove")
    r.remove:SetScript("OnClick", function(self)
        local name = ns.RemoveWatchedIndex(self:GetParent().index)
        if name then SetStatus("Removed " .. name) end
    end)

    rows[i] = r
    return r
end

table.insert(refreshers, function()
    local watched = DB().watched
    for i, e in ipairs(watched) do
        local r = GetRow(i)
        r.index = i
        r.icon:SetTexture(e.icon or 134400)
        r.text:SetText(e.name .. AltText(e.alt))
        r:Show()
    end
    for i = #watched + 1, #rows do rows[i]:Hide() end
    emptyText:SetShown(#watched == 0)
    content:SetHeight(math.max(1, #watched * ROW_HEIGHT))
end)

---------------------------------------------------------------------------
-- Class buff picker (opens to the right of the options window)
---------------------------------------------------------------------------
local PICK_W, CAT_W = 400, 140
local picker = CreateWindow("BuffWatchPicker", win, PICK_W, HEIGHT, "Add buffs")
picker:SetPoint("TOPLEFT", win, "TOPRIGHT", 2, 0)
picker:EnableMouse(true)
picker:Hide()

local pickHint = picker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pickHint:SetPoint("TOPLEFT", 16, -32)
pickHint:SetPoint("RIGHT", -16, 0)
pickHint:SetJustifyH("LEFT")
pickHint:SetText("Tick a buff to watch it. Grey names in brackets also count.")

local selectedCat
local catButtons = {}
local pickRows = {}

local pickScroll, pickContent = CreateScrollList(picker, "TOPLEFT", CAT_W + 20, -52)
pickScroll:SetPoint("BOTTOMRIGHT", -34, 14)

local function PickRow_OnEnter(self)
    if not self.entry or not self.entry.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.entry.id)
    GameTooltip:Show()
end

local function GetPickRow(i)
    if pickRows[i] then return pickRows[i] end
    local r = CreateFrame("Frame", nil, pickContent)
    r:SetHeight(ROW_HEIGHT)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    r:SetPoint("RIGHT", pickContent, "RIGHT")
    r:EnableMouse(true)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)

    r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.check:SetSize(24, 24)
    r.check:SetPoint("LEFT", 0, 0)
    r.check:SetScript("OnClick", function(self)
        local e = self:GetParent().entry
        if self:GetChecked() then
            ns.AddWatchedEntry(e); SetStatus("Watching " .. e.name, true)
        else
            ns.RemoveWatchedName(e.name); SetStatus("Removed " .. e.name)
        end
    end)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
    r.icon:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)

    -- Clicking anywhere on the row toggles it
    r:SetScript("OnMouseUp", function(self) self.check:Click() end)
    r:SetScript("OnEnter", PickRow_OnEnter)
    r:SetScript("OnLeave", GameTooltip_Hide)

    pickRows[i] = r
    return r
end

local function RefreshPicker()
    if not picker:IsShown() or not selectedCat then return end
    for _, b in ipairs(catButtons) do
        b.selected:SetShown(b.cat == selectedCat)
    end
    local entries = selectedCat.entries
    for i, def in ipairs(entries) do
        local r = GetPickRow(i)
        local e = ns.ResolveCatalogEntry(def)
        r.entry = e
        r.icon:SetTexture(e.icon or 134400)
        r.text:SetText(e.name .. AltText(e.alt))
        r.check:SetChecked(ns.IsWatched(e.name) ~= nil)
        r:Show()
    end
    for i = #entries + 1, #pickRows do pickRows[i]:Hide() end
    pickContent:SetHeight(math.max(1, #entries * ROW_HEIGHT))
    pickScroll:SetVerticalScroll(0)
end
table.insert(refreshers, RefreshPicker)

-- Category buttons down the left side
for i, cat in ipairs(ns.BuffCatalog) do
    local b = CreateFrame("Button", nil, picker)
    b:SetSize(CAT_W, 22)
    b:SetPoint("TOPLEFT", 14, -52 - (i - 1) * 24)
    b.cat = cat

    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetColorTexture(1, 0.82, 0, 0.18)
    b.selected:Hide()

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.text:SetText(ns.CategoryLabel(cat))

    b:SetScript("OnClick", function(self)
        selectedCat = self.cat
        RefreshPicker()
    end)
    catButtons[i] = b
end

picker:SetScript("OnShow", function()
    if not selectedCat then
        local _, myClass = UnitClass("player")
        for _, cat in ipairs(ns.BuffCatalog) do
            if cat.key == myClass then selectedCat = cat end
        end
        selectedCat = selectedCat or ns.BuffCatalog[1]
    end
    RefreshPicker()
end)

browseBtn:SetScript("OnClick", function()
    picker:SetShown(not picker:IsShown())
end)

---------------------------------------------------------------------------
-- Refresh / open
---------------------------------------------------------------------------
local function RefreshAll()
    if not DB() then return end
    for _, c in ipairs(controls) do c:Refresh() end
    for _, f in ipairs(refreshers) do f() end
end

win:SetScript("OnShow", function()
    status:SetText("")
    RefreshAll()
end)

ns.OnSettingsChanged = function()
    if win:IsShown() then RefreshAll() end
end

function ns.OpenOptions()
    if win:IsShown() then win:Hide() else win:Show() end
end

---------------------------------------------------------------------------
-- Entry in Esc > Options > AddOns
---------------------------------------------------------------------------
if Settings and Settings.RegisterCanvasLayoutCategory then
    local page = CreateFrame("Frame")
    local t = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("BuffWatch")
    local d = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText("Settings live in their own window. You can also type /bw.")
    local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    b:SetSize(180, 24)
    b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
    b:SetText("Open BuffWatch options")
    b:SetScript("OnClick", function()
        if SettingsPanel then HideUIPanel(SettingsPanel) end
        win:Show()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(page, "BuffWatch")
    Settings.RegisterAddOnCategory(category)
end

end -- Build

local built, err = pcall(Build)
if not built then
    ns.optionsError = tostring(err)
end
