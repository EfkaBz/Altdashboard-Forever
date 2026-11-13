-- Alt Dashboard (Forever): custom skin, WoW Forever theme (no game templates).
-- Deep navy panels, arcane blue trim, soft gold titles (the addon icon's colors),
-- eased animations: window open/close, hover fades, sliding tab marker, animated bars,
-- menus and dialogs that slide in
local ADDON, ns = ...

local S = {}
ns.Skin = S

local WHITE = "Interface\\Buttons\\WHITE8x8"
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\UI\\"
S.MEDIA, S.WHITE = MEDIA, WHITE

-- Palette ------------------------------------------------------------------
local function hex(h)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, 1 }
end

local C = {
  bg1    = hex("#121B2B"), -- window, top
  bg2    = hex("#090E17"), -- window, bottom
  card1  = hex("#141E2F"), -- panels, top
  card2  = hex("#0D1420"), -- panels, bottom
  well   = hex("#070B12"), -- inputs, tracks
  head   = hex("#162236"), -- column headers
  trim   = hex("#24344B"), -- borders
  ring   = hex("#3E6C9F"), -- hover / focus border
  accent = hex("#4FA3E8"), -- arcane blue
  glow   = hex("#2F7FD0"),
  gold   = hex("#D8B46A"), -- titles (the icon's gold trim)
  goldHi = hex("#F0D79A"),
  text   = hex("#E2E8F1"),
  muted  = hex("#8392A8"),
  dim    = hex("#55637A"),
  good   = hex("#6CCB8A"),
  warn   = hex("#E3A84E"),
  bad    = hex("#E06A6A"),
  btn1   = hex("#1A2639"), btn2 = hex("#0F1724"),
  prim1  = hex("#24507F"), prim2 = hex("#163353"),
  xp1    = hex("#7FC4FF"), xp2 = hex("#2E6FC0"),
  rest   = { 0.30, 0.52, 0.95, 0.45 },
  gold1  = hex("#F2D48A"), gold2 = hex("#A8741F"),
}
S.C = C

local function color(t, a) return t[1], t[2], t[3], a or t[4] end
S.Color = color

-- "|cffRRGGBB" from a palette color
function S.Hex(t) return ("|cff%02x%02x%02x"):format(t[1] * 255, t[2] * 255, t[3] * 255) end

local function lerp(a, b, p) return a + (b - a) * p end
local function lerpColor(c1, c2, p)
  return lerp(c1[1], c2[1], p), lerp(c1[2], c2[2], p), lerp(c1[3], c2[3], p), lerp(c1[4] or 1, c2[4] or 1, p)
end

-- gradient c1 -> c2, top to bottom (or left to right when horizontal)
local function gradient(tex, c1, c2, horizontal, keepTexture)
  if not keepTexture then tex:SetTexture(WHITE) end
  tex:SetVertexColor(1, 1, 1, 1)
  local o = horizontal and "HORIZONTAL" or "VERTICAL"
  local a, b = c1, c2
  if not horizontal then a, b = c2, c1 end -- VERTICAL runs bottom -> top
  if tex.SetGradient then
    local function col(c) return { r = c[1], g = c[2], b = c[3], a = c[4] or 1 } end
    if pcall(tex.SetGradient, tex, o, col(a), col(b)) then return end
  end
  if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, o,
    a[1], a[2], a[3], a[4] or 1, b[1], b[2], b[3], b[4] or 1) then return end
  tex:SetVertexColor(color(c1))
end
S.Gradient = gradient

-- Tweens -------------------------------------------------------------------
local ease = {
  linear = function(p) return p end,
  outCubic = function(p) return 1 - (1 - p) ^ 3 end,
  inOutCubic = function(p) return p < 0.5 and 4 * p ^ 3 or 1 - (-2 * p + 2) ^ 3 / 2 end,
  outBack = function(p) local c = 1.2; return 1 + (c + 1) * (p - 1) ^ 3 + c * (p - 1) ^ 2 end,
}

local tweens, running = {}, {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
  wipe(running)
  for key, t in pairs(tweens) do running[key] = t end
  for key, t in pairs(running) do
    if tweens[key] == t then
      t.t = t.t + elapsed
      if t.t >= 0 then
        local p = math.min(1, t.t / t.dur)
        t.set(lerp(t.from, t.to, t.ease(p)), p)
        if p >= 1 and tweens[key] == t then
          tweens[key] = nil
          if t.done then t.done() end
        end
      end
    end
  end
  if not next(tweens) then self:Hide() end
end)

-- S.Tween(key, { dur, delay, from, to, ease, set(value, p), done }); same key replaces the running one
function S.Tween(key, a)
  a.t, a.dur = -(a.delay or 0), a.dur or 0.25
  a.ease = type(a.ease) == "function" and a.ease or ease[a.ease or "outCubic"]
  tweens[key] = a
  driver:Show()
