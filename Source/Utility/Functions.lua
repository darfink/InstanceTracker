select(2, ...) 'Utility.Functions'

-- Imports
local const = require 'Utility.Constants'

------------------------------------------
-- Public functions
------------------------------------------

local stringToColorCache = {}

-- Converts a string to a deterministic color
function export.StringToColor(string)
  if stringToColorCache[string] ~= nil then
    return stringToColorCache[string]
  end

  local hash = 0
  for c in string:gmatch('.') do
    hash = c:byte() + bit.lshift(hash, 5) - hash
  end

  local colors = { 'ff' }
  for i = 0,2 do
    local value = bit.band(bit.rshift(hash, i * 8), 0xFF)
    colors[#colors + 1] = format('%02x', value)
  end

  stringToColorCache[string] = table.concat(colors)
  return stringToColorCache[string]
end

-- Converts a number to a green/yellow/red color
function export.NumberToColor(value, max)
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

-- Invokes a callback after a delay
function export.SetTimeout(delay, callback)
  return C_Timer.After(delay, callback)
end

-- Binds an argument to a function
function export.Bind(context, callee)
  return function(...)
    return callee(context, ...)
  end
end

-- Registers an in-game slash command
function export.RegisterSlashCommand(command, callback)
  local identifier = (const.ADDON_NAME .. '_' .. command):upper()
  _G['SLASH_' .. identifier .. '1'] = '/' .. command
  _G.SlashCmdList[identifier] = callback
end