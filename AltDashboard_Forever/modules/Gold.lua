-- Alt Dashboard (Forever): Gold tab (gold and played time per character, total gold history)
local _, ns = ...
local L = ns.L
local UI = ns.UI
local S = ns.Skin
local C = S.C

local page = { key = "gold", label = "Gold" }
local ROW_H, DAYS = 30, 30
local LIST_W = 530
local GRAPH_H = 170
local BAR_W = 150

local function createRow(p, i)
  local row = UI.RowBase(p.content, LIST_W - 24, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row.name = UI.Text(row, "GameFontHighlightSmall", "LEFT", 10, 0, 150)
  row.bar = S.Bar(row, BAR_W, 6, "gold")
  row.bar:SetPoint("LEFT", 165, 0)
  row.gold = UI.Text(row, "GameFontHighlightSmall", "LEFT", 326, 0, 100)
  row.played = UI.Text(row, "GameFontHighlightSmall", "LEFT", 430, 0, 70)
  UI.Ink(row.played)
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
  local head = UI.HeaderBar(box, LIST_W - 12, 24)
  local function h(textKey, x)
    local t = S.Text(head, 11, "muted")
    t:SetPoint("LEFT", x, 0)
    t:SetText(L[textKey])
  end
  h("Character", 10); h("Gold", 326); h("Played", 430)
  local _, content = UI.Scroll(box, 24, LIST_W - 24)
  p.content = content
  p.rows = {}

  -- totals
  local side = UI.ListBox(p)
  side:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, 0)
  side:SetPoint("BOTTOMRIGHT")
  local shead = UI.HeaderBar(side, 1, 24)
  shead:SetPoint("TOPRIGHT", -6, -5)
  local acc = S.Text(shead, 11, "muted")
  acc:SetPoint("LEFT", 10, 0)
  acc:SetText(L["Account"])
  p.totals = {}
  for i = 1, 5 do
    local l = S.Text(side, 12, "muted")
    l:SetPoint("TOPLEFT", 16, -42 - (i - 1) * 24)
    local r = S.Text(side, 13, "text")
    r:SetPoint("TOPRIGHT", -16, -42 - (i - 1) * 24)
    r:SetJustifyH("RIGHT")
    p.totals[i] = { l, r }
  end

  -- history graph (total gold per day)
  local gtitle = S.Text(side, 11, "gold")
  gtitle:SetPoint("BOTTOMLEFT", 16, GRAPH_H + 24)
  gtitle:SetText(L["Total gold, last %d days"]:format(DAYS))
  p.graph = CreateFrame("Frame", nil, side)
  p.graph:SetPoint("BOTTOMLEFT", 16, 16)
  p.graph:SetPoint("BOTTOMRIGHT", -16, 16)
  p.graph:SetHeight(GRAPH_H)
  S.Box(p.graph, { 0, 0, 0, 0.3 }, C.trim)
  -- faint guide lines
  for k = 1, 3 do
    local g = p.graph:CreateTexture(nil, "BORDER")
    g:SetHeight(1)
    g:SetPoint("BOTTOMLEFT", 1, (GRAPH_H - 14) * k / 4)
    g:SetPoint("BOTTOMRIGHT", -1, (GRAPH_H - 14) * k / 4)
    g:SetColorTexture(1, 1, 1, 0.04)
  end
  p.graphMax = S.Text(p.graph, 10, "muted")
  p.graphMax:SetPoint("TOPLEFT", 4, -3)
  p.bars = {}
  for i = 1, DAYS do
    local b = CreateFrame("Frame", nil, p.graph)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("BOTTOMLEFT", 0, 1)
    b.tex:SetPoint("BOTTOMRIGHT", 0, 1)
    S.Gradient(b.tex, C.gold1, C.gold2)
    b.tex:SetAlpha(0.85)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
      self.tex:SetAlpha(1)
      if not self.day then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self.day)
      GameTooltip:AddLine(self.value and ns.Money(self.value, true) or L["No data"], 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.85); GameTooltip:Hide() end)
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
    row:Show()
    row.name:SetText(ns.ColoredName(c))
    row.bar:SetValue((c.money or 0) / richest)
    row.gold:SetText(ns.Money(c.money, true))
    row.played:SetText(c.played and ns.FormatPlayed(c.played) or "-")
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
    { L["Grand total"], S.Hex(C.goldHi) .. ns.Money(total + mail + ah, true) .. "|r" },
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
    b.h = math.max(1, (GRAPH_H - 16) * (v.value or 0) / top)
    b.tex:SetHeight(b.h)
    b.tex:SetShown(v.value ~= nil)
  end
  p.graphMax:SetText(ns.Money(top, true))
end

-- bars grow from the left / from the floor when the tab is shown
function page.animate(p)
  UI.Cascade(p.rows, #p.rows)
  for i, row in ipairs(p.rows) do
    if row:IsShown() then row.bar:Replay(0.1 + i * 0.03) end
  end
  for i, b in ipairs(p.bars) do
    local h = b.h or 1
    b.tex:SetHeight(0.01)
    S.Tween(b.tex, { dur = 0.5, delay = 0.15 + i * 0.015, from = 0.01, to = h,
      set = function(v) b.tex:SetHeight(math.max(0.01, v)) end })
  end
end

table.insert(ns.PAGES, page)