end
function S.StopTween(key) tweens[key] = nil end
function S.IsTweening(key) return tweens[key] ~= nil end

function S.FadeTo(region, alpha, dur, done, delay)
  S.Tween(region, { dur = dur or 0.15, delay = delay, from = region:GetAlpha(), to = alpha,
    set = function(v) region:SetAlpha(v) end, done = done })
end

-- Fonts (the game font) ----------------------------------------------------
local FONT = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT
local fonts = {}
function S.Font(size, flags)
  local key = size .. (flags or "")
  if not fonts[key] then
    local f = CreateFont("AltDashboardForeverFont" .. key:gsub("%W", ""))
    f:SetFont(FONT, size, flags or "")
    if not flags then
      f:SetShadowColor(0, 0, 0, 0.85)
      f:SetShadowOffset(1, -1)
    end
    fonts[key] = f
  end
  return fonts[key]
end

function S.Text(parent, size, col, layer, flags)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(S.Font(size or 12, flags))
  fs:SetTextColor(color(C[col or "text"]))
  fs:SetJustifyH("LEFT")
  return fs
end

-- Boxes --------------------------------------------------------------------
local function setBorderColor(f, r, g, b, a)
  for _, t in ipairs(f.borders) do
    if t.isCorner then t:SetVertexColor(r, g, b, a or 1) else t:SetColorTexture(r, g, b, a or 1) end
  end
end

-- border color that eases to a palette color
local function tweenBorder(f, to, dur)
  local from = f.borderNow or f.borderBase
  S.Tween(f.borders, { dur = dur or 0.18, from = 0, to = 1, set = function(v)
    local r, g, b, a = lerpColor(from, to, v)
    f.borderNow = { r, g, b, a }
    f:SetBorderColor(r, g, b, a)
  end })
end
S.TweenBorder = tweenBorder

-- square box: background (color, or {top, bottom} gradient) + 1px border (false: none)
function S.Box(f, bg, border)
  f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.bg:SetAllPoints()
  if bg and type(bg[1]) == "table" then gradient(f.bg, bg[1], bg[2])
  else f.bg:SetColorTexture(color(bg or C.well)) end
  if border ~= false then
    local t, b, l, r = f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER"),
      f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER")
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
    f.borders = { t, b, l, r }
    f.SetBorderColor = setBorderColor
    f.borderBase = border or C.trim
    f:SetBorderColor(color(f.borderBase))
  end
  return f
end

-- 9-slice of a square texture with `margin` px corners (out of `size`), corners drawn at `cs` px
local POINTS = {
  { "TOPLEFT", "TOP" }, { "TOP", "TOP" }, { "TOPRIGHT", "TOP" },
  { "LEFT", "MID" }, { "CENTER", "MID" }, { "RIGHT", "MID" },
  { "BOTTOMLEFT", "BOTTOM" }, { "BOTTOM", "BOTTOM" }, { "BOTTOMRIGHT", "BOTTOM" },
}
local function slice9(f, file, size, margin, cs, layer, sub)
  local m = margin / size
  local u = { 0, m, 1 - m, 1 }
  local tex = {}
  for i, p in ipairs(POINTS) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(file)
    t:SetTexCoord(u[col + 1], u[col + 2], u[row + 1], u[row + 2])
    t.row = p[2]
    tex[p[1]] = t
  end
  for _, k in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    tex[k]:SetSize(cs, cs); tex[k]:SetPoint(k)
  end
  tex.TOP:SetPoint("TOPLEFT", tex.TOPLEFT, "TOPRIGHT"); tex.TOP:SetPoint("BOTTOMRIGHT", tex.TOPRIGHT, "BOTTOMLEFT")
  tex.BOTTOM:SetPoint("TOPLEFT", tex.BOTTOMLEFT, "TOPRIGHT"); tex.BOTTOM:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "BOTTOMLEFT")
  tex.LEFT:SetPoint("TOPLEFT", tex.TOPLEFT, "BOTTOMLEFT"); tex.LEFT:SetPoint("BOTTOMRIGHT", tex.BOTTOMLEFT, "TOPRIGHT")
  tex.RIGHT:SetPoint("TOPLEFT", tex.TOPRIGHT, "BOTTOMLEFT"); tex.RIGHT:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "TOPRIGHT")
  tex.CENTER:SetPoint("TOPLEFT", tex.TOPLEFT, "BOTTOMRIGHT"); tex.CENTER:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "TOPLEFT")
  return tex
end

