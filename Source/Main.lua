select(2, ...) 'Main'

-- Imports
local LDBIcon = LibStub('LibDBIcon-1.0')
local EventSource = require 'Shared.EventSource'
local Persistence = require 'Shared.Persistence'
local InstanceObserver = require 'Utility.InstanceObserver'
local util = require 'Utility.Functions'
local InstanceController = require 'InstanceController'

------------------------------------------
-- Bootstrap
------------------------------------------

local eventSource = EventSource.New()

eventSource:AddListener('ADDON_LOADED', function (addonName)
  if addonName ~= util.GetAddonName() then
    return
  end

  local persistence = Persistence.New(addonName .. 'DB')
  local instanceObserver = InstanceObserver.New(eventSource)
  local instanceController = InstanceController.New(persistence, instanceObserver)

  LDBIcon:Register(addonName, instanceController:GetBroker(), persistence:GetCharacterItem('minimap'))
end)