-- Constants
SECONDS_PER_MINUTE = 60
INSTANCE_TIMEOUT = 3600
INSTANCE_LIMIT = 5

-- Globals
InstanceCounter = CreateFrame('Frame')
InstanceCounter.visitedInstances = nil
InstanceCounter.insideUnknownInstance = false
InstanceCounter.instanceEnterTime = nil

-- Locals
local self = InstanceCounter;
local events = {}

------------------------------------------
-- Private methods
------------------------------------------

local function SetInsideUnknownInstance(state)
  if self.insideUnknownInstance == state then
    return
  end

  self.insideUnknownInstance = state

  local unitEvents = {
    'NAME_PLATE_UNIT_ADDED',
    'UPDATE_MOUSEOVER_UNIT',
    'PLAYER_TARGET_CHANGED',
  }

  if self.insideUnknownInstance then
    for _, event in ipairs(unitEvents) do self:RegisterEvent(event) end
  else
    for _, event in ipairs(unitEvents) do self:UnregisterEvent(event) end
  end
end

local function OnIdentifiedUnit(guid)
  if not (guid and self.insideUnknownInstance) then
    return
  end

  local type, _, _, _, zoneUid, _, _ = strsplit('-', guid)

  -- Only creatures' zone UIDs can be trusted, pet's may have an origin from elsewhere
  if type == 'Creature' then
    self:UpsertInstanceVisit(GetRealZoneText(), tonumber(zoneUid))
    SetInsideUnknownInstance(false)
  end
end

local function LockTimeRemaining(enterTime, baseTime)
  local timeReference = baseTime or GetServerTime()
  return max(INSTANCE_TIMEOUT - (timeReference - enterTime), 0)
end

------------------------------------------
-- Public methods
------------------------------------------

-- Inserts or updates an instance visit
function InstanceCounter:UpsertInstanceVisit(instanceName, sessionId, enterTime)
  local timestamp = enterTime or self.instanceEnterTime
  assert(timestamp ~= nil, "Instance enter time unknown")

  if self.visitedInstances[sessionId] ~= nil then
    -- TODO: Is it measured from most recent enter time? Including as spirit?
    self.visitedInstances[sessionId].enterTime = timestamp
  else
    self.visitedInstances[sessionId] = {
      enterTime = timestamp,
      instance = instanceName,
      character = UnitName('player'),
    }
  end
end

-- Prints the visited instances to the default chat frame
function InstanceCounter:PrintList()
  for _, visit in pairs(self.visitedInstances) do
    local secondsLeft = LockTimeRemaining(visit.enterTime)
    local showTimeInSeconds = secondsLeft < SECONDS_PER_MINUTE

    print(format(
      '[%s] %s (%s) - %s%s',
      date('%H:%M', visit.enterTime),
      visit.instance,
      visit.character,
      showTimeInSeconds and secondsLeft or math.ceil(secondsLeft / SECONDS_PER_MINUTE),
      showTimeInSeconds and 's' or 'm'
    ))
  end
end

-- Returns whether the account is instance locked or not
function InstanceCounter:IsLocked()
  return #self.visitedInstances > INSTANCE_LIMIT
end

-- Returns the instance lock time remaining, or zero if not applicable
function InstanceCounter:GetLockTimeRemaining()
  if not self:IsLocked() then
    return 0
  end

  local shortestInstanceLock = nil
  for _, visit in pairs(self.visitedInstances) do
    shortestInstanceLock = min(LockTimeRemaining(visit.enterTime), shortestInstanceLock or math.huge)
  end

  return shortestInstanceLock
end

-- Returns the number of visited instances
function InstanceCounter:GetCount()
  return #self.visitedInstances
end

------------------------------------------
-- Event handlers
------------------------------------------

function events.NAME_PLATE_UNIT_ADDED(_, unit) OnIdentifiedUnit(UnitGUID(unit)) end
function events.UPDATE_MOUSEOVER_UNIT(...) OnIdentifiedUnit(UnitGUID('mouseover')) end
function events.PLAYER_TARGET_CHANGED(...) OnIdentifiedUnit(UnitGUID('target')) end

function events.ADDON_LOADED(self, addon, ...)
  if addon == 'InstanceCounter' then
    InstanceCounterDB = InstanceCounterDB or {}
    self.visitedInstances = InstanceCounterDB
  end
end

function events.PLAYER_ENTERING_WORLD(...)
  local inInstance, instanceType = IsInInstance()

  if inInstance and instanceType == 'party' then
    self.instanceEnterTime = GetServerTime()
    SetInsideUnknownInstance(true)
    return
  end

  self.instanceEnterTime = nil

  if self.insideUnknownInstance then
    DEFAULT_CHAT_FRAME:AddMessage('Warning: the previous instance was never identified', 1.0, 0.65, 0.25)
    SetInsideUnknownInstance(false)
  end
end

InstanceCounter:SetScript('OnEvent', function(self, event, ...)
  events[event](self, ...)
end)

InstanceCounter:RegisterEvent('ADDON_LOADED')
InstanceCounter:RegisterEvent('PLAYER_ENTERING_WORLD')

------------------------------------------
-- Command handlers
------------------------------------------

SLASH_INSTANCE_COUNTER1, SLASH_INSTANCE_COUNTER2 = '/ic', '/instancecounter'
function SlashCmdList.INSTANCE_COUNTER(message, editBox)
  self:PrintList()
end
