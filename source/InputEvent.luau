local Types = require(script.Parent.Types)

export type InputEvent = Types.InputEvent

local InputEvent = {}
InputEvent.__index = InputEvent

function InputEvent.new(data: Types.InputEventData): Types.InputEvent
	local self = setmetatable({}, InputEvent)
	self.binding = data.binding
	self.phase = data.phase
	self.position = data.position
	self.delta = data.delta
	self.held = data.held
	self.consumed = false
	return self :: any
end

function InputEvent:consume()
	self.consumed = true
end

return InputEvent