-- soft dark halo around a frame
function S.Shadow(f, size, alpha)
  size = size or 14
  local holder = CreateFrame("Frame", nil, f)
  holder:SetPoint("TOPLEFT", -size, size)
  holder:SetPoint("BOTTOMRIGHT", size, -size)
  holder:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  for _, t in pairs(slice9(holder, MEDIA .. "Shadow", 64, 16, size * 1.6, "BACKGROUND", -8)) do
    t:SetVertexColor(0, 0, 0, alpha or 0.7)
  end
  return holder
end

-- rounded box (radius r): vertical gradient top -> bottom and a 1px border
function S.Rounded(f, r, top, bottom, border)
  r, top, bottom = r or 10, top or C.bg1, bottom or C.bg2
  local cs = r * 16 / 12 -- textures: radius 12 in a 16px margin
  for _, t in pairs(slice9(f, MEDIA .. "RoundFill", 64, 16, cs, "BACKGROUND", -7)) do
    if t.row == "TOP" then t:SetVertexColor(color(top))
    elseif t.row == "BOTTOM" then t:SetVertexColor(color(bottom))
    else gradient(t, top, bottom, false, true) end
  end
  f.borders = {}
  for _, t in pairs(slice9(f, MEDIA .. "RoundEdge", 64, 16, cs, "BORDER", 1)) do
    t.isCorner = true
    f.borders[#f.borders + 1] = t
  end
  f.SetBorderColor = setBorderColor
  f.borderBase = border or C.trim
  f:SetBorderColor(color(f.borderBase))
  return f
end

-- panel: rounded card used for lists and side boxes
function S.Panel(parent, r)
  local p = CreateFrame("Frame", nil, parent)
  S.Rounded(p, r or 8, C.card1, C.card2, C.trim)
  return p
end

-- faint blue light along the inner edges, breathing very slowly
function S.EdgeGlow(f, depth, alpha)
  depth, alpha = depth or 48, alpha or 0.12
  local pieces = slice9(f, MEDIA .. "RoundGlow", 128, 48, depth, "BACKGROUND", -5)
  for _, t in pairs(pieces) do t:SetVertexColor(C.glow[1], C.glow[2], C.glow[3], alpha) end
  local d = CreateFrame("Frame", nil, f)
  local clock = math.random() * 6
  d:SetScript("OnUpdate", function(_, elapsed)
    clock = clock + elapsed
    local a = 0.85 + 0.15 * math.sin(clock * 1.2)
    for _, t in pairs(pieces) do t:SetAlpha(a) end
  end)
end

-- line fading out on both sides
function S.Rule(parent, col, alpha)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetHeight(1)
  col = col or C.ring
  local c1, c2 = { col[1], col[2], col[3], 0 }, { col[1], col[2], col[3], alpha or 0.8 }
  local l = holder:CreateTexture(nil, "ARTWORK")
  l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMRIGHT", holder, "BOTTOM")
  gradient(l, c1, c2, true)
  local r = holder:CreateTexture(nil, "ARTWORK")
  r:SetPoint("TOPLEFT", holder, "TOP"); r:SetPoint("BOTTOMRIGHT")
  gradient(r, c2, c1, true)
  return holder
end

-- framed icon, cropped edges, gloss
function S.Icon(parent, size, texture)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)
  S.Box(holder, { 0, 0, 0, 1 }, C.trim)
  local tex = holder:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", 1, -1)
  tex:SetPoint("BOTTOMRIGHT", -1, 1)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if texture then tex:SetTexture(texture) end
  holder.tex = tex
  local gloss = holder:CreateTexture(nil, "OVERLAY")
  gloss:SetAllPoints(tex)
  gloss:SetTexture(MEDIA .. "Gloss")
  gloss:SetAlpha(0.6)
  return holder
end

-- smooth hover: a region fades in/out with the mouse
function S.HoverFade(frame, region, alpha)
  region:SetAlpha(0)
  frame:HookScript("OnEnter", function() S.FadeTo(region, alpha or 1, 0.12) end)
  frame:HookScript("OnLeave", function() S.FadeTo(region, 0, 0.3) end)
end

-- row highlight: blue wash fading to the right + thin accent bar on the left
function S.RowHighlight(row)
  local hl = CreateFrame("Frame", nil, row)
  hl:SetAllPoints()
  hl:SetFrameLevel(row:GetFrameLevel())
  local wash = hl:CreateTexture(nil, "BACKGROUND", nil, 1)
  wash:SetAllPoints()
  gradient(wash, { C.accent[1], C.accent[2], C.accent[3], 0.13 }, { C.accent[1], C.accent[2], C.accent[3], 0.02 }, true)
  local bar = hl:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
  bar:SetColorTexture(color(C.accent))
  S.HoverFade(row, hl)
  return hl
end

