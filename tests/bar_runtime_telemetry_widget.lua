local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Learning Coach Telemetry",
		desc = "Collects resource and ENERGY_STALL diagnostic samples for runtime verification",
		author = "Dmitry / Codex",
		date = "2026-07-21",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local MODULE_ROOT = "LuaUI/Include/bar_learning_coach/"
local HistoryBuffer = VFS.Include(MODULE_ROOT .. "history_buffer.lua")
local EnergyStall = VFS.Include(MODULE_ROOT .. "energy_stall.lua")
local EnergyStallRecommendation = VFS.Include(MODULE_ROOT .. "energy_stall_recommendation.lua")
local SnapshotCollector = VFS.Include(MODULE_ROOT .. "snapshot_collector.lua")
local BuildPowerAdapter = VFS.Include(MODULE_ROOT .. "build_power_adapter.lua")
local BuildPowerSnapshot = VFS.Include(MODULE_ROOT .. "build_power_snapshot.lua")
local OpeningContext = VFS.Include(MODULE_ROOT .. "opening_context.lua")
local OpeningAdapter = VFS.Include(MODULE_ROOT .. "opening_adapter.lua")
local OpeningTracker = VFS.Include(MODULE_ROOT .. "opening_tracker.lua")
local OpeningProgress = VFS.Include(MODULE_ROOT .. "opening_progress.lua")

local SAMPLE_INTERVAL = 5
local history = HistoryBuffer.new(120)
local detector = EnergyStall.new()
local collector = SnapshotCollector.new(history, detector)
local buildPowerAdapter = BuildPowerAdapter.new(Spring, UnitDefs)
local openingContext = OpeningContext.get()
local openingAdapter = OpeningAdapter.new(Spring, UnitDefs, Game)
local openingTracker = OpeningTracker.new(openingAdapter, openingContext)
local elapsed = SAMPLE_INTERVAL
local sampleCount = 0

local function value(valueToFormat)
	if type(valueToFormat) ~= "number" then
		return "unknown"
	end
	return string.format("%.3f", valueToFormat)
end

local function field(valueToFormat)
	if valueToFormat == nil then
		return "unknown"
	end
	return tostring(valueToFormat)
end

local function readResource(teamID, resourceName)
	if type(Spring.GetTeamResources) ~= "function" or type(teamID) ~= "number" then
		return {}
	end

	local current, storage, pull, income, expense, share, sent, received, excess =
		Spring.GetTeamResources(teamID, resourceName)
	return {
		current = current,
		storage = storage,
		pull = pull,
		income = income,
		expense = expense,
		share = share,
		sent = sent,
		received = received,
		excess = excess,
	}
end

local function teamID()
	if type(Spring.GetMyTeamID) == "function" then
		return Spring.GetMyTeamID()
	end
	if type(Spring.GetLocalTeamID) == "function" then
		return Spring.GetLocalTeamID()
	end
	return nil
end

local function resourceFields(prefix, resource)
	return table.concat({
		prefix .. ".current=" .. value(resource.current),
		prefix .. ".storage=" .. value(resource.storage),
		prefix .. ".pull=" .. value(resource.pull),
		prefix .. ".income=" .. value(resource.income),
		prefix .. ".expense=" .. value(resource.expense),
		prefix .. ".share=" .. value(resource.share),
		prefix .. ".sent=" .. value(resource.sent),
		prefix .. ".received=" .. value(resource.received),
		prefix .. ".excess=" .. value(resource.excess),
	}, " ")
end

