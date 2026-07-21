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

local SAMPLE_INTERVAL = 5
local history = HistoryBuffer.new(120)
local detector = EnergyStall.new()
local collector = SnapshotCollector.new(history, detector)
local elapsed = SAMPLE_INTERVAL
local sampleCount = 0

local function value(valueToFormat)
	if type(valueToFormat) ~= "number" then
		return "unknown"
	end
	return string.format("%.3f", valueToFormat)
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
		"reason=" .. tostring(result.reason or "tracked"),
	}, " "))
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
