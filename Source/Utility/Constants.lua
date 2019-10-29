select(2, ...) 'Utility.Constants'

local addonName = select(1, ...)
local constants = {
  ADDON_NAME = addonName,
  ADDON_VERSION = GetAddOnMetadata(addonName, 'Version'),
  SECONDS_PER_MINUTE = 60,
  INSTANCE_TIMEOUT = 3600,
  INSTANCE_LIMIT = 5,
}

for key, value in pairs(constants) do
  export[key] = value
end