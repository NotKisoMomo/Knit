local Signal = require(script.Parent.Signal)

export type SessionHandle = {
	get: (self: SessionHandle, key: string) -> any,
	set: (self: SessionHandle, key: string, value: any) -> (),
	patch: (self: SessionHandle, data: { [string]: any }) -> (),
	toggle: (self: SessionHandle, key: string) -> boolean,
	increment: (self: SessionHandle, key: string, amount: number?) -> number,
	decrement: (self: SessionHandle, key: string, amount: number?) -> number,
	reset: (self: SessionHandle) -> (),
	onChange: (self: SessionHandle, key: string, cb: (any, any) -> ()) -> () -> (),
	onAnyChange: (self: SessionHandle, cb: (key: string, value: any, previous: any) -> ()) -> () -> (),
	snapshot: (self: SessionHandle) -> { [string]: any },
	destroy: (self: SessionHandle) -> (),
}

local Session = {}
Session.__index = Session

function Session.new(name: string, defaults: { [string]: any }): SessionHandle
	local self = setmetatable({}, Session)

	self._name = name
	self._defaults = {}
	self._data = {}
	self._signals = {} :: { [string]: any }
	self._anyChanged = Signal.new()

	for k, v in defaults do
		self._defaults[k] = v
		self._data[k] = v
	end

	return self :: any
end

function Session:get(key: string): any
	return self._data[key]
end

function Session:set(key: string, value: any)
	local previous = self._data[key]
	if previous == value then return end
	self._data[key] = value
	if self._signals[key] then
		self._signals[key]:fire(value, previous)
	end
	self._anyChanged:fire(key, value, previous)
end

function Session:patch(data: { [string]: any })
	for k, v in data do
		self:set(k, v)
	end
end

function Session:toggle(key: string): boolean
	local current = self._data[key]
	assert(type(current) == "boolean" or current == nil, `Session:toggle -- "{key}" is not a boolean`)
	local next = not (current or false)
	self:set(key, next)
	return next
end

function Session:increment(key: string, amount: number?): number
	local current = self._data[key] or 0
	assert(type(current) == "number", `Session:increment -- "{key}" is not a number`)
	local next = current + (amount or 1)
	self:set(key, next)
	return next
end

function Session:decrement(key: string, amount: number?): number
	local current = self._data[key] or 0
	assert(type(current) == "number", `Session:decrement -- "{key}" is not a number`)
	local next = current - (amount or 1)
	self:set(key, next)
	return next
end

function Session:reset()
	for k, v in self._defaults do
		self:set(k, v)
	end
end

function Session:onChange(key: string, cb: (any, any) -> ()): () -> ()
	if not self._signals[key] then
		self._signals[key] = Signal.new()
	end
	return self._signals[key]:connect(cb)
end

function Session:onAnyChange(cb: (key: string, value: any, previous: any) -> ()): () -> ()
	return self._anyChanged:connect(cb)
end

function Session:snapshot(): { [string]: any }
	local copy = {}
	for k, v in self._data do
		copy[k] = v
	end
	return copy
end

function Session:destroy()
	for _, signal in self._signals do
		signal:destroy()
	end
	self._anyChanged:destroy()
	table.clear(self._signals)
	table.clear(self._data)
	table.clear(self._defaults)
end

return Session