select(2, ...) 'Main'

-- Imports
local const = require 'Utility.Constants'
local util = require 'Utility.Functions'
local EventEmitter = require 'Utility.EventEmitter'
local Persistence = require 'Persistence'
local Addon = require 'Addon'

------------------------------------------
-- Bootstrap
------------------------------------------

local eventEmitter = EventEmitter.New(CreateFrame('Frame'))
local addon = nil

eventEmitter:AddListener('ADDON_LOADED', function (addonName)
  if addonName ~= const.ADDON_NAME then
    return
  end

  local persistence = Persistence.New()
  addon = Addon.New(persistence, eventEmitter)
end)