-- small "x" close button, red glow on hover
function S.CloseButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  local glow = b:CreateTexture(nil, "BACKGROUND")
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetPoint("CENTER")
  glow:SetSize(30, 30)
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1, 0.35, 0.35, 0.45)
  S.HoverFade(b, glow)
  local function bar(angle)
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE)
    t:SetSize(11, 1.6)
    t:SetPoint("CENTER")
    t:SetRotation(math.rad(angle))
    t:SetVertexColor(color(C.muted))
    return t
  end
  local x1, x2 = bar(45), bar(-45)
  b:HookScript("OnEnter", function() x1:SetVertexColor(1, 0.75, 0.75); x2:SetVertexColor(1, 0.75, 0.75) end)
  b:HookScript("OnLeave", function() x1:SetVertexColor(color(C.muted)); x2:SetVertexColor(color(C.muted)) end)
  b:SetScript("OnClick", onClick or function() S.Close(parent) end)
  return b
end

-- chevron made of two rotated lines; :Point("up"|"down"|"left"|"right") turns it (animated)
local ANGLES = { down = 0, up = 180, right = 90, left = -90 }
function S.Chevron(parent, size, col)
  size = size or 8
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  local function bar(x)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE)
    t:SetSize(size * 0.75, 1.6)
    t:SetVertexColor(color(col or C.gold))
    return t
  end
  local l, r = bar(), bar()
  local turn = 0
  local function place(a)
    turn = a
    local rad = math.rad(a)
    local cx, cy = math.cos(rad), math.sin(rad)
    local d = size * 0.24
    -- each half sits on one side of the tip, then the whole shape is rotated by `a`
    l:ClearAllPoints(); r:ClearAllPoints()
    l:SetPoint("CENTER", f, "CENTER", -d * cx, -d * cy)
    r:SetPoint("CENTER", f, "CENTER", d * cx, d * cy)
    l:SetRotation(math.rad(-40) + rad)
    r:SetRotation(math.rad(40) + rad)
  end
  place(0)
  function f:Point(dir, animate)
    local to = ANGLES[dir] or 0
    if animate then S.Tween(f, { dur = 0.2, from = turn, to = to, set = place }) else place(to) end
  end
  function f:SetColor(c) l:SetVertexColor(color(c)); r:SetVertexColor(color(c)) end
  return f
end

-- Windows ------------------------------------------------------------------
-- opening: fade + short rise with a soft overshoot
function S.AnimateOpen(f, dx, dy)
  local p, rel, rp, x, y = f:GetPoint(1)
  if not p then return end
  f.home = f.home or { p, rel, rp, x, y }
  local h = f.home
  dx, dy = dx or 0, dy or -10
  f:SetAlpha(0)
  S.Tween(f, { dur = 0.3, from = 0, to = 1, ease = "outBack", set = function(v, pr)
    f:SetAlpha(math.min(1, pr * 2.5))
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4] + dx * (1 - v), h[5] + dy * (1 - v))
  end })
end

-- closing: fade + slight drop, then hide (back in place for the next opening)
function S.Close(f, done)
  if not f:IsShown() then return end
  local p, rel, rp, x, y = f:GetPoint(1)
  f.home = f.home or { p, rel, rp, x, y }
  local h = f.home
  local a0 = f:GetAlpha()
  S.Tween(f, { dur = 0.16, from = 0, to = 1, ease = "inOutCubic", set = function(v)
    f:SetAlpha(a0 * (1 - v))
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4], h[5] - 6 * v)
  end, done = function()
    f:Hide()
    f:SetAlpha(1)
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4], h[5])
    if done then done() end
  end })
end

-- makes a frame draggable by a handle (onStop: after moving)
function S.Draggable(f, handle, onStop)
  f:SetMovable(true)
  handle = handle or f
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function() S.StopTween(f); f:SetAlpha(1); f:StartMoving() end)
  handle:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, rel, rp, x, y = f:GetPoint(1)
    f.home = { p, rel, rp, x, y }
    if onStop then onStop(f) end
  end)
end

-- rounded navy window with shadow and breathing edge light
function S.Window(name, parent, width, height, radius)
  local f = CreateFrame("Frame", name, parent or UIParent)
  f:SetSize(width, height)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  S.Shadow(f, 18, 0.65)
  S.Rounded(f, radius or 12)
  S.EdgeGlow(f, 48, 0.12)
  -- thin gold line along the top edge, like the icon's frame
  local top = S.Rule(f, C.gold, 0.55)
  top:SetPoint("TOPLEFT", 40, -1)
  top:SetPoint("TOPRIGHT", -40, -1)
  f:HookScript("OnShow", function(self) S.AnimateOpen(self, self.openDX, self.openDY) end)
  return f
