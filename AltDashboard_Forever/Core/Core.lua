-- Alt Dashboard (Forever): constants, saved data, helpers, tasks, startup
local ADDON, ns = ...
local L = ns.L

ns.ADDON_ICON = "Interface\\AddOns\\AltDashboard_Forever\\media\\icon"ns.PREFIX = "|cff33ff99Alt Dashboard|r: "

-- Profession names (EN + FR) -> icon; everything else in the skill list is ignored
ns.PROFESSIONS = {
  Alchemy = "Trade_Alchemy", Alchimie = "Trade_Alchemy",
  Blacksmithing = "Trade_BlackSmithing", Forge = "Trade_BlackSmithing",
  Enchanting = "Trade_Engraving", Enchantement = "Trade_Engraving",
  Engineering = "Trade_Engineering", ["Ingénierie"] = "Trade_Engineering",
  Herbalism = "Spell_Nature_NatureTouchGrow", Herboristerie = "Spell_Nature_NatureTouchGrow",
  Leatherworking = "INV_Misc_ArmorKit_17", ["Travail du cuir"] = "INV_Misc_ArmorKit_17",
  Mining = "Trade_Mining", Minage = "Trade_Mining",
  Skinning = "INV_Misc_Pelt_Wolf_01", ["Dépeçage"] = "INV_Misc_Pelt_Wolf_01",
  Tailoring = "Trade_Tailoring", Couture = "Trade_Tailoring",
}
ns.SECONDARY = {
  Cooking = "INV_Misc_Food_15", Cuisine = "INV_Misc_Food_15",
  ["First Aid"] = "Spell_Holy_SealOfSacrifice", Secourisme = "Spell_Holy_SealOfSacrifice",
  Fishing = "Trade_Fishing", ["Pêche"] = "Trade_Fishing",
}

-- Tracked cooldowns: spells (transmutes share one cooldown) and items
ns.COOLDOWNS = {
  { key = "transmute", spells = { 17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 25146 }, icon = "Trade_Alchemy" },
  { key = "mooncloth", spells = { 18560 }, icon = "INV_Fabric_Moonrag_01" },
  { key = "saltshaker", item = 15846, icon = "INV_Egg_05" },
}

ns.RIDING_LEVEL = 40
ns.LOW_DURABILITY = 25
ns.MAIL_WARN_DAYS = 3
local WEEK, DAY = 604800, 86400

-- Helpers ----------------------------------------------------------------
-- item API: global on some clients, only in C_Item on others
ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

-- full name ("Daeler Backbi"), without the PvP rank placed before it
function ns.FullName(unit)
  local first = UnitName(unit)
  local full = UnitPVPName and UnitPVPName(unit)
  local i = full and first and full:find(first, 1, true)
  return i and full:sub(i) or first
end

-- key of a character from "Name" or "Name-Realm" (for /alts remove)
function ns.FindChar(text)
  text = text:lower()
  for key, c in pairs(ns.db.chars) do
    local name = (c.name or ""):lower()
    if name == text or (name .. "-" .. (c.realm or "")):lower() == text then return key end
  end
end

function ns.FormatTime(sec)
  sec = math.max(0, math.floor(sec))
  local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
  if d > 0 then return ("%d%s %dh"):format(d, ns.IS_FRENCH and "j" or "d", h) end
  if h > 0 then return ("%dh %02dm"):format(h, m) end
  return ("%dm"):format(math.max(m, 1))
end

function ns.FormatShortTime(sec)
  sec = math.max(0, sec)
  if sec >= 86400 then return math.floor(sec / 86400) .. (ns.IS_FRENCH and "j" or "d") end
  if sec >= 3600 then return math.floor(sec / 3600) .. "h" end
  return math.max(1, math.floor(sec / 60)) .. "m"
end

function ns.FormatPlayed(sec)
  sec = math.floor(sec or 0)
  return ("%d%s %dh"):format(math.floor(sec / 86400), ns.IS_FRENCH and "j" or "d", math.floor(sec % 86400 / 3600))
