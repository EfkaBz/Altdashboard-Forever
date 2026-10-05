-- Alt Dashboard (Forever): the dashboard window (header, summary, tabs) and the Overview tab
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT, CONTENT_W = UI.WIDTH, UI.HEIGHT, UI.CONTENT_W
local ROW_H, HEAD_H = 42, 22
local icon = UI.Icon

local COLUMNS = {
  { key = "name",  label = "Character",   x = 0,   w = 165 },
  { key = "level", label = "Level",       x = 165, w = 70 },
  { key = "gold",  label = "Gold",        x = 235, w = 100 },
  { key = "prof",  label = "Professions", x = 335, w = 130 },
  { key = "cd",    label = "Cooldowns",   x = 465, w = 100 },
  { key = "mail",  label = "Mail / AH",   x = 565, w = 75 },
  { key = "gear",  label = "Gear",        x = 640, w = 65 },
  { key = "lock",  label = "Lockouts",    x = 705, w = 65 },
  { key = "todo",  label = "To do",       x = 770, w = CONTENT_W - 770 },
}

local LANGUAGES = {
  { value = "auto", text = "Automatic (game language)" },
  { value = "enUS", text = "English" },
  { value = "frFR", text = "Français" },
}

local function countCooldowns(c)
  local n = 0
  for _ in pairs(c.cooldowns or {}) do n = n + 1 end
  return n
end

-- each sorter returns the value to compare (bigger first, names A-Z); ties fall back to the name
local SORT_VALUES = {
  name  = function(c) return c.name or "" end,
  level = function(c) return (c.level or 0) + (c.xpMax and c.xpMax > 0 and (c.xp or 0) / c.xpMax or 0) end,
  gold  = function(c) return c.money or 0 end,
  prof  = function(c) local n = 0 for _, p in ipairs(c.professions or {}) do n = n + p.rank end return n end,
  cd    = countCooldowns,
  mail  = function(c) return (c.mail and c.mail.count or 0) + (c.auctions and c.auctions.count or 0) end,
  gear  = function(c) return c.ilvl or 0 end,
  lock  = function(c) return #ns.ActiveLockouts(c) end,
  todo  = function(c) return #ns.GetTasks(c) end,
}

local frame

