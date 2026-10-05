-- Alt Dashboard (Forever): compact window (tasks only), can stay on screen while playing
local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, LINE_H, MAX_LINES = 280, 15, 30
local mini

local function create()
  local f = CreateFrame("Frame", "AltDashboardForeverMini", UIParent, "BackdropTemplate")
  f:SetWidth(WIDTH)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    ns.db.miniPos = { point, rel, x, y }
  end)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropBorderColor(0.8, 0.65, 0.2, 0.9)
  local pos = ns.db.miniPos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("RIGHT", -80, 80) end

  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(16, 16)
  logo:SetPoint("TOPLEFT", 8, -7)
  logo:SetTexture(ns.ADDON_ICON)
  f.title = UI.Text(f, "GameFontNormal", "TOPLEFT", 30, -8, WIDTH - 60)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -1, -1)
  close:SetScript("OnClick", function() ns.SetMiniShown(false) end)

  -- click the title zone: open the full dashboard
  local open = CreateFrame("Button", nil, f)
  open:SetPoint("TOPLEFT", 4, -4)
  open:SetSize(WIDTH - 34, 20)
  open:RegisterForClicks("LeftButtonUp")
  open:SetScript("OnClick", function() ns.ToggleDashboard("overview") end)
  open:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Click: open the dashboard"], 0.5, 1, 0.5)
    GameTooltip:AddLine(L["Drag: move"], 0.5, 1, 0.5)
    GameTooltip:Show()
  end)
  open:SetScript("OnLeave", function() GameTooltip:Hide() end)
  open:RegisterForDrag("LeftButton")
  open:SetScript("OnDragStart", function() f:StartMoving() end)
  open:SetScript("OnDragStop", function() f:GetScript("OnDragStop")(f) end)

  f.lines = {}
  for i = 1, MAX_LINES do
    local fs = UI.Text(f, "GameFontHighlightSmall", "TOPLEFT", 12, -30 - (i - 1) * LINE_H, WIDTH - 24)
    f.lines[i] = fs
  end
  return f
end

function ns.RefreshMini()
  if not mini or not mini:IsShown() then return end
  local n, total = 0, 0
  local function line(text)
    n = n + 1
    if n <= MAX_LINES then mini.lines[n]:SetText(text) end
  end
  for _, c in ipairs(ns.VisibleChars()) do
    local tasks = ns.GetTasks(c)
    if #tasks > 0 then
      total = total + #tasks
      line(ns.ColoredName(c) .. " |cff808080(" .. (c.level or "?") .. ")|r")
      for _, t in ipairs(tasks) do line("   |cffffd100-|r " .. t) end
    end
  end
  if n == 0 then line("|cff00ff00" .. L["Nothing to do"] .. "|r") end
  for i = math.min(n, MAX_LINES) + 1, MAX_LINES do mini.lines[i]:SetText("") end
  mini.title:SetText(L["%d tasks this week"]:format(total))
  mini:SetHeight(36 + math.min(n, MAX_LINES) * LINE_H)
end

function ns.SetMiniShown(shown)
  ns.db.miniShown = shown or nil
  if shown then
    mini = mini or create()
    mini:Show()
    ns.RefreshMini()
  elseif mini then
    mini:Hide()
  end
  ns.RefreshDashboard()
end

function ns.InitMini()
  if ns.db.miniShown then ns.SetMiniShown(true) end
  -- cooldown timers go by while nothing else happens
  C_Timer.NewTicker(60, ns.RefreshMini)
end
