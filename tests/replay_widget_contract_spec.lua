local WIDGET_PATH = "LuaUI/Widgets/bar_replay_coach.lua"

local function loadWidget(environment)
	setmetatable(environment, { __index = getfenv() })
	if VFS and VFS.Include then
		VFS.Include(WIDGET_PATH, environment)
	else
		local chunk = assert(loadfile(WIDGET_PATH))
		setfenv(chunk, environment)
		chunk()
	end
	return environment.widget
end

describe("replay widget contract", function()
	it("stays disabled by default and stops before team reads outside replay", function()
		local teamListCalled = false
		local rendered = {}
		local replayWidget = loadWidget({
			widget = {},
			Spring = {
				IsReplay = function() return false end,
				GetTeamList = function()
					teamListCalled = true
					return { 0 }
				end,
			},
			Game = { mapName = "Ravaged Remake v1.2" },
			UnitDefs = {},
			gl = {
				Color = function() end,
				Rect = function() end,
				Text = function(line) rendered[#rendered + 1] = line end,
			},
		})

		assert.are.equal(false, replayWidget:GetInfo().enabled)
		replayWidget:SetConfigData({
			lastReport = {
				playerName = "Old replay",
				mapName = "Old map",
				faction = "Cortex",
				summary = "SAVED_REPORT_MUST_NOT_RENDER_LIVE",
			},
		})
		replayWidget:Initialize()
		replayWidget:DrawScreen()
		assert.are.equal(false, teamListCalled)
		assert.is_nil(table.concat(rendered, "\n"):find("SAVED_REPORT_MUST_NOT_RENDER_LIVE", 1, true))
	end)

	it("can hide and show the panel without requiring an analysis session", function()
		local replayWidget = loadWidget({
			widget = {},
			Spring = { IsReplay = function() return false end },
			Game = {},
			UnitDefs = {},
			gl = {},
		})

		assert.are.equal(true, replayWidget:TextCommand("replaycoach hide"))
		assert.are.equal(true, replayWidget:TextCommand("replaycoach show"))
	end)
end)