end

-- Buttons ------------------------------------------------------------------
-- gradient button with gloss; hover: border eases to blue + soft inner light
function S.Button(parent, text, width, height, onClick, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, height or 24)
  local border = primary and C.ring or C.trim
  S.Box(b, primary and { C.prim1, C.prim2 } or { C.btn1, C.btn2 }, border)
  local gloss = b:CreateTexture(nil, "ARTWORK", nil, 1)
  gloss:SetPoint("TOPLEFT", 1, -1); gloss:SetPoint("BOTTOMRIGHT", -1, 1)
  gloss:SetTexture(MEDIA .. "Gloss")
  gloss:SetAlpha(0.5)
  local light = b:CreateTexture(nil, "ARTWORK", nil, 2)
  light:SetPoint("TOPLEFT", 1, -1); light:SetPoint("BOTTOMRIGHT", -1, 1)
  gradient(light, { C.accent[1], C.accent[2], C.accent[3], 0 }, { C.accent[1], C.accent[2], C.accent[3], 0.22 })
  light:SetBlendMode("ADD")
  S.HoverFade(b, light)

  b.text = S.Text(b, 12, primary and "goldHi" or "text")
  b.text:SetPoint("CENTER")
  b.text:SetJustifyH("CENTER")
  b.text:SetText(text or "")
  b:HookScript("OnEnter", function() tweenBorder(b, C.accent) end)
  b:HookScript("OnLeave", function() tweenBorder(b, border) end)
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.text:SetPoint("CENTER", 0, -1) end end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER") end)
  b:SetScript("OnClick", onClick)
  function b:SetText(t) self.text:SetText(t) end
  local setEnabled = b.SetEnabled
  function b:SetEnabled(on)
    setEnabled(self, on)
    self:SetAlpha(on and 1 or 0.4)
  end
  return b
end

-- small square button holding a chevron (pagers)
function S.ArrowButton(parent, dir, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(20, 20)
  S.Box(b, { C.btn1, C.btn2 }, C.trim)
  b.chev = S.Chevron(b, 9, C.gold)
  b.chev:SetPoint("CENTER")
  b.chev:Point(dir)
  b:HookScript("OnEnter", function() tweenBorder(b, C.accent) end)
  b:HookScript("OnLeave", function() tweenBorder(b, C.trim) end)
  b:SetScript("OnClick", onClick)
  local setEnabled = b.SetEnabled
  function b:SetEnabled(on)
    setEnabled(self, on)
    self:SetAlpha(on and 1 or 0.35)
  end
  return b
end

-- Checkbox -----------------------------------------------------------------
-- dark well, blue fill and check mark that fade in; the label is clickable too
function S.Check(parent, label, size)
  size = size or 16
  local c = CreateFrame("CheckButton", nil, parent)
  c:SetSize(size, size)
  S.Box(c, C.well, C.trim)
  local inner = c:CreateTexture(nil, "ARTWORK")
  inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
  gradient(inner, C.prim1, C.prim2)
  local glow = c:CreateTexture(nil, "BACKGROUND", nil, -7)
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER")
  glow:SetSize(size * 2.2, size * 2.2)
  glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.5)
  c.mark = CreateFrame("Frame", nil, c)
  c.mark:SetAllPoints()
  local k = size / 18
  local short = c.mark:CreateTexture(nil, "OVERLAY")
  short:SetTexture(WHITE)
  short:SetSize(6 * k, 2.2 * k)
  short:SetPoint("CENTER", -3 * k, -0.5 * k)
  short:SetRotation(math.rad(-45))
  local long = c.mark:CreateTexture(nil, "OVERLAY")
  long:SetTexture(WHITE)
  long:SetSize(11 * k, 2.2 * k)
  long:SetPoint("CENTER", 1.6 * k, 1 * k)
  long:SetRotation(math.rad(50))
  for _, l in ipairs({ short, long }) do l:SetVertexColor(color(C.goldHi)) end

  local function update(self, animate)
    local on = self:GetChecked() and true or false
    if animate then
      S.FadeTo(self.mark, on and 1 or 0, 0.15)
      S.FadeTo(inner, on and 1 or 0, 0.15)
      if on then glow:SetAlpha(1); S.FadeTo(glow, 0, 0.5) end
    else
      self.mark:SetAlpha(on and 1 or 0)
      inner:SetAlpha(on and 1 or 0)
      glow:SetAlpha(0)
    end
  end
  local setChecked = c.SetChecked
  function c:SetChecked(v) setChecked(self, v); update(self) end
  c:SetScript("PostClick", function(self) update(self, true) end) -- callers own OnClick
  c:HookScript("OnEnter", function(self) tweenBorder(self, C.accent) end)
  c:HookScript("OnLeave", function(self) tweenBorder(self, C.trim) end)
  update(c)

  if label then
    c.text = S.Text(c, 12, "text")
    c.text:SetPoint("LEFT", c, "RIGHT", 7, 0)
    c.text:SetText(label)
    c:SetHitRectInsets(0, -(c.text:GetStringWidth() + 10), -3, -3)
    c:HookScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    c:HookScript("OnLeave", function(self) self.text:SetTextColor(color(C.text)) end)
  end
  return c
