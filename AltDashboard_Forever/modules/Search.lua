-- Alt Dashboard (Forever): Search tab (items in bags/bank of every alt, and who can craft what)
local _, ns = ...
local L = ns.L
local UI = ns.UI

local page = { key = "search", label = "Search" }
local ROW_H = 34

local itemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon or function() end

local function ownersText(r)
  local parts = {}
  for _, o in ipairs(r.owners) do
    local where = o.bank > 0 and o.bags > 0 and (" |cff999999(" .. L["bags %d, bank %d"]:format(o.bags, o.bank) .. ")|r")
      or o.bank > 0 and (" |cff999999(" .. L["bank"] .. ")|r") or ""
    parts[#parts + 1] = ns.ColoredName(o.char) .. " |cffffffff" .. (o.bags + o.bank) .. "|r" .. where
  end
  return table.concat(parts, ",  ")
end

local function createRow(p, i)
  local row = UI.RowBase(p.content, UI.CONTENT_W, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row.iconFrame = ns.Skin.Icon(row, 26)
  row.iconFrame:SetPoint("LEFT", 8, 0)
  row.icon = row.iconFrame.tex
  row.name = UI.Text(row, "GameFontNormal", "TOPLEFT", 40, -3, 330)
  row.sub = UI.Text(row, "GameFontHighlightSmall", "BOTTOMLEFT", 40, 3, 330)
  UI.Ink(row.sub)
  row.owners = UI.Text(row, "GameFontHighlightSmall", "LEFT", 380, 0, UI.CONTENT_W - 390)
  row:HookScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. self.itemID)
    GameTooltip:Show()
  end)
  row:HookScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    if self.itemID and IsModifiedClick("CHATLINK") then
      local _, link = ns.GetItemInfo(self.itemID)
      if link then ChatEdit_InsertLink(link) end
    end
  end)
  return row
end

function page.build(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()

  local label = UI.Text(p, "GameFontNormal", "TOPLEFT", 4, -4)
  label:SetText(L["Find an item or a recipe:"])
  UI.Ink(label)
  p.box = UI.EditBox(p, 320, L["Search items, recipes"])
  p.box:SetPoint("LEFT", label, "RIGHT", 14, 0)
  p.box:HookScript("OnTextChanged", function() page.refresh(p) end)
  p.count = UI.Text(p, "GameFontHighlightSmall", "TOPRIGHT", -6, -6)
  p.count:SetJustifyH("RIGHT")
  UI.Ink(p.count)
  -- the search box of the window title bar writes here
  function ns.SetSearchText(text)
    p.box:SetText(text or "")
    page.refresh(p)
  end

  local box = UI.ListBox(p)
  box:SetPoint("TOPLEFT", 0, -26)
  box:SetPoint("BOTTOMRIGHT")
  local _, content = UI.Scroll(box, 0)
  p.content = content
  p.rows = {}

  p.hint = ns.Skin.Text(box, 13, "muted")
  p.hint:SetJustifyH("CENTER")
  p.hint:SetPoint("CENTER")
  p.hint:SetWidth(UI.CONTENT_W - 100)
  return p
end

function page.refresh(p)
  local text = p.box:GetText() or ""
  local items, recipes = ns.SearchItems(text), ns.SearchRecipes(text)
  local i = 0
  local function nextRow()
    i = i + 1
    local row = p.rows[i] or createRow(p, i)
    p.rows[i] = row
    UI.Stripe(row, i)
    row:Show()
    return row
  end

  for _, r in ipairs(items) do
    local row = nextRow()
    row.itemID = r.id
    row.icon:SetTexture(itemIcon(r.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[r.quality or 1]
    row.name:SetText((col and col.hex or "|cffffffff") .. r.name .. "|r")
    row.sub:SetText(L["Total: %d"]:format(r.total))
    row.owners:SetText(ownersText(r))
  end
  for _, r in ipairs(recipes) do
    local row = nextRow()
    row.itemID = nil
    row.icon:SetTexture(UI.Icon(ns.PROFESSIONS[r.prof] or ns.SECONDARY[r.prof] or "INV_Scroll_03"))
    row.name:SetText("|cff71d5ff" .. r.recipe .. "|r")
    row.sub:SetText(r.prof)
    row.owners:SetText(L["Can craft it:"] .. " " .. ns.ColoredName(r.char))
  end
  for k = i + 1, #p.rows do p.rows[k]:Hide() end
  p.content:SetHeight(math.max(i * ROW_H, 1))

  if #text < 2 then
    p.hint:SetText(L["Type at least 2 letters. Bags and gear are recorded at login, the bank when you open it, recipes when you open a profession window."])
  else
    p.hint:SetText(i == 0 and L["Nothing found."] or "")
  end
  p.count:SetText(#text >= 2 and L["%d items, %d recipes"]:format(#items, #recipes) or "")
end

function page.animate(p) UI.Cascade(p.rows, #p.rows) end

table.insert(ns.PAGES, page)
