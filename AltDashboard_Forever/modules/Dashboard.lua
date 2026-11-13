-- Alt Dashboard (Forever): the dashboard window (title bar, tabs, summary cards) and the Overview tab
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local S = ns.Skin
local C = S.C

local WIDTH, HEIGHT, CONTENT_W = UI.WIDTH, UI.HEIGHT, UI.CONTENT_W
local ROW_H, HEAD_H = 40, 24
local icon = UI.Icon

local COLUMNS = {
  { key = "name",  label = "Character",   x = 0,   w = 170 },
  { key = "level", label = "Level",       x = 170, w = 74 },
  { key = "gold",  label = "Gold",        x = 244, w = 100 },
  { key = "prof",  label = "Professions", x = 344, w = 130 },
  { key = "cd",    label = "Cooldowns",   x = 474, w = 100 },
  { key = "mail",  label = "Mail / AH",   x = 574, w = 76 },
  { key = "gear",  label = "Gear",        x = 650, w = 66 },
  { key = "lock",  label = "Lockouts",    x = 716, w = 70 },
  { key = "todo",  label = "To do",       x = 786, w = CONTENT_W - 786 },
}

local LANGUAGES = {
  { "auto", "Automatic (game language)" },
  { "enUS", "English" },
  { "frFR", "Français" },
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
    -- letters sent by the other characters since this one last opened its mailbox
    local incoming = c.mail.incoming or {}
    if #incoming > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L["Sent by your characters"], 0.85, 0.7, 0.42)
      for i = #incoming, math.max(1, #incoming - 5), -1 do
        local m = incoming[i]
        local what = {}
        if (m.items or 0) > 0 then what[#what + 1] = L["%d items"]:format(m.items) end
        if (m.money or 0) > 0 then what[#what + 1] = ns.Money(m.money, true) end
        GameTooltip:AddDoubleLine((m.from or "?") .. "  |cff999999" .. L["%s ago"]:format(ns.FormatTime(now - (m.at or now))) .. "|r",
          #what > 0 and table.concat(what, ", ") or (m.subject or ""), 1, 1, 1, 1, 1, 1)
      end
    end
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

-- Row menu and dialogs (note / remove / language) -------------------------
local function editNote(c)
  S.Dialog({
    text = L["Note for %s (shown in its tasks):"]:format(ns.ColoredName(c)),
    edit = true, value = c.note or "", maxLetters = 120,
    onAccept = function(text)
      local char = ns.db.chars[c.key]
      if char then char.note = text; ns.RefreshAll() end
    end,
  })
end

local function confirmRemove(c)
  S.Dialog({
    text = L["Remove %s from the dashboard?"]:format(ns.ColoredName(c)),
    accept = YES, cancel = NO,
    onAccept = function() ns.RemoveChar(c.key) end,
  })
end

local function openMenu(c)
  local entries = {
    { text = ns.ColoredName(c), title = true },
    { text = L["Edit note"], func = function() editNote(c) end },
  }
  if c.key ~= ns.me then
    entries[#entries + 1] = { text = L["Remove from the dashboard"], color = C.bad, func = function() confirmRemove(c) end }
  end
  S.Menu(entries)
end

-- Overview row -----------------------------------------------------------
-- a cell only shows a tooltip; clicks go to the row (menu on right-click)
local function cell(row, col, fill)
  local c = CreateFrame("Frame", nil, row)
  c:SetPoint("TOPLEFT", col.x, 0)
  c:SetSize(col.w, ROW_H)
  c:EnableMouse(true)
  c:SetScript("OnEnter", function()
    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
    fill(row.char)
    GameTooltip:Show()
    -- keep the row highlight while the mouse is over one of its cells
    S.FadeTo(row.hl, 1, 0.12)
  end)
  c:SetScript("OnLeave", function()
    GameTooltip:Hide()
    S.FadeTo(row.hl, 0, 0.3)
  end)
  -- (SetPropagateMouseClicks is protected in combat: handle the click here instead)
  c:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" and row.char then openMenu(row.char) end
  end)
  return c
end

local text = UI.Text

-- ready cooldowns breathe softly (one driver for every row)
local readyGlows = {}
local pulse = CreateFrame("Frame")
local pulseClock = 0
pulse:SetScript("OnUpdate", function(_, e)
  if not frame or not frame:IsShown() then return end
  pulseClock = pulseClock + e
  local a = 0.35 + 0.3 * (0.5 + 0.5 * math.sin(pulseClock * 2.4))
  for g in pairs(readyGlows) do if g:IsShown() then g:SetAlpha(a) end end
end)

local function createRow(parent)
  local row = UI.RowBase(parent, CONTENT_W, ROW_H)
  row:RegisterForClicks("RightButtonUp")

  -- character
  local ch = cell(row, COLUMNS[1], tipChar)
  row.classIcon = ch:CreateTexture(nil, "ARTWORK")
  row.classIcon:SetSize(28, 28)
  row.classIcon:SetPoint("LEFT", 8, 0)
  row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
  row.classRing = ch:CreateTexture(nil, "BACKGROUND", nil, 3)
  row.classRing:SetTexture(S.MEDIA .. "Glow")
  row.classRing:SetSize(42, 42)
  row.classRing:SetPoint("CENTER", row.classIcon)
  row.classRing:SetBlendMode("ADD")
  row.name = S.Text(ch, 13, "text")
  row.name:SetPoint("TOPLEFT", 44, -7)
  row.name:SetWidth(COLUMNS[1].w - 50)
  row.name:SetWordWrap(false)
  row.realm = S.Text(ch, 10, "muted")
  row.realm:SetPoint("BOTTOMLEFT", 44, 7)
  row.realm:SetWidth(COLUMNS[1].w - 50)
  row.realm:SetWordWrap(false)
  row.noteIcon = ch:CreateTexture(nil, "OVERLAY")
  row.noteIcon:SetSize(6, 6)
  row.noteIcon:SetPoint("TOPRIGHT", -6, -8)
  row.noteIcon:SetTexture(S.MEDIA .. "Dot")
  row.noteIcon:SetVertexColor(S.Color(C.accent))

  -- level + xp bar (rested part behind, lighter)
  local lv = cell(row, COLUMNS[2], tipLevel)
  row.level = S.Text(lv, 15, "text")
  row.level:SetPoint("TOPLEFT", 4, -6)
  row.talents = S.Text(lv, 10, "good")
  row.talents:SetPoint("LEFT", row.level, "RIGHT", 5, 0)
  row.xpBar = S.Bar(lv, 60, 4, "xp")
  row.xpBar:SetPoint("BOTTOMLEFT", 4, 9)

  -- gold
  local gd = cell(row, COLUMNS[3], tipGold)
  row.gold = text(gd, "GameFontHighlight", "LEFT", 4, 0)

  -- professions: 2 framed icons + ranks
  local pr = cell(row, COLUMNS[4], tipProf)
  row.prof = {}
  for i = 1, 2 do
    local t = S.Icon(pr, 22)
    t:SetPoint("LEFT", 4 + (i - 1) * 64, 0)
    t.rank = S.Text(pr, 11, "text")
    t.rank:SetPoint("LEFT", t, "RIGHT", 5, 0)
    row.prof[i] = t
  end
  row.noProf = text(pr, "GameFontDisableSmall", "LEFT", 4, 0)
  row.noProf:SetText("-")

  -- cooldowns: up to 3 icons with their timer; a soft glow when ready
  local cd = cell(row, COLUMNS[5], tipCooldowns)
  row.cd = {}
  for i = 1, 3 do
    local t = S.Icon(cd, 24)
    t:SetPoint("LEFT", 6 + (i - 1) * 31, 2)
    t.glow = cd:CreateTexture(nil, "BACKGROUND", nil, 3)
    t.glow:SetTexture(S.MEDIA .. "Glow")
    t.glow:SetBlendMode("ADD")
    t.glow:SetSize(44, 44)
    t.glow:SetPoint("CENTER", t)
    t.glow:SetVertexColor(S.Color(C.good))
    readyGlows[t.glow] = true
    t.timer = S.Text(t, 9, "text", "OVERLAY", "OUTLINE")
    t.timer:SetPoint("BOTTOM", t, "BOTTOM", 0, -6)
    row.cd[i] = t
  end
  row.noCd = text(cd, "GameFontDisableSmall", "LEFT", 4, 0)
  row.noCd:SetText("-")

  -- mail / auctions
  local ml = cell(row, COLUMNS[6], tipMail)
  row.mail = text(ml, "GameFontHighlightSmall", "TOPLEFT", 4, -7)
  row.ah = text(ml, "GameFontHighlightSmall", "BOTTOMLEFT", 4, 7)

  -- gear
  local ge = cell(row, COLUMNS[7], tipGear)
  row.ilvl = text(ge, "GameFontHighlightSmall", "TOPLEFT", 4, -7)
  row.dura = text(ge, "GameFontHighlightSmall", "BOTTOMLEFT", 4, 7)

  -- lockouts
  local lo = cell(row, COLUMNS[8], tipLockouts)
  row.lock = text(lo, "GameFontHighlightSmall", "LEFT", 4, 0)

  -- to do: colored dot + count
  local td = cell(row, COLUMNS[9], tipTasks)
  row.todoDot = td:CreateTexture(nil, "ARTWORK")
  row.todoDot:SetTexture(S.MEDIA .. "Dot")
  row.todoDot:SetSize(8, 8)
  row.todoDot:SetPoint("LEFT", 6, 0)
  row.todo = text(td, "GameFontHighlight", "LEFT", 22, 0, COLUMNS[9].w - 26)

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
  local col = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[c.class or ""]
  if col then row.classRing:SetVertexColor(col.r, col.g, col.b, 0.35) else row.classRing:SetVertexColor(1, 1, 1, 0) end
  row.name:SetText(ns.ColoredName(c))
  if c.key == ns.me then
    row.realm:SetText(S.Hex(C.good) .. L["online"] .. "|r")
  elseif ns.db.currentRealmOnly then
    row.realm:SetText(L["Last seen: %s ago"]:format(ns.FormatTime(now - (c.lastSeen or now))))
  else
    row.realm:SetText(c.realm or "")
  end
  row.noteIcon:SetShown(c.note ~= nil and c.note ~= "")

  row.level:SetText(c.level or "?")
  row.talents:SetText((c.talentPoints or 0) > 0 and ("+" .. c.talentPoints) or "")
  local maxed = (c.level or 0) >= ns.MAX_LEVEL or not c.xpMax or c.xpMax == 0
  row.xpBar:SetShown(not maxed)
  if not maxed then
    local pct = math.min(1, (c.xp or 0) / c.xpMax)
    local rested = (ns.RestedPercent(c) or 0) / 100
    row.xpBar:SetValue(pct)
    row.xpBar:SetSecond(math.min(1, pct + rested))
  end

  row.gold:SetText(ns.Money(c.money, true))

  local profs = c.professions or {}
  for i, t in ipairs(row.prof) do
    local p = profs[i]
    t:SetShown(p ~= nil)
    t.rank:SetShown(p ~= nil)
    if p then
      t.tex:SetTexture(icon(p.icon))
      local hex = p.rank >= 300 and S.Hex(C.good) or p.rank >= p.max and S.Hex(C.warn) or S.Hex(C.text)
      t.rank:SetText(hex .. p.rank .. "|r")
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
    t.glow:SetShown(false)
    if cd then
      t.tex:SetTexture(icon(cd.icon))
      local left = cd.expires - now
      t.tex:SetDesaturated(left > 0)
      t.glow:SetShown(left <= 0)
      t.timer:SetText(left <= 0 and (S.Hex(C.good) .. L["Ready"] .. "|r") or (S.Hex(C.bad) .. ns.FormatShortTime(left) .. "|r"))
    end
  end
  row.noCd:SetShown(#cds == 0)

  local mailIcon = "|TInterface\\Icons\\INV_Letter_15:13:13:0:0:64:64:5:59:5:59|t "
  local ahIcon = "|TInterface\\Icons\\INV_Misc_Coin_01:13:13:0:0:64:64:5:59:5:59|t "
  local grey = S.Hex(C.dim)
  if c.mail then
    local warn = c.mail.expires and c.mail.expires - now < ns.MAIL_WARN_DAYS * 86400
    local hex = warn and S.Hex(C.bad) or ((c.mail.count or 0) > 0 or c.mail.new) and S.Hex(C.gold) or grey
    row.mail:SetText(mailIcon .. hex .. (c.mail.count or 0) .. (c.mail.new and "+" or "") .. "|r")
  else
    row.mail:SetText(mailIcon .. grey .. "?|r")
  end
  if c.auctions then
    local hex = c.auctions.count == 0 and grey or c.auctions.expires <= now and S.Hex(C.good) or S.Hex(C.text)
    row.ah:SetText(ahIcon .. hex .. c.auctions.count .. "|r")
  else
    row.ah:SetText(ahIcon .. grey .. "?|r")
  end

  row.ilvl:SetText(c.ilvl and (S.Hex(C.muted) .. L["ilvl"] .. "|r " .. c.ilvl) or (grey .. "-|r"))
  if c.durability then
    local hex = c.durability <= ns.LOW_DURABILITY and S.Hex(C.bad) or c.durability < 60 and S.Hex(C.warn) or S.Hex(C.good)
    row.dura:SetText(hex .. c.durability .. "%|r")
  else
    row.dura:SetText("")
  end

  local nLock = #ns.ActiveLockouts(c)
  row.lock:SetText(nLock > 0 and (S.Hex(C.warn) .. L["%d saved"]:format(nLock) .. "|r") or (grey .. L["None"] .. "|r"))

  local n = #ns.GetTasks(c)
  if n == 0 then
    row.todoDot:SetVertexColor(S.Color(C.good))
    row.todo:SetText(grey .. L["Nothing to do"] .. "|r")
  else
    row.todoDot:SetVertexColor(S.Color(C.gold))
    row.todo:SetText(S.Hex(C.goldHi) .. (n == 1 and L["%d task"] or L["%d tasks"]):format(n) .. "|r")
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
  p.todoOnly:SetPoint("TOPLEFT", 2, -2)

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
    h.label = S.Text(h, 11, "muted")
    h.label:SetPoint("LEFT", col.key == "name" and 44 or 4, 0)
    h.label:SetText(L[col.label])
    h.arrow = S.Chevron(h, 7, C.gold)
    h.arrow:SetPoint("LEFT", h.label, "RIGHT", 5, 0)
    h:SetScript("OnEnter", function(self) if ns.db.sort ~= self.key then self.label:SetTextColor(S.Color(C.text)) end end)
    h:SetScript("OnLeave", function(self) if ns.db.sort ~= self.key then self.label:SetTextColor(S.Color(C.muted)) end end)
    h:SetScript("OnClick", function()
      if ns.db.sort == col.key then ns.db.sortDesc = not ns.db.sortDesc or nil
      else ns.db.sort, ns.db.sortDesc = col.key, nil end
      ns.RefreshDashboard()
      h.arrow:Point(ns.db.sortDesc and "up" or "down", true)
      UI.Cascade(p.rows, #p.rows)
    end)
    p.heads[#p.heads + 1] = h
  end

  local _, content = UI.Scroll(box, HEAD_H)
  p.content = content
  p.rows = {}

  p.empty = S.Text(box, 13, "muted")
  p.empty:SetPoint("CENTER", 0, -10)
  p.empty:SetText(L["Nothing to do"])
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
    row:Show()
    fillRow(row, c, i)
  end
  for i = #list + 1, #p.rows do p.rows[i]:Hide() end
  p.content:SetHeight(math.max(#list * ROW_H, 1))
  p.empty:SetShown(#list == 0)

  for _, h in ipairs(p.heads) do
    local active = ns.db.sort == h.key
    h.label:SetTextColor(S.Color(active and C.gold or C.muted))
    h.arrow:SetShown(active)
    if active and not S.IsTweening(h.arrow) then h.arrow:Point(ns.db.sortDesc and "up" or "down") end
  end
end

function overview.animate(p)
  UI.Cascade(p.rows, #p.rows)
  for _, row in ipairs(p.rows) do
    if row:IsShown() and row.xpBar:IsShown() then row.xpBar:Replay(0.15) end
  end
end

table.insert(ns.PAGES, 1, overview)

-- Summary cards ----------------------------------------------------------
local CARD_H = 52
local function card(parent, iconName, label)
  local f = S.Panel(parent, 8)
  f:SetHeight(CARD_H)
  f.icon = S.Icon(f, 30, icon(iconName))
  f.icon:SetPoint("LEFT", 12, 0)
  f.label = S.Text(f, 10, "muted")
  f.label:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 11, -1)
  f.label:SetText(label)
  f.value = S.Text(f, 15, "text")
  f.value:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 11, 0)
  f.value:SetPoint("RIGHT", -10, 0)
  f.value:SetWordWrap(false)
  -- hover: border eases to blue
  f:EnableMouse(true)
  f:SetScript("OnEnter", function() S.TweenBorder(f, C.ring) end)
  f:SetScript("OnLeave", function() S.TweenBorder(f, C.trim) end)
  -- a changed value fades in
  function f:Set(v)
    if self.last == v then return end
    local first = self.last == nil
    self.last = v
    self.value:SetText(v)
    if not first and self:IsVisible() then
      self.value:SetAlpha(0.2)
      S.FadeTo(self.value, 1, 0.4)
    end
  end
  return f
end

-- Refresh ----------------------------------------------------------------
local function showPage(tab, animate)
  local pageFrame = tab.frame
  pageFrame:Show()
  if not animate then return end
  pageFrame:SetAlpha(0)
  S.Tween(pageFrame, { dur = 0.28, from = 10, to = 0, set = function(v, pr)
    pageFrame:SetAlpha(pr)
    pageFrame:ClearAllPoints()
    pageFrame:SetPoint("TOPLEFT", 0, -v)
    pageFrame:SetPoint("BOTTOMRIGHT", 0, -v)
  end })
  if tab.page.animate then tab.page.animate(pageFrame) end
end

-- the tab marker slides under the active tab
local function moveMarker(tab, instant)
  local m = frame.marker
  local x0, w0 = m.x or 0, m.w or 0
  local x1, w1 = tab.x, tab:GetWidth()
  local function place(px, pw)
    m.x, m.w = px, pw
    m:ClearAllPoints()
    m:SetPoint("BOTTOMLEFT", frame.tabBar, "BOTTOMLEFT", px, 0)
    m:SetWidth(math.max(1, pw))
  end
  if instant or w0 == 0 then place(x1, w1) return end
  S.Tween(m, { dur = 0.3, from = 0, to = 1, ease = "inOutCubic", set = function(v)
    place(x0 + (x1 - x0) * v, w0 + (w1 - w0) * v)
  end })
end

function ns.RefreshDashboard(animate)
  if not frame or not frame:IsShown() then return end
  local chars = ns.VisibleChars()
  local total, tasks = 0, 0
  for _, c in ipairs(chars) do
    total = total + (c.money or 0)
    tasks = tasks + #ns.GetTasks(c)
  end
  frame.cards[1]:Set(tostring(#chars))
  frame.cards[2]:Set(ns.Money(total, true))
  local reset = ns.NextWeeklyReset()
  frame.cards[3]:Set(reset and ns.FormatTime(reset - time()) or "-")
  frame.cards[4]:Set((tasks > 0 and S.Hex(C.goldHi) or S.Hex(C.good)) .. tasks .. "|r")

  frame.realmOnly:SetChecked(ns.db.currentRealmOnly)
  frame.minimap:SetChecked(not ns.db.hideMinimap)
  frame.miniCheck:SetChecked(ns.db.miniShown)

  local changed = frame.shownTab ~= ns.db.tab
  for _, tab in ipairs(frame.tabs) do
    local active = tab.page.key == ns.db.tab
    tab:SetActive(active)
    if active then
      frame.pageTitle:SetText(L[tab.page.label])
      if not tab.frame then tab.frame = tab.page.build(frame.pageArea) end
      tab.page.refresh(tab.frame)
      if changed or animate then
        showPage(tab, true)
        moveMarker(tab, frame.shownTab == nil)
        frame.shownTab = ns.db.tab
      end
    elseif tab.frame then
      tab.frame:Hide()
    end
  end
end

-- Window -----------------------------------------------------------------
local TAB_ICONS = {
  overview = "INV_Misc_Book_11", reps = "Ability_Warrior_BattleShout", weekly = "INV_Misc_Note_01",
  search = "INV_Misc_Bag_08", gold = "INV_Misc_Coin_01",
}

local function createTab(parent, page)
  local tab = CreateFrame("Button", nil, parent)
  tab.page = page
  tab:SetHeight(32)
  tab.icon = tab:CreateTexture(nil, "ARTWORK")
  tab.icon:SetSize(16, 16)
  tab.icon:SetPoint("LEFT", 10, 0)
  tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  tab.icon:SetTexture(icon(TAB_ICONS[page.key] or "INV_Misc_QuestionMark"))
  tab.label = S.Text(tab, 13, "muted")
  tab.label:SetPoint("LEFT", tab.icon, "RIGHT", 7, 0)
  tab.label:SetText(L[page.label])
  tab:SetWidth(tab.label:GetStringWidth() + 44)
  local hl = tab:CreateTexture(nil, "BACKGROUND")
  hl:SetPoint("TOPLEFT", 0, -3)
  hl:SetPoint("BOTTOMRIGHT", 0, 2)
  S.Gradient(hl, { C.accent[1], C.accent[2], C.accent[3], 0 }, { C.accent[1], C.accent[2], C.accent[3], 0.12 })
  S.HoverFade(tab, hl)
  function tab:SetActive(on)
    self.active = on
    self.label:SetTextColor(S.Color(on and C.gold or C.muted))
    self.icon:SetDesaturated(not on)
    self.icon:SetAlpha(on and 1 or 0.7)
  end
  tab:HookScript("OnEnter", function(self)
    if not self.active then self.label:SetTextColor(S.Color(C.text)); self.icon:SetAlpha(1) end
  end)
  tab:HookScript("OnLeave", function(self)
    if not self.active then self.label:SetTextColor(S.Color(C.muted)); self.icon:SetAlpha(0.7) end
  end)
  tab:SetScript("OnClick", function()
    if ns.db.tab == page.key then return end
    ns.db.tab = page.key
    ns.RefreshDashboard()
  end)
  return tab
end

local function create()
  local f = S.Window("AltDashboardForeverFrame", UIParent, WIDTH, HEIGHT, 14)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  tinsert(UISpecialFrames, f:GetName()) -- close with Escape

  -- title bar (drag handle)
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(48)
  S.Draggable(f, bar)

  local logo = S.Icon(bar, 32, ns.ADDON_ICON)
  logo.tex:SetTexCoord(0, 1, 0, 1)
  logo:SetPoint("LEFT", 14, -1)
  logo:SetBorderColor(S.Color(C.gold, 0.7))
  local title = S.Text(bar, 17, "gold")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 11, 0)
  title:SetText("Alt Dashboard")
  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  local sub = S.Text(bar, 10, "muted")
  sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 11, 1)
  sub:SetText(S.Hex(C.accent) .. "FOREVER|r   v" .. (getMeta(ADDON, "Version") or "?"))

  f.close = S.CloseButton(f, function() S.Close(f) end)
  f.close:SetPoint("TOPRIGHT", -12, -13)
  f.close:SetFrameLevel(bar:GetFrameLevel() + 5)

  -- search box (top right): opens the Search tab
  local search = S.EditBox(f, 240, 24, L["Search items, recipes"])
  search:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
  search:SetFrameLevel(bar:GetFrameLevel() + 5)
  search:HookScript("OnTextChanged", function(self, user)
    if not user then return end
    ns.db.tab = "search"
    ns.RefreshDashboard()
    if ns.SetSearchText then ns.SetSearchText(self:GetText()) end
  end)

  local rule = S.Rule(f, C.ring, 0.5)
  rule:SetPoint("TOPLEFT", 16, -49)
  rule:SetPoint("TOPRIGHT", -16, -49)

  -- tabs + sliding marker
  f.tabBar = CreateFrame("Frame", nil, f)
  f.tabBar:SetPoint("TOPLEFT", 24, -54)
  f.tabBar:SetPoint("TOPRIGHT", -24, -54)
  f.tabBar:SetHeight(34)
  local base = f.tabBar:CreateTexture(nil, "BACKGROUND")
  base:SetPoint("BOTTOMLEFT"); base:SetPoint("BOTTOMRIGHT"); base:SetHeight(1)
  base:SetColorTexture(S.Color(C.trim))
  f.marker = CreateFrame("Frame", nil, f.tabBar)
  f.marker:SetHeight(2)
  local mline = f.marker:CreateTexture(nil, "OVERLAY")
  mline:SetAllPoints()
  S.Gradient(mline, { C.accent[1], C.accent[2], C.accent[3], 0.3 }, C.accent, true)
  local mglow = f.marker:CreateTexture(nil, "ARTWORK")
  mglow:SetTexture(S.MEDIA .. "Glow")
  mglow:SetBlendMode("ADD")
  mglow:SetPoint("BOTTOMLEFT", 0, -6)
  mglow:SetPoint("TOPRIGHT", 0, 8)
  mglow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.35)

  f.tabs = {}
  local x = 0
  for _, page in ipairs(ns.PAGES) do
    local tab = createTab(f.tabBar, page)
    tab:SetPoint("BOTTOMLEFT", x, 0)
    tab.x = x
    x = x + tab:GetWidth() + 4
    f.tabs[#f.tabs + 1] = tab
  end

  -- summary cards
  local cw = (WIDTH - 60 - 3 * 12) / 4
  f.cards = {
    card(f, "INV_Misc_Head_Human_01", L["Characters"]),
    card(f, "INV_Misc_Coin_02", L["Total gold"]),
    card(f, "INV_Misc_PocketWatch_01", L["Weekly reset"]),
    card(f, "INV_Scroll_03", L["Tasks this week"]),
  }
  for i, cd in ipairs(f.cards) do
    cd:SetPoint("TOPLEFT", 30 + (i - 1) * (cw + 12), -100)
    cd:SetWidth(cw)
  end

  -- page title + realm filter
  f.pageTitle = S.Text(f, 16, "gold")
  f.pageTitle:SetPoint("TOPLEFT", 32, -170)
  f.realmOnly = UI.Check(f, L["Current realm only"], function(self)
    ns.db.currentRealmOnly = self:GetChecked() or nil
    ns.RefreshAll()
  end)
  f.realmOnly:SetPoint("TOPRIGHT", -40 - f.realmOnly.text:GetStringWidth(), -170)

  f.pageArea = CreateFrame("Frame", nil, f)
  f.pageArea:SetPoint("TOPLEFT", 30, -196)
  f.pageArea:SetPoint("BOTTOMRIGHT", -30, 52)

  -- footer: options, language, refresh
  local foot = S.Rule(f, C.ring, 0.35)
  foot:SetPoint("BOTTOMLEFT", 16, 44)
  foot:SetPoint("BOTTOMRIGHT", -16, 44)

  f.minimap = UI.Check(f, L["Minimap button"], function(self)
    ns.db.hideMinimap = not self:GetChecked() or nil
    ns.UpdateMinimapButton()
  end)
  f.minimap:SetPoint("BOTTOMLEFT", 32, 16)
  f.miniCheck = UI.Check(f, L["Compact window"], function(self) ns.SetMiniShown(self:GetChecked()) end)
  f.miniCheck:SetPoint("LEFT", f.minimap.text, "RIGHT", 24, 0)

  -- item tooltip options, in a small menu (alts that own the item, quest of the item)
  local tips = S.Button(f, L["Tooltips"], 120, 22)
  tips:SetPoint("LEFT", f.miniCheck.text, "RIGHT", 24, 0)
  tips.text:ClearAllPoints()
  tips.text:SetPoint("LEFT", 9, 0)
  local chev = S.Chevron(tips, 8, C.gold)
  chev:SetPoint("RIGHT", -9, 0)
  chev:Point("up")
  tips:SetScript("OnClick", function(self)
    local function toggle(key) return function() ns.db[key] = not ns.db[key] or nil end end
    S.Menu({
      { text = L["Tooltips"], title = true },
      { text = L["Alts in item tooltips"], checked = not ns.db.noItemTooltip, func = toggle("noItemTooltip") },
      { text = L["Quest of the item in tooltips"], checked = not ns.db.noQuestTooltip, func = toggle("noQuestTooltip") },
    }, self, 200)
  end)

  local refresh = UI.Button(f, L["Refresh"], 110, function() ns.ScanAll() end, true)
  refresh:SetPoint("BOTTOMRIGHT", -30, 12)

  local langOptions = {}
  for _, o in ipairs(LANGUAGES) do langOptions[#langOptions + 1] = { o[1], L[o[2]] } end
  local lang = S.Dropdown(f, langOptions, 200, function() return ns.db.lang or "auto" end, function(value)
    if (ns.db.lang or "auto") == value then return end
    S.Dialog({
      text = L["The interface will be reloaded to apply the language."],
      onAccept = function() ns.db.lang = value; ReloadUI() end,
    })
  end)
  lang:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
  local langLabel = S.Text(f, 11, "muted")
  langLabel:SetPoint("RIGHT", lang, "LEFT", -8, 0)
  langLabel:SetText(L["Language"])

  -- timers tick while the window is open
  local elapsed = 0
  f:SetScript("OnUpdate", function(_, e)
    elapsed = elapsed + e
    if elapsed > 30 then elapsed = 0; ns.RefreshDashboard() end
  end)
  -- opening: cards rise one after the other, the page fades in
  f:HookScript("OnShow", function()
    for i, cd in ipairs(f.cards) do
      cd:SetAlpha(0)
      S.Tween(cd, { dur = 0.35, delay = 0.05 + i * 0.05, from = 0, to = 1, set = function(v) cd:SetAlpha(v) end })
    end
    ns.RefreshDashboard(true)
  end)
  f:Hide()
  return f
end

function ns.ToggleDashboard(tab)
  frame = frame or create()
  if tab then
    ns.db.tab = tab
    if frame:IsShown() then ns.RefreshDashboard() else frame:Show() end
  elseif frame:IsShown() then
    S.Close(frame)
  else
    frame:Show()
  end
end