end

-- Edit box -----------------------------------------------------------------
-- dark well, border eases to blue on focus, grey placeholder, clear button when filled
function S.EditBox(parent, width, height, placeholder)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, height or 22)
  e:SetAutoFocus(false)
  e:SetFontObject(S.Font(12))
  e:SetTextColor(color(C.text))
  local small = width < 80 -- tiny fields (numbers): no clear button
  e:SetTextInsets(small and 6 or 8, small and 6 or 22, 0, 0)
  S.Box(e, C.well, C.trim)
  e.placeholder = S.Text(e, 12, "dim")
  e.placeholder:SetPoint("LEFT", 8, 0)
  e.placeholder:SetText(placeholder or "")
  local clear = S.CloseButton(e, function()
    e:SetText("")
    e:ClearFocus()
  end)
  clear:SetSize(18, 18)
  clear:SetPoint("RIGHT", -2, 0)
  clear:SetAlpha(0)
  clear:Hide()
  if small then clear.Show = clear.Hide end
  local filled = false
  local function update()
    local now = (e:GetText() or "") ~= ""
    e.placeholder:SetShown(not now and not e:HasFocus())
    if now == filled then return end
    filled = now
    if now then
      clear:Show()
      S.FadeTo(clear, 1, 0.15)
    else
      S.FadeTo(clear, 0, 0.12, function() if not filled then clear:Hide() end end)
    end
  end
  e:SetScript("OnTextChanged", update)
  e:SetScript("OnEditFocusGained", function(self) tweenBorder(self, C.accent); update() end)
  e:SetScript("OnEditFocusLost", function(self) tweenBorder(self, C.trim); update() end)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:HookScript("OnEnter", function(self) if not self:HasFocus() then tweenBorder(self, C.ring) end end)
  e:HookScript("OnLeave", function(self) if not self:HasFocus() then tweenBorder(self, C.trim) end end)
  return e
end

-- Popup menu ---------------------------------------------------------------
-- rounded menu at the cursor (or under an anchor), slides in; a click elsewhere closes it.
-- entries = { { text, func, title = bool, color = palette color, checked = bool } }
local MENU_ROW, MENU_PAD = 22, 5
local menu, catcher, menuRows = nil, nil, {}

local function closeMenu()
  if not menu or not menu:IsShown() then return end
  catcher:Hide()
  S.Close(menu)
end
S.CloseMenu = closeMenu

local function buildMenu()
  catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:SetFrameLevel(10)
  catcher:RegisterForClicks("AnyUp")
  catcher:SetScript("OnClick", closeMenu)
  catcher:Hide()
  menu = CreateFrame("Frame", nil, UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetFrameLevel(20)
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  S.Shadow(menu, 10, 0.7)
  S.Rounded(menu, 6)
  menu:Hide()
end

local function menuRow(i)
  local row = menuRows[i]
  if row then return row end
  row = CreateFrame("Button", nil, menu)
  row:SetHeight(MENU_ROW)
  row.hl = S.RowHighlight(row)
  row.dot = row:CreateTexture(nil, "OVERLAY")
  row.dot:SetTexture(MEDIA .. "Dot")
  row.dot:SetSize(6, 6)
  row.dot:SetPoint("LEFT", 7, 0)
  row.dot:SetVertexColor(color(C.accent))
  row.text = S.Text(row, 12)
  row.text:SetPoint("LEFT", 18, 0)
  row:SetScript("OnClick", function(self)
    closeMenu()
    if self.func then self.func() end
  end)
  menuRows[i] = row
  return row
end

function S.Menu(entries, anchor, minWidth)
  if not menu then buildMenu() end
  local width = minWidth or 140
  for i, e in ipairs(entries) do
    local row = menuRow(i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", MENU_PAD, -MENU_PAD - (i - 1) * MENU_ROW)
    row:SetPoint("TOPRIGHT", -MENU_PAD, -MENU_PAD - (i - 1) * MENU_ROW)
    row.func = e.func
    row.text:SetText(e.text)
    row.text:SetTextColor(color(e.title and C.gold or e.color or C.text))
    row.dot:SetShown(e.checked == true)
    row:EnableMouse(not e.title)
    row.hl:SetShown(not e.title)
    width = math.max(width, row.text:GetStringWidth() + 36)
    row:Show()
  end
  for i = #entries + 1, #menuRows do menuRows[i]:Hide() end
  menu:SetSize(width + 2 * MENU_PAD, #entries * MENU_ROW + 2 * MENU_PAD)
  menu:ClearAllPoints()
  menu.home = nil
  if anchor then
    -- opens upward when the anchor sits low on the screen
    local up = (anchor:GetBottom() or 999) * anchor:GetEffectiveScale() / UIParent:GetEffectiveScale() < menu:GetHeight() + 20
    if up then menu:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 4)
    else menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4) end
  else
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 4, y / s - 4)
  end
  catcher:Show()
  menu:Show()
  S.AnimateOpen(menu, 0, 8)
  GameTooltip:Hide()
