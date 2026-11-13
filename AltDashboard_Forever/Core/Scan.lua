-- Alt Dashboard (Forever): records the logged-in character (level, gold, skills, cooldowns, reps, lockouts, gear, mail, auctions)
local _, ns = ...
local L = ns.L

local function me() return ns.db.chars[ns.me] end

local spellName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
local isKnown = IsPlayerSpell or IsSpellKnown

local function spellCooldown(id)
  if C_Spell and C_Spell.GetSpellCooldown then
    local cd = C_Spell.GetSpellCooldown(id)
    if cd then return cd.startTime, cd.duration end
  end
  return GetSpellCooldown(id)
end
local itemCooldown = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
local itemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

-- remaining seconds (GetTime based) -> epoch expiry, saved across characters
local function expiry(start, duration)
  if not start or not duration or start == 0 or duration <= 1.5 then return time() end
  return time() + (start + duration - GetTime())
end

local function scanBasics(c)
  -- the surname can arrive after login: never replace a full name by the bare first name
  local name = ns.FullName("player")
  if not c.name or #name >= #c.name or not c.name:find(name, 1, true) then c.name = name end
  c.realm = GetRealmName()
  c.mailName = UnitName("player") -- the name to write in the mail "To" field
  c.className, c.class = UnitClass("player")
  c.faction = UnitFactionGroup("player")
  c.level = UnitLevel("player")
  c.money = GetMoney()
  c.xp, c.xpMax = UnitXP("player"), UnitXPMax("player")
  c.rested = GetXPExhaustion() or 0
  c.resting = IsResting()
  c.zone = GetRealZoneText()
  c.talentPoints = UnitCharacterPoints and (UnitCharacterPoints("player")) or nil
  c.lastSeen = time()
  -- one gold total per day, for the Gold tab
  if c.money > 0 or c.level > 1 then
    local h = ns.db.goldHistory
    h[date("%Y-%m-%d")] = ns.TotalGold()
    local keys = {}
    for k in pairs(h) do keys[#keys + 1] = k end
    table.sort(keys)
    for i = 1, #keys - 60 do h[keys[i]] = nil end
  end
end

local function isRiding(name)
  return name:find("Riding") or name:find("Horsemanship") or name:find("Piloting")
    or name:find("^Monte") or name:find("quitation") or name:find("Pilotage")
end

-- average item level (shirt and tabard ignored) and lowest durability
local itemLevel = function(link)
  if ns.GetDetailedItemLevelInfo then return (ns.GetDetailedItemLevelInfo(link)) end
  return (select(4, ns.GetItemInfo(link)))
end
local function scanGear(c)
  local sum, n, lowest = 0, 0, 100
  for slot = 1, 18 do
    if slot ~= 4 then
      local link = GetInventoryItemLink("player", slot)
      local ilvl = link and itemLevel(link)
      if ilvl and ilvl > 0 then sum, n = sum + ilvl, n + 1 end
      local cur, max = GetInventoryItemDurability(slot)
      if cur and max and max > 0 then lowest = math.min(lowest, math.floor(cur / max * 100)) end
    end
  end
  c.ilvl = n > 0 and math.floor(sum / n + 0.5) or nil
  c.durability = lowest
end

-- Mail: count, soonest expiry and gold waiting
local function scanMail(c)
  local n = GetInboxNumItems()
  local soonest, money = nil, 0
  for i = 1, n do
    local _, _, _, _, m, _, daysLeft = GetInboxHeaderInfo(i)
    money = money + (m or 0)
    if daysLeft then
      local exp = time() + daysLeft * 86400
      if not soonest or exp < soonest then soonest = exp end
    end
  end
  -- the real mailbox replaces what was sent by the other characters (it includes it)
  c.mail = { count = n, expires = soonest, money = money, new = false }
end

-- Mail sent to one of our alts: added to its mailbox right away, without logging on it ------
local MAIL_DAYS = 30

-- accented Latin letters (UTF-8, 0xC3 xx) -> plain letter: "Mïne" and "Mine" are the same name
local PLAIN = {}
do
  local groups = {
    a = "\128\129\130\131\132\133\160\161\162\163\164\165", c = "\135\167", e = "\136\137\138\139\168\169\170\171",
    i = "\140\141\142\143\172\173\174\175", n = "\145\177", o = "\146\147\148\149\150\152\178\179\180\181\182\184",
    u = "\153\154\155\156\185\186\187\188", y = "\157\189\191",
  }
  for letter, bytes in pairs(groups) do
    for k = 1, #bytes do PLAIN["\195" .. bytes:sub(k, k)] = letter end
  end
end
local function norm(s)
  s = (s or ""):lower():gsub("\195[\128-\191]", function(ch) return PLAIN[ch] or ch end)
  return (s:gsub("[%s'%-]", ""))
end

-- the alt a recipient ("Name" or "Name-Realm") stands for: compared with the character's real
-- name, its displayed full name ("Daeler Backbi") and the first word of it, without accents
local function findAlt(recipient)
  local name, realm = strsplit("-", strtrim(recipient or ""), 2)
  name = norm(name)
  if name == "" then return end
  local wantRealm = norm(realm and realm ~= "" and realm or GetRealmName())
  for key, c in pairs(ns.db.chars) do
    if key ~= ns.me and norm(c.realm) == wantRealm then
      local full = c.name or ""
      if name == norm(c.mailName) or name == norm(full) or name == norm(full:match("^(%S+)")) then return c end
    end
  end
end

local outgoing -- mail waiting for the server's answer
local onMailSent
local function onSendMail(recipient, subject)
  -- some UIs pass nothing: read the "To" field of the send frame
  if (not recipient or recipient == "") and SendMailNameEditBox then recipient = SendMailNameEditBox:GetText() end
  local c = findAlt(recipient)
  if not c then outgoing = nil return end
  local items = 0
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    if GetSendMailItem and GetSendMailItem(i) then items = items + 1 end
  end
  local cod = GetSendMailCOD and GetSendMailCOD() or 0
  local m = {
    key = c.key, subject = subject, items = items,
    money = cod > 0 and 0 or (GetSendMailMoney and GetSendMailMoney() or 0),
  }
  outgoing = m
  -- the success event does not exist on every client: without a failure, count it after 3 s
  C_Timer.After(3, function() if outgoing == m then onMailSent() end end)
end

function onMailSent()
  local m = outgoing
  outgoing = nil
  local c = m and ns.db.chars[m.key]
  if not c then return end
  local now = time()
  c.mail = c.mail or { count = 0, money = 0 }
  c.mail.count = (c.mail.count or 0) + 1
  c.mail.money = (c.mail.money or 0) + m.money
  c.mail.new = true
  c.mail.expires = math.min(c.mail.expires or math.huge, now + MAIL_DAYS * 86400)
  c.mail.incoming = c.mail.incoming or {}
  table.insert(c.mail.incoming, { from = me().name, at = now, subject = m.subject, items = m.items, money = m.money })
  print(ns.PREFIX .. L["Mail recorded for %s."]:format(ns.ColoredName(c)))
  ns.RefreshAll()
end

if SendMail then hooksecurefunc("SendMail", onSendMail) end
if C_Mail and C_Mail.SendMail then hooksecurefunc(C_Mail, "SendMail", onSendMail) end

-- Auction house: own auctions (count, total buyout, latest estimated end)
local TIME_LEFT = { 1800, 7200, 28800, 86400 }
local function scanAuctions(c)
  if not GetNumAuctionItems then return end
  local n = GetNumAuctionItems("owner")
  local value, latest = 0, time()
  for i = 1, n do
    local buyout = select(10, GetAuctionItemInfo("owner", i))
    value = value + (buyout or 0)
    local left = TIME_LEFT[GetAuctionItemTimeLeft("owner", i) or 0]
    if left then latest = math.max(latest, time() + left) end
  end
  c.auctions = { count = n, value = value, expires = latest, scanned = time() }
end

-- /played without the chat message
local silentPlayed
local origDisplay = ChatFrame_DisplayTimePlayed
if origDisplay then
  ChatFrame_DisplayTimePlayed = function(...)
    if silentPlayed then silentPlayed = nil return end
    return origDisplay(...)
  end
end

local function scanSkills(c)
  local prof, sec, riding = {}, {}, false
  local seen = {}
  local function add(name, rank, maxRank)
    -- C_SkillInfo (WoW Forever) can list the same skill twice: keep each name once
    if not name or seen[name] then return end
    seen[name] = true
    if ns.PROFESSIONS[name] then
      prof[#prof + 1] = { name = name, rank = rank, max = maxRank, icon = ns.PROFESSIONS[name] }
    elseif ns.SECONDARY[name] then
      sec[#sec + 1] = { name = name, rank = rank, max = maxRank, icon = ns.SECONDARY[name] }
    elseif isRiding(name) then
      riding = true
    end
  end

  local SI = C_SkillInfo
  if SI and SI.GetNumSkillLines and SI.GetSkillLineInfo then
    -- WoW Forever: the global skill-line API is replaced by C_SkillInfo.
    -- Expand collapsed headers first (back to front: expanding shifts the next indices)
    if SI.ExpandSkillHeader then
      for i = SI.GetNumSkillLines() or 0, 1, -1 do
        local s = SI.GetSkillLineInfo(i)
        if s and s.isHeader and s.isCollapsed then SI.ExpandSkillHeader(i) end
      end
    end
    for i = 1, SI.GetNumSkillLines() or 0 do
      local s = SI.GetSkillLineInfo(i)
      if s and not s.isHeader then
        add(s.name, s.rank or 0, s.maxRank or s.max or s.skillMaxRank or 0)
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() or 0 do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      if not isHeader then add(name, rank, maxRank) end
    end
  elseif GetProfessions and GetProfessionInfo then
    -- clients without the skill-line API: professions only, riding unknown
    riding = nil
    for _, idx in pairs({ GetProfessions() }) do
      if idx then
        local name, _, rank, maxRank = GetProfessionInfo(idx)
        add(name, rank, maxRank)
      end
    end
  else
    return -- no API to read skills: keep what was saved
  end
  c.professions, c.secondary, c.riding = prof, sec, riding
end

local function scanCooldowns(c)
  local list = {}
  for _, def in ipairs(ns.COOLDOWNS) do
    if def.spells then
      for _, id in ipairs(def.spells) do
        if isKnown(id) then
          local start, duration = spellCooldown(id)
          list[def.key] = { name = spellName(id), icon = def.icon, expires = expiry(start, duration) }
          break
        end
      end
    elseif def.item and (itemCount(def.item) or 0) > 0 then
      local start, duration = itemCooldown(def.item)
      local name = (C_Item and C_Item.GetItemNameByID or ns.GetItemInfo)(def.item) or ("item:" .. def.item)
      list[def.key] = { name = name, icon = def.icon, expires = expiry(start, duration) }
    end
  end
  c.cooldowns = list
end

local function factionAt(i)
  if C_Reputation and C_Reputation.GetFactionDataByIndex then
    local d = C_Reputation.GetFactionDataByIndex(i)
    if not d then return end
    return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding,
      d.isHeader and not d.isHeaderWithRep, d.isWatched
  end
  local name, _, standing, bMin, bMax, value, _, _, isHeader, _, hasRep, isWatched = GetFactionInfo(i)
  return name, standing, bMin, bMax, value, isHeader and not hasRep, isWatched
end

local function scanReputations(c)
  local reps, watched = {}, nil
  local n = (C_Reputation and C_Reputation.GetNumFactions or GetNumFactions)()
  for i = 1, n do
    local name, standing, bMin, bMax, value, isHeader, isWatched = factionAt(i)
    if name and not isHeader and standing then
      reps[#reps + 1] = { name = name, standing = standing, value = value - bMin, max = bMax - bMin }
      if isWatched then watched = name end
    end
  end
  c.reputations, c.watched = reps, watched
end

local function scanLockouts(c)
  local list = {}
  for i = 1, GetNumSavedInstances() do
    local name, _, reset, _, locked, _, _, isRaid, _, _, numEnc, progress = GetSavedInstanceInfo(i)
    if name and locked and reset and reset > 0 then
      list[#list + 1] = { name = name, expires = time() + reset, raid = isRaid, bosses = numEnc, killed = progress }
      if isRaid then ns.db.seenRaids[name] = true end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  c.lockouts = list
end

-- Events (throttled: one refresh per burst) ------------------------------
local SCANS = {
  { "basics", scanBasics }, { "skills", scanSkills }, { "cooldowns", scanCooldowns },
  { "reps", scanReputations }, { "lockouts", scanLockouts }, { "gear", scanGear },
  { "mail", scanMail }, { "auctions", scanAuctions },
}

-- one broken scan (missing API on some client) must not stop the others:
-- the error is reported once per session, the scan is retried on later events
local reported = {}
local function safeScan(name, fn, c)
  local ok, err = pcall(fn, c)
  if not ok and not reported[name] then
    reported[name] = true
    geterrorhandler()(err)
  end
end

local pending = {}
local function queue(what)
  if next(pending) == nil then
    C_Timer.After(0.5, function()
      local c = me()
      local todo = pending
      pending = {}
      for _, step in ipairs(SCANS) do
        if todo[step[1]] then safeScan(step[1], step[2], c) end
      end
      ns.RefreshAll()
    end)
  end
  pending[what] = true
end

function ns.ScanAll()
  for _, w in ipairs({ "basics", "skills", "cooldowns", "reps", "lockouts", "gear" }) do queue(w) end
  if RequestRaidInfo then RequestRaidInfo() end
end

local EVENTS = {
  PLAYER_MONEY = "basics", PLAYER_LEVEL_UP = "basics", PLAYER_XP_UPDATE = "basics",
  UPDATE_EXHAUSTION = "basics", PLAYER_ENTERING_WORLD = "basics", UNIT_NAME_UPDATE = "basics", PLAYER_PVP_RANK_CHANGED = "basics", PLAYER_UPDATE_RESTING = "basics", ZONE_CHANGED_NEW_AREA = "basics",
  SKILL_LINES_CHANGED = "skills", CHAT_MSG_SKILL = "skills",
  SPELL_UPDATE_COOLDOWN = "cooldowns", BAG_UPDATE_COOLDOWN = "cooldowns", TRADE_SKILL_UPDATE = "cooldowns",
  UPDATE_FACTION = "reps",
  UPDATE_INSTANCE_INFO = "lockouts",
  CHARACTER_POINTS_CHANGED = "basics",
  UPDATE_INVENTORY_DURABILITY = "gear", PLAYER_EQUIPMENT_CHANGED = "gear",
  MAIL_INBOX_UPDATE = "mail",
  AUCTION_OWNED_LIST_UPDATE = "auctions", OWNED_AUCTIONS_UPDATED = "auctions",
}

function ns.InitScan()
  ns.db.chars[ns.me] = ns.db.chars[ns.me] or { key = ns.me }
  safeScan("basics", scanBasics, me())
  local f = CreateFrame("Frame")
  for e in pairs(EVENTS) do pcall(f.RegisterEvent, f, e) end
  f:RegisterEvent("PLAYER_LOGOUT")
  f:RegisterEvent("TIME_PLAYED_MSG")
  f:RegisterEvent("UPDATE_PENDING_MAIL")
  pcall(f.RegisterEvent, f, "MAIL_SEND_SUCCESS")
  pcall(f.RegisterEvent, f, "MAIL_FAILED")
  f:SetScript("OnEvent", function(_, event, a1)
    if event == "TIME_PLAYED_MSG" then
      me().played = a1
    elseif event == "MAIL_SEND_SUCCESS" then
      onMailSent()
    elseif event == "MAIL_FAILED" then
      outgoing = nil
    elseif event == "UPDATE_PENDING_MAIL" then
      local c = me()
      c.mail = c.mail or { count = 0 }
      c.mail.new = HasNewMail() or nil
      ns.RefreshAll()
    elseif event == "PLAYER_LOGOUT" then
      -- money/name can read empty while logging out: only keep the time and rested state
      local c = me()
      c.lastSeen, c.resting = time(), IsResting()
      c.rested = GetXPExhaustion() or c.rested
    else
      queue(EVENTS[event])
    end
  end)
  -- skills/reps/cooldowns, money and the surname are not ready at login
  C_Timer.After(3, ns.ScanAll)
  C_Timer.After(10, function() queue("basics") end)
  C_Timer.After(30, function() queue("basics") end)
  C_Timer.After(5, function()
    silentPlayed = true
    RequestTimePlayed()
    C_Timer.After(10, function() silentPlayed = nil end)
  end)

  C_Timer.After(8, function()
    local n = 0
    for _, c in pairs(ns.db.chars) do n = n + #ns.GetTasks(c) end
    if n > 0 then print(ns.PREFIX .. L["%d tasks for your alts this week"]:format(n) .. "  |cff808080/alts|r") end
  end)
end
