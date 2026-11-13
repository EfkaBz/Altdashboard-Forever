-- Alt Dashboard (Forever): compact window (tasks only), can stay on screen while playing
local _, ns = ...
local L = ns.L
local S = ns.Skin
local C = S.C

local WIDTH, LINE_H, MAX_LINES, TOP = 290, 16, 30, 40
local mini

-- gold dot drawn inline before each task
local BULLET = ("|T%sDot:6:6:0:0:16:16:0:16:0:16:%d:%d:%d|t"):format(S.MEDIA,
  C.gold[1] * 255, C.gold[2] * 255, C.gold[3] * 255)

local function create()
  local f = S.Window("AltDashboardForeverMini", UIParent, WIDTH, 80, 10)
  f:SetFrameStrata("MEDIUM")
  f.openDY = -6
  local pos = ns.db.miniPos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("RIGHT", -80, 80) end

  -- title bar: click opens the dashboard, drag moves the window
  local bar = CreateFrame("Button", nil, f)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -30, -1)
  bar:SetHeight(30)
  S.Draggable(f, bar, function(self)
    local point, _, rel, x, y = self:GetPoint()
    ns.db.miniPos = { point, rel, x, y }
  end)
  bar:RegisterForClicks("LeftButtonUp")
  bar:SetScript("OnClick", function() ns.ToggleDashboard("overview") end)
  bar:SetScript("OnEnter", function(self)
    f.title:SetTextColor(S.Color(C.goldHi))
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Click: open the dashboard"], 0.5, 1, 0.5)
    GameTooltip:AddLine(L["Drag: move"], 0.5, 1, 0.5)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function()
    f.title:SetTextColor(S.Color(C.gold))
    GameTooltip:Hide()
  end)

  local logo = S.Icon(bar, 20, ns.ADDON_ICON)
  logo.tex:SetTexCoord(0, 1, 0, 1)
  logo:SetBorderColor(S.Color(C.gold, 0.7))
  logo:SetPoint("LEFT", 10, -1)
  f.title = S.Text(bar, 13, "gold")
  f.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  f.title:SetText("Alt Dashboard")
  f.count = S.Text(bar, 11, "muted")
  f.count:SetPoint("RIGHT", -2, 0)

  local close = S.CloseButton(f, function() ns.SetMiniShown(false) end)
  close:SetPoint("TOPRIGHT", -6, -5)

  local rule = S.Rule(f, C.ring, 0.45)
  rule:SetPoint("TOPLEFT", 10, -31)
  rule:SetPoint("TOPRIGHT", -10, -31)

  f.lines = {}
  for i = 1, MAX_LINES do
    local fs = S.Text(f, 11, "text")
    fs:SetPoint("TOPLEFT", 14, -TOP - (i - 1) * LINE_H)
    fs:SetWidth(WIDTH - 28)
    fs:SetWordWrap(false)
    f.lines[i] = fs
  end
  f.height = 80
  return f
end

-- the window grows / shrinks smoothly with the list
local function setHeight(h)
  if not mini.height or not mini:IsVisible() then
    mini.height = h
    mini:SetHeight(h)
    return
  end
  if math.abs(h - mini.height) < 1 then return end
  local from = mini.height
  mini.height = h
  S.Tween(mini.lines, { dur = 0.25, from = from, to = h, set = function(v) mini:SetHeight(v) end })
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
      line(ns.ColoredName(c) .. " " .. S.Hex(C.dim) .. (c.level or "?") .. "|r")
      for _, t in ipairs(tasks) do line("   " .. BULLET .. "  " .. t) end
    end
  end
  if n == 0 then line(S.Hex(C.good) .. L["Nothing to do"] .. "|r") end
  for i = math.min(n, MAX_LINES) + 1, MAX_LINES do mini.lines[i]:SetText("") end
  mini.count:SetText(L["%d tasks this week"]:format(total))
  setHeight(TOP + 10 + math.min(n, MAX_LINES) * LINE_H)
end

function ns.SetMiniShown(shown)
  ns.db.miniShown = shown or nil
  if shown then
    mini = mini or create()
    if S.IsTweening(mini) and mini:IsShown() then
      -- reopened while it was closing: put it back in place first
      S.StopTween(mini)
      mini:Hide()
      mini:SetAlpha(1)
      local h = mini.home
      if h then mini:ClearAllPoints(); mini:SetPoint(h[1], h[2], h[3], h[4], h[5]) end
    end
    if not mini:IsShown() then mini:Show() end
    ns.RefreshMini()
  elseif mini then
    S.Close(mini)
  end
  ns.RefreshDashboard()
end

function ns.InitMini()
  if ns.db.miniShown then ns.SetMiniShown(true) end
  -- cooldown timers go by while nothing else happens
  C_Timer.NewTicker(60, ns.RefreshMini)
end
