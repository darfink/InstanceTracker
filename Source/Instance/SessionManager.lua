select(2, ...) 'Instance.SessionManager'

-- Imports
local const = require 'Utility.Constants'
local util = require 'Utility.Functions'

------------------------------------------
-- Class definition
------------------------------------------

local SessionManager = {}
SessionManager.__index = SessionManager

------------------------------------------
-- Public methods
------------------------------------------

-- Creates a new instance session manager
function SessionManager.New(sessions)
  local self = setmetatable({}, SessionManager)
  self.instanceSessions = sessions or {}
  self:_RemoveExpiredInstances()
  for _, session in pairs(self.instanceSessions) do
    self:_ScheduleRemoveExpiredInstances(session.enterTime)
  end
  return self
end

-- Inserts or updates an instance visit
function SessionManager:UpsertInstanceVisit(instanceName, instanceUid, enterTime)
  assert(instanceName ~= nil)
  assert(instanceUid ~= nil)
  assert(enterTime ~= nil)

  if self.instanceSessions[instanceUid] ~= nil then
    -- TODO: Is it measured from most recent enter time? Including as spirit?
    self.instanceSessions[instanceUid].enterTime = enterTime
  else
    self.instanceSessions[instanceUid] = {
      enterTime = enterTime,
      instance = instanceName,
      character = UnitName('player'),
    }
  end

  self:_ScheduleRemoveExpiredInstances(enterTime)
end

-- Returns the instance lock time remaining, or zero if not active
function SessionManager:GetLockTimeRemaining()
  if not self:IsLocked() then
    return 0
  end

  local shortestInstanceTimeout = nil
  for _, session in pairs(self.instanceSessions) do
    shortestInstanceTimeout = min(
      self._GetExpirationTime(session.enterTime),
      shortestInstanceTimeout or math.huge)
  end

  return shortestInstanceTimeout
end

-- Returns a list of all instance sessions, sorted by enter time in ascending order
function SessionManager:GetList()
  local sortedSessions = {}
  for _, session in pairs(self.instanceSessions) do
    sortedSessions[#sortedSessions + 1] = {
      character = session.character,
      enterTime = session.enterTime,
      expireTime = self._GetExpirationTime(session.enterTime),
      instance = session.instance,
    }
  end

  table.sort(sortedSessions, function(a, b) return a.enterTime > b.enterTime end)
  return sortedSessions
end

-- Returns the number of registered instance sessions
function SessionManager:GetCount()
  local count = 0
  for _ in pairs(self.instanceSessions) do count = count + 1 end
  return count
end

-- Returns whether the instance lock is in place or not
function SessionManager:IsLocked()
  return self:GetCount() > const.INSTANCE_LIMIT
end

------------------------------------------
-- Private static methods
------------------------------------------

function SessionManager._GetExpirationTime(enterTime, currentTime)
  local timeReference = currentTime or GetServerTime()
  return max(const.INSTANCE_TIMEOUT - (timeReference - enterTime), 0)
end

------------------------------------------
-- Private methods
------------------------------------------

function SessionManager:_RemoveExpiredInstances()
  local currentTime = GetServerTime()

  for instanceUid, session in pairs(self.instanceSessions) do
    if self._GetExpirationTime(session.enterTime, currentTime) == 0 then
      self.instanceSessions[instanceUid] = nil
    end
  end
end

function SessionManager:_ScheduleRemoveExpiredInstances(timestamp)
  -- Add a 1 second margin to ensure the instance has actually expired
  util.SetTimeout(self._GetExpirationTime(timestamp) + 1, util.Bind(self, self._RemoveExpiredInstances))
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return SessionManager.New(...) end