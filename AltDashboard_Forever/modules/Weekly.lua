-- Alt Dashboard (Forever): Weekly tab (raid/dungeon lockouts + your own checklist, per character)
local _, ns = ...
local L = ns.L
local UI = ns.UI

local page = { key = "weekly", label = "Weekly" }

local function lockout(c, name)
  for _, lo in ipairs(ns.ActiveLockouts(c)) do if lo.name == name then return lo end end
end

local function instanceEntry(name, isRaid)
  local ignored = ns.db.ignoredRaids[name]
  return {
    label = (ignored and "|cff808080" or "") .. name .. (ignored and ("  (" .. L["ignored"] .. ")|r") or ""),
    icon = isRaid and "Interface\\Icons\\INV_Misc_Head_Dragon_01" or "Interface\\Icons\\INV_Misc_Key_03",
    cell = function(c)
      local lo = lockout(c, name)
      if lo then
        local prog = (lo.bosses and lo.bosses > 0) and (lo.killed .. "/" .. lo.bosses .. " ") or ""
        return "|cffff6060" .. prog .. "|cff999999" .. ns.FormatShortTime(lo.expires - time()) .. "|r"
      end
      if isRaid and (c.level or 0) >= ns.MAX_LEVEL and not ignored then return "|cff00ff00" .. L["Free"] .. "|r" end
      return "|cff505050-|r"
    end,
    tip = function(c)
      GameTooltip:AddLine(name)
      GameTooltip:AddLine(ns.ColoredName(c))
      local lo = lockout(c, name)
      if lo then
        if lo.bosses and lo.bosses > 0 then GameTooltip:AddLine(L["%d/%d bosses"]:format(lo.killed or 0, lo.bosses), 1, 1, 1) end
        GameTooltip:AddLine(L["Resets in %s"]:format(ns.FormatTime(lo.expires - time())), 0.7, 0.7, 0.7)
      else
        GameTooltip:AddLine(L["Not saved"], 0.5, 1, 0.5)
      end
    end,
    labelTip = isRaid and function()
      GameTooltip:AddLine(name)
      GameTooltip:AddLine(L["Right-click: count it in the tasks or not"], 0.5, 1, 0.5)
    end or nil,
    labelClick = isRaid and function(button)
      if button ~= "RightButton" then return end
      ns.db.ignoredRaids[name] = not ns.db.ignoredRaids[name] or nil
      ns.RefreshAll()
    end or nil,
  }
end

local function checkEntry(item)
  return {
    label = "|cffffd100" .. item.name .. "|r  |cff808080" .. (item.daily and L["daily"] or L["weekly"])
      .. ((item.minLevel or 1) > 1 and (", " .. L["lvl %d+"]:format(item.minLevel)) or "") .. "|r",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    highlight = true,
    cell = function(c)
      if not ns.CheckApplies(c, item) then return "|cff505050-|r" end
      if ns.IsCheckDone(c, item) then return "|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t" end
      return "|TInterface\\RaidFrame\\ReadyCheck-Waiting:16|t"
    end,
    tip = function(c)
      GameTooltip:AddLine(item.name)
      GameTooltip:AddLine(ns.ColoredName(c))
      GameTooltip:AddLine(L["Click: done / not done"], 0.5, 1, 0.5)
    end,
    click = function(c)
      if ns.CheckApplies(c, item) then ns.SetCheckDone(c, item, not ns.IsCheckDone(c, item)) end
    end,
    labelTip = function()
      GameTooltip:AddLine(item.name)
      GameTooltip:AddLine(L["Right-click: delete this line"], 1, 0.4, 0.4)
    end,
    labelClick = function(button)
      if button == "RightButton" then ns.RemoveCheck(item.id) end
    end,
  }
end

local function rows()
  local entries = {}
  for _, item in ipairs(ns.db.checklist) do entries[#entries + 1] = checkEntry(item) end

  -- raids ever seen, then dungeons currently saved by someone
  local raids, dungeons, seen = {}, {}, {}
  for name in pairs(ns.db.seenRaids) do raids[#raids + 1] = name; seen[name] = true end
  for _, c in ipairs(ns.VisibleChars()) do
    for _, lo in ipairs(ns.ActiveLockouts(c)) do
      if not seen[lo.name] then seen[lo.name] = true; dungeons[#dungeons + 1] = lo.name end
    end
  end
  table.sort(raids)
  table.sort(dungeons)
  for _, name in ipairs(raids) do entries[#entries + 1] = instanceEntry(name, true) end
  for _, name in ipairs(dungeons) do entries[#entries + 1] = instanceEntry(name, false) end
  return entries
end

function page.build(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()
  p.grid = UI.Grid(p, { rows = rows, title = L["Weekly activity"], bottom = 34,
    emptyText = L["Add your own weekly tasks below. Raids appear once a character has been saved in them."] })

  -- add a checklist line: name, minimum level, daily or weekly
  local label = UI.Text(p, "GameFontNormalSmall", "BOTTOMLEFT", 4, 12)
  label:SetText(L["New task:"])
  UI.Ink(label)
  local name = UI.EditBox(p, 300)
  name:SetPoint("LEFT", label, "RIGHT", 12, 0)
  local lvlLabel = UI.Text(p, "GameFontHighlightSmall", "LEFT", 0, 0)
  lvlLabel:ClearAllPoints()
  lvlLabel:SetPoint("LEFT", name, "RIGHT", 14, 0)
  lvlLabel:SetText(L["Min. level"])
  UI.Ink(lvlLabel)
  local lvl = UI.EditBox(p, 34)
  lvl:SetPoint("LEFT", lvlLabel, "RIGHT", 8, 0)
  lvl:SetNumeric(true)
  lvl:SetMaxLetters(2)
  local daily = UI.Check(p, L["Daily"])
  daily:SetPoint("LEFT", lvl, "RIGHT", 10, 0)
  local function add()
    local text = strtrim(name:GetText() or "")
    if text == "" then return end
    ns.AddCheck(text, tonumber(lvl:GetText()) or 1, daily:GetChecked())
    name:SetText("")
    name:ClearFocus()
  end
  name:SetScript("OnEnterPressed", add)
  local btn = UI.Button(p, L["Add"], 90, add, true)
  btn:SetPoint("LEFT", daily.text, "RIGHT", 14, 0)
  return p
end

function page.refresh(p) p.grid:Refresh() end
function page.animate(p) p.grid:Cascade() end

table.insert(ns.PAGES, page)