end

-- Dropdown -----------------------------------------------------------------
-- button with a chevron that flips and a menu; options = { {value, text} }
function S.Dropdown(parent, options, width, getValue, onSelect)
  local b = S.Button(parent, "", width, 22)
  b.text:ClearAllPoints()
  b.text:SetPoint("LEFT", 9, 0)
  b.text:SetPoint("RIGHT", -22, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b:SetScript("OnMouseDown", nil)
  b:SetScript("OnMouseUp", nil)
  local chev = S.Chevron(b, 8, C.gold)
  chev:SetPoint("RIGHT", -9, 0)
  local function refresh()
    local v = getValue()
    for _, o in ipairs(options) do if o[1] == v then b:SetText(o[2]) end end
  end
  b:SetScript("OnClick", function(self)
    local entries = {}
    local v = getValue()
    for _, o in ipairs(options) do
      entries[#entries + 1] = { text = o[2], checked = o[1] == v, func = function() onSelect(o[1]); refresh() end }
    end
    chev:Point("up", true)
    S.Menu(entries, self, width - 10)
  end)
  -- the chevron turns back once the menu closes
  b:SetScript("OnUpdate", function()
    if chev.up and not (menu and menu:IsShown()) then chev.up = nil; chev:Point("down", true) end
    if menu and menu:IsShown() and not chev.up then chev.up = true end
  end)
  b.Refresh = refresh
  refresh()
  return b
end

-- Dialog -------------------------------------------------------------------
-- small rounded dialog: text, optional edit box, accept / cancel. Enter accepts, Escape cancels.
-- opts = { text, edit = bool, value, maxLetters, accept, cancel, onAccept(text) }
local dialog
local function buildDialog()
  local d = CreateFrame("Frame", "AltDashboardForeverDialog", UIParent)
  d:SetSize(360, 130)
  d:SetPoint("CENTER", 0, 120)
  d:SetFrameStrata("FULLSCREEN_DIALOG")
  d:SetFrameLevel(50)
  d:EnableMouse(true)
  d:SetClampedToScreen(true)
  S.Shadow(d, 16, 0.75)
  S.Rounded(d, 10)
  S.EdgeGlow(d, 32, 0.14)
  local top = S.Rule(d, C.gold, 0.55)
  top:SetPoint("TOPLEFT", 30, -1)
  top:SetPoint("TOPRIGHT", -30, -1)
  d.text = S.Text(d, 13, "text")
  d.text:SetPoint("TOPLEFT", 18, -18)
  d.text:SetPoint("TOPRIGHT", -18, -18)
  d.text:SetJustifyH("CENTER")
  d.text:SetSpacing(2)
  d.edit = S.EditBox(d, 324, 24)
  d.edit:SetPoint("TOP", d.text, "BOTTOM", 0, -12)
  d.ok = S.Button(d, OKAY, 120, 24, nil, true)
  d.no = S.Button(d, CANCEL, 120, 24)
  d.ok:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 16)
  d.no:SetPoint("BOTTOMLEFT", d, "BOTTOM", 6, 16)
  d.no:SetScript("OnClick", function() S.Close(d) end)
  d.ok:SetScript("OnClick", function()
    local cb, txt = d.onAccept, d.edit:GetText()
    S.Close(d)
    if cb then cb(d.hasEdit and strtrim(txt or "") or nil) end
  end)
  d.edit:SetScript("OnEnterPressed", function() d.ok:Click() end)
  d.edit:SetScript("OnEscapePressed", function() S.Close(d) end)
  d:Hide()
  tinsert(UISpecialFrames, d:GetName())
  return d
end

function S.Dialog(opts)
  dialog = dialog or buildDialog()
  local d = dialog
  d.onAccept, d.hasEdit = opts.onAccept, opts.edit
  d.text:SetText(opts.text or "")
  d.ok:SetText(opts.accept or OKAY)
  d.no:SetText(opts.cancel or CANCEL)
  d.edit:SetShown(opts.edit == true)
  d.edit:SetMaxLetters(opts.maxLetters or 0)
  d.edit:SetText(opts.value or "")
  d:SetHeight(d.text:GetStringHeight() + (opts.edit and 104 or 74))
  if d:IsShown() then S.StopTween(d); d:Hide() end
  d.home = nil
  d:ClearAllPoints()
  d:SetPoint("CENTER", 0, 120)
  d:Show()
  S.AnimateOpen(d, 0, -10)
  if opts.edit then d.edit:SetFocus() end
end

-- Scroll frame with a thin bar ---------------------------------------------
-- returns the scroll frame and its content (caller sets the content width); smooth wheel
function S.Scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(1, 1)
  sf:SetScrollChild(content)

  local bar = CreateFrame("Slider", nil, parent)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(4)
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, -2)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 2)
  bar:SetHitRectInsets(-4, -4, 0, 0)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0, 0, 0, 0.45)
  local thumb = bar:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(WHITE)
  thumb:SetSize(4, 30)
  thumb:SetVertexColor(color(C.ring))
  bar:SetThumbTexture(thumb)
  bar:SetMinMaxValues(0, 0)
  bar:SetValue(0)
  bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
  bar:SetScript("OnEnter", function() thumb:SetVertexColor(color(C.accent)) end)
  bar:SetScript("OnLeave", function() thumb:SetVertexColor(color(C.ring)) end)

  sf:SetScript("OnScrollRangeChanged", function(self)
    local range = self:GetVerticalScrollRange()
    local h = self:GetHeight()
    bar:SetMinMaxValues(0, range)
    bar:SetShown(range > 0)
    if h > 0 then thumb:SetHeight(math.max(20, h * h / (h + range))) end
    if bar:GetValue() > range then bar:SetValue(range) end
  end)
  sf:EnableMouseWheel(true)
  local target = 0
  sf:SetScript("OnMouseWheel", function(_, d)
    local _, hi = bar:GetMinMaxValues()
    target = math.max(0, math.min(hi, (tweens[bar] and target or bar:GetValue()) - d * 60))
    S.Tween(bar, { dur = 0.25, from = bar:GetValue(), to = target, set = function(v) bar:SetValue(v) end })
  end)
  bar:Hide()
  sf.bar = bar
  return sf, content
