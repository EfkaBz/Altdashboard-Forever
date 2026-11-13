-- Alt Dashboard (Forever): minimap button
local _, ns = ...
local L = ns.L

local btn

local function place()
  local a = math.rad(ns.db.minimapAngle or 160)
  local r = (Minimap:GetWidth() / 2) + 10
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.UpdateMinimapButton()
  if btn then btn:SetShown(not ns.db.hideMinimap) end
end

function ns.InitMinimapButton()
  btn = CreateFrame("Button", "AltDashboardForeverMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ns.ADDON_ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local s = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.SetMiniShown(not ns.db.miniShown) else ns.ToggleDashboard() end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Alt Dashboard (Forever)")
    -- one line per character: level, gold, tasks
    local n = 0
    for _, c in ipairs(ns.VisibleChars()) do
      local t = #ns.GetTasks(c)
      n = n + t
      GameTooltip:AddDoubleLine(ns.ColoredName(c) .. " |cff808080" .. (c.level or "?") .. "|r",
        ns.Money(c.money, true) .. (t > 0 and ("  |cffffd100" .. t .. "|r") or "  |cff00ff00-|r"), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(L["Total"], ns.Money(ns.TotalGold(), true), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(L["%d tasks this week"]:format(n), 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Left-click: open the dashboard"], 0.5, 1, 0.5)
    GameTooltip:AddLine(L["Right-click: compact window"], 0.5, 1, 0.5)
    GameTooltip:AddLine(L["Drag: move button"], 0.5, 1, 0.5)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  place()
  ns.UpdateMinimapButton()
end
