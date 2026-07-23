local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Learning Coach Replay Control",
		desc = "Keeps research replay playback at 1x and clears the initial pause",
		author = "Dmitry / Codex",
		date = "2026-07-23",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local elapsed = 0
local speedRequested = false
local unpauseRequested = false

function widget:Update(dt)
	elapsed = elapsed + (dt or 0)
	if elapsed < 1 then
		return
	end

	if not speedRequested and type(Spring.SendCommands) == "function" then
		speedRequested = true
		Spring.SendCommands("setspeed 1")
		Spring.Echo("[BAR Learning Coach Replay Control] speed=1 requested")
	end

	local gameTime = type(Spring.GetGameSeconds) == "function" and Spring.GetGameSeconds() or nil
	if not unpauseRequested and gameTime == 0 and type(Spring.SendCommands) == "function" then
		unpauseRequested = true
		Spring.SendCommands("pause")
		Spring.Echo("[BAR Learning Coach Replay Control] unpause requested")
	end
end
