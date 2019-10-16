-- Constants
SECONDS_PER_MINUTE = 60
INSTANCE_TIMEOUT = 3600
INSTANCE_LIMIT = 5

-- Globals
InstanceCounter = CreateFrame('Frame')

-- Locals
local ADDON_NAME = 'InstanceCounter'
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, 'Version')
local LDB = LibStub:GetLibrary('LibDataBroker-1.1')
local LDBIcon = LibStub('LibDBIcon-1.0')
local self = InstanceCounter

------------------------------------------
-- Private methods
------------------------------------------

-- TODO: Introduce caching & move to util
function StringToColor(string)
  local hash = 0
  for c in string:gmatch('.') do
    hash = c:byte() + bit.lshift(hash, 5) - hash
  end

  local colors = { 'ff' }
  for i=0,2 do
    local value = bit.band(bit.rshift(hash, i * 8), 0xFF)
    colors[#colors + 1] = format('%02x', value)
  end

  return table.concat(colors, '')
end

function NumberToColor(value, max)
  value = value * (510 / max)

  local red = 0
  local green = 0
  if value < 0xFF then
    green = 0xFF;
    red = math.sqrt(value) * 16;
    red = math.floor(red + 0.5)
  else
    red = 0xFF;
    value = value - 0xFF;
    green = 0xFF - (value * value / 0xFF)
    green = math.floor(green + 0.5);
  end

  return format('ff%02x%02x00', red, green)
end

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

local function LockTimeRemaining(enterTime, baseTime)
  local timeReference = baseTime or GetServerTime()
  return max(INSTANCE_TIMEOUT - (timeReference - enterTime), 0)
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

local function RenderTooltip(tooltip)
  tooltip:ClearLines()
  tooltip:AddDoubleLine(ADDON_NAME, ADDON_VERSION)
  tooltip:AddLine(' ')

  local sortedSessions = {}
  for _, session in pairs(self.instanceSessions) do
    sortedSessions[#sortedSessions + 1] = session
  end
  table.sort(sortedSessions, function(a, b) return a.enterTime > b.enterTime end)

  for _, session in ipairs(sortedSessions) do
    local secondsLeft = LockTimeRemaining(session.enterTime)
    local showTimeInSeconds = secondsLeft < SECONDS_PER_MINUTE

    tooltip:AddDoubleLine(
      format(
        '[%s] |cFFEDA55F%s|r (|c%s%s|r)',
        date('%H:%M', session.enterTime),
        session.instance,
        StringToColor(session.character),
        session.character),
      format(
        '|c%s%d%s',
        NumberToColor(secondsLeft, INSTANCE_TIMEOUT),
        showTimeInSeconds and secondsLeft or math.ceil(secondsLeft / SECONDS_PER_MINUTE),
        showTimeInSeconds and 's' or 'm')
    )
  end
end

local function Initialize(sessions)
  self.instanceSessions = sessions
  self.insideUnknownInstance = false
  self.instanceEnterTime = nil
  self.broker = LDB:NewDataObject(ADDON_NAME, {
    type = 'data source',
    text = ADDON_NAME,
    icon = 'Interface\\Icons\\INV_Chest_Cloth_17',
    OnTooltipShow = RenderTooltip,
  })
end

local function RemoveExpiredInstances()
  local cachedTime = GetServerTime()

  for sessionId, session in pairs(self.instanceSessions) do
    if LockTimeRemaining(session.enterTime, cachedTime) == 0 then
      print('REMOOOVING')
      self.instanceSessions[sessionId] = nil
    end
  end
end

------------------------------------------
-- Public methods
------------------------------------------

-- Inserts or updates an instance visit
function InstanceCounter:UpsertInstanceVisit(instanceName, sessionId, enterTime)
  local timestamp = enterTime or self.instanceEnterTime
  assert(timestamp ~= nil, 'Instance enter time unknown')

  if self.instanceSessions[sessionId] ~= nil then
    -- TODO: Is it measured from most recent enter time? Including as spirit?
    self.instanceSessions[sessionId].enterTime = timestamp
  else
    self.instanceSessions[sessionId] = {
      enterTime = timestamp,
      instance = instanceName,
      character = UnitName('player'),
    }
  end

  C_Timer.After(LockTimeRemaining(timestamp), RemoveExpiredInstances)
end

-- Prints the visited instances to the default chat frame
function InstanceCounter:PrintList()
  if self:GetCount() == 0 then
    print('No registered instance sessions.')
    return
  end

  -- TODO: Sort by time left
  for _, session in pairs(self.instanceSessions) do
    local secondsLeft = LockTimeRemaining(session.enterTime)
    local showTimeInSeconds = secondsLeft < SECONDS_PER_MINUTE

    print(format(
      '[%s] %s (%s) - %s%s',
      date('%H:%M', session.enterTime),
      session.instance,
      session.character,
      showTimeInSeconds and secondsLeft or math.ceil(secondsLeft / SECONDS_PER_MINUTE),
      showTimeInSeconds and 's' or 'm'
    ))
  end
end

-- Returns whether the account is instance locked or not
function InstanceCounter:IsLocked()
  return self:GetCount() > INSTANCE_LIMIT
end

-- Returns the instance lock time remaining, or zero if not applicable
function InstanceCounter:GetLockTimeRemaining()
  if not self:IsLocked() then
    return 0
  end

  local shortestInstanceTimeout = nil
  for _, session in pairs(self.instanceSessions) do
    shortestInstanceTimeout = min(
      LockTimeRemaining(session.enterTime),
      shortestInstanceTimeout or math.huge)
  end

  return shortestInstanceTimeout
end

-- Returns the number of registered instance sessions
function InstanceCounter:GetCount()
  local count = 0
  for _ in pairs(self.instanceSessions) do count = count + 1 end
  return count
end

------------------------------------------
-- Event handlers
------------------------------------------

local events = {}

function events.NAME_PLATE_UNIT_ADDED(_, unit) OnIdentifiedUnit(UnitGUID(unit)) end
function events.UPDATE_MOUSEOVER_UNIT(...) OnIdentifiedUnit(UnitGUID('mouseover')) end
function events.PLAYER_TARGET_CHANGED(...) OnIdentifiedUnit(UnitGUID('target')) end

function events.ADDON_LOADED(self, addon, ...)
  if addon ~= ADDON_NAME then
    return
  end

  InstanceCounterDB = InstanceCounterDB or {
    minimap = { hide = false },
    sessions = {},
  }

  -- Instance lock outs are realm specific
  local realm = GetRealmName()
  if InstanceCounterDB.sessions[realm] == nil then
    InstanceCounterDB.sessions[realm] = {}
  end

  Initialize(InstanceCounterDB.sessions[realm])
  RemoveExpiredInstances()

  LDBIcon:Register(ADDON_NAME, self.broker, InstanceCounterDB.minimap)

  for _, session in pairs(self.instanceSessions) do
    C_Timer.After(LockTimeRemaining(session.enterTime), RemoveExpiredInstances)
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
    DEFAULT_CHAT_FRAME:AddMessage('Warning: the previous instance was never identified', 1.0, 0.35, 0.25)
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
