local Types = require(script.Parent.Types)

local AXIS_INPUT_TYPES = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.Gyro] = true,
	[Enum.UserInputType.Accelerometer] = true,
}

local AXIS_KEYCODES = {
	[Enum.KeyCode.Thumbstick1] = true,
	[Enum.KeyCode.Thumbstick2] = true,
}

local Util = {}

function Util.inferMode(bindings: { Types.InputBinding }): Types.ActionMode
	for _, binding in bindings do
		if typeof(binding) == "EnumItem" then
			if binding.EnumType == Enum.UserInputType then
				if AXIS_INPUT_TYPES[binding] then
					return "axis"
				end
			elseif binding.EnumType == Enum.KeyCode then
				if AXIS_KEYCODES[binding] then
					return "axis"
				end
			end
		end
	end
	return "button"
end

function Util.isAxisBinding(binding: Types.InputBinding): boolean
	if typeof(binding) ~= "EnumItem" then return false end
	if binding.EnumType == Enum.UserInputType then
		return AXIS_INPUT_TYPES[binding] == true
	end
	if binding.EnumType == Enum.KeyCode then
		return AXIS_KEYCODES[binding] == true
	end
	return false
end

function Util.matchesBinding(input: InputObject, binding: Types.InputBinding): boolean
	if typeof(binding) ~= "EnumItem" then return false end
	if binding.EnumType == Enum.KeyCode then
		return input.KeyCode == binding
	elseif binding.EnumType == Enum.UserInputType then
		return input.UserInputType == binding
	end
	return false
end

function Util.getDelta(input: InputObject): Vector2
	return Vector2.new(input.Delta.X, input.Delta.Y)
end

function Util.getPosition(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

return Util