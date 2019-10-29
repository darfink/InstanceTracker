select(2, ...) 'Addon'

-- Externals
local LDB = LibStub('LibDataBroker-1.1')
local LDBIcon = LibStub('LibDBIcon-1.0')

-- Imports
local const = require 'Utility.Constants'
local util = require 'Utility.Functions'
local InstanceObserver = require 'Instance.Observer'
local InstanceSessionManager = require 'Instance.SessionManager'

------------------------------------------
-- Class definition
------------------------------------------

local Addon = {}
Addon.__index = Addon

------------------------------------------
-- Public methods
------------------------------------------

-- Creates a new instance session manager
function Addon.New(persistence, eventEmitter)
  local self = setmetatable({}, Addon)
  self.instanceObserver = InstanceObserver.New(eventEmitter)
  self.instanceObserver:SetOnInstanceIdentifiedHandler(util.Bind(self, self._OnInstanceIdentified))
  self.sessionManager = InstanceSessionManager.New(persistence:GetRealmItem('sessions'))
  self.broker = LDB:NewDataObject(const.ADDON_NAME, {
    type = 'data source',
    text = ADDON_NAME,
    icon = 'Interface\\AddOns\\InstanceCounter\\Images\\Digit-0.blp',
    OnTooltipShow = util.Bind(self, self._RenderTooltip),
  })

  util.RegisterSlashCommand('ic', util.Bind(self, self._PrintList))
  LDBIcon:Register(const.ADDON_NAME, self.broker, persistence:GetCharacterItem('minimap'))
  return self
end

------------------------------------------
-- Private methods
------------------------------------------

function Addon:_OnInstanceIdentified(instanceName, instanceUid, enterTime)
  self.sessionManager:UpsertInstanceVisit(instanceName, instanceUid, enterTime)
end

function Addon:_PrintList()
  if self.sessionManager:GetCount() == 0 then
    print('No registered instance sessions.')
    return
  end

  for _, session in pairs(self.sessionManager:GetList()) do
    local showTimeInSeconds = session.expireTime < const.SECONDS_PER_MINUTE

    print(format(
      '[%s] %s (%s) - %s%s',
      date('%H:%M', session.enterTime),
      session.instance,
      session.character,
      showTimeInSeconds and session.expireTime or math.ceil(session.expireTime / const.SECONDS_PER_MINUTE),
      showTimeInSeconds and 's' or 'm'
    ))
  end
end

function Addon:_RenderTooltip(tooltip)
  tooltip:ClearLines()
  tooltip:AddDoubleLine(const.ADDON_NAME, const.ADDON_VERSION)
  tooltip:AddLine(' ')

  for _, session in ipairs(self.sessionManager:GetList()) do
    local showTimeInSeconds = session.expireTime < const.SECONDS_PER_MINUTE

    tooltip:AddDoubleLine(
      format(
        '[%s] |cFFEDA55F%s|r (|c%s%s|r)',
        date('%H:%M', session.enterTime),
        session.instance,
        util.StringToColor(session.character),
        session.character),
      format(
        '|c%s%d%s',
        util.NumberToColor(session.expireTime, const.INSTANCE_TIMEOUT),
        showTimeInSeconds and session.expireTime or math.ceil(session.expireTime / const.SECONDS_PER_MINUTE),
        showTimeInSeconds and 's' or 'm')
    )
  end

  tooltip:AddLine(' ')
  if not self.sessionManager:IsLocked() then
    tooltip:AddLine('|cff00ff00You can enter instances.|r')
  else
    tooltip:AddLine('|cffff0000You are instance locked.|r')
  end
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return Addon.New(...) end
