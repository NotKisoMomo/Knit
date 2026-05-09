-- VersionChecker
-- Compares a module's _version against the latest GitHub release.
-- Place in: ServerScriptService (or wherever you initialise your modules).
-- Requires HttpService to be enabled in Game Settings > Security.

local HttpService = game:GetService("HttpService")

export type VersionCheckerConfig = {
	Module: { _version: string },
	Repo: string,
	AutoUpdate: boolean,
	Silent: boolean,
}

local VersionChecker = {}

local function parseVersion(v: string): { number }
	local parts = {}
	for n in v:gmatch("%d+") do
		table.insert(parts, tonumber(n) :: number)
	end
	return parts
end

-- Returns -1 (a < b), 0 (equal), 1 (a > b)
local function compareVersions(a: string, b: string): number
	local pa, pb = parseVersion(a), parseVersion(b)
	for i = 1, math.max(#pa, #pb) do
		local na = pa[i] or 0
		local nb = pb[i] or 0
		if na < nb then return -1 end
		if na > nb then return  1 end
	end
	return 0
end

function VersionChecker.check(config: VersionCheckerConfig)
	local ok, result = pcall(function()
		local localVersion: string = config.Module._version
		assert(type(localVersion) == "string", "Module._version must be a string")

		local url = string.format(
			"https://api.github.com/repos/%s/releases/latest",
			config.Repo
		)

		local raw = HttpService:GetAsync(url, true)
		local data = HttpService:JSONDecode(raw)

		local latestVersion: string = (data.tag_name or ""):gsub("^v", "")
		assert(latestVersion ~= "", "Could not parse tag_name from GitHub response")

		local cmp = compareVersions(localVersion, latestVersion)

		if cmp == 0 then
			if not config.Silent then
				print(string.format(
					"[VersionChecker] ? %s is up-to-date (v%s)",
					config.Repo, localVersion
					))
			end
			return
		end

		if cmp == 1 then
			warn(string.format(
				"[VersionChecker] ? Local v%s is AHEAD of latest release v%s on %s — dev build?",
				localVersion, latestVersion, config.Repo
				))
			return
		end

		warn(string.format(
			"[VersionChecker] ? %s is OUT OF DATE — local: v%s | latest: v%s",
			config.Repo, localVersion, latestVersion
			))

		if config.AutoUpdate then
			-- Release notes
			local body: string = data.body or "No release notes provided."
			if #body > 800 then
				body = body:sub(1, 797) .. "..."
			end

			print(string.format(
				"\n-----------------------------------------\n" ..
					"  Release notes for v%s (%s)\n" ..
					"-----------------------------------------\n" ..
					"%s\n" ..
					"-----------------------------------------",
				latestVersion, data.name or latestVersion, body
				))

			-- Link to the release
			local releaseUrl: string = data.html_url
				or string.format("https://github.com/%s/releases/latest", config.Repo)

			warn(string.format(
				"[VersionChecker] Update available ? %s",
				releaseUrl
				))
		end
	end)

	if not ok then
		warn(string.format(
			"[VersionChecker] Failed to check version for %s: %s",
			config.Repo, tostring(result)
			))
	end
end

return VersionChecker