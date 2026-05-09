local RunService = game:GetService("RunService")
local VersionChecker = require(script.VersionChecker)
local IsClient = RunService:IsClient()

local VersionHandler = {}
VersionHandler._version = "0.0.0"
VersionHandler._reporef = "NotKisoMomo/Knit"
VersionHandler._autoUpdate = true
VersionHandler._silent = false

function VersionHandler.Start()
	if IsClient then return end
	
	VersionChecker.check({
		Module     = VersionHandler,
		Repo       = VersionHandler._reporef,
		AutoUpdate = VersionHandler._autoUpdate,
		Silent     = VersionHandler._silent,
	})
end

return VersionHandler