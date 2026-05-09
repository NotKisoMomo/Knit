local Types = require(script.Parent.Types)

export type Signal<T> = Types.Signal<T>

local Signal = {}
Signal.__index = Signal

function Signal.new<T>(): Signal<T>
	local self = setmetatable({}, Signal)
	self._listeners = {} :: { (T) -> () }
	self._destroyed = false
	return self :: any
end

function Signal:connect<T>(cb: (T) -> ()): () -> ()
	if self._destroyed then return function() end end
	table.insert(self._listeners, cb)
	return function()
		for i, listener in self._listeners do
			if listener == cb then
				table.remove(self._listeners, i)
				break
			end
		end
	end
end

function Signal:fire<T>(value: T)
	if self._destroyed then return end
	for _, listener in self._listeners do
		task.spawn(listener, value)
	end
end

function Signal:once<T>(): Types.Promise<T>
	local Promise = require(script.Parent.Promise)
	return Promise.new(function(resolve, _, onCancel)
		local disconnect
		disconnect = self:connect(function(value)
			disconnect()
			resolve(value)
		end)
		onCancel(function()
			disconnect()
		end)
	end)
end

function Signal:destroy()
	self._destroyed = true
	table.clear(self._listeners)
end

return Signal