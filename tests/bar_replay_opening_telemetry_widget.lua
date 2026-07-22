local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Learning Coach Telemetry",
		desc = "Collects target-team opening evidence from a replay without opponent data",
		author = "Dmitry / Codex",
		date = "2026-07-22",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local MODULE_ROOT = "LuaUI/Include/bar_learning_coach/"
local CONFIG_PATH = "LuaUI/Config/bar_learning_coach_replay_target.lua"
local ReplayOpeningCollector = VFS.Include(MODULE_ROOT .. "replay_opening_collector.lua")
local BuildPowerAdapter = VFS.Include(MODULE_ROOT .. "build_power_adapter.lua")

local SAMPLE_INTERVAL = 5
local config = nil
local collector = nil
local buildPowerAdapter = nil
local sampleCount = 0
local elapsed = 0
local startupElapsed = 0
local unpauseRequested = false
local nextSampleGameTime = 0
local lastObservedGameTime = nil
local active = false
local finished = false

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function field(value)
	if value == nil then
		return "unknown"
	end
	return tostring(value)
end

local function numberField(value)
	if not finiteNumber(value) then
		return "unknown"
	end
	return string.format("%.3f", value)
end

local function boolField(value)
	if type(value) ~= "boolean" then
		return "unknown"
	end
	return tostring(value)
end

local function resourceFields(prefix, resource)
	resource = resource or {}
	return table.concat({
		prefix .. ".known=" .. boolField(resource.known),
		prefix .. ".current=" .. numberField(resource.current),
		prefix .. ".storage=" .. numberField(resource.storage),
		prefix .. ".pull=" .. numberField(resource.pull),
		prefix .. ".income=" .. numberField(resource.income),
		prefix .. ".expense=" .. numberField(resource.expense),
		prefix .. ".share=" .. numberField(resource.share),
		prefix .. ".sent=" .. numberField(resource.sent),
		prefix .. ".received=" .. numberField(resource.received),
		prefix .. ".excess=" .. numberField(resource.excess),
	}, " ")
end