-- Cell tooltips ----------------------------------------------------------
local function tipChar(c)
  GameTooltip:AddLine(ns.ColoredName(c) .. "  |cff999999" .. (c.realm or "") .. "|r")
  GameTooltip:AddLine(("%s %d %s"):format(LEVEL or "Level", c.level or 0, c.className or ""), 1, 1, 1)
  if c.zone and c.zone ~= "" then GameTooltip:AddLine(c.zone, 0.7, 0.7, 0.7) end
  GameTooltip:AddLine(c.key == ns.me and L["online"] or L["Last seen: %s ago"]:format(ns.FormatTime(time() - (c.lastSeen or time()))), 0.6, 0.6, 0.6)
  if c.played then GameTooltip:AddLine(L["Played: %s"]:format(ns.FormatPlayed(c.played)), 0.6, 0.6, 0.6) end
  if c.note and c.note ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(c.note, 0.6, 0.8, 1, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Right-click: note / remove"], 0.5, 1, 0.5)
end

local function tipLevel(c)
  GameTooltip:AddLine(("%s %d"):format(LEVEL or "Level", c.level or 0))
  if (c.level or 0) < ns.MAX_LEVEL and c.xpMax and c.xpMax > 0 then
    GameTooltip:AddDoubleLine(L["Experience"], ("%d / %d (%d%%)"):format(c.xp or 0, c.xpMax, (c.xp or 0) / c.xpMax * 100), 1, 1, 1, 1, 1, 1)
    local rested = ns.RestedPercent(c)
    if rested then GameTooltip:AddDoubleLine(L["Rested XP"], rested .. "%", 1, 1, 1, 0.4, 0.6, 1) end
  end
  if c.talentPoints then GameTooltip:AddDoubleLine(L["Unspent talent points"], c.talentPoints, 1, 1, 1, 1, 1, 1) end
  if c.riding ~= nil then
    GameTooltip:AddDoubleLine(L["Riding"], c.riding and ("|cff00ff00" .. YES .. "|r") or ("|cffff6060" .. NO .. "|r"), 1, 1, 1)
  end
  if c.played then GameTooltip:AddDoubleLine(L["Played"], ns.FormatPlayed(c.played), 1, 1, 1, 1, 1, 1) end
end

local function tipGold(c)
  GameTooltip:AddDoubleLine(L["Gold"], ns.Money(c.money), 1, 0.82, 0, 1, 1, 1)
  if c.mail and (c.mail.money or 0) > 0 then GameTooltip:AddDoubleLine(L["In the mailbox"], ns.Money(c.mail.money), 1, 1, 1, 1, 1, 1) end
  if c.auctions and c.auctions.count > 0 then GameTooltip:AddDoubleLine(L["At the auction house"], ns.Money(c.auctions.value), 1, 1, 1, 1, 1, 1) end
end

local function tipProf(c)
  GameTooltip:AddLine(L["Professions"])
  if #(c.professions or {}) == 0 then GameTooltip:AddLine(L["No profession"], 0.6, 0.6, 0.6) end
  for _, p in ipairs(c.professions or {}) do
    local recipes = c.recipes and c.recipes[p.name]
    GameTooltip:AddDoubleLine("|T" .. icon(p.icon) .. ":14|t " .. p.name .. (recipes and ("  |cff999999" .. L["%d recipes"]:format(#recipes) .. "|r") or ""),
      p.rank .. " / " .. p.max, 1, 1, 1, 1, 0.82, 0)
  end
  if #(c.secondary or {}) > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Secondary skills"])
    for _, p in ipairs(c.secondary) do
      GameTooltip:AddDoubleLine("|T" .. icon(p.icon) .. ":14|t " .. p.name, p.rank .. " / " .. p.max, 1, 1, 1, 1, 0.82, 0)
    end
  end
end

local function tipCooldowns(c)
  GameTooltip:AddLine(L["Cooldowns"])
  local any
  for _, cd in pairs(c.cooldowns or {}) do
    any = true
    local left = cd.expires - time()
    GameTooltip:AddDoubleLine("|T" .. icon(cd.icon) .. ":14|t " .. cd.name,
      left <= 0 and ("|cff00ff00" .. L["Ready!"] .. "|r") or ns.FormatTime(left), 1, 1, 1, 1, 0.4, 0.4)
  end
  if not any then GameTooltip:AddLine(L["None"], 0.6, 0.6, 0.6) end
end

local function tipMail(c)
  local now = time()
  GameTooltip:AddLine(L["Mailbox"])
  if not c.mail then
    GameTooltip:AddLine(L["Open the mailbox once to record it"], 0.6, 0.6, 0.6, true)
  else
    GameTooltip:AddDoubleLine(L["Letters"], c.mail.count or 0, 1, 1, 1, 1, 1, 1)
    if c.mail.new then GameTooltip:AddLine(L["New mail waiting"], 0.5, 1, 0.5) end
    if c.mail.expires then GameTooltip:AddDoubleLine(L["First expiry"], ns.FormatTime(c.mail.expires - now), 1, 1, 1, 1, 0.6, 0.3) end
    if (c.mail.money or 0) > 0 then GameTooltip:AddDoubleLine(L["Gold"], ns.Money(c.mail.money), 1, 1, 1, 1, 1, 1) end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Auction house"])
  if not c.auctions then
    GameTooltip:AddLine(L["Open the auction house once to record it"], 0.6, 0.6, 0.6, true)
  else
    GameTooltip:AddDoubleLine(L["Auctions"], c.auctions.count, 1, 1, 1, 1, 1, 1)
    if c.auctions.count > 0 then
      GameTooltip:AddDoubleLine(L["Buyout value"], ns.Money(c.auctions.value), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine(L["All ended in"], c.auctions.expires > now and ns.FormatTime(c.auctions.expires - now) or ("|cff00ff00" .. L["Ended"] .. "|r"), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(L["Recorded %s ago"]:format(ns.FormatTime(now - c.auctions.scanned)), 0.6, 0.6, 0.6)
  end
end

local function tipGear(c)
  GameTooltip:AddLine(L["Gear"])
  GameTooltip:AddDoubleLine(L["Average item level"], c.ilvl or "?", 1, 1, 1, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Lowest durability"], c.durability and (c.durability .. "%") or "?", 1, 1, 1, 1, 1, 1)
end

local function tipLockouts(c)
  GameTooltip:AddLine(L["Lockouts"])
  local list = ns.ActiveLockouts(c)
  if #list == 0 then GameTooltip:AddLine(L["No saved instance"], 0.6, 0.6, 0.6) end
  for _, lo in ipairs(list) do
    local prog = (lo.bosses and lo.bosses > 0) and ("  |cffaaaaaa" .. L["%d/%d bosses"]:format(lo.killed or 0, lo.bosses) .. "|r") or ""
    GameTooltip:AddDoubleLine(lo.name .. prog, L["Resets in %s"]:format(ns.FormatTime(lo.expires - time())), 1, 1, 1, 0.7, 0.7, 0.7)
  end
end

local function tipTasks(c)
  GameTooltip:AddLine(L["To do"])
  local tasks = ns.GetTasks(c)
  if #tasks == 0 then GameTooltip:AddLine(L["Nothing to do"], 0.5, 1, 0.5) end
  for _, t in ipairs(tasks) do GameTooltip:AddLine("- " .. t, 1, 1, 1, true) end
end

-- Row menu (note / remove) -----------------------------------------------
local menu = CreateFrame("Frame", "AltDashboardForeverRowMenu", UIParent, "UIDropDownMenuTemplate")
local function openMenu(c)
  UIDropDownMenu_Initialize(menu, function()
    local info = UIDropDownMenu_CreateInfo()
    info.text, info.isTitle, info.notCheckable = ns.ColoredName(c), true, true
    UIDropDownMenu_AddButton(info)
    info = UIDropDownMenu_CreateInfo()
    info.text, info.notCheckable = L["Edit note"], true
    info.func = function() StaticPopup_Show("ALTDASHBOARDFOREVER_NOTE", c.name, nil, c.key) end
    UIDropDownMenu_AddButton(info)
    if c.key ~= ns.me then
      info = UIDropDownMenu_CreateInfo()
      info.text, info.notCheckable = L["Remove from the dashboard"], true
      info.func = function() StaticPopup_Show("ALTDASHBOARDFOREVER_REMOVE", c.name, nil, c.key) end
      UIDropDownMenu_AddButton(info)
    end
    info = UIDropDownMenu_CreateInfo()
    info.text, info.notCheckable = CANCEL, true
    UIDropDownMenu_AddButton(info)
  end, "MENU")
  ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

local function editBoxOf(dialog) return dialog.editBox or dialog.EditBox or _G[dialog:GetName() .. "EditBox"] end

StaticPopupDialogs.ALTDASHBOARDFOREVER_NOTE = {
  text = L["Note for %s (shown in its tasks):"],
  button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 120,
  OnShow = function(self, key)
    local e = editBoxOf(self)
    e:SetText(ns.db.chars[key] and ns.db.chars[key].note or "")
    e:SetFocus()
  end,
  OnAccept = function(self, key)
    local c = ns.db.chars[key]
    if c then c.note = strtrim(editBoxOf(self):GetText()); ns.RefreshAll() end
  end,
  EditBoxOnEnterPressed = function(self)
    local d = self:GetParent()
    StaticPopupDialogs.ALTDASHBOARDFOREVER_NOTE.OnAccept(d, d.data)
    d:Hide()
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs.ALTDASHBOARDFOREVER_REMOVE = {
  text = L["Remove %s from the dashboard?"],
  button1 = YES, button2 = NO,
  OnAccept = function(_, key) ns.RemoveChar(key) end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs.ALTDASHBOARDFOREVER_RELOAD = {
  text = L["The interface will be reloaded to apply the language."],
  button1 = OKAY, button2 = CANCEL,
  OnAccept = function(_, lang) ns.db.lang = lang; ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Overview row -----------------------------------------------------------
-- a cell only shows a tooltip; clicks go to the row (menu on right-click)
local function cell(row, col, fill)
  local c = CreateFrame("Frame", nil, row)
  c:SetPoint("TOPLEFT", col.x, 0)
  c:SetSize(col.w, ROW_H)
  c:SetScript("OnEnter", function()
    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
    fill(row.char)
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  c:EnableMouse(true)
  -- (SetPropagateMouseClicks is protected in combat: handle the click here instead)
  c:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" and row.char then openMenu(row.char) end
  end)
  return c
end

local function iconSlot(parent, x, size)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size, size)
  t:SetPoint("LEFT", x, 0)
  t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  return t
end

local text = UI.Text

local function createRow(parent)
  local row = UI.RowBase(parent, CONTENT_W, ROW_H)
  row:RegisterForClicks("RightButtonUp")

  -- character
  local ch = cell(row, COLUMNS[1], tipChar)
  row.classIcon = iconSlot(ch, 6, 28)
  row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
  row.name = text(ch, "GameFontNormal", "TOPLEFT", 42, -7, COLUMNS[1].w - 46)
  row.realm = text(ch, "GameFontHighlightSmall", "BOTTOMLEFT", 42, 7, COLUMNS[1].w - 46)
  row.realm:SetTextColor(0.6, 0.6, 0.6)
  row.noteIcon = ch:CreateTexture(nil, "OVERLAY")
  row.noteIcon:SetSize(14, 14)
  row.noteIcon:SetPoint("TOPRIGHT", -2, -5)
  row.noteIcon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")

  -- level + xp bar (rested part in blue)
  local lv = cell(row, COLUMNS[2], tipLevel)
  row.level = text(lv, "GameFontHighlightLarge", "TOPLEFT", 4, -5)
  row.talents = text(lv, "GameFontGreenSmall", "LEFT", 34, 6)
  row.xpBg = lv:CreateTexture(nil, "BORDER")
  row.xpBg:SetPoint("BOTTOMLEFT", 4, 8)
  row.xpBg:SetSize(58, 5)
  row.xpBg:SetColorTexture(0, 0, 0, 0.7)
  row.rest = lv:CreateTexture(nil, "ARTWORK")
  row.rest:SetPoint("BOTTOMLEFT", row.xpBg)
  row.rest:SetHeight(5)
  row.rest:SetColorTexture(0.25, 0.45, 1, 0.6)
  row.xp = lv:CreateTexture(nil, "OVERLAY")
  row.xp:SetPoint("BOTTOMLEFT", row.xpBg)
  row.xp:SetHeight(5)
  row.xp:SetColorTexture(0.6, 0.2, 0.9, 1)

  -- gold
  local gd = cell(row, COLUMNS[3], tipGold)
  row.gold = text(gd, "GameFontHighlight", "LEFT", 4, 0)

  -- professions: 2 icons + ranks
  local pr = cell(row, COLUMNS[4], tipProf)
  row.prof = {}
  for i = 1, 2 do
    local t = iconSlot(pr, 4 + (i - 1) * 64, 24)
    t.rank = text(pr, "GameFontHighlightSmall", "LEFT", 32 + (i - 1) * 64, 0)
    row.prof[i] = t
  end
  row.noProf = text(pr, "GameFontDisableSmall", "LEFT", 4, 0)
  row.noProf:SetText("-")

  -- cooldowns: up to 3 icons with their timer
  local cd = cell(row, COLUMNS[5], tipCooldowns)
  row.cd = {}
  for i = 1, 3 do
    local t = iconSlot(cd, 4 + (i - 1) * 32, 26)
    t.timer = cd:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    t.timer:SetPoint("BOTTOM", t, "BOTTOM", 0, -3)
    row.cd[i] = t
  end
  row.noCd = text(cd, "GameFontDisableSmall", "LEFT", 4, 0)
  row.noCd:SetText("-")

  -- mail / auctions
  local ml = cell(row, COLUMNS[6], tipMail)
  row.mail = text(ml, "GameFontHighlightSmall", "TOPLEFT", 4, -8)
  row.ah = text(ml, "GameFontHighlightSmall", "BOTTOMLEFT", 4, 8)

  -- gear
  local ge = cell(row, COLUMNS[7], tipGear)
  row.ilvl = text(ge, "GameFontHighlightSmall", "TOPLEFT", 4, -8)
  row.dura = text(ge, "GameFontHighlightSmall", "BOTTOMLEFT", 4, 8)

  -- lockouts
  local lo = cell(row, COLUMNS[8], tipLockouts)
  row.lock = text(lo, "GameFontHighlightSmall", "LEFT", 4, 0)

  -- to do
  local td = cell(row, COLUMNS[9], tipTasks)
  row.todoIcon = iconSlot(td, 4, 18)
  row.todoIcon:SetTexCoord(0, 1, 0, 1)
  row.todo = text(td, "GameFontHighlight", "LEFT", 26, 0, COLUMNS[9].w - 30)

  row:SetScript("OnClick", function(self) if self.char then openMenu(self.char) end end)
  return row
end

local function fillRow(row, c, index)
  row.char = c
  local now = time()
  UI.Stripe(row, index, c.key == ns.me)

  local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c.class or ""]
  row.classIcon:SetShown(coords ~= nil)
  if coords then row.classIcon:SetTexCoord(unpack(coords)) end
  row.name:SetText(ns.ColoredName(c))
  if c.key == ns.me then
    row.realm:SetText("|cff00ff00" .. L["online"] .. "|r")
  elseif ns.db.currentRealmOnly then
    row.realm:SetText(L["Last seen: %s ago"]:format(ns.FormatTime(now - (c.lastSeen or now))))
  else
    row.realm:SetText(c.realm or "")
  end
  row.noteIcon:SetShown(c.note ~= nil and c.note ~= "")

  row.level:SetText(c.level or "?")
  row.talents:SetText((c.talentPoints or 0) > 0 and ("+" .. c.talentPoints) or "")
  local maxed = (c.level or 0) >= ns.MAX_LEVEL or not c.xpMax or c.xpMax == 0
  row.xpBg:SetShown(not maxed)
  row.xp:SetShown(not maxed and (c.xp or 0) > 0)
  row.rest:SetShown(not maxed)
  if not maxed then
    local pct = math.min(1, (c.xp or 0) / c.xpMax)
    local rested = (ns.RestedPercent(c) or 0) / 100
    row.xp:SetWidth(math.max(1, 58 * pct))
    row.rest:SetWidth(math.max(1, 58 * math.min(1, pct + rested)))
  end

  row.gold:SetText(ns.Money(c.money, true))

  local profs = c.professions or {}
  for i, t in ipairs(row.prof) do
    local p = profs[i]
    t:SetShown(p ~= nil)
    t.rank:SetShown(p ~= nil)
    if p then
      t:SetTexture(icon(p.icon))
      local col = p.rank >= 300 and "|cff00ff00" or p.rank >= p.max and "|cffff9933" or "|cffffffff"
      t.rank:SetText(col .. p.rank .. "|r")
    end
  end
  row.noProf:SetShown(#profs == 0)

  local cds = {}
  for _, def in ipairs(ns.COOLDOWNS) do
    if c.cooldowns and c.cooldowns[def.key] then cds[#cds + 1] = c.cooldowns[def.key] end
  end
  for i, t in ipairs(row.cd) do
    local cd = cds[i]
    t:SetShown(cd ~= nil)
    t.timer:SetShown(cd ~= nil)
    if cd then
      t:SetTexture(icon(cd.icon))
      local left = cd.expires - now
      t:SetDesaturated(left > 0)
      t.timer:SetText(left <= 0 and ("|cff00ff00" .. L["Ready"] .. "|r") or ("|cffff6060" .. ns.FormatShortTime(left) .. "|r"))
    end
  end
  row.noCd:SetShown(#cds == 0)

  local mailIcon = "|TInterface\\Icons\\INV_Letter_15:14|t "
  local ahIcon = "|TInterface\\Icons\\INV_Misc_Coin_01:14|t "
  if c.mail then
    local warn = c.mail.expires and c.mail.expires - now < ns.MAIL_WARN_DAYS * 86400
    local col = warn and "|cffff6060" or ((c.mail.count or 0) > 0 or c.mail.new) and "|cffffd100" or "|cff808080"
    row.mail:SetText(mailIcon .. col .. (c.mail.count or 0) .. (c.mail.new and "+" or "") .. "|r")
  else
    row.mail:SetText(mailIcon .. "|cff808080?|r")
  end
  if c.auctions then
    local col = c.auctions.count == 0 and "|cff808080" or c.auctions.expires <= now and "|cff00ff00" or "|cffffffff"
    row.ah:SetText(ahIcon .. col .. c.auctions.count .. "|r")
  else
    row.ah:SetText(ahIcon .. "|cff808080?|r")
  end

  row.ilvl:SetText(c.ilvl and ("|cffaaaaaa" .. L["ilvl"] .. "|r " .. c.ilvl) or "|cff808080-|r")
  if c.durability then
    local col = c.durability <= ns.LOW_DURABILITY and "|cffff4040" or c.durability < 60 and "|cffffd100" or "|cff00ff00"
    row.dura:SetText(col .. c.durability .. "%|r")
  else
    row.dura:SetText("")
  end

  local nLock = #ns.ActiveLockouts(c)
  row.lock:SetText(nLock > 0 and ("|cffff9933" .. L["%d saved"]:format(nLock) .. "|r") or ("|cff808080" .. L["None"] .. "|r"))

  local n = #ns.GetTasks(c)
  if n == 0 then
    row.todoIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    row.todo:SetText("|cff808080" .. L["Nothing to do"] .. "|r")
  else
    row.todoIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    row.todo:SetText("|cffffd100" .. (n == 1 and L["%d task"] or L["%d tasks"]):format(n) .. "|r")
  end
end

-- Overview page ----------------------------------------------------------
local overview = { key = "overview", label = "Overview" }

function overview.build(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()

  p.todoOnly = UI.Check(p, L["Only characters with tasks"], function(self)
    ns.db.todoOnly = self:GetChecked() or nil
    ns.RefreshDashboard()
  end)
  p.todoOnly:SetPoint("TOPLEFT", 0, 0)

  local box = UI.ListBox(p)
  box:SetPoint("TOPLEFT", 0, -26)
  box:SetPoint("BOTTOMRIGHT")

  -- column titles (click to sort)
  local headBar = UI.HeaderBar(box, CONTENT_W, HEAD_H)
  p.heads = {}
  for _, col in ipairs(COLUMNS) do
    local h = CreateFrame("Button", nil, headBar)
    h:SetPoint("TOPLEFT", col.x, 0)
    h:SetSize(col.w, HEAD_H)
    h.key = col.key
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.label:SetPoint("LEFT", col.key == "name" and 42 or 4, 0)
    h.label:SetText(L[col.label])
    h.arrow = h:CreateTexture(nil, "OVERLAY")
    h.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    h.arrow:SetSize(9, 8)
    h.arrow:SetPoint("LEFT", h.label, "RIGHT", 3, 0)
    local hl = h:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    h:SetScript("OnClick", function()
      if ns.db.sort == col.key then ns.db.sortDesc = not ns.db.sortDesc or nil
      else ns.db.sort, ns.db.sortDesc = col.key, nil end
      ns.RefreshDashboard()
    end)
    p.heads[#p.heads + 1] = h
  end

  local _, content = UI.Scroll(box, HEAD_H)
  p.content = content
  p.rows = {}
  return p
end

function overview.refresh(p)
  p.todoOnly:SetChecked(ns.db.todoOnly)
  local list = {}
  for _, c in ipairs(ns.VisibleChars()) do
    if not ns.db.todoOnly or #ns.GetTasks(c) > 0 then list[#list + 1] = c end
  end
  local value = SORT_VALUES[ns.db.sort] or SORT_VALUES.level
  local asc = ns.db.sort == "name"
  if ns.db.sortDesc then asc = not asc end
  table.sort(list, function(a, b)
    local x, y = value(a), value(b)
    if x == y then return (a.name or "") < (b.name or "") end
    if asc then return x < y end
    return x > y
  end)

  for i, c in ipairs(list) do
    local row = p.rows[i] or createRow(p.content)
    p.rows[i] = row
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    fillRow(row, c, i)
    row:Show()
  end
  for i = #list + 1, #p.rows do p.rows[i]:Hide() end
  p.content:SetHeight(math.max(#list * ROW_H, 1))

  for _, h in ipairs(p.heads) do
    local active = ns.db.sort == h.key
    if active then h.label:SetTextColor(1, 1, 1) else h.label:SetTextColor(1, 0.82, 0) end
    h.arrow:SetShown(active)
    if ns.db.sortDesc then h.arrow:SetTexCoord(0, 0.5625, 1, 0) else h.arrow:SetTexCoord(0, 0.5625, 0, 1) end
  end
end

table.insert(ns.PAGES, 1, overview)

-- Refresh ----------------------------------------------------------------
function ns.RefreshDashboard()
  if not frame or not frame:IsShown() then return end
  local chars = ns.VisibleChars()
  local total, tasks = 0, 0
  for _, c in ipairs(chars) do
    total = total + (c.money or 0)
    tasks = tasks + #ns.GetTasks(c)
  end
  local parts = { L["%d characters"]:format(#chars), L["Total: %s"]:format(ns.Money(total, true)) }
  local reset = ns.NextWeeklyReset()
  if reset then parts[#parts + 1] = L["Weekly reset: %s"]:format(ns.FormatTime(reset - time())) end
  parts[#parts + 1] = (tasks > 0 and "|cff7a0000" or "|cff0f4a00") .. L["%d tasks this week"]:format(tasks) .. "|r"
  frame.stats:SetText(table.concat(parts, "   |cff4a3010-|r   "))

  frame.realmOnly:SetChecked(ns.db.currentRealmOnly)
  frame.minimap:SetChecked(not ns.db.hideMinimap)
  frame.itemTip:SetChecked(not ns.db.noItemTooltip)
  frame.miniCheck:SetChecked(ns.db.miniShown)

  for _, tab in ipairs(frame.tabs) do
    local active = tab.page.key == ns.db.tab
    tab:SetChecked(active)
    if active then frame.pageTitle:SetText(L[tab.page.label]) end
    if active and not tab.frame then tab.frame = tab.page.build(frame.pageArea) end
    if tab.frame then tab.frame:SetShown(active) end
    if active then tab.page.refresh(tab.frame) end
  end
end

-- Window (same look as the WoW Forever spellbook: metal frame, portrait, parchment) ----
local TAB_ICONS = {
  overview = "INV_Misc_Book_11", reps = "Ability_Warrior_BattleShout", weekly = "INV_Misc_Note_01",
  search = "INV_Misc_Bag_08", gold = "INV_Misc_Coin_01",
}

local function atlasExists(name)
  return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- parchment: the spellbook atlas when the client has it, else the classic spellbook pages
local function parchment(f)
  local left = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  local right = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  left:SetPoint("TOPLEFT", 6, -62)
  left:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, 6)
  right:SetPoint("TOPLEFT", f, "TOP", 0, -62)
  right:SetPoint("BOTTOMRIGHT", -6, 6)
  if atlasExists("spellbook-background-evergreen-left") then
    left:SetAtlas("spellbook-background-evergreen-left")
    right:SetAtlas("spellbook-background-evergreen-right")
  else
    left:SetTexture("Interface\\Spellbook\\Spellbook-Page-1")
    left:SetTexCoord(0, 0.86, 0, 0.9)
    right:SetTexture("Interface\\Spellbook\\Spellbook-Page-2")
    right:SetTexCoord(0, 0.86, 0, 0.9)
  end
end

local function setPortrait(f)
  local tex = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait
  if not tex then
    tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetSize(58, 58)
    tex:SetPoint("TOPLEFT", -5, 7)
  end
  tex:SetTexture(ns.ADDON_ICON)
  if tex.SetMask then tex:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
end

local function setTitle(f, text)
  if f.SetTitle then f:SetTitle(text) return end
  local t = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
  if not t then
    t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", 0, -5)
  end
  t:SetText(text)
end

local function create()
  local ok, f = pcall(CreateFrame, "Frame", "AltDashboardForeverFrame", UIParent, "PortraitFrameTemplate")
  if not ok then
    f = CreateFrame("Frame", "AltDashboardForeverFrame", UIParent, "BackdropTemplate")
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      tile = true, tileSize = 32, edgeSize = 24,
      insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
  end
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  tinsert(UISpecialFrames, f:GetName()) -- close with Escape

  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  setTitle(f, "Alt Dashboard (Forever)  |cff9d9d9dv" .. (getMeta(ADDON, "Version") or "?") .. "|r")
  setPortrait(f)
  parchment(f)

  -- tab icons under the title, like the spellbook
  f.tabs = {}
  for i, page in ipairs(ns.PAGES) do
    local tab = CreateFrame("CheckButton", nil, f)
    tab.page = page
    tab:SetSize(34, 34)
    tab:SetPoint("TOPLEFT", 70 + (i - 1) * 42, -26)
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(UI.Icon(TAB_ICONS[page.key] or "INV_Misc_QuestionMark"))
    local border = tab:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    tab:GetCheckedTexture():SetBlendMode("ADD")
    tab:SetScript("OnClick", function()
      ns.db.tab = page.key
      ns.RefreshDashboard()
    end)
    tab:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(L[page.label])
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.tabs[#f.tabs + 1] = tab
  end

  -- search box (top right): opens the Search tab
  local ok2, search = pcall(CreateFrame, "EditBox", nil, f, "SearchBoxTemplate")
  if not ok2 then search = UI.EditBox(f, 220) end
  search:SetSize(220, 20)
  search:SetPoint("TOPRIGHT", -40, -34)
  search:SetAutoFocus(false)
  if search.Instructions then search.Instructions:SetText(L["Search items, recipes"]) end
  search:HookScript("OnTextChanged", function(self, user)
    if not user then return end
    ns.db.tab = "search"
    ns.RefreshDashboard()
    if ns.SetSearchText then ns.SetSearchText(self:GetText()) end
  end)

  -- page title, as the "General" heading of the spellbook
  f.pageTitle = f:CreateFontString(nil, "OVERLAY", "QuestFont_Huge")
  f.pageTitle:SetPoint("TOPLEFT", 36, -76)
  f.pageTitle:SetTextColor(0.1, 0.05, 0.01)
  f.pageTitle:SetShadowOffset(0, 0)
  local rule = f:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", 30, -104)
  rule:SetPoint("TOPRIGHT", -30, -104)
  rule:SetHeight(1)
  rule:SetColorTexture(0.2, 0.12, 0.04, 0.8)

  f.stats = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.stats:SetPoint("BOTTOMRIGHT", rule, "TOPRIGHT", -4, 6)
  f.stats:SetTextColor(0.1, 0.05, 0.01)
  f.stats:SetShadowOffset(0, 0)

  f.realmOnly = UI.Check(f, L["Current realm only"], function(self)
    ns.db.currentRealmOnly = self:GetChecked() or nil
    ns.RefreshAll()
  end)
  f.realmOnly:SetPoint("TOPRIGHT", -34 - f.realmOnly.text:GetStringWidth(), -108)

  f.pageArea = CreateFrame("Frame", nil, f)
  f.pageArea:SetPoint("TOPLEFT", 30, -134)
  f.pageArea:SetPoint("BOTTOMRIGHT", -30, 44)

  -- footer: options, language, refresh
  f.minimap = UI.Check(f, L["Minimap button"], function(self)
    ns.db.hideMinimap = not self:GetChecked() or nil
    ns.UpdateMinimapButton()
  end)
  f.minimap:SetPoint("BOTTOMLEFT", 30, 14)
  f.itemTip = UI.Check(f, L["Alts in item tooltips"], function(self) ns.db.noItemTooltip = not self:GetChecked() or nil end)
  f.itemTip:SetPoint("BOTTOMLEFT", 200, 14)
  f.miniCheck = UI.Check(f, L["Compact window"], function(self) ns.SetMiniShown(self:GetChecked()) end)
  f.miniCheck:SetPoint("BOTTOMLEFT", 410, 14)

  local lang = CreateFrame("Frame", "AltDashboardForeverLangDropDown", f, "UIDropDownMenuTemplate")
  lang:SetPoint("BOTTOMRIGHT", -150, 10)
  UIDropDownMenu_SetWidth(lang, 150)
  UIDropDownMenu_Initialize(lang, function()
    for _, o in ipairs(LANGUAGES) do
      local info = UIDropDownMenu_CreateInfo()
      info.text, info.value = L[o.text], o.value
      info.checked = (ns.db.lang or "auto") == o.value
      info.func = function()
        CloseDropDownMenus()
        if (ns.db.lang or "auto") ~= o.value then StaticPopup_Show("ALTDASHBOARDFOREVER_RELOAD", nil, nil, o.value) end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  for _, o in ipairs(LANGUAGES) do
    if o.value == (ns.db.lang or "auto") then UIDropDownMenu_SetText(lang, L[o.text]) end
  end

  local refresh = UI.Button(f, L["Refresh"], 110, function() ns.ScanAll() end)
  refresh:SetPoint("BOTTOMRIGHT", -30, 12)

  -- timers tick while the window is open
  local elapsed = 0
  f:SetScript("OnUpdate", function(_, e)
    elapsed = elapsed + e
    if elapsed > 30 then elapsed = 0; ns.RefreshDashboard() end
  end)
  f:SetScript("OnShow", ns.RefreshDashboard)
  f:Hide()
  return f
end

function ns.ToggleDashboard(tab)
  frame = frame or create()
  if tab then
    ns.db.tab = tab
    frame:Show()
    ns.RefreshDashboard()
  else
    frame:SetShown(not frame:IsShown())
  end
end
