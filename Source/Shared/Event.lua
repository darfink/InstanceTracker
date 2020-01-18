select(2, ...) 'Shared.Event'

------------------------------------------
-- Class definition
------------------------------------------

local Event = {}
Event.__index = Event

------------------------------------------
-- Constructor
------------------------------------------

function Event.New()
  return setmetatable({}, Event)
end

------------------------------------------
-- Public methods
------------------------------------------

function Event:AddListener(listener)
  assert(type(listener) == 'function')
  self[listener] = 1
end

function Event:RemoveListener(listener)
  self[listener] = nil
end

------------------------------------------
-- Meta methods
------------------------------------------

function Event.__call(self, ...)
  for listener in pairs(self) do
    listener(...)
  end
end

------------------------------------------
-- Exports
------------------------------------------

export.New = function(...) return Event.New(...) end