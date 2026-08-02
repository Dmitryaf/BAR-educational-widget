local ReplaySession = {}
ReplaySession.__index = ReplaySession

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function findFactory(factories, unitID)
	for i = 1, #(factories or {}) do
		if factories[i].unitID == unitID then
			return factories[i]
		end
	end
	return nil
end

local function firstFinishedFactory(factories)
	for i = 1, #(factories or {}) do
		if factories[i].finished == true then
			return factories[i]
		end
	end
	return nil
end

function ReplaySession.new(context, dependencies)
	assert(type(context) == "table", "replay context is required")
	assert(type(dependencies) == "table", "replay dependencies are required")
	local self = setmetatable({
		context = context,
		dependencies = dependencies,
	}, ReplaySession)
	self:reset("initialized")
	return self
end

function ReplaySession:reset(reason)
	self.history = self.dependencies.HistoryBuffer.new(240)
	self.energyDetector = self.dependencies.EnergyStall.new(self.context.energy)
	self.aggregator = self.dependencies.EpisodeAggregator.new({
		energy_stall = self.context.thresholds.energyEpisodeDuration,
		factory_idle = self.context.thresholds.factoryIdleDuration,
		late_expansion = 0,
	})
	self.teamID = nil
	self.lastGameTime = nil
	self.firstFactoryID = nil
	self.firstExpansionTime = nil
	self.sampleCount = 0
	self.supportedSamples = 0
	self.unknownSamples = 0
	self.contextStatus = "unknown"
	self.contextReason = "no observations"
	self.contextConfirmed = false
	self.finished = false
	self.lastResetReason = reason
	self.lastEnergyDiagnostic = nil
end

function ReplaySession:updateEnergy(observation)
	if type(observation.energy) ~= "table" then
		self.unknownSamples = self.unknownSamples + 1
		self.aggregator:update("energy_stall", nil, observation.gameTime)
		return
	end
	local sample = {
		gameTime = observation.gameTime,
		energy = observation.energy,
	}
	self.history:push(sample)
	local diagnostic = self.energyDetector:evaluate(sample, self.history)
	self.lastEnergyDiagnostic = diagnostic
	if diagnostic.state == "active" or diagnostic.state == "resolving" then
		self.aggregator:update("energy_stall", true, observation.gameTime, {
			startedAt = observation.gameTime - diagnostic.episodeDuration,
			evidence = {
				storageRatio = diagnostic.storageRatio,
				deficit = diagnostic.deficit,
			},
		})
	elseif diagnostic.state == "resolved" then
		self.aggregator:update("energy_stall", false, observation.gameTime, {
			endedAt = observation.gameTime - self.context.energy.resolveDuration,
		})
	elseif diagnostic.state == "unknown" then
		self.unknownSamples = self.unknownSamples + 1
		self.aggregator:update("energy_stall", nil, observation.gameTime)
	else
		self.aggregator:update("energy_stall", false, observation.gameTime)
	end
end

function ReplaySession:updateFactory(observation)
	if observation.factoryListKnown ~= true then
		self.aggregator:update("factory_idle", nil, observation.gameTime)
		return
	end
	if self.firstFactoryID == nil then
		local first = firstFinishedFactory(observation.factories)
		self.firstFactoryID = first and first.unitID or nil
	end
	if self.firstFactoryID == nil then
		self.aggregator:update("factory_idle", false, observation.gameTime)
		return
	end

	local factory = findFactory(observation.factories, self.firstFactoryID)
	if factory == nil then
		local state = observation.factoryListKnown and false or nil
		self.aggregator:update("factory_idle", state, observation.gameTime)
	elseif factory.finished ~= true or factory.activityKnown ~= true then
		self.aggregator:update("factory_idle", nil, observation.gameTime)
	else
		self.aggregator:update("factory_idle", factory.active == false, observation.gameTime, {
			evidence = {
				factoryUnitID = self.firstFactoryID,
				energyState = self.lastEnergyDiagnostic and self.lastEnergyDiagnostic.state or nil,
				metalCurrent = observation.metal and observation.metal.current or nil,
			},
		})
	end
