local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Signal)
local InputEvent = require(script.Parent.InputEvent)
local Util = require(script.Parent.Util)

local Combo = {}
Combo.__index = Combo

function Combo.new(name: string, config: Types.ActionConfig)
	assert(config.sequence and #config.sequence >= 2, "Combo requires a sequence of at least 2 bindings")

	local self = setmetatable({}, Combo)

	self._name = name
	self._sequence = config.sequence :: { Types.InputBinding }
	self._window = config.window or 0.4
	self._contexts = config.contexts or nil
	self._enabled = true
	self._progress = 0
	self._lastTime = 0

	local seen = {}
	local inferred = {}
	for _, binding in self._sequence do
		local key = tostring(binding)
		if not seen[key] then
			seen[key] = true
			table.insert(inferred, binding)
		end
	end
	self._bindings = config.bindings or inferred

	self.triggered = Signal.new()

	return self
end

function Combo:_handleInput(input: InputObject, began: boolean)
	if not self._enabled or not began then return end

	local matchesAny = false
	for _, binding in self._bindings do
		if Util.matchesBinding(input, binding) then
			matchesAny = true
			break
		end
	end
	if not matchesAny then return end

	local expected = self._sequence[self._progress + 1]
	if not expected then return end

	if not Util.matchesBinding(input, expected) then
		self._progress = 0
		self._lastTime = 0

		local first = self._sequence[1]
		if Util.matchesBinding(input, first) then
			self._progress = 1
			self._lastTime = os.clock()
		end
		return
	end

	local now = os.clock()
	if self._progress > 0 and (now - self._lastTime) > self._window then
		self._progress = 0
		self._lastTime = 0
		return
	end

	self._progress += 1
	self._lastTime = now

	if self._progress == #self._sequence then
		self._progress = 0
		self._lastTime = 0

		local event = InputEvent.new({
			binding = expected,
			phase = "pressed",
			position = Util.getPosition(input),
			delta = nil,
			held = false,
			consumed = false,
		})
		self.triggered:fire(event)
	end
end

function Combo:_matchesContext(activeContexts: { string }): boolean
	if not self._contexts then return true end
	for _, required in self._contexts do
		for _, active in activeContexts do
			if active == required then return true end
		end
	end
	return false
end

function Combo:enable()
	self._enabled = true
end

function Combo:disable()
	self._enabled = false
	self._progress = 0
	self._lastTime = 0
end

function Combo:destroy()
	self:disable()
	self.triggered:destroy()
end

return Combo