select(2, ...) 'InstanceController'

-- Imports
local LDB = LibStub('LibDataBroker-1.1')
local util = require 'Utility.Functions'

-- Consts
local const = util.ReadOnly({
  infinity = 1 / 0,
  instanceLimit = 5,
  instanceTimeout = 3600,
  secondsPerMinute = 60,
})

------------------------------------------
-- Class definition
------------------------------------------

local InstanceController = {}
InstanceController.__index = InstanceController

------------------------------------------
-- Constructor
------------------------------------------

function InstanceController.New(persistence, instanceObserver)
  local self = setmetatable({}, InstanceController)

  self.methods = util.ContextBinder(self)
  self.instanceObserver = instanceObserver
  self.instanceObserver.OnInstanceEntered:AddListener(self.methods._UpdateBroker)
  self.instanceObserver.OnInstanceZoneIdentified:AddListener(self.methods._OnInstanceZoneIdentified)
  self.instanceObserver.OnInstanceExited:AddListener(self.methods._OnInstanceExited)
  self.instanceVisits = persistence:GetAccountItem('instanceVisits')
  self.unidentifiedInstanceVisits = persistence:GetAccountItem('unidentifiedInstanceVisits')
  self.dataObject = LDB:NewDataObject(util.GetAddonName(), {
    type = 'data source',
    OnTooltipShow = self.methods._OnTooltipShow,
    OnClick = self.methods._OnClick,
  })

  self:_RemoveExpiredVisits(true)
  self:_UpdateBroker()
  return self
end

------------------------------------------
-- Public methods
------------------------------------------

-- Returns the instance broker
function InstanceController:GetBroker()
  return self.dataObject
end

-- Returns the number of non-expired instance visits
function InstanceController:GetNumVisits()
  local visits = 0
  for _ in pairs(self.instanceVisits) do visits = visits + 1 end
  return visits
end

-- Returns whether the instance lock is in place or not
function InstanceController:IsLocked()
  return self:GetNumVisits() >= const.instanceLimit
end

------------------------------------------
-- Private static methods
------------------------------------------

function InstanceController._GetTimeUntilExpiration(exitTime, currentTime)
  if exitTime == nil then
    return const.infinity
  end

  local timeReference = currentTime or GetServerTime()
  return max(const.instanceTimeout - (timeReference - exitTime), 0)
end

------------------------------------------
-- Private methods
------------------------------------------

function InstanceController:_UpdateBroker()
  local function SetIcon(icon, red, green, blue)
    self.dataObject.icon = util.GetImagePath(icon)
    self.dataObject.iconR = red
    self.dataObject.iconG = green
    self.dataObject.iconB = blue
  end

  if self.instanceObserver:IsInUnidentifiedInstance() then
    SetIcon('Unknown', 1.0, 0.6, 0.0)
  elseif self:IsLocked() then
    SetIcon('Lock', 1.0, 0.0, 0.0)
  else
    local instanceVisits = math.min(self:GetNumVisits(), const.instanceLimit)
    local color = util.RatioToColor(instanceVisits, const.instanceLimit)
    local icon = 'Digit-' .. instanceVisits

    SetIcon(icon, color.r, color.g, color.b)
  end
end

function InstanceController:_RemoveExpiredVisits(scheduleExpirations)
  local serverTime = GetServerTime()
  local expiredVisits = 0

  for key, visit in pairs(self.instanceVisits) do
    local timeUntilExpiration = self._GetTimeUntilExpiration(visit.exitTime, serverTime)

    if timeUntilExpiration == 0 then
      expiredVisits = expiredVisits + 1
      self.instanceVisits[key] = nil
    elseif scheduleExpirations and timeUntilExpiration ~= const.infinity then
      util.SetTimeout(timeUntilExpiration + 1, self.methods._RemoveExpiredVisits)
    end
  end

  if expiredVisits > 0 then
    self:_UpdateBroker()
  end
end

function InstanceController:_GetVisitsSortedByExitTimeDescending()
  local sortedInstanceVisits = {}
  for _, visit in pairs(self.instanceVisits) do
    sortedInstanceVisits[#sortedInstanceVisits + 1] = visit
  end

  table.sort(sortedInstanceVisits, function(a, b)
    return (a.exitTime or const.infinity) > (b.exitTime or const.infinity)
  end)

  return sortedInstanceVisits
end

function InstanceController:_OnInstanceZoneIdentified(instance)
  if self.instanceVisits[instance.zoneId] == nil then
    self.instanceVisits[instance.zoneId] = {
      characterName = UnitName('player'),
      characterClass = select(2, UnitClass('player')),
      instanceName = instance.name,
      entryTime = instance.entryTime,
    }
  else
    self.instanceVisits[instance.zoneId].exitTime = nil
  end

  self:_UpdateBroker()
end

function InstanceController:_OnInstanceExited(instance)
  local serverTime = GetServerTime()

  if instance.zoneId == nil then
    -- Keep track of all unidentified visits, since they may cause a lock out as well
    self.unidentifiedInstanceVisits[#self.unidentifiedInstanceVisits + 1] = serverTime
  else
    -- The instance lock is calculated based on the exit time
    self.instanceVisits[instance.zoneId].exitTime = serverTime
  end

  util.SetTimeout(const.instanceTimeout + 1, self.methods._RemoveExpiredVisits)
  self:_UpdateBroker()
end

function InstanceController:_OnTooltipShow(tooltip)
  local numVisits = self:GetNumVisits()
  local instanceRatio = format('%d/%d', numVisits, const.instanceLimit)

  tooltip:ClearLines()
  tooltip:AddDoubleLine(util.GetAddonName(), instanceRatio)

  if numVisits > 0 then
    tooltip:AddLine(' ')
  end

  local serverTime = GetServerTime()
  for _, visit in ipairs(self:_GetVisitsSortedByExitTimeDescending()) do
    local timeUntilExpiration = self._GetTimeUntilExpiration(visit.exitTime, serverTime)
    local expirationInfo

    if timeUntilExpiration ~= const.infinity then
      expirationInfo = string.format(
        '|c%s%s%dm',
        util.RatioToColor(timeUntilExpiration, const.instanceTimeout):GenerateHexColor(),
        timeUntilExpiration < const.secondsPerMinute and '<' or '',
        math.max(util.Round(timeUntilExpiration / const.secondsPerMinute), 1))
    else
      expirationInfo = 'n/a'
    end

    local instanceInfo = string.format(
      '[%s] |cFFEDA55F%s|r (|c%s%s|r)',
      date('%H:%M', visit.entryTime),
      visit.instanceName,
      RAID_CLASS_COLORS[visit.characterClass].colorStr,
      visit.characterName)

    tooltip:AddDoubleLine(instanceInfo, expirationInfo)
  end

  tooltip:AddLine(' ')
  if self.instanceObserver:IsInUnidentifiedInstance() then
    tooltip:AddLine('|cffffa500Current instance has not yet been identified.|r')
  elseif self:IsLocked() then
    tooltip:AddLine('|cffff0000You are instance locked.|r')
  else
    tooltip:AddLine('|cff00ff00You can enter instances.|r')
  end
end

function InstanceController:_OnClick()
  if IsShiftKeyDown() then
    ResetInstances()
  else
    StaticPopup_Show('CONFIRM_RESET_INSTANCES')
  end
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return InstanceController.New(...) end