end

-- Bar ----------------------------------------------------------------------
-- dark track, gradient fill easing to new values, optional second (lighter) fill behind it
-- kind: "xp" (blue) or "gold"
function S.Bar(parent, width, height, kind)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(width, height or 6)
  S.Box(bar, { 0, 0, 0, 0.6 }, false)
  local inner = width
  local back = bar:CreateTexture(nil, "BORDER")
  back:SetPoint("TOPLEFT"); back:SetPoint("BOTTOMLEFT")
  back:SetColorTexture(color(C.rest))
  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT"); fill:SetPoint("BOTTOMLEFT")
  if kind == "gold" then gradient(fill, C.gold1, C.gold2) else gradient(fill, C.xp1, C.xp2) end
  local shown, shownBack = 0, 0
  local target, targetBack = 0, 0
  local function place(f)
    shown = f
    fill:SetWidth(math.max(0.01, inner * f))
    fill:SetShown(f > 0.002)
  end
  local function placeBack(f)
    shownBack = f
    back:SetWidth(math.max(0.01, inner * f))
    back:SetShown(f > 0.002)
  end
  place(0); placeBack(0)
  function bar:SetWidthPx(w) inner = w; self:SetWidth(w); place(shown); placeBack(shownBack) end
  function bar:SetValue(f, instant)
    f = math.max(0, math.min(1, f or 0))
    target = f
    if instant or not self:IsVisible() or math.abs(f - shown) < 0.001 then
      S.StopTween(fill); place(f)
    else
      S.Tween(fill, { dur = 0.6, from = shown, to = f, set = place })
    end
  end
  function bar:SetSecond(f, instant)
    f = math.max(0, math.min(1, f or 0))
    targetBack = f
    if instant or not self:IsVisible() or math.abs(f - shownBack) < 0.001 then
      S.StopTween(back); placeBack(f)
    else
      S.Tween(back, { dur = 0.6, from = shownBack, to = f, set = placeBack })
    end
  end
  -- replays the fill from empty (page shown)
  function bar:Replay(delay)
    local to, toBack = target, targetBack
    place(0); placeBack(0)
    S.Tween(fill, { dur = 0.7, delay = delay, from = 0, to = to, set = place })
    if toBack > 0 then S.Tween(back, { dur = 0.7, delay = delay, from = 0, to = toBack, set = placeBack }) end
  end
  return bar
end
