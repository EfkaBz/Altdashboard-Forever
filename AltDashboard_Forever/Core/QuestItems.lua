-- Alt Dashboard (Forever): quest items in tooltips — which quest an item is for, its progress,
-- and whether the quest is done (the item can be thrown away).
-- Sources: the quest log (objectives), and Questie's database when it is installed
-- (relatedQuests / startQuest of the item), plus the "quest completed" flags of the character.
local _, ns = ...
local L = ns.L

local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
local MAX_QUESTS = 4

local itemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function isCompleted(questID)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(questID) end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(questID) end
  return false
end

-- Quest log cache ---------------------------------------------------------
-- byQuest[questID] = { title, complete }; byItem[item name] = { {questID, have, need} }
local byQuest, byItem, dirty = {}, {}, true

local function numEntries()
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then return C_QuestLog.GetNumQuestLogEntries() end
  return GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
end

-- title, isHeader, isComplete, questID of a quest log line
local function entry(i)
  if C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(i)
    if not info then return end
    local complete = not info.isHeader and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
    return info.title, info.isHeader, complete, info.questID
  end
  local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
  return title, isHeader, isComplete == 1, questID
end

-- item objectives of a quest: { {name, have, need} }
local function itemObjectives(questID, logIndex)
  local list = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
      if o.type == "item" and o.text then list[#list + 1] = { o.text, o.numFulfilled, o.numRequired } end
    end
  elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    for k = 1, GetNumQuestLeaderBoards(logIndex) or 0 do
      local text, kind = GetQuestLogLeaderBoard(k, logIndex)
      if kind == "item" and text then list[#list + 1] = { text } end
    end
  end
  return list
end

local function rebuild()
  dirty = false
  wipe(byQuest)
  wipe(byItem)
  for i = 1, numEntries() do
    local title, isHeader, complete, questID = entry(i)
    if title and not isHeader and questID then
      byQuest[questID] = { title = title, complete = complete }
      for _, o in ipairs(itemObjectives(questID, i)) do
        -- "Bandana rouge : 3/10" or "3/10 Bandana rouge": keep the text, matched against item names
        local text, have, need = o[1], o[2], o[3]
        if not have then
          local a, b = text:match("(%d+)%s*/%s*(%d+)")
          have, need = tonumber(a), tonumber(b)
        end
        byItem[#byItem + 1] = { text = text, questID = questID, have = have, need = need }
      end
    end
  end
end

local watcher = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD" }) do
  pcall(watcher.RegisterEvent, watcher, e)
end
watcher:SetScript("OnEvent", function() dirty = true end)

-- Questie database (optional) ----------------------------------------------
local function questieDB()
  local db = _G.LibQuestieDB
  if type(db) == "table" and db.Item and db.Item.Get and db.Quest and db.Quest.Get then return db end
end

local function dbItem(itemID, key)
  local db = questieDB()
  if not db then return end
  local ok, v = pcall(db.Item.Get, itemID, key)
  return ok and v or nil
end

local function dbQuest(questID, key)
  local db = questieDB()
  if not db then return end
  local ok, v = pcall(db.Quest.Get, questID, key)
  return ok and v or nil
end

-- the database links an item to every version of its quests (other faction, other classes,
-- removed quests): keep the ones this character can do
local band = bit and bit.band
local function doable(questID)
  if byQuest[questID] then return true end
  local db = questieDB()
  if not db then return true end
  if db.Quest.Exists then
    local ok, exists = pcall(db.Quest.Exists, questID)
    if ok and not exists then return false end
  end
  if not band then return true end
  local races = dbQuest(questID, "requiredRaces")
  local raceID = select(3, UnitRace("player"))
  if type(races) == "number" and races > 0 and raceID and band(races, 2 ^ (raceID - 1)) == 0 then return false end
  local classes = dbQuest(questID, "requiredClasses")
  local classID = select(3, UnitClass("player"))
  if type(classes) == "number" and classes > 0 and classID and band(classes, 2 ^ (classID - 1)) == 0 then return false end
  return true
end

-- Full index of the quest database -------------------------------------------
-- index[itemID] = { questID, ... }: every quest that asks for the item (objective), needs it
-- (required source item) or hands it out (source item). Built once, a few hundred quests per
-- frame, so the game never stalls.
local index, indexState = {}, nil -- nil: not started, "building", "done"
local CHUNK = 250

local function link(itemID, questID)
  if type(itemID) ~= "number" then return end
  local list = index[itemID]
  if not list then list = {}; index[itemID] = list end
  for _, q in ipairs(list) do if q == questID then return end end
  list[#list + 1] = questID
end

local function indexQuest(db, questID)
  local ok, v = pcall(db.Quest.GetAll, questID, { "objectives", "sourceItemId", "requiredSourceItems" })
  if not ok or not v then return end
  local objectives, source, required = v[1], v[2], v[3]
  -- objectives: six groups (creature, object, item, reputation, kill credit, spell); items are group 3
  local items = type(objectives) == "table" and objectives[3]
  if type(items) == "table" then
    for _, o in pairs(items) do link(type(o) == "table" and o[1] or o, questID) end
  end
  link(source, questID)
  if type(required) == "table" then
    for _, id in pairs(required) do link(id, questID) end
  end
end

local function buildIndex()
  local db = questieDB()
  if indexState or not db or not db.Quest.GetAllIds or not db.Quest.GetAll then return end
  local ok, ids = pcall(db.Quest.GetAllIds)
  if not ok or type(ids) ~= "table" then return end
  indexState = "building"
  local i = 1
  local function step()
    local last = math.min(#ids, i + CHUNK - 1)
    for k = i, last do indexQuest(db, ids[k]) end
    i = last + 1
    if i > #ids then indexState = "done" else C_Timer.After(0, step) end
  end
  step()
end

local starter = CreateFrame("Frame")
starter:RegisterEvent("PLAYER_LOGIN")
starter:SetScript("OnEvent", function() C_Timer.After(8, buildIndex) end)

local function questName(questID)
  if byQuest[questID] then return byQuest[questID].title end
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local t = C_QuestLog.GetTitleForQuestID(questID)
    if t and t ~= "" then return t end
  end
  local name = dbQuest(questID, "name")
  if type(name) == "string" and name ~= "" then return name end
  if C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, questID) end
  return L["Quest #%d"]:format(questID)
end

-- /alts quest <item link or id>: prints what each source knows about the item
function ns.DebugQuestItem(itemID)
  rebuild()
  local p = function(...) print("|cff33ff99AD|r", ...) end
  local db = questieDB()
  p("item", itemID, "Questie DB:", db and "yes" or "no",
    "class:", itemInfoInstant and select(6, itemInfoInstant(itemID)) or "?")
  local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or ns.GetItemInfo(itemID)
  p("name:", tostring(name))
  for _, o in ipairs(byItem) do
    if name and o.text:find(name, 1, true) then p("log objective:", o.text, "quest", o.questID) end
  end
  local starts = dbItem(itemID, "startQuest")
  if type(starts) == "table" then starts = starts[1] end
  p("startQuest:", tostring(starts))
  local n = 0
  for _ in pairs(index) do n = n + 1 end
  p("index:", tostring(indexState), n, "items; quests for this item:", table.concat(index[itemID] or {}, ", "))
  local logIDs = {}
  for q in pairs(byQuest) do logIDs[#logIDs + 1] = q end
  p("log quests:", table.concat(logIDs, ", "))
  local list = dbItem(itemID, "relatedQuests") or {}
  p("relatedQuests:", #list)
  for _, q in ipairs(index[itemID] or {}) do list[#list + 1] = q end
  if starts then table.insert(list, 1, starts) end
  for _, q in ipairs(list) do
    local exists = db and db.Quest.Exists and select(2, pcall(db.Quest.Exists, q))
    p(("  %d  %s  exists=%s races=%s classes=%s doable=%s done=%s inLog=%s"):format(q,
      tostring(dbQuest(q, "name")), tostring(exists), tostring(dbQuest(q, "requiredRaces")),
      tostring(dbQuest(q, "requiredClasses")), tostring(doable(q)), tostring(isCompleted(q)),
      tostring(byQuest[q] ~= nil)))
  end
end

-- Tooltip ------------------------------------------------------------------
local GOLD, GREEN, RED, GREY, WHITE = "|cffd8b46a", "|cff6ccb8a", "|cffe06a6a", "|cff8392a8", "|cffe2e8f1"

-- status text (right column) of a quest for this item
local function status(questID, objective)
  local q = byQuest[questID]
  if q then
    if q.complete then return GREEN .. L["To turn in"] .. "|r" end
    if objective and objective.need then
      local col = objective.have >= objective.need and GREEN or WHITE
      return col .. objective.have .. "/" .. objective.need .. "|r"
    end
    return WHITE .. L["In progress"] .. "|r"
  end
  if isCompleted(questID) then return GREY .. L["Completed"] .. "|r" end
  return GREY .. L["Not done yet"] .. "|r"
end

function ns.AddQuestItemInfo(tooltip, itemID)
  if not itemID or not ns.db or ns.db.noQuestTooltip then return end
  if dirty then rebuild() end

  -- the name shown in the tooltip is always loaded; the item cache may not be yet
  local name = tooltip.GetItem and tooltip:GetItem()
  if not name or name == "" then
    name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or ns.GetItemInfo(itemID)
  end
  local classID = itemInfoInstant and select(6, itemInfoInstant(itemID))
  local isQuestItem = classID == QUEST_CLASS

  -- quests of the log that ask for this item
  local quests, order, objectiveOf = {}, {}, {}
  local function add(questID)
    if questID and not quests[questID] and doable(questID) then quests[questID] = true; order[#order + 1] = questID end
  end
  if name then
    for _, o in ipairs(byItem) do
      if o.text:find(name, 1, true) then add(o.questID); objectiveOf[o.questID] = o end
    end
  end

  -- the full index of the quest database, matched by item ID: quests of the log always count,
  -- the others only for real quest items (cloth & co would list dozens of quests)
  if not indexState then buildIndex() end
  for _, q in ipairs(index[itemID] or {}) do
    -- quests under a collapsed header are not listed line by line: ask the game directly
    if not byQuest[q] then
      local onQuest = (C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(q))
        or (GetQuestLogIndexByID and (GetQuestLogIndexByID(q) or 0) > 0)
      if onQuest then
        local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
        local complete = C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(q)
        byQuest[q] = { title = (title and title ~= "") and title or questName(q), complete = complete }
      end
    end
    if byQuest[q] then
      add(q)
      if not objectiveOf[q] then
        -- progress: the only item objective of the quest, or the one naming the item
        local only, count = nil, 0
        for _, o in ipairs(byItem) do
          if o.questID == q then count = count + 1; only = o end
        end
        if count == 1 then objectiveOf[q] = only end
      end
    elseif isQuestItem then
      add(q)
    end
  end

  -- what Questie's item table says (only for real quest items as well)
  local starts = dbItem(itemID, "startQuest")
  if type(starts) == "table" then starts = starts[1] end
  if isQuestItem or starts then
    for _, q in ipairs(dbItem(itemID, "relatedQuests") or {}) do add(q) end
  end
  if starts then add(starts) end

  if #order == 0 and not isQuestItem then return end

  tooltip:AddLine(" ")
  if #order == 0 then
    -- a quest item no quest of the log or of the database knows about
    local why = indexState == "building" and L["quest database still loading..."] or L["no quest in your log uses it"]
    tooltip:AddLine(GOLD .. L["Quest item"] .. "|r  " .. GREY .. why .. "|r", 1, 1, 1, true)
    tooltip:Show()
    return
  end

  -- current quests first, then the others
  table.sort(order, function(a, b)
    local la, lb = byQuest[a] ~= nil, byQuest[b] ~= nil
    if la ~= lb then return la end
    return a < b
  end)
  local inLog, pending = false, false
  for i, questID in ipairs(order) do
    if byQuest[questID] then inLog = true
    elseif not isCompleted(questID) then pending = true end
    if i <= MAX_QUESTS then
      local prefix = questID == starts and L["Starts:"] or L["Quest:"]
      tooltip:AddDoubleLine(GOLD .. prefix .. "|r " .. WHITE .. questName(questID) .. "|r", status(questID, objectiveOf[questID]))
    end
  end
  if #order > MAX_QUESTS then
    tooltip:AddLine(GREY .. L["and %d more quests"]:format(#order - MAX_QUESTS) .. "|r")
  end

  -- verdict: every quest done and none in the log -> the item is useless
  if not inLog and not pending then
    tooltip:AddLine(RED .. L["Quest completed: you can throw this item away"] .. "|r", 1, 1, 1, true)
  end
  tooltip:Show()
end
