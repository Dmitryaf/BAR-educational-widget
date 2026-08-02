local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Replay Coach",
		desc = "Finds one confirmed practice focus after a supported replay",
		author = "Dmitry Afonasenko",
		date = "2026-08-02",
		license = "GPL-2.0-or-later",
		layer = 1,
		enabled = false,
	}
end

local MODULE_ROOT = "LuaUI/Include/bar_learning_coach/"
local CONFIG_PATH = "LuaUI/Config/bar_replay_coach.lua"
local ReplayOpeningCollector = VFS.Include(MODULE_ROOT .. "replay_opening_collector.lua")
local ReplayContext = VFS.Include(MODULE_ROOT .. "replay_context.lua")
local ReplayObservation = VFS.Include(MODULE_ROOT .. "replay_observation.lua")
local EpisodeAggregator = VFS.Include(MODULE_ROOT .. "episode_aggregator.lua")
local HistoryBuffer = VFS.Include(MODULE_ROOT .. "history_buffer.lua")
local EnergyStall = VFS.Include(MODULE_ROOT .. "energy_stall.lua")
local IssueRanker = VFS.Include(MODULE_ROOT .. "issue_ranker.lua")
local TrainingTaskSelector = VFS.Include(MODULE_ROOT .. "training_task_selector.lua")
local ReplayReport = VFS.Include(MODULE_ROOT .. "replay_report.lua")
local ReplayReportPresentation = VFS.Include(MODULE_ROOT .. "replay_report_presentation.lua")
local ReplaySession = VFS.Include(MODULE_ROOT .. "replay_session.lua")

local context = ReplayContext.get()
local collector = nil
local session = nil
local targetTeamID = nil
local playerName = nil
local active = false
local elapsed = context.sampleInterval
local panelVisible = true
local status = "initializing"
local statusDetail = nil
local availableTeamsText = nil
local latestState = nil
local displayReport = nil
local savedReport = nil

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
end

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