end

function ns.Money(copper, noCopper)
  copper = copper or 0
  if noCopper then copper = copper - copper % 100 end
  local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
  local coin = "|TInterface\\MoneyFrame\\UI-%sIcon:12:12:2:0|t"
  local parts = {}
  if g > 0 then parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) .. coin:format("Gold") end
  if s > 0 or (g > 0 and not noCopper) then parts[#parts + 1] = s .. coin:format("Silver") end
  if not noCopper or #parts == 0 then parts[#parts + 1] = c .. coin:format("Copper") end
  return table.concat(parts, " ")
end

function ns.ClassColor(c)
  local col = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[c.class or ""]
  return col and col.colorStr and ("|c" .. col.colorStr) or "|cffffffff"
end

function ns.ColoredName(c) return ns.ClassColor(c) .. (c.name or "?") .. "|r" end

-- Rested XP estimated since the last logout (5% of a level per 8h resting, 1/4 of that elsewhere)
function ns.RestedPercent(c)
  if not c.xpMax or c.xpMax == 0 or (c.level or 0) >= ns.MAX_LEVEL then return nil end
  local rested = c.rested or 0
  if c.key ~= ns.me and c.lastSeen then
    local rate = c.resting and 1 or 0.25
    rested = rested + (time() - c.lastSeen) / 28800 * 0.05 * c.xpMax * rate
  end
  return math.min(150, math.floor(rested / c.xpMax * 100))
end

-- Lockouts still running
function ns.ActiveLockouts(c)
  local list, now = {}, time()
  for _, lo in ipairs(c.lockouts or {}) do
    if lo.expires > now then list[#list + 1] = lo end
  end
  return list
end

-- Resets -----------------------------------------------------------------
-- next weekly reset (epoch): Wednesday 3:00 in local time
local RESET_WDAY, RESET_HOUR = 4, 3 -- date() weekday: 1 = Sunday, 4 = Wednesday
function ns.NextWeeklyReset()
  local now = time()
  local t = date("*t", now)
  local reset = time({ year = t.year, month = t.month, day = t.day + (RESET_WDAY - t.wday) % 7,
    hour = RESET_HOUR, min = 0, sec = 0 })
  if reset <= now then
    reset = time({ year = t.year, month = t.month, day = t.day + (RESET_WDAY - t.wday) % 7 + 7,
      hour = RESET_HOUR, min = 0, sec = 0 })
  end
  return reset
end

function ns.NextDailyReset()
  local s = GetQuestResetTime and GetQuestResetTime()
  if s and s > 0 then return time() + s end
end

-- Custom checklist -------------------------------------------------------
-- an entry is done when it was ticked after the last reset of its period
function ns.IsCheckDone(c, item)
  local at = c.checks and c.checks[item.id]
  if not at then return false end
  local nextReset = item.daily and ns.NextDailyReset() or ns.NextWeeklyReset()
  if not nextReset then return true end
  return at > nextReset - (item.daily and DAY or WEEK)
end

function ns.SetCheckDone(c, item, done)
  c.checks = c.checks or {}
  c.checks[item.id] = done and time() or nil
  ns.RefreshAll()
end

function ns.CheckApplies(c, item) return (c.level or 0) >= (item.minLevel or 1) end

function ns.AddCheck(name, minLevel, daily)
  ns.db.nextCheckId = (ns.db.nextCheckId or 0) + 1
  table.insert(ns.db.checklist, { id = ns.db.nextCheckId, name = name, minLevel = minLevel, daily = daily or nil })
  ns.RefreshAll()
end

function ns.RemoveCheck(id)
  for i, item in ipairs(ns.db.checklist) do
    if item.id == id then table.remove(ns.db.checklist, i) break end
  end
  ns.RefreshAll()
end

-- Tasks ------------------------------------------------------------------
-- each task: text (+ kind, used by the compact window icons)
function ns.GetTasks(c)
  local tasks, now = {}, time()
  local function add(text) tasks[#tasks + 1] = text end
  local level = c.level or 0

  for _, cd in pairs(c.cooldowns or {}) do
    if cd.expires <= now then add(L["Cooldown ready: %s"]:format(cd.name)) end
  end

  if level >= ns.MAX_LEVEL then
    local saved = {}
    for _, lo in ipairs(ns.ActiveLockouts(c)) do saved[lo.name] = true end
    local raids = {}
    for name in pairs(ns.db.seenRaids) do if not ns.db.ignoredRaids[name] then raids[#raids + 1] = name end end
    table.sort(raids)
    for _, name in ipairs(raids) do
      if not saved[name] then add(L["Not saved: %s"]:format(name)) end
    end
  elseif (ns.RestedPercent(c) or 0) >= 150 then
    add(L["Rested XP full"])
  end

  for _, item in ipairs(ns.db.checklist) do
    if ns.CheckApplies(c, item) and not ns.IsCheckDone(c, item) then add(item.name) end
  end

  if (c.talentPoints or 0) > 0 then add(L["%d talent points to spend"]:format(c.talentPoints)) end
  if level >= ns.RIDING_LEVEL and c.riding == false then add(L["Learn riding"]) end
  for _, p in ipairs(c.professions or {}) do
    if p.rank >= p.max and p.max < 300 then add(L["Visit your %s trainer (%d/%d)"]:format(p.name, p.rank, p.max)) end
  end
  if c.durability and c.durability <= ns.LOW_DURABILITY then add(L["Repair your gear (%d%%)"]:format(c.durability)) end

  if c.mail then
    if c.mail.expires and c.mail.expires - now < ns.MAIL_WARN_DAYS * DAY then
      add(L["Mail expires in %s"]:format(ns.FormatTime(c.mail.expires - now)))
    elseif (c.mail.count or 0) > 0 or c.mail.new then
      add(L["Mail waiting"])
    end
  end
  if c.auctions and c.auctions.count > 0 and c.auctions.expires <= now then add(L["Auctions ended: check the mailbox"]) end

  if c.note and c.note ~= "" then add("|cff99ccff" .. c.note .. "|r") end
  return tasks
end

function ns.VisibleChars()
  local list, realm = {}, GetRealmName()
  for _, c in pairs(ns.db.chars) do
    if not ns.db.currentRealmOnly or c.realm == realm then list[#list + 1] = c end
  end
  table.sort(list, function(a, b)
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    return (a.name or "") < (b.name or "")
  end)
  return list
end

function ns.TotalGold()
  local total = 0
  for _, c in pairs(ns.db.chars) do total = total + (c.money or 0) end
  return total
end

function ns.RemoveChar(key)
  if not ns.db.chars[key] or key == ns.me then return false end
  ns.db.chars[key] = nil
  ns.RefreshAll()
  return true
end

-- every open view
function ns.RefreshAll()
  if ns.RefreshDashboard then ns.RefreshDashboard() end
  if ns.RefreshMini then ns.RefreshMini() end
end

-- Startup ----------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    AltDashboardForeverDB = AltDashboardForeverDB or {}
    local db = AltDashboardForeverDB
    ns.db = db
    db.chars = db.chars or {}
    db.seenRaids = db.seenRaids or {}
    db.ignoredRaids = db.ignoredRaids or {}
    db.checklist = db.checklist or {}
    db.items = db.items or {}
    db.goldHistory = db.goldHistory or {}
    db.sort = db.sort or "level"
    db.tab = db.tab or "overview"
    ns.ApplyLanguage(db.lang)
  elseif event == "PLAYER_LOGIN" then
    ns.MAX_LEVEL = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    -- keyed by GUID: WoW Forever characters can share a first name
    ns.me = UnitGUID("player")
    for key in pairs(ns.db.chars) do
      if not key:find("^Player%-") then ns.db.chars[key] = nil end -- old name-realm keys
    end
    ns.InitScan()
    ns.InitInventory()
    ns.InitMinimapButton()
    ns.InitMini()
  end
end)
