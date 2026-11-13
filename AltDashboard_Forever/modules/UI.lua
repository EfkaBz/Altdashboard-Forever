-- Alt Dashboard (Forever): shared widgets (panels, scroll, rows, character grid) on the custom skin
local _, ns = ...
local L = ns.L
local S = ns.Skin
local C = S.C

local UI = {}
ns.UI = UI
ns.PAGES = {} -- tabs, filled by the page modules: { key, label, build(parent) -> page, refresh(page) }

UI.WIDTH, UI.HEIGHT = 1000, 700
UI.CONTENT_W = UI.WIDTH - 60 - 24 -- page area minus the panel insets and the scroll bar

-- old parchment helper: text is light on the dark theme now, kept for the page modules
function UI.Ink(fs)
  fs:SetTextColor(S.Color(C.muted))
  return fs
end

function UI.Icon(name) return "Interface\\Icons\\" .. name end

function UI.StandingText(standing)
  local col = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing] or { r = 1, g = 1, b = 1 }
  return ("|cff%02x%02x%02x%s|r"):format(col.r * 255, col.g * 255, col.b * 255, _G["FACTION_STANDING_LABEL" .. standing] or "?")
end

function UI.GoldLine(parent, anchor, alpha)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", anchor)
  line:SetPoint("BOTTOMRIGHT", anchor)
  line:SetColorTexture(C.trim[1], C.trim[2], C.trim[3], alpha or 0.8)
  return line
end

function UI.Button(parent, label, width, onClick, primary)
  return S.Button(parent, label, width or 130, 24, onClick, primary)
end

function UI.Check(parent, label, onClick)
  local c = S.Check(parent, label, 16)
  if onClick then c:SetScript("OnClick", onClick) end
  return c
end

function UI.EditBox(parent, width, placeholder)
  return S.EditBox(parent, width, 22, placeholder)
end

-- the old game font names, mapped to the skin's sizes and colors
local FONTS = {
  GameFontNormal = { 13, "gold" }, GameFontNormalSmall = { 11, "gold" }, GameFontNormalLarge = { 15, "gold" },
  GameFontHighlight = { 13, "text" }, GameFontHighlightSmall = { 11, "text" }, GameFontHighlightLarge = { 16, "text" },
  GameFontDisable = { 13, "dim" }, GameFontDisableSmall = { 11, "dim" }, GameFontGreenSmall = { 11, "good" },
  QuestFont_Huge = { 17, "gold" },
}
function UI.Text(parent, font, point, x, y, width)
  local f = FONTS[font] or { 12, "text" }
  local fs = S.Text(parent, f[1], f[2])
  fs:SetPoint(point, x or 0, y or 0)
  fs:SetWordWrap(false)
  if width then fs:SetWidth(width) end
  return fs
end

function UI.ListBox(parent)
  return S.Panel(parent, 8)
end

-- scroll frame inside a panel, below an optional header of headH pixels
function UI.Scroll(box, headH, width)
  local scroll, content = S.Scroll(box)
  scroll:SetPoint("TOPLEFT", 6, -6 - (headH or 0))
  scroll:SetPoint("BOTTOMRIGHT", -14, 6)
  content:SetSize(width or UI.CONTENT_W, 1)
  return scroll, content
end

-- column header strip at the top of a panel
function UI.HeaderBar(box, width, height)
  local bar = CreateFrame("Frame", nil, box)
  bar:SetPoint("TOPLEFT", 6, -5)
  bar:SetSize(width or UI.CONTENT_W, height)
  local bg = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
  bg:SetAllPoints()
  S.Gradient(bg, { C.head[1], C.head[2], C.head[3], 0.9 }, { C.head[1], C.head[2], C.head[3], 0.4 })
  local rule = S.Rule(bar, C.ring, 0.7)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  return bar
end

function UI.RowBase(parent, width, height)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, height)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.mark = row:CreateTexture(nil, "BORDER")
  row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(2)
  row.mark:SetColorTexture(S.Color(C.gold))
  row.mark:Hide()
  row.hl = S.RowHighlight(row)
  local line = row:CreateTexture(nil, "BORDER")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
  line:SetColorTexture(1, 1, 1, 0.035)
  return row
end

-- zebra stripes; the logged-in character gets a faint blue band and a gold mark
function UI.Stripe(row, index, current)
  if current then row.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
  elseif index % 2 == 0 then row.bg:SetColorTexture(1, 1, 1, 0.022)
  else row.bg:SetColorTexture(0, 0, 0, 0) end
  if row.mark then row.mark:SetShown(current == true) end
end

-- rows slide in one after the other when a page is shown
function UI.Cascade(rows, count)
  for i = 1, math.min(count, 18) do
    local row = rows[i]
    if row and row:IsShown() then
      row:SetAlpha(0)
      S.Tween(row, { dur = 0.22, delay = (i - 1) * 0.025, from = 0, to = 1, set = function(v) row:SetAlpha(v) end })
    end
  end
end

-- Character grid: one line per entry, one column per character ----------------
-- opts: rows() -> { {label, icon?, cell(c) -> text, tip(c)?, click(c, button)?, labelTip()?, labelClick(button)?} }
local LABEL_W, COL_W, GRID_ROW_H, GRID_HEAD_H = 210, 96, 24, 36