local function safeDisplay(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	value = value:gsub("[%c]", " ")
	return value:sub(1, 48)
end

local function loadConfig()
	local ok, loaded = pcall(VFS.Include, CONFIG_PATH)
	if not ok or type(loaded) ~= "table" then
		return nil, "create LuaUI/Config/bar_replay_coach.lua with targetTeamID"
	end
	if not finiteNumber(loaded.targetTeamID) or loaded.targetTeamID % 1 ~= 0 then
		return nil, "configured targetTeamID is invalid"
	end
	return loaded.targetTeamID, nil
end

local function teamExists(teamID)
	local ok, teams = safeCall(Spring and Spring.GetTeamList, -1)
	if not ok or type(teams) ~= "table" then
		return false, "team list unavailable"
	end
	for i = 1, #teams do
		if teams[i] == teamID then
			local gaiaOk, gaiaTeamID = safeCall(Spring and Spring.GetGaiaTeamID)
			if not gaiaOk or not finiteNumber(gaiaTeamID) then
				return false, "Gaia team ID unavailable"
			end
			if gaiaTeamID == teamID then
				return false, "Gaia team is not analyzable"
			end
			return true, nil
		end
	end
	return false, "configured team is unavailable"
end

local function teamDisplayName(teamID)
	local ok, players = safeCall(Spring and Spring.GetPlayerList, teamID, false)
	if ok and type(players) == "table" then
		for i = 1, #players do
			local infoOk, name, _, spectator, observedTeamID = safeCall(
				Spring and Spring.GetPlayerInfo,
				players[i],
				false
			)
			if infoOk and spectator == false and observedTeamID == teamID then
				local safeName = safeDisplay(name)
				if safeName then
					return safeName
				end
			end
		end
	end
	local aiOk, aiName = safeCall(Spring and Spring.GetTeamLuaAI, teamID)
	if aiOk then
		local safeName = safeDisplay(aiName)
		if safeName then
			return safeName
		end
	end
	return "Team " .. tostring(teamID)
end

local function availableTeams()
	local ok, teams = safeCall(Spring and Spring.GetTeamList, -1)
	if not ok or type(teams) ~= "table" then
		return nil
	end
	local gaiaOk, gaiaTeamID = safeCall(Spring and Spring.GetGaiaTeamID)
	if not gaiaOk or not finiteNumber(gaiaTeamID) then
		return nil
	end
	local labels = {}
	for i = 1, #teams do
		if teams[i] ~= gaiaTeamID then
			labels[#labels + 1] = tostring(teams[i]) .. "=" .. teamDisplayName(teams[i])
		end
	end
	return #labels > 0 and table.concat(labels, ", ") or nil
end

local function gameTime()
	local ok, value = safeCall(Spring and Spring.GetGameSeconds)
	return ok and finiteNumber(value) and value or nil
end

local function gameFrame()
	local ok, value = safeCall(Spring and Spring.GetGameFrame)
	return ok and finiteNumber(value) and value or nil
end

local function dependencies()
	return {
		HistoryBuffer = HistoryBuffer,
		EnergyStall = EnergyStall,
		EpisodeAggregator = EpisodeAggregator,
		IssueRanker = IssueRanker,
		TrainingTaskSelector = TrainingTaskSelector,
		ReplayReport = ReplayReport,
	}
end

local function collectObservation()
	if not active or collector == nil or session == nil then
		return
	end
	local raw = collector:collect(gameTime(), gameFrame())
	local observation, observationError = ReplayObservation.normalize(context, raw, {
		mapName = type(Game) == "table" and Game.mapName or nil,
	})
	if observation == nil then
		status = "temporarily_unavailable"
		statusDetail = observationError
		return
	end
	local state, sessionError = session:record(observation)
	if state == nil then
		status = "temporarily_unavailable"
		statusDetail = sessionError
		return
	end
	latestState = state
	status = observation.contextStatus == "supported" and "analyzing" or observation.contextStatus
	statusDetail = observation.contextReason
end

local function reportLines()
	if displayReport then
		return ReplayReportPresentation.lines(displayReport)
	end
	local team = playerName and (playerName .. " (#" .. tostring(targetTeamID) .. ")") or "not selected"
	local lines = {
		"BAR Replay Coach",
		"Статус: " .. tostring(status),
		"Team: " .. team,
		"Контекст: " .. tostring(latestState and latestState.contextStatus or statusDetail or "unknown"),
		"Подтверждённых эпизодов: " .. tostring(latestState and latestState.episodeCount or 0),
		"Отчёт: /luaui replaycoach report",
		"Панель: /luaui replaycoach hide | show",
	}
	if availableTeamsText then
		lines[#lines + 1] = "Доступные teams: " .. availableTeamsText
	end
	return lines
end

local function wrapLine(text, limit)
	if text == "" then
		return { "" }
	end
	local result = {}
	local current = ""
	for word in tostring(text):gmatch("%S+") do
		if current == "" then
			current = word
		elseif #current + #word + 1 <= limit then
			current = current .. " " .. word
		else
			result[#result + 1] = current
			current = word
		end
	end
	if current ~= "" then
		result[#result + 1] = current
	end
	return result
end

local function wrappedLines(lines)
	local result = {}
	for i = 1, #lines do
		local wrapped = wrapLine(lines[i], 68)
		for j = 1, #wrapped do
			result[#result + 1] = wrapped[j]
		end
	end
	return result
end

local function generateReport(reason)
	if session == nil then
		status = "temporarily_unavailable"
		statusDetail = "analysis session unavailable"
		return
	end
	displayReport = session:finish(playerName)
	savedReport = displayReport
	active = false
	status = "report_ready"
	local lines = ReplayReportPresentation.lines(displayReport)
	if Spring and type(Spring.Echo) == "function" then
		Spring.Echo("[BAR Replay Coach] report generated: " .. tostring(reason))
		for i = 1, #lines do
			if lines[i] ~= "" then
				Spring.Echo("[BAR Replay Coach] " .. lines[i])
			end
		end
	end
end

function widget:Initialize()
	local replayOk, isReplay = safeCall(Spring and Spring.IsReplay)
	if not replayOk or isReplay ~= true then
		status = "unsupported_mode"
		statusDetail = "Replay Coach only runs during replay playback"
		displayReport = nil
		return
	end

	local configError = nil
	targetTeamID, configError = loadConfig()
	if targetTeamID == nil then
		status = "team_not_selected"
		statusDetail = configError
		availableTeamsText = availableTeams()
		return
	end
	local validTeam, teamError = teamExists(targetTeamID)
	if not validTeam then
		status = "team_unavailable"
		statusDetail = teamError
		availableTeamsText = availableTeams()
		return
	end

	playerName = teamDisplayName(targetTeamID)
	collector = ReplayOpeningCollector.new(Spring, UnitDefs, targetTeamID)
	session = ReplaySession.new(context, dependencies())
	displayReport = nil
	active = true
	status = "analyzing"
	statusDetail = nil
	collectObservation()
end

function widget:Update(dt)
	if not active then
		return
	end
	elapsed = elapsed + (dt or 0)
	if elapsed < context.sampleInterval then
		return
	end
	elapsed = 0
	collectObservation()
end

function widget:GameOver()
	if active then
		collectObservation()
		generateReport("game over")
	end
end

function widget:TextCommand(command)
	if command == "replaycoach report" or command == "replaycoach" then
		generateReport("manual command")
		return true
	elseif command == "replaycoach hide" then
		panelVisible = false
		return true
	elseif command == "replaycoach show" then
		panelVisible = true
		return true
	end
	return false
end

function widget:DrawScreen()
	if not panelVisible then
		return
	end
	local glColor = gl and gl.Color
	local glRect = gl and gl.Rect
	local glText = gl and gl.Text
	if type(glColor) ~= "function" or type(glRect) ~= "function" or type(glText) ~= "function" then
		return
	end

	local geometryOk, vsx, vsy = safeCall(Spring and Spring.GetViewGeometry)
	if not geometryOk or not finiteNumber(vsx) or not finiteNumber(vsy) then
		vsx, vsy = 1920, 1080
	end
	local lines = wrappedLines(reportLines())
	local width = math.min(620, vsx * 0.40)
	local lineHeight = 17
	local padding = 12
	local height = #lines * lineHeight + padding * 2
	local x1 = 24
	local y2 = vsy - 90
	local x2 = x1 + width
	local y1 = math.max(0, y2 - height)

	glColor(0.04, 0.05, 0.06, 0.92)
	glRect(x1, y1, x2, y2)
	glColor(0.38, 0.72, 0.92, 1.0)
	glRect(x1, y2 - 3, x2, y2)
	for i = 1, #lines do
		local line = lines[i]
		local y = y2 - padding - i * lineHeight
		if line == "BAR Replay Coach" then
			glColor(0.78, 0.92, 1.0, 1.0)
		else
			glColor(0.94, 0.94, 0.91, 1.0)
		end
		glText(line, x1 + padding, y, 13, "o")
	end
	glColor(1, 1, 1, 1)
end

function widget:GetConfigData()
	return {
		version = 1,
		panelVisible = panelVisible,
		lastReport = savedReport,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	if type(data.panelVisible) == "boolean" then
		panelVisible = data.panelVisible
	end
	if type(data.lastReport) == "table" then
		savedReport = data.lastReport
	end
end
