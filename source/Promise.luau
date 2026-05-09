export type Promise<T> = {
	andThen: (self: Promise<T>, cb: (T) -> ()) -> Promise<T>,
	catch: (self: Promise<T>, cb: (any) -> ()) -> Promise<T>,
	cancel: (self: Promise<T>) -> (),
	await: (self: Promise<T>) -> (boolean, T),
}

type PromiseState = "pending" | "resolved" | "rejected" | "cancelled"

local Promise = {}
Promise.__index = Promise

function Promise.new<T>(executor: (
	resolve: (T) -> (),
	reject: (any) -> (),
	onCancel: (cb: () -> ()) -> ()
	) -> ()): Promise<T>
	local self = setmetatable({}, Promise)
	self._state = "pending" :: PromiseState
	self._value = nil
	self._thenCbs = {}
	self._catchCbs = {}
	self._cancelCb = nil

	local function resolve(value)
		if self._state ~= "pending" then return end
		self._state = "resolved"
		self._value = value
		for _, cb in self._thenCbs do
			task.spawn(cb, value)
		end
	end

	local function reject(err)
		if self._state ~= "pending" then return end
		self._state = "rejected"
		self._value = err
		for _, cb in self._catchCbs do
			task.spawn(cb, err)
		end
	end

	local function onCancel(cb)
		self._cancelCb = cb
	end

	task.spawn(executor, resolve, reject, onCancel)

	return self :: any
end

function Promise.resolve<T>(value: T): Promise<T>
	return Promise.new(function(resolve)
		resolve(value)
	end)
end

function Promise.reject<T>(err: any): Promise<T>
	return Promise.new(function(_, reject)
		reject(err)
	end)
end

function Promise:andThen<T>(cb: (T) -> ()): Promise<T>
	if self._state == "resolved" then
		task.spawn(cb, self._value)
	elseif self._state == "pending" then
		table.insert(self._thenCbs, cb)
	end
	return self
end

function Promise:catch(cb: (any) -> ()): Promise<any>
	if self._state == "rejected" then
		task.spawn(cb, self._value)
	elseif self._state == "pending" then
		table.insert(self._catchCbs, cb)
	end
	return self
end

function Promise:cancel()
	if self._state ~= "pending" then return end
	self._state = "cancelled"
	if self._cancelCb then
		self._cancelCb()
	end
	table.clear(self._thenCbs)
	table.clear(self._catchCbs)
end

function Promise:await(): (boolean, any)
	if self._state == "resolved" then
		return true, self._value
	elseif self._state == "rejected" then
		return false, self._value
	end

	local thread = coroutine.running()
	self:andThen(function(value)
		task.spawn(thread, true, value)
	end)
	self:catch(function(err)
		task.spawn(thread, false, err)
	end)
	return coroutine.yield()
end

return Promise