local function sortedKeys(values)
	local keys = {}
	for key in pairs(values or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function gameTime()
	if type(Spring.GetGameSeconds) ~= "function" then
		return nil
	end
	local ok, value = pcall(Spring.GetGameSeconds)
	return ok and finiteNumber(value) and value or nil
end

local function gameFrame()
	if type(Spring.GetGameFrame) ~= "function" then
		return nil
	end
	local ok, value = pcall(Spring.GetGameFrame)
	return ok and finiteNumber(value) and value or nil
end

local function loadConfig()
	local ok, loaded = pcall(VFS.Include, CONFIG_PATH)
	if not ok or type(loaded) ~= "table" then
		return nil, "config unavailable"
	end
	if not finiteNumber(loaded.targetTeamID) then
		return nil, "targetTeamID invalid"
	end
	if loaded.maxGameTime ~= nil and (not finiteNumber(loaded.maxGameTime) or loaded.maxGameTime <= 0) then
		return nil, "maxGameTime invalid"
	end
	return {
		targetTeamID = loaded.targetTeamID,
		maxGameTime = loaded.maxGameTime or 480,
		autoUnpause = loaded.autoUnpause == true,
	}
end

local function logUnit(prefix, eventName, item, time, frame, builderID)
	Spring.Echo(table.concat({
		prefix,
		"event=" .. eventName,
		"frame=" .. numberField(frame),
		"time=" .. numberField(time),
		"team=" .. numberField(config and config.targetTeamID),
		"unit=" .. numberField(item and item.unitID),
		"def=" .. numberField(item and item.unitDefID),
		"name=" .. field(item and item.name),
		"definitionKnown=" .. boolField(item and item.definitionKnown),
		"commander=" .. boolField(item and item.isCommander),
		"factory=" .. boolField(item and item.isFactory),
		"builder=" .. boolField(item and item.isBuilder),
		"buildSpeed=" .. numberField(item and item.buildSpeed),
		"buildStateKnown=" .. boolField(item and item.buildStateKnown),
		"beingBuilt=" .. boolField(item and item.beingBuilt),
		"builderID=" .. numberField(builderID),
		"positionKnown=" .. boolField(item and item.positionKnown),
		"x=" .. numberField(item and item.x),
		"z=" .. numberField(item and item.z),
	}, " "))
end

local function collectSnapshot()
	if not active or finished then
		return
	end

	local time = gameTime()
	local frame = gameFrame()
	local snapshot = collector:collect(time, frame)
	local buildPower = buildPowerAdapter:collect(config.targetTeamID)
	sampleCount = sampleCount + 1
	Spring.Echo(table.concat({
		"[BAR Learning Coach ReplaySnapshot]",
		"sample=" .. sampleCount,
		"frame=" .. numberField(snapshot.gameFrame),
		"time=" .. numberField(snapshot.gameTime),
		"team=" .. numberField(snapshot.targetTeamID),
		"unitListKnown=" .. boolField(snapshot.unitListKnown),
		"units=" .. numberField(snapshot.unitCount),
		"unknownUnits=" .. numberField(snapshot.unknownUnitCount),
		"commanders=" .. (#snapshot.commanderNames > 0 and table.concat(snapshot.commanderNames, ",") or "none"),
		"reason=" .. field(snapshot.reason),
		resourceFields("metal", snapshot.resources and snapshot.resources.metal),
		resourceFields("energy", snapshot.resources and snapshot.resources.energy),
		"buildPowerListKnown=" .. boolField(buildPower.unitListKnown),
		"buildPowerReason=" .. field(buildPower.reason),
	}, " "))

	local names = sortedKeys(snapshot.countsByName)
	for i = 1, #names do
		local name = names[i]
		Spring.Echo(table.concat({
			"[BAR Learning Coach ReplayCount]",
			"sample=" .. sampleCount,
			"name=" .. name,
			"total=" .. numberField(snapshot.countsByName[name]),
			"finished=" .. numberField(snapshot.finishedCountsByName[name]),
		}, " "))
	end

	for i = 1, #snapshot.units do
		local item = snapshot.units[i]
		if item.isFactory == true then
			Spring.Echo(table.concat({
				"[BAR Learning Coach ReplayFactory]",
				"sample=" .. sampleCount,
				"unit=" .. numberField(item.unitID),
				"name=" .. field(item.name),
				"taskKnown=" .. boolField(item.taskKnown),
				"command=" .. numberField(item.taskCommandID),
				"target=" .. numberField(item.taskTargetID),
			}, " "))
		end
	end

	for i = 1, #buildPower.units do
		local item = buildPower.units[i]
		if item.isBuilder == true or item.definitionKnown ~= true then
			Spring.Echo(table.concat({
				"[BAR Learning Coach ReplayBuildPower]",
				"sample=" .. sampleCount,
				"unit=" .. numberField(item.unitID),
				"def=" .. numberField(item.unitDefID),
				"definitionKnown=" .. boolField(item.definitionKnown),
				"factory=" .. boolField(item.isFactory),
				"buildSpeed=" .. numberField(item.buildSpeed),
				"stateKnown=" .. boolField(item.stateKnown),
				"beingBuilt=" .. boolField(item.beingBuilt),
				"stunned=" .. boolField(item.stunned),
				"taskKnown=" .. boolField(item.taskKnown),
				"command=" .. numberField(item.taskCommandID),
				"target=" .. numberField(item.taskTargetID),
				"nanoActivity=" .. numberField(item.nanoActivity),
			}, " "))
		end
	end

	if finiteNumber(time) and time >= config.maxGameTime then
		finished = true
		Spring.Echo(table.concat({
			"[BAR Learning Coach Replay]",
			"status=complete",
			"samples=" .. sampleCount,
			"time=" .. numberField(time),
			"target=" .. numberField(config.maxGameTime),
		}, " "))
	end
end

local function targetEvent(eventName, unitID, unitDefID, unitTeam, builderID)
	if not active or finished or unitTeam ~= config.targetTeamID then
		return
	end
	logUnit(
		"[BAR Learning Coach ReplayEvent]",
		eventName,
		collector:describeUnit(unitID, unitDefID),
		gameTime(),
		gameFrame(),
		builderID
	)
end

function widget:Initialize()
	local reason = nil
	config, reason = loadConfig()
	if config == nil then
		Spring.Echo("[BAR Learning Coach Replay] status=disabled reason=" .. reason)
		return
	end

	collector = ReplayOpeningCollector.new(Spring, UnitDefs, config.targetTeamID)
	buildPowerAdapter = BuildPowerAdapter.new(Spring, UnitDefs)
	active = true
	Spring.Echo(table.concat({
		"[BAR Learning Coach Replay]",
		"status=started",
		"team=" .. numberField(config.targetTeamID),
		"target=" .. numberField(config.maxGameTime),
		"interval=" .. numberField(SAMPLE_INTERVAL),
	}, " "))
	collectSnapshot()
	nextSampleGameTime = SAMPLE_INTERVAL
end

function widget:Update(dt)
	if not active or finished then
		return
	end
	startupElapsed = startupElapsed + (dt or 0)
	if config.autoUnpause and not unpauseRequested and startupElapsed >= 1 and gameTime() == 0 then
		unpauseRequested = true
		if type(Spring.SendCommands) == "function" then
			Spring.SendCommands("pause")
			Spring.Echo("[BAR Learning Coach Replay] status=unpause-requested")
		else
			Spring.Echo("[BAR Learning Coach Replay] status=unpause-unavailable")
		end
	end
	local currentGameTime = gameTime()
	if finiteNumber(currentGameTime) then
		if finiteNumber(lastObservedGameTime) and currentGameTime < lastObservedGameTime then
			nextSampleGameTime = 0
		end
		lastObservedGameTime = currentGameTime
		if currentGameTime < config.maxGameTime and currentGameTime < nextSampleGameTime then
			return
		end
		while nextSampleGameTime <= currentGameTime do
			nextSampleGameTime = nextSampleGameTime + SAMPLE_INTERVAL
		end
	else
		elapsed = elapsed + (dt or 0)
		if elapsed < SAMPLE_INTERVAL then
			return
		end
		elapsed = 0
	end
	collectSnapshot()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	targetEvent("created", unitID, unitDefID, unitTeam, builderID)
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	targetEvent("finished", unitID, unitDefID, unitTeam, nil)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	targetEvent("destroyed", unitID, unitDefID, unitTeam, nil)
end

function widget:Shutdown()
	Spring.Echo(table.concat({
		"[BAR Learning Coach Replay]",
		"status=stopped",
		"samples=" .. sampleCount,
		"complete=" .. tostring(finished),
	}, " "))
end
