local UserInputService = game:GetService("UserInputService")

local Types = require(script.Types)
local Action = require(script.Action)
local Combo = require(script.Combo)

local Signal = require(script.Signal)
local Promise = require(script.Promise)
local Util = require(script.Util)

local Session = require(script.Session)
local VersionHandler = require(script.VersionHandler)


type ActionHandle = Types.ActionHandle
type InputBinding = Types.InputBinding

local Knit = {}
VersionHandler.Start()

function Knit.RunVersionCheck()
	VersionHandler.Start()
end

local _registry: { [string]: any } = {}
local _sessions: { [string]: any } = {}
local _contextStack: { string } = {}
local _rawListeners: { { binding: InputBinding, cb: (Types.InputEvent) -> () } } = {}

local function getActiveContexts(): { string }
	return _contextStack
end

local function dispatchToRegistry(input: InputObject, began: boolean)
	local activeContexts = getActiveContexts()

	for _, entry in _registry do
		if not entry:_matchesContext(activeContexts) then continue end
		entry:_handleInput(input, began)
	end

	for _, listener in _rawListeners do
		if Util.matchesBinding(input, listener.binding) then
			local InputEvent = require(script.InputEvent)
			local event = InputEvent.new({
				binding = listener.binding,
				phase = began and "pressed" or "released",
				position = Util.getPosition(input),
				delta = nil,
				held = false,
				consumed = false,
			})
			task.spawn(listener.cb, event)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	dispatchToRegistry(input, true)
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	dispatchToRegistry(input, false)
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	dispatchToRegistry(input, true)
end)

Knit.context = {}

local _contextChanged = Signal.new()
Knit.context.changed = _contextChanged

function Knit.context.push(name: string)
	table.insert(_contextStack, name)
	_contextChanged:fire(_contextStack)
end

function Knit.context.pop(): string?
	local removed = table.remove(_contextStack)
	_contextChanged:fire(_contextStack)
	return removed
end