end

function ReplaySession:updateExpansion(observation)
	if observation.expansionMex == nil then
		self.aggregator:update("late_expansion", nil, observation.gameTime)
		return
	end
	if self.firstExpansionTime == nil and observation.expansionMex > 0 then
		self.firstExpansionTime = observation.gameTime
	end
	if self.firstExpansionTime ~= nil then
		self.aggregator:update("late_expansion", false, observation.gameTime, {
			endedAt = self.firstExpansionTime,
		})
	elseif observation.gameTime > self.context.thresholds.lateExpansionTime then
		self.aggregator:update("late_expansion", true, observation.gameTime, {
			startedAt = self.context.thresholds.lateExpansionTime,
			evidence = { expansionMex = observation.expansionMex },
		})
	else
		self.aggregator:update("late_expansion", false, observation.gameTime)
	end
end

function ReplaySession:record(observation)
	if self.finished then
		return nil, "analysis session finished"
	end
	if type(observation) ~= "table"
		or not finiteNumber(observation.teamID)
		or not finiteNumber(observation.gameTime)
	then
		return nil, "observation identity or time missing"
	end

	local resetReason = nil
	if self.teamID ~= nil and self.teamID ~= observation.teamID then
		self:reset("team_changed")
		resetReason = "team_changed"
	elseif self.lastGameTime ~= nil and observation.gameTime < self.lastGameTime then
		self:reset("rewind")
		resetReason = "rewind"
	end

	self.teamID = observation.teamID
	self.lastGameTime = observation.gameTime
	self.sampleCount = self.sampleCount + 1
	local observedContextStatus = observation.contextStatus or "unknown"
	if observedContextStatus == "supported" then
		self.contextConfirmed = true
		self.contextStatus = "supported"
		self.contextReason = observation.contextReason
	elseif observedContextStatus == "unknown" and self.contextConfirmed then
		self.contextStatus = "supported"
		self.contextReason = "context confirmed earlier in this timeline"
	elseif observedContextStatus == "unsupported" then
		self.contextStatus = "unsupported"
		self.contextReason = observation.contextReason
	else
		self.contextStatus = "unknown"
		self.contextReason = observation.contextReason
	end
	if self.contextStatus ~= "supported" then
		if self.contextStatus == "unknown" then
			self.unknownSamples = self.unknownSamples + 1
		end
		return self:state(resetReason), nil
	end

	self.supportedSamples = self.supportedSamples + 1
	self:updateEnergy(observation)
	self:updateFactory(observation)
	self:updateExpansion(observation)
	return self:state(resetReason), nil
end

function ReplaySession:state(resetReason)
	return {
		teamID = self.teamID,
		lastGameTime = self.lastGameTime,
		sampleCount = self.sampleCount,
		supportedSamples = self.supportedSamples,
		unknownSamples = self.unknownSamples,
		contextStatus = self.contextStatus,
		contextReason = self.contextReason,
		episodeCount = self.aggregator:confirmedCount(self.lastGameTime),
		lastResetReason = resetReason or self.lastResetReason,
		finished = self.finished,
	}
end

function ReplaySession:finish(playerName)
	if not self.finished then
		self.aggregator:finish(self.lastGameTime or 0)
		self.finished = true
	end
	local episodes = self.aggregator:getEpisodes()
	local ranking = self.dependencies.IssueRanker.rank(
		episodes,
		self.context.thresholds.relationWindow
	)
	local trainingTask = self.dependencies.TrainingTaskSelector.select(ranking.primaryIssue, self.context)
	return self.dependencies.ReplayReport.build(
		self.context,
		self:state(),
		ranking,
		trainingTask,
		playerName
	)
end

return ReplaySession
