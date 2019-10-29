select(2, ...) 'Instance.Observer'

-- Imports
local util = require 'Utility.Functions'

------------------------------------------
-- Class definition
------------------------------------------

local Observer = {}
Observer.__index = Observer

------------------------------------------
-- Public methods
------------------------------------------

-- Creates a new instance observer
function Observer.New(eventEmitter)
  assert(eventEmitter ~= nil)

  local self = setmetatable({}, Observer)
  self.instanceEnterTime = nil
  self.insideUnknownInstance = false
  self.onInstanceIdentifiedHandler = nil
  self.eventEmitter = eventEmitter
  self.eventEmitter:AddListener('PLAYER_ENTERING_WORLD', util.Bind(self, self._OnPlayerEnteringWorld))
  self.unitEventListeners = {
    ['NAME_PLATE_UNIT_ADDED'] = function(unit) self:_OnIdentifiedUnit(UnitGUID(unit)) end,
    ['UPDATE_MOUSEOVER_UNIT'] = function(...) self:_OnIdentifiedUnit(UnitGUID('mouseover')) end,
    ['PLAYER_TARGET_CHANGED'] = function(...) self:_OnIdentifiedUnit(UnitGUID('target')) end,
  }

  return self
end

-- Sets the handler called when an instance has been identified
function Observer:SetOnInstanceIdentifiedHandler(handler)
  self.onInstanceIdentifiedHandler = handler
end

------------------------------------------
-- Private methods
------------------------------------------

function Observer:_ToggleUnitEventListeners(enabled)
  for event, listener in pairs(self.unitEventListeners) do
    if enabled then
      self.eventEmitter:AddListener(event, listener)
    else
      self.eventEmitter:RemoveListener(event, listener)
    end
  end
end

function Observer:_OnPlayerEnteringWorld()
  local inInstance, instanceType = IsInInstance()
  local isInDungeonInstance = inInstance and instanceType == 'party'

  if isInDungeonInstance then
    self.instanceEnterTime = GetServerTime()
    self.insideUnknownInstance = true
    self:_ToggleUnitEventListeners(true)
  elseif self.insideUnknownInstance then
    print('|cFFFF5A5AWarning: the previous instance was never identified')
    self.instanceEnterTime = nil
    self.insideUnknownInstance = false
    self:_ToggleUnitEventListeners(false)
  end
end

function Observer:_OnIdentifiedUnit(guid)
  if not (guid and self.insideUnknownInstance) then
    return
  end

  assert(self.instanceEnterTime ~= nil, 'Instance enter time unknown')
  local type, _, _, _, zoneUid, _, _ = strsplit('-', guid)

  -- Only creatures' zone UIDs can be trusted, pet's may have an origin from elsewhere
  if type == 'Creature' then
    self.insideUnknownInstance = false
    self:_ToggleUnitEventListeners(false)

    if self.onInstanceIdentifiedHandler ~= nil then
      local instanceName = GetRealZoneText()
      local instanceUid = tonumber(zoneUid)

      self.onInstanceIdentifiedHandler(instanceName, instanceUid, self.instanceEnterTime)
    end
  end
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return Observer.New(...) end