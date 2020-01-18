select(2, ...) 'Utility.Functions'

------------------------------------------
-- Constants
------------------------------------------

local addonName = select(1, ...)

------------------------------------------
-- Public functions
------------------------------------------

-- Returns the addon's name
function export.GetAddonName()
  return addonName
end

-- Returns an image's resource path
function export.GetImagePath(...)
  return string.format('Interface\\AddOns\\%s\\Images\\%s.blp', addonName, table.concat({...}, '\\'))
end

-- Rounds a number to its nearest integer
function export.Round(value)
  return math.floor(value + 0.5)
end

-- Converts a ratio to a green/yellow/red color
function export.RatioToColor(value, max)
  value = value * (510 / max)

  local red, green
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

  return CreateColor(red / 0xFF, green / 0xFF, 0)
end

-- Invokes a callback after a delay
function export.SetTimeout(delay, callback)
  return C_Timer.After(delay, callback)
end

-- Returns a read only version of a table
function export.ReadOnly(table)
  return setmetatable({}, {
    __index = table,
    __newindex = function() error('Attempt to modify read-only table') end,
    __metatable = false,
  })
end

-- Returns a table which exposes context bound methods
function export.ContextBinder(context)
  return setmetatable({}, {
    __index = function (self, key)
      local method = context[key]

      if type(method) ~= 'function' then
        error('Unknown method ' .. key)
      end

      self[key] = function(...)
        return method(context, ...)
      end

      return rawget(self, key)
    end,
    __metatable = false,
  })
end

-- Registers an in-game slash command
function export.RegisterSlashCommand(command, callback)
  local identifier = (addonName .. '_' .. command):upper()
  _G['SLASH_' .. identifier .. '1'] = '/' .. command
  _G.SlashCmdList[identifier] = callback
end