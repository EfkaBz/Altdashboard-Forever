-- Alt Dashboard (Forever): Gold tab (gold and played time per character, total gold history)
local _, ns = ...
local L = ns.L
local UI = ns.UI

local page = { key = "gold", label = "Gold" }
local ROW_H, DAYS = 28, 30
local LIST_W = 520
local GRAPH_H = 150

local function createRow(p, i)
  local row = UI.RowBase(p.content, LIST_W - 34, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row.name = UI.Text(row, "GameFontNormalSmall", "LEFT", 8, 0, 150)
  row.barBg = row:CreateTexture(nil, "BORDER")
  row.barBg:SetPoint("LEFT", 160, 0)
  row.barBg:SetSize(150, 10)
  row.barBg:SetColorTexture(0, 0, 0, 0.6)
  row.bar = row:CreateTexture(nil, "ARTWORK")
  row.bar:SetPoint("LEFT", row.barBg)
  row.bar:SetHeight(10)
  row.bar:SetColorTexture(0.85, 0.65, 0.1, 0.9)
  row.gold = UI.Text(row, "GameFontHighlightSmall", "LEFT", 318, 0, 100)
  row.played = UI.Text(row, "GameFontHighlightSmall", "LEFT", 420, 0, 70)
  row.played:SetTextColor(0.7, 0.7, 0.7)
  return row
end

function page.build(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()

  -- per character list
  local box = UI.ListBox(p)
  box:SetPoint("TOPLEFT")
  box:SetPoint("BOTTOMLEFT")
  box:SetWidth(LIST_W)
  local head = UI.HeaderBar(box, LIST_W - 12, 22)
  local function h(textKey, x)
    local t = UI.Text(head, "GameFontNormalSmall", "LEFT", x, 0)
    t:SetText(L[textKey])
  end
  h("Character", 8); h("Gold", 318); h("Played", 420)
  local _, content = UI.Scroll(box, 22, LIST_W - 34)
  p.content = content
  p.rows = {}

  -- totals
  local side = UI.ListBox(p)
  side:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
  side:SetPoint("BOTTOMRIGHT")
  local shead = UI.HeaderBar(side, UI.CONTENT_W - LIST_W - 20, 22)
  UI.Text(shead, "GameFontNormalSmall", "LEFT", 8, 0):SetText(L["Account"])
  p.totals = {}
  for i = 1, 5 do
    local l = UI.Text(side, "GameFontHighlight", "TOPLEFT", 14, -34 - (i - 1) * 22)
    local r = side:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r:SetPoint("TOPRIGHT", -14, -34 - (i - 1) * 22)
    p.totals[i] = { l, r }
  end

  -- history graph (total gold per day)
  local gtitle = UI.Text(side, "GameFontNormalSmall", "BOTTOMLEFT", 14, GRAPH_H + 20)
  gtitle:SetText(L["Total gold, last %d days"]:format(DAYS))
  p.graph = CreateFrame("Frame", nil, side)
  p.graph:SetPoint("BOTTOMLEFT", 14, 14)
  p.graph:SetPoint("BOTTOMRIGHT", -14, 14)
  p.graph:SetHeight(GRAPH_H)
  local gbg = p.graph:CreateTexture(nil, "BACKGROUND")
  gbg:SetAllPoints()
  gbg:SetColorTexture(0, 0, 0, 0.35)
  p.graphMax = UI.Text(p.graph, "GameFontDisableSmall", "TOPLEFT", 3, -2)
  p.bars = {}
  for i = 1, DAYS do
    local b = CreateFrame("Frame", nil, p.graph)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("BOTTOMLEFT")
    b.tex:SetPoint("BOTTOMRIGHT")
    b.tex:SetColorTexture(0.85, 0.65, 0.1, 0.9)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
      if not self.day then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self.day)
      GameTooltip:AddLine(self.value and ns.Money(self.value, true) or L["No data"], 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.bars[i] = b
  end
  return p
end

function page.refresh(p)
  local chars = ns.VisibleChars()
  table.sort(chars, function(a, b) return (a.money or 0) > (b.money or 0) end)
  local richest = math.max(1, chars[1] and chars[1].money or 1)
  local total, played, mail, ah = 0, 0, 0, 0
  for i, c in ipairs(chars) do
    local row = p.rows[i] or createRow(p, i)
    p.rows[i] = row
    UI.Stripe(row, i, c.key == ns.me)
    row.name:SetText(ns.ColoredName(c))
    row.bar:SetWidth(math.max(1, 150 * (c.money or 0) / richest))
    row.gold:SetText(ns.Money(c.money, true))
    row.played:SetText(c.played and ns.FormatPlayed(c.played) or "-")
    row:Show()
    total = total + (c.money or 0)
    played = played + (c.played or 0)
    mail = mail + (c.mail and c.mail.money or 0)
    ah = ah + (c.auctions and c.auctions.value or 0)
  end
  for i = #chars + 1, #p.rows do p.rows[i]:Hide() end
  p.content:SetHeight(math.max(#chars * ROW_H, 1))

  local lines = {
    { L["Gold on characters"], ns.Money(total, true) },
    { L["In the mailbox"], ns.Money(mail, true) },
    { L["At the auction house"], ns.Money(ah, true) },
    { L["Grand total"], "|cffffd100" .. ns.Money(total + mail + ah, true) .. "|r" },
    { L["Total played"], ns.FormatPlayed(played) },
  }
  for i, t in ipairs(p.totals) do
    t[1]:SetText(lines[i][1])
    t[2]:SetText(lines[i][2])
  end

  -- history: one bar per day, oldest on the left
  local values, top = {}, 1
  for i = 1, DAYS do
    local day = date("%Y-%m-%d", time() - (DAYS - i) * 86400)
    values[i] = { day = day, value = ns.db.goldHistory[day] }
    top = math.max(top, values[i].value or 0)
  end
  local w = p.graph:GetWidth()
  if w <= 0 then w = UI.CONTENT_W - LIST_W - 50 end
  local bw = w / DAYS
  for i, b in ipairs(p.bars) do
    local v = values[i]
    b.day, b.value = v.day, v.value
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", (i - 1) * bw + 1, 0)
    b:SetSize(math.max(1, bw - 2), GRAPH_H)
    b.tex:SetHeight(math.max(1, (GRAPH_H - 14) * (v.value or 0) / top))
    b.tex:SetShown(v.value ~= nil)
  end
  p.graphMax:SetText(ns.Money(top, true))
end

table.insert(ns.PAGES, page)