function UI.Grid(parent, opts)
  local g = { opts = opts, offset = 0, rows = {} }
  local box = UI.ListBox(parent)
  box:SetPoint("TOPLEFT", 0, opts.top or 0)
  box:SetPoint("BOTTOMRIGHT", 0, opts.bottom or 0)
  g.box = box
  local cols = math.floor((UI.CONTENT_W - LABEL_W) / COL_W)
  g.cols = cols

  local head = UI.HeaderBar(box, UI.CONTENT_W, GRID_HEAD_H)
  g.headLabel = UI.Text(head, "GameFontNormal", "LEFT", 10, 0)
  g.headLabel:SetText(opts.title or "")
  g.heads = {}
  for i = 1, cols do
    local h = CreateFrame("Frame", nil, head)
    h:SetPoint("TOPLEFT", LABEL_W + (i - 1) * COL_W, 0)
    h:SetSize(COL_W, GRID_HEAD_H)
    h.name = S.Text(h, 12, "text")
    h.name:SetPoint("TOP", 0, -5)
    h.name:SetWidth(COL_W - 6)
    h.name:SetJustifyH("CENTER")
    h.name:SetWordWrap(false)
    h.level = S.Text(h, 10, "muted")
    h.level:SetPoint("BOTTOM", 0, 5)
    g.heads[i] = h
  end
  -- pager when there are more characters than columns
  local function pager(dir, x)
    local b = S.ArrowButton(head, dir < 0 and "left" or "right", function()
      g.offset = math.max(0, g.offset + dir * cols)
      g:Refresh()
      UI.Cascade(g.rows, #g.rows)
    end)
    b:SetPoint("LEFT", x, 0)
    return b
  end
  g.prev = pager(-1, LABEL_W - 52)
  g.next = pager(1, LABEL_W - 28)

  local _, content = UI.Scroll(box, GRID_HEAD_H)
  g.content = content

  function g:Row(i)
    local row = self.rows[i]
    if row then return row end
    row = UI.RowBase(content, UI.CONTENT_W, GRID_ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * GRID_ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label = UI.Text(row, "GameFontHighlightSmall", "LEFT", 32, 0, LABEL_W - 38)
    row:SetScript("OnClick", function(r, button) if r.entry.labelClick then r.entry.labelClick(button) end end)
    row:HookScript("OnEnter", function(r)
      if not r.entry.labelTip then return end
      GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
      r.entry.labelTip()
      GameTooltip:Show()
    end)
    row:HookScript("OnLeave", function() GameTooltip:Hide() end)
    row.cells = {}
    for k = 1, cols do
      local cell = CreateFrame("Button", nil, row)
      cell:SetPoint("TOPLEFT", LABEL_W + (k - 1) * COL_W, 0)
      cell:SetSize(COL_W, GRID_ROW_H)
      cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      cell.text = S.Text(cell, 11, "text")
      cell.text:SetPoint("CENTER")
      cell.text:SetWidth(COL_W - 6)
      cell.text:SetJustifyH("CENTER")
      cell.text:SetWordWrap(false)
      local hl = cell:CreateTexture(nil, "BACKGROUND", nil, 2)
      hl:SetPoint("TOPLEFT", 2, -2)
      hl:SetPoint("BOTTOMRIGHT", -2, 2)
      hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
      S.HoverFade(cell, hl)
      cell:SetScript("OnClick", function(b, button)
        if row.entry.click and b.char then row.entry.click(b.char, button) end
      end)
      cell:HookScript("OnEnter", function(b)
        if not row.entry.tip or not b.char then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        row.entry.tip(b.char)
        GameTooltip:Show()
      end)
      cell:HookScript("OnLeave", function() GameTooltip:Hide() end)
      row.cells[k] = cell
    end
    self.rows[i] = row
    return row
  end

  function g:Refresh()
    local chars = ns.VisibleChars()
    if self.offset >= #chars then self.offset = 0 end
    self.prev:SetEnabled(self.offset > 0)
    self.next:SetEnabled(self.offset + cols < #chars)
    self.prev:SetShown(#chars > cols)
    self.next:SetShown(#chars > cols)
    local shown = {}
    for i = 1, cols do
      local c = chars[self.offset + i]
      shown[i] = c
      local h = self.heads[i]
      h:SetShown(c ~= nil)
      if c then
        h.name:SetText(ns.ColoredName(c))
        h.level:SetText((LEVEL or "Level") .. " " .. (c.level or "?"))
      end
    end
    local entries = self.opts.rows()
    for i, e in ipairs(entries) do
      local row = self:Row(i)
      row.entry = e
      UI.Stripe(row, i, e.highlight)
      row.icon:SetShown(e.icon ~= nil)
      if e.icon then row.icon:SetTexture(e.icon) end
      row.label:SetText(e.label)
      for k, cell in ipairs(row.cells) do
        local c = shown[k]
        cell.char = c
        cell:SetShown(c ~= nil)
        if c then cell.text:SetText(e.cell(c) or "") end
      end
      row:Show()
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
    content:SetHeight(math.max(#entries * GRID_ROW_H, 1))
    if self.empty then self.empty:SetShown(#entries == 0) end
  end

  function g:Cascade() UI.Cascade(self.rows, #self.rows) end

  if opts.emptyText then
    g.empty = S.Text(box, 13, "muted")
    g.empty:SetPoint("CENTER", 0, 0)
    g.empty:SetWidth(UI.CONTENT_W - 80)
    g.empty:SetJustifyH("CENTER")
    g.empty:SetText(opts.emptyText)
  end
  return g
end
