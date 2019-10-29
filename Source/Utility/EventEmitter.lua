select(2, ...) 'Utility.EventEmitter'

------------------------------------------
-- Class definition
------------------------------------------

local EventEmitter = {}
EventEmitter.__index = EventEmitter

------------------------------------------
-- Public methods
------------------------------------------

-- Creates a new event emitter
function EventEmitter.New(frame)
  local self = setmetatable({}, EventEmitter)
  self.frame = frame
  self.frame:SetScript('OnEvent', function (_, event, ...) self:_OnEvent(event, ...) end)
  self.eventListeners = {}
  return self
end

-- Adds a new listener for an event
function EventEmitter:AddListener(event, listener)
  if self.eventListeners[event] == nil then
    self.frame:RegisterEvent(event)
    self.eventListeners[event] = {}
  end

  self.eventListeners[event][listener] = true
end

-- Removes an existing listener from an event
function EventEmitter:RemoveListener(event, listener)
  if self.eventListeners[event] == nil then
    return
  end

  self.eventListeners[event][listener] = nil

  if next(self.eventListeners[event]) == nil then
    self.frame:UnregisterEvent(event)
    self.eventListeners[event] = nil
  end
end

------------------------------------------
-- Private methods
------------------------------------------

function EventEmitter:_OnEvent(event, ...)
  for listener, _ in pairs(self.eventListeners[event]) do
    listener(...)
  end
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return EventEmitter.New(...) end