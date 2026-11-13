-- Alt Dashboard (Forever): Reputations tab (one line per faction, one column per character)
local _, ns = ...
local L = ns.L
local UI = ns.UI

local page = { key = "reps", label = "Reputations" }

local function find(c, name)
  for _, r in ipairs(c.reputations or {}) do if r.name == name then return r end end
end

local function rows()
  -- every faction known by at least one visible character, best standing first
  local best, list = {}, {}
  for _, c in ipairs(ns.VisibleChars()) do
    for _, r in ipairs(c.reputations or {}) do
      if not best[r.name] then list[#list + 1] = r.name end
      best[r.name] = math.max(best[r.name] or 0, r.standing)
    end
  end
  table.sort(list, function(a, b)
    if best[a] ~= best[b] then return best[a] > best[b] end
    return a < b
  end)
  local entries = {}
  for _, name in ipairs(list) do
    entries[#entries + 1] = {
      label = name,
      cell = function(c)
        local r = find(c, name)
        if not r then return "|cff505050-|r" end
        return UI.StandingText(r.standing)
      end,
      tip = function(c)
        local r = find(c, name)
        GameTooltip:AddLine(name)
        GameTooltip:AddLine(ns.ColoredName(c))
        if r then
          GameTooltip:AddDoubleLine(UI.StandingText(r.standing), r.max > 0 and ("%d / %d"):format(r.value, r.max) or "", 1, 1, 1, 1, 1, 1)
          if r.max > 0 and r.standing < 8 then
            GameTooltip:AddLine(L["%d to the next rank"]:format(r.max - r.value), 0.7, 0.7, 0.7)
          end
        else
          GameTooltip:AddLine(L["Unknown faction for this character"], 0.6, 0.6, 0.6)
        end
      end,
    }
  end
  return entries
end

function page.build(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()
  p.grid = UI.Grid(p, { rows = rows, title = L["Faction"], emptyText = L["No reputation recorded yet: log in on your characters."] })
  return p
end

function page.refresh(p) p.grid:Refresh() end
function page.animate(p) p.grid:Cascade() end

table.insert(ns.PAGES, page)
