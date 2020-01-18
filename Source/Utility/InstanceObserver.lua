select(2, ...) 'Utility.InstanceObserver'

-- Imports
local Event = require 'Shared.Event'
local util = require 'Utility.Functions'

------------------------------------------
-- Class definition
------------------------------------------

local InstanceObserver = {}
InstanceObserver.__index = InstanceObserver

------------------------------------------
-- Constructor
------------------------------------------

-- Creates a new instance observer
function InstanceObserver.New(eventSource)
  assert(eventSource ~= nil)
  local self = setmetatable({}, InstanceObserver)

  self.methods = util.ContextBinder(self)
  self.currentInstance = nil
  self.eventSource = eventSource
  self.eventSource:AddListener('PLAYER_ENTERING_WORLD', self.methods._OnPlayerEnteringWorld)
  self.eventSource:AddListener('PLAYER_LEAVING_WORLD', self.methods._OnPlayerLeavingWorld)
  self.unitEventListeners = {
    ['NAME_PLATE_UNIT_ADDED'] = function(unit) self:_OnUnitEncounter(UnitGUID(unit)) end,
    ['UPDATE_MOUSEOVER_UNIT'] = function(_) self:_OnUnitEncounter(UnitGUID('mouseover')) end,
    ['PLAYER_TARGET_CHANGED'] = function(_) self:_OnUnitEncounter(UnitGUID('target')) end,
  }

  -- These act as public fields
  self.OnInstanceEntered = Event.New()
  self.OnInstanceExited = Event.New()
  self.OnInstanceZoneIdentified = Event.New()

  return self
end

------------------------------------------
-- Public methods
------------------------------------------

function InstanceObserver:IsInUnidentifiedInstance()
  return self.currentInstance ~= nil and self.currentInstance.zoneId == nil
end

------------------------------------------
-- Private methods
------------------------------------------

function InstanceObserver:_ToggleUnitEventListeners(enabled)
  for event, listener in pairs(self.unitEventListeners) do
    if enabled then
      self.eventSource:AddListener(event, listener)
    else
      self.eventSource:RemoveListener(event, listener)
    end
  end
end

function InstanceObserver:_OnPlayerEnteringWorld()
  local inInstance, instanceType = IsInInstance()
  local inDungeonInstance = inInstance and instanceType == 'party'

  if inDungeonInstance then
    self.currentInstance = {
      name = select(1, GetInstanceInfo()),
      entryTime = GetServerTime(),
    }

    self:_ToggleUnitEventListeners(true)
    self.OnInstanceEntered(self.currentInstance)
  end
end

function InstanceObserver:_OnPlayerLeavingWorld()
  if self.currentInstance ~= nil then
    local instance = self.currentInstance
    self.currentInstance = nil

    self:_ToggleUnitEventListeners(false)
    self.OnInstanceExited(instance)
  end
end

function InstanceObserver:_OnUnitEncounter(guid)
  if not guid then return end

  -- Only creatures' zone UIDs can be trusted, pet's may have an origin from elsewhere
  local type, _, _, _, zoneUid, _, _ = strsplit('-', guid)
  if type ~= 'Creature' then return end

  self.currentInstance.zoneId = tonumber(zoneUid)
  self:_ToggleUnitEventListeners(false)
  self.OnInstanceZoneIdentified(self.currentInstance)
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return InstanceObserver.New(...) end