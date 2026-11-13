-- Alt Dashboard (Forever): bags, bank, known recipes and the "your alts have it" item tooltip
local _, ns = ...
local L = ns.L

local BAGS = { 0, 1, 2, 3, 4 }
local BANK = { -1, 5, 6, 7, 8, 9, 10 }

local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

-- itemID, count, link of a bag slot (old and new container APIs)
local function slotItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount, info.hyperlink end
    return
  end
  local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
  local id = link and tonumber(link:match("item:(%d+)"))
  return id, count, link
end

-- remembers the name/quality of every item seen, for the search tab
local function remember(id, link)
  if ns.db.items[id] then return end
  local name, _, quality = ns.GetItemInfo(link or id)
  if name then ns.db.items[id] = { n = name, q = quality } end
end

local function scanContainers(list)
  local items = {}
  for _, bag in ipairs(list) do
    for slot = 1, numSlots(bag) or 0 do
      local id, count, link = slotItem(bag, slot)
      if id then
        items[id] = (items[id] or 0) + (count or 1)
        remember(id, link)
      end
    end
  end
  return items
end

-- the equipped gear counts as "bags" too
local function scanBags(c)
  local items = scanContainers(BAGS)
  for slot = 1, 19 do
    local id = GetInventoryItemID("player", slot)
    if id then
      items[id] = (items[id] or 0) + 1
      remember(id, GetInventoryItemLink("player", slot))
    end
  end
  c.bags = items
end

local function scanBank(c) c.bank = scanContainers(BANK) end

-- Recipes (trade skill window, and the craft window used by enchanting)
local function scanTradeSkill(c)
  local prof = GetTradeSkillLine and GetTradeSkillLine()
  if not prof or prof == "UNKNOWN" or not GetNumTradeSkills then return end
  local list = {}
  for i = 1, GetNumTradeSkills() do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" then list[#list + 1] = name end
  end
  if #list > 0 then
    c.recipes = c.recipes or {}
    c.recipes[prof] = list
  end
end

local function scanCraft(c)
  local prof = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
  if not prof or not GetNumCrafts then return end
  local list = {}
  for i = 1, GetNumCrafts() do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then list[#list + 1] = name end
  end
  if #list > 0 then
    c.recipes = c.recipes or {}
    c.recipes[prof] = list
  end
end

-- Search -----------------------------------------------------------------
-- { {id, name, quality, owners = { {char, bags, bank} }, total} }, sorted by name
function ns.SearchItems(text)
  text = (text or ""):lower()
  local results = {}
  if #text < 2 then return results end
  for id, info in pairs(ns.db.items) do
    if info.n:lower():find(text, 1, true) then
      local r = { id = id, name = info.n, quality = info.q, owners = {}, total = 0 }
      for _, c in ipairs(ns.VisibleChars()) do
        local b, k = c.bags and c.bags[id] or 0, c.bank and c.bank[id] or 0
        if b + k > 0 then
          r.owners[#r.owners + 1] = { char = c, bags = b, bank = k }
          r.total = r.total + b + k
        end
      end
      if r.total > 0 then results[#results + 1] = r end
    end
  end
  table.sort(results, function(a, b) return a.name < b.name end)
  return results
end

-- { {recipe, prof, char} }
function ns.SearchRecipes(text)
  text = (text or ""):lower()
  local results = {}
  if #text < 2 then return results end
  for _, c in ipairs(ns.VisibleChars()) do
    for prof, list in pairs(c.recipes or {}) do
      for _, name in ipairs(list) do
        if name:lower():find(text, 1, true) then
          results[#results + 1] = { recipe = name, prof = prof, char = c }
        end
      end
    end
  end
  table.sort(results, function(a, b) return a.recipe < b.recipe end)
  return results
end

-- Item tooltip -----------------------------------------------------------
local function addOwners(tooltip, id)
  if not id or not ns.db or ns.db.noItemTooltip then return end
  local lines = {}
  for _, c in ipairs(ns.VisibleChars()) do
    local b, k = c.bags and c.bags[id] or 0, c.bank and c.bank[id] or 0
    if b + k > 0 then
      local detail = k > 0 and b > 0 and ("|cffaaaaaa(" .. L["bags %d, bank %d"]:format(b, k) .. ")|r ")
        or k > 0 and ("|cffaaaaaa(" .. L["bank"] .. ")|r ") or ""
      lines[#lines + 1] = { ns.ColoredName(c), detail .. (b + k) }
    end
  end
  if #lines == 0 then return end
  tooltip:AddLine(" ")
  for _, l in ipairs(lines) do tooltip:AddDoubleLine(l[1], l[2], 1, 1, 1, 1, 1, 1) end
  tooltip:Show()
end

local function hookTooltips()
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      if tooltip == GameTooltip or tooltip == ItemRefTooltip then
        if ns.AddQuestItemInfo then ns.AddQuestItemInfo(tooltip, data and data.id) end
        addOwners(tooltip, data and data.id)
      end
    end)
    return
  end
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    tt:HookScript("OnTooltipSetItem", function(self)
      local _, link = self:GetItem()
      local id = link and tonumber(link:match("item:(%d+)"))
      if ns.AddQuestItemInfo then ns.AddQuestItemInfo(self, id) end
      addOwners(self, id)
    end)
  end
end

-- Events -----------------------------------------------------------------
function ns.InitInventory()
  local c = ns.db.chars[ns.me]
  local bankOpen, pending
  local function later(fn)
    if pending then return end
    pending = true
    C_Timer.After(1, function()
      pending = nil
      fn()
    end)
  end
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "BAG_UPDATE", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE", "PLAYER_EQUIPMENT_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
  end
  f:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then bankOpen = true; scanBank(c)
    elseif event == "BANKFRAME_CLOSED" then bankOpen = nil
    elseif event == "PLAYERBANKSLOTS_CHANGED" then if bankOpen then scanBank(c) end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then scanTradeSkill(c)
    elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then scanCraft(c)
    else
      later(function()
        scanBags(c)
        if bankOpen then scanBank(c) end
      end)
    end
  end)
  C_Timer.After(4, function() scanBags(c) end)
  hookTooltips()
end