function Knit.context.peek(): string?
	return _contextStack[#_contextStack]
end

function Knit.context.clear()
	table.clear(_contextStack)
	_contextChanged:fire(_contextStack)
end

function Knit.context.stack(): { string }
	local copy = {}
	for i, v in _contextStack do
		copy[i] = v
	end
	return copy
end

function Knit.context.has(name: string): boolean
	for _, v in _contextStack do
		if v == name then return true end
	end
	return false
end

-- define

function Knit.define(name: string, config: Types.ActionConfig): ActionHandle
	assert(not _registry[name], `Knit: action "{name}" already defined`)

	local mode = config.mode or (
		config.sequence and "combo"
			or Util.inferMode(config.bindings or {})
	)

	local handle

	if mode == "combo" then
		handle = Combo.new(name, config)
	else
		handle = Action.new(name, config)
	end

	_registry[name] = handle
	return handle :: any
end

-- raw input

Knit.input = {}

function Knit.input.on(binding: InputBinding, cb: (Types.InputEvent) -> ()): () -> ()
	local entry = { binding = binding, cb = cb }
	table.insert(_rawListeners, entry)
	return function()
		for i, listener in _rawListeners do
			if listener == entry then
				table.remove(_rawListeners, i)
				break
			end
		end
	end
end

function Knit.input.held(binding: InputBinding): boolean
	if typeof(binding) == "EnumItem" then
		if binding.EnumType == Enum.KeyCode then
			return UserInputService:IsKeyDown(binding :: Enum.KeyCode)
		elseif binding.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(binding :: Enum.UserInputType)
		end
	end
	return false
end

-- helpers

function Knit.race(signals: { Types.Signal<any> }): Types.Promise<any>
	return Promise.new(function(resolve, _, onCancel)
		local promises: { Types.Promise<any> } = {}
		local settled = false

		for _, signal in signals do
			local p = signal:once()
			table.insert(promises, p)
			p:andThen(function(value)
				if settled then return end
				settled = true
				for _, other in promises do
					if other ~= p then
						other:cancel()
					end
				end
				resolve(value)
			end)
		end

		onCancel(function()
			for _, p in promises do
				p:cancel()
			end
		end)
	end)
end

function Knit.sequence(promises: { Types.Promise<any> }): Types.Promise<{ any }>
	return Promise.new(function(resolve, reject, onCancel)
		local results = {}
		local cancelled = false

		onCancel(function()
			cancelled = true
			for _, p in promises do
				p:cancel()
			end
		end)

		task.spawn(function()
			for i, p in promises do
				if cancelled then return end
				local ok, value = p:await()
				if not ok then
					reject(value)
					return
				end
				results[i] = value
			end
			if not cancelled then
				resolve(results)
			end
		end)
	end)
end

function Knit.get(name: string): ActionHandle?
	return _registry[name] :: any
end

function Knit.action(name: string): ActionHandle?
	return _registry[name] :: any
end

function Knit.rebindAll(map: { [string]: { Types.InputBinding } })
	for name, bindings in map do
		local handle = _registry[name]
		if handle and handle.rebind then
			handle:rebind(bindings)
		end
	end
end

function Knit.export(): { [string]: { string } }
	local out = {}
	for name, handle in _registry do
		if handle._bindings then
			local bindings = {}
			for _, b in handle._bindings do
				table.insert(bindings, tostring(b))
			end
			out[name] = bindings
		end
	end
	return out
end

function Knit.import(map: { [string]: { Types.InputBinding } })
	Knit.rebindAll(map)
end

function Knit.waitFor(action: ActionHandle, phase: Types.Phase?): Types.Promise<Types.InputEvent>
	local signal = (action :: any)[(phase or "pressed")]
	assert(signal, `Knit.waitFor: invalid phase "{phase}"`)
	return signal:once()
end

function Knit.timeout(promise: Types.Promise<any>, seconds: number): Types.Promise<any>
	return Promise.new(function(resolve, reject, onCancel)
		local settled = false

		onCancel(function()
			promise:cancel()
		end)

		promise:andThen(function(value)
			if settled then return end
			settled = true
			resolve(value)
		end):catch(function(err)
			if settled then return end
			settled = true
			reject(err)
		end)

		task.delay(seconds, function()
			if settled then return end
			settled = true
			promise:cancel()
			reject("timeout")
		end)
	end)
end

function Knit.buffer(action: ActionHandle, window: number): Types.Promise<Types.InputEvent>
	return Knit.timeout((action :: any).pressed:once(), window)
end

function Knit.visualizer(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "KnitVisualizer"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 400)
	frame.Position = UDim2.new(1, -290, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "Knit  --  Input Visualizer"
	title.TextColor3 = Color3.fromRGB(167, 139, 250)
	title.Font = Enum.Font.Code
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local rows: { [string]: TextLabel } = {}

	local function getOrCreateRow(name: string): TextLabel
		if rows[name] then return rows[name] end
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 16)
		row.BackgroundTransparency = 1
		row.Text = name .. "  --  idle"
		row.TextColor3 = Color3.fromRGB(161, 161, 170)
		row.Font = Enum.Font.Code
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = frame
		rows[name] = row
		return row
	end

	local function watch(name: string, handle: any)
		local row = getOrCreateRow(name)
		if handle.pressed then
			handle.pressed:connect(function()
				row.Text = name .. "  --  pressed"
				row.TextColor3 = Color3.fromRGB(167, 139, 250)
			end)
		end
		if handle.released then
			handle.released:connect(function()
				row.Text = name .. "  --  idle"
				row.TextColor3 = Color3.fromRGB(161, 161, 170)
			end)
		end
		if handle.triggered then
			handle.triggered:connect(function()
				row.Text = name .. "  --  triggered"
				row.TextColor3 = Color3.fromRGB(134, 239, 172)
				task.delay(0.4, function()
					row.Text = name .. "  --  idle"
					row.TextColor3 = Color3.fromRGB(161, 161, 170)
				end)
			end)
		end
		if handle.moved then
			handle.moved:connect(function(event)
				row.Text = string.format("%s  --  %.2f, %.2f", name, event.delta and event.delta.X or 0, event.delta and event.delta.Y or 0)
				row.TextColor3 = Color3.fromRGB(253, 224, 71)
			end)
		end
	end

	for name, handle in _registry do
		watch(name, handle)
	end

	Knit.context.changed:connect(function(stack)
		local contextRow = getOrCreateRow("__context__")
		contextRow.Text = "context  --  " .. (stack[#stack] or "none")
		contextRow.TextColor3 = Color3.fromRGB(94, 234, 212)
	end)

	gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Knit.remove(name: string)
	local handle = _registry[name]
	if handle then
		handle:destroy()
		_registry[name] = nil
	end
end

function Knit.clear()
	for name, handle in _registry do
		handle:destroy()
		_registry[name] = nil
	end
	table.clear(_rawListeners)
	table.clear(_contextStack)
end

function Knit.createSession(name: string, defaults: { [string]: any }) : Types.SessionHandle
	if _sessions[name] then
		return _sessions[name]
	end
	local session = Session.new(name, defaults)
	_sessions[name] = session
	return session
end

function Knit.getSession(name: string)
	return _sessions[name]
end

function Knit.modifySession(name: string, data: { [string]: any })
	local session = _sessions[name]
	assert(session, `Knit.modifySession: session "{name}" does not exist`)
	session:patch(data)
end

function Knit.removeSession(name: string)
	local session = _sessions[name]
	if session then
		session:destroy()
		_sessions[name] = nil
	end
end

return Knit