-- Alt Dashboard (Forever): slash commands (/alts or /altdash)
local _, ns = ...
local L = ns.L

SLASH_ALTDASHBOARD1, SLASH_ALTDASHBOARD2 = "/alts", "/altdash"
SlashCmdList.ALTDASHBOARD = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then
    ns.ToggleDashboard()
  elseif cmd == "mini" then
    ns.SetMiniShown(not ns.db.miniShown)
  elseif cmd == "search" or cmd == "find" then
    ns.ToggleDashboard("search")
  elseif cmd == "reps" or cmd == "weekly" or cmd == "gold" then
    ns.ToggleDashboard(cmd)
  elseif cmd == "minimap" then
    ns.db.hideMinimap = not ns.db.hideMinimap
    ns.UpdateMinimapButton()
  elseif cmd == "list" then
    for _, c in ipairs(ns.VisibleChars()) do
      local tasks = ns.GetTasks(c)
      print(("%s%s|r (%d) - %s - %s"):format(ns.ClassColor(c), c.name, c.level or 0, ns.Money(c.money, true),
        #tasks > 0 and table.concat(tasks, ", ") or L["Nothing to do"]))
    end
  elseif cmd == "quest" and rest ~= "" then
    -- item link (shift-click) or item ID
    local id = tonumber(rest:match("item:(%d+)") or rest)
    if id then ns.DebugQuestItem(id) end
  elseif cmd == "remove" and rest ~= "" then
    if ns.RemoveChar(ns.FindChar(rest) or "") then print(ns.PREFIX .. L["%s removed."]:format(rest))
    else print(ns.PREFIX .. L["Unknown character: %s"]:format(rest)) end
  else
    print(ns.PREFIX .. L["/alts (window) | mini | search | reps | weekly | gold | list | minimap | remove Name"])
  end
end
