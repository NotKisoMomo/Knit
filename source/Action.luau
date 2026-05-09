local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Signal)
local Promise = require(script.Parent.Promise)
local InputEvent = require(script.Parent.InputEvent)
local Util = require(script.Parent.Util)

export type ActionHandle = Types.ActionHandle

local Action = {}
Action.__index = Action

function Action.new(name: string, config: Types.ActionConfig): Types.ActionHandle
	local self = setmetatable({}, Action)

	self._name = name
	self._bindings = config.bindings
	self._contexts = config.contexts or nil
	self._mode = config.mode or Util.inferMode(config.bindings)
	self._enabled = true
	self._heldSince = nil :: number?
	self._heldBindings = {} :: { [string]: boolean }
	self._deadzone = config.deadzone or 0.0
	self._repeatInterval = config.repeatInterval or nil
	self._repeatThread = nil :: thread?

	self.pressed = Signal.new()
	self.released = Signal.new()
	self.held = Signal.new()
	self.moved = Signal.new()
	self.triggered = Signal.new()

	return self :: any
end

function Action:_handleInput(input: InputObject, began: boolean)
	if not self._enabled then return end

	for _, binding in self._bindings do
		if not Util.matchesBinding(input, binding) then continue end

		if Util.isAxisBinding(binding) then
			local delta = Util.getDelta(input)
			if self._deadzone > 0 and delta.Magnitude < self._deadzone then return nil end
			local event = InputEvent.new({
				binding = binding,
				phase = "changed",
				position = Util.getPosition(input),
				delta = delta,
				held = false,
				consumed = false,
			})
			self.moved:fire(event)
			return event
		end

		if began then
			self._heldSince = os.clock()
			self._heldBindings[tostring(binding)] = true

			local event = InputEvent.new({
				binding = binding,
				phase = "pressed",
				position = Util.getPosition(input),
				delta = nil,
				held = false,
				consumed = false,
			})
			self.pressed:fire(event)

			if self._repeatInterval then
				self._repeatThread = task.spawn(function()
					while self:isHeld() do
						task.wait(self._repeatInterval)
						if not self:isHeld() then break end
						local repeatEvent = InputEvent.new({
							binding = binding,
							phase = "pressed",
							position = Util.getPosition(input),
							delta = nil,
							held = true,
							consumed = false,
						})
						self.pressed:fire(repeatEvent)
					end
				end)
			end

			return event
		else
			self._heldSince = nil
			self._heldBindings[tostring(binding)] = nil

			if self._repeatThread then
				task.cancel(self._repeatThread)
				self._repeatThread = nil
			end

			local event = InputEvent.new({
				binding = binding,
				phase = "released",
				position = Util.getPosition(input),
				delta = nil,
				held = false,
				consumed = false,
			})
			self.released:fire(event)
			return event
		end
	end

	return nil
end

function Action:isHeld(): boolean
	return self._heldSince ~= nil
end

function Action:heldDuration(): number
	if not self._heldSince then return 0 end
	return os.clock() - self._heldSince
end

function Action:holdFor(seconds: number): Types.Promise<Types.InputEvent>
	return Promise.new(function(resolve, _, onCancel)
		local cancelled = false
		onCancel(function()
			cancelled = true
		end)

		task.spawn(function()
			local startTime = os.clock()
			local disconnect

			disconnect = self.pressed:connect(function()
				startTime = os.clock()
			end)

			while not cancelled do
				task.wait()
				if self:isHeld() and (os.clock() - startTime) >= seconds then
					disconnect()
					if not cancelled then
						resolve(nil)
					end
					return
				end
			end

			disconnect()
		end)
	end)
end

function Action:next(): Types.Promise<Types.InputEvent>
	return self.pressed:once()
end

function Action:log()
	local function printer(signal, label)
		signal:connect(function(event)
			print(string.format("[Knit] %s.%s  binding=%s  held=%.2fs", self._name, label, tostring(event.binding), self:heldDuration()))
		end)
	end
	printer(self.pressed, "pressed")
	printer(self.released, "released")
	printer(self.moved, "moved")
	printer(self.triggered, "triggered")
end

function Action:rebind(bindings: { Types.InputBinding })
	self._bindings = bindings
	self._mode = Util.inferMode(bindings)
end

function Action:enable()
	self._enabled = true
end

function Action:disable()
	self._enabled = false
	self._heldSince = nil
	table.clear(self._heldBindings)
	if self._repeatThread then
		task.cancel(self._repeatThread)
		self._repeatThread = nil
	end
end

function Action:destroy()
	self:disable()
	self.pressed:destroy()
	self.released:destroy()
	self.held:destroy()
	self.moved:destroy()
	self.triggered:destroy()
end

function Action:_matchesContext(activeContexts: { string }): boolean
	if not self._contexts then return true end
	for _, required in self._contexts do
		for _, active in activeContexts do
			if active == required then return true end
		end
	end
	return false
end

return Action