local function collect()
	local currentTeamID = teamID()
	local gameTime = type(Spring.GetGameSeconds) == "function" and Spring.GetGameSeconds() or nil
	local gameFrame = type(Spring.GetGameFrame) == "function" and Spring.GetGameFrame() or nil
	local metal = readResource(currentTeamID, "metal")
	local energy = readResource(currentTeamID, "energy")
	local result = collector:record({
		gameTime = gameTime,
		resources = {
			metal = metal,
			energy = energy,
		},
	})
	local recommendation = EnergyStallRecommendation.fromDiagnostic(result)
	local buildPowerRaw = buildPowerAdapter:collect(currentTeamID)
	local buildPower = BuildPowerSnapshot.fromRaw(buildPowerRaw)
	local opening = openingTracker:observe(currentTeamID, gameTime, result.state)
	local progress = OpeningProgress.evaluate(openingContext, opening)

	sampleCount = sampleCount + 1
	Spring.Echo(table.concat({
		"[BAR Learning Coach Telemetry]",
		"sample=" .. sampleCount,
		"frame=" .. value(gameFrame),
		"time=" .. value(gameTime),
		"team=" .. value(currentTeamID),
		resourceFields("metal", metal),
		resourceFields("energy", energy),
		"state=" .. tostring(result.state),
		"ratio=" .. value(result.storageRatio),
		"deficit=" .. value(result.deficit),
		"trend=" .. value(result.storageTrend),
		"duration=" .. value(result.duration),
		"episode=" .. value(result.episodeDuration),
		"cooldown=" .. value(result.cooldownRemaining),
		"recommendation=" .. tostring(recommendation and recommendation.id or "none"),
		"buildPower.status=" .. tostring(buildPower.status),
		"buildPower.units=" .. value(buildPower.unitCount),
		"buildPower.builders=" .. value(buildPower.knownBuilderCount),
		"buildPower.total=" .. value(buildPower.totalBuildPower),
		"buildPower.active=" .. value(buildPower.activeBuildPower),
		"buildPower.activeBuilders=" .. value(buildPower.activeBuilderCount),
		"buildPower.inactiveBuilders=" .. value(buildPower.inactiveBuilderCount),
		"buildPower.targets=" .. value(#buildPower.targets),
		"buildPower.unknownUnits=" .. value(buildPower.unknownUnitCount),
		"buildPower.reason=" .. tostring(buildPower.reason),
		"reason=" .. tostring(result.reason or "tracked"),
	}, " "))

	local milestoneFields = {}
	for i = 1, #progress.milestones do
		local milestone = progress.milestones[i]
		milestoneFields[#milestoneFields + 1] = milestone.id .. ":" .. milestone.state
	end
	Spring.Echo(table.concat({
		"[BAR Learning Coach Opening]",
		"sample=" .. sampleCount,
		"frame=" .. value(gameFrame),
		"time=" .. value(gameTime),
		"team=" .. value(currentTeamID),
		"map=" .. field(opening.evidence and opening.evidence.mapName),
		"context=" .. field(opening.contextId),
		"contextStatus=" .. field(opening.contextStatus),
		"contextReason=" .. field(opening.reason),
		"commanders=" .. (#opening.evidence.commanderUnitDefNames > 0
			and table.concat(opening.evidence.commanderUnitDefNames, ",") or "none"),
		"units=" .. value(opening.evidence and opening.evidence.unitCount),
		"unknownUnits=" .. value(opening.evidence and opening.evidence.unknownUnitCount),
		"apiTeamUnits=" .. field(opening.evidence.api and opening.evidence.api.getTeamUnits),
		"apiUnitDef=" .. field(opening.evidence.api and opening.evidence.api.getUnitDefID),
		"apiBuildState=" .. field(opening.evidence.api and opening.evidence.api.getUnitIsBeingBuilt),
		"apiWorkerTask=" .. field(opening.evidence.api and opening.evidence.api.getUnitWorkerTask),
		"apiPosition=" .. field(opening.evidence.api and opening.evidence.api.getUnitPosition),
		"apiUnitDefs=" .. field(opening.evidence.api and opening.evidence.api.unitDefs),
		"cormex=" .. value(opening.finishedCounts.cormex),
		"corwin=" .. value(opening.finishedCounts.corwin),
		"corsolar=" .. value(opening.finishedCounts.corsolar),
		"corlab=" .. value(opening.finishedCounts.corlab),
		"corck=" .. value(opening.finishedCounts.corck),
		"combatBots=" .. value(opening.finishedCounts.combatBots),
		"expansionMex=" .. value(opening.finishedCounts.expansionMex),
		"factoryActive=" .. field(opening.factory.active),
		"factoryIdle=" .. value(opening.factory.idleDuration),
		"recovery=" .. field(opening.recovery.energyState),
		"lesson=" .. field(progress.lessonState),
		"next=" .. field(progress.nextMilestoneId),
		"presentation=" .. field(progress.presentation),
		"milestones=" .. (#milestoneFields > 0 and table.concat(milestoneFields, ",") or "none"),
	}, " "))

	for i = 1, #progress.milestones do
		local milestone = progress.milestones[i]
		Spring.Echo(table.concat({
			"[BAR Learning Coach OpeningMilestone]",
			"sample=" .. sampleCount,
			"id=" .. field(milestone.id),
			"state=" .. field(milestone.state),
			"progressState=" .. field(milestone.progressState),
			"reason=" .. field(milestone.reason),
		}, " "))
	end

	local mexPositions = opening.evidence and opening.evidence.finishedMexPositions or {}
	for i = 1, #mexPositions do
		local mex = mexPositions[i]
		Spring.Echo(table.concat({
			"[BAR Learning Coach OpeningMex]",
			"sample=" .. sampleCount,
			"unit=" .. field(mex.unitID),
			"positionKnown=" .. field(mex.positionKnown),
			"x=" .. value(mex.x),
			"z=" .. value(mex.z),
		}, " "))
	end

	for i = 1, #buildPowerRaw.units do
		local unit = buildPowerRaw.units[i]
		if unit.isBuilder == true or unit.definitionKnown ~= true then
			Spring.Echo(table.concat({
				"[BAR Learning Coach BuildPowerUnit]",
				"sample=" .. sampleCount,
				"unit=" .. field(unit.unitID),
				"def=" .. field(unit.unitDefID),
				"definitionKnown=" .. field(unit.definitionKnown),
				"builder=" .. field(unit.isBuilder),
				"factory=" .. field(unit.isFactory),
				"buildSpeed=" .. value(unit.buildSpeed),
				"stateKnown=" .. field(unit.stateKnown),
				"beingBuilt=" .. field(unit.beingBuilt),
				"stunned=" .. field(unit.stunned),
				"taskKnown=" .. field(unit.taskKnown),
				"command=" .. value(unit.taskCommandID),
				"target=" .. value(unit.taskTargetID),
				"nanoActivity=" .. value(unit.nanoActivity),
			}, " "))
		end
	end

	for i = 1, #buildPower.targets do
		local target = buildPower.targets[i]
		Spring.Echo(table.concat({
			"[BAR Learning Coach BuildPowerTarget]",
			"sample=" .. sampleCount,
			"target=" .. value(target.targetID),
			"active=" .. value(target.activeBuildPower),
			"contributors=" .. value(target.contributors),
			"factories=" .. value(target.factoryContributors),
		}, " "))
	end
end

function widget:Initialize()
	Spring.Echo("[BAR Learning Coach Telemetry] started interval=5s")
	collect()
	elapsed = 0
end

function widget:Update(dt)
	elapsed = elapsed + (dt or 0)
	if elapsed < SAMPLE_INTERVAL then
		return
	end

	elapsed = 0
	collect()
end

function widget:Shutdown()
	Spring.Echo("[BAR Learning Coach Telemetry] stopped samples=" .. sampleCount)
end
