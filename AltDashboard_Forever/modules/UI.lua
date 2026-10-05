-- Alt Dashboard (Forever): shared widgets (list box, scroll, buttons, character grid)
local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI
ns.PAGES = {} -- tabs, filled by the page modules: { key, label, build(parent) -> page, refresh(page) }

UI.WIDTH, UI.HEIGHT = 990, 660
UI.CONTENT_W = UI.WIDTH - 60 - 34

-- dark brown ink for text written on the parchment
function UI.Ink(fs)
  fs:SetTextColor(0.1, 0.05, 0.01)
  fs:SetShadowOffset(0, 0)
  return fs
end

function UI.Icon(name) return "Interface\\Icons\\" .. name end

function UI.StandingText(standing, short)
  local col = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing] or { r = 1, g = 1, b = 1 }
  return ("|cff%02x%02x%02x%s|r"):format(col.r * 255, col.g * 255, col.b * 255, _G["FACTION_STANDING_LABEL" .. standing] or "?")
end

function UI.GoldLine(parent, anchor, alpha)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", anchor)
  line:SetPoint("BOTTOMRIGHT", anchor)
  line:SetColorTexture(1, 0.82, 0, alpha or 0.5)
  return line
end

function UI.Button(parent, label, width, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width or 130, 24)
  btn:SetText(label)
  btn:SetScript("OnClick", onClick)
  return btn
end

function UI.Check(parent, label, onClick, small)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.text = c:CreateFontString(nil, "OVERLAY", small and "GameFontHighlightSmall" or "GameFontHighlightSmall")
  c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
  c.text:SetText(label)
  UI.Ink(c.text)
  c:SetScript("OnClick", onClick)
  return c
end

function UI.EditBox(parent, width)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width, 20)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  return e
end

function UI.Text(parent, font, point, x, y, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint(point, x or 0, y or 0)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  if width then fs:SetWidth(width) end
  return fs
end

function UI.ListBox(parent)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(0.04, 0.03, 0.02, 0.9)
  box:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
  return box
end

-- scroll frame inside a list box, below an optional header of headH pixels
function UI.Scroll(box, headH, width)
  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6 - (headH or 0))
  scroll:SetPoint("BOTTOMRIGHT", -28, 6)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width or UI.CONTENT_W, 1)
  scroll:SetScrollChild(content)
  return scroll, content
end

function UI.HeaderBar(box, width, height)
  local bar = CreateFrame("Frame", nil, box)
  bar:SetPoint("TOPLEFT", 6, -5)
  bar:SetSize(width or UI.CONTENT_W, height)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.12)
  UI.GoldLine(bar, bar)
  return bar
end

function UI.RowBase(parent, width, height)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, height)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  UI.GoldLine(row, row, 0.15)
  return row
end

function UI.Stripe(row, index, current)
  if current then row.bg:SetColorTexture(1, 0.82, 0, 0.12)
  elseif index % 2 == 0 then row.bg:SetColorTexture(1, 1, 1, 0.03)
  else row.bg:SetColorTexture(0, 0, 0, 0) end
end

-- Character grid: one line per entry, one column per character ----------------
-- opts: rows() -> { {label, icon?, color?, cell(c) -> text, tip(c)?, click(c, button)?, labelTip()?, labelClick(button)?} }
local LABEL_W, COL_W, GRID_ROW_H, GRID_HEAD_H = 210, 96, 24, 34

function UI.Grid(parent, opts)
  local g = { opts = opts, offset = 0, rows = {} }
  local box = UI.ListBox(parent)
  box:SetPoint("TOPLEFT", 0, opts.top or 0)
  box:SetPoint("BOTTOMRIGHT", 0, opts.bottom or 0)
  g.box = box
  local cols = math.floor((UI.CONTENT_W - LABEL_W) / COL_W)
  g.cols = cols

  local head = UI.HeaderBar(box, UI.CONTENT_W, GRID_HEAD_H)
  g.headLabel = UI.Text(head, "GameFontNormalSmall", "LEFT", 8, 0)
  g.headLabel:SetText(opts.title or "")
  g.heads = {}
  for i = 1, cols do
    local h = CreateFrame("Frame", nil, head)
    h:SetPoint("TOPLEFT", LABEL_W + (i - 1) * COL_W, 0)
    h:SetSize(COL_W, GRID_HEAD_H)
    h.name = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.name:SetPoint("TOP", 0, -4)
    h.name:SetWidth(COL_W - 6)
    h.name:SetWordWrap(false)
    h.level = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h.level:SetPoint("BOTTOM", 0, 5)
    g.heads[i] = h
  end
  -- pager when there are more characters than columns
  local function pager(dir, x)
    local b = CreateFrame("Button", nil, head)
    b:SetSize(20, 20)
    b:SetPoint("LEFT", x, 0)
    local tex = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage"
    b:SetNormalTexture(tex .. "-Up")
    b:SetPushedTexture(tex .. "-Down")
    b:SetDisabledTexture(tex .. "-Disabled")
    b:SetScript("OnClick", function()
      g.offset = math.max(0, g.offset + dir * cols)
      g:Refresh()
    end)
    return b
  end
  g.prev = pager(-1, LABEL_W - 48)
  g.next = pager(1, LABEL_W - 26)

  local _, content = UI.Scroll(box, GRID_HEAD_H)
  g.content = content

  function g:Row(i)
    local row = self.rows[i]
    if row then return row end
    row = UI.RowBase(content, UI.CONTENT_W, GRID_ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * GRID_ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.label = UI.Text(row, "GameFontHighlightSmall", "LEFT", 30, 0, LABEL_W - 36)
    row:SetScript("OnClick", function(r, button) if r.entry.labelClick then r.entry.labelClick(button) end end)
    row:SetScript("OnEnter", function(r)
      if not r.entry.labelTip then return end
      GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
      r.entry.labelTip()
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.cells = {}
    for k = 1, cols do
      local cell = CreateFrame("Button", nil, row)
      cell:SetPoint("TOPLEFT", LABEL_W + (k - 1) * COL_W, 0)
      cell:SetSize(COL_W, GRID_ROW_H)
      cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cell.text:SetPoint("CENTER")
      cell.text:SetWidth(COL_W - 6)
      cell.text:SetWordWrap(false)
      local hl = cell:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.06)
      cell:SetScript("OnClick", function(b, button)
        if row.entry.click and b.char then row.entry.click(b.char, button) end
      end)
      cell:SetScript("OnEnter", function(b)
        if not row.entry.tip or not b.char then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        row.entry.tip(b.char)
        GameTooltip:Show()
      end)
      cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
        h.level:SetText(LEVEL and (LEVEL .. " " .. (c.level or "?")) or c.level)
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

  if opts.emptyText then
    g.empty = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    g.empty:SetPoint("CENTER", 0, 0)
    g.empty:SetWidth(UI.CONTENT_W - 80)
    g.empty:SetText(opts.emptyText)
  end
  return g
end
