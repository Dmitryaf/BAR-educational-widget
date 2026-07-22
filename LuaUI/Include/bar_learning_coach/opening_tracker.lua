local OpeningTracker = {}
OpeningTracker.__index = OpeningTracker

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function finishedFactoryCount(observation)
	if type(observation) ~= "table" or type(observation.finishedCounts) ~= "table" then
		return nil
	end
	local count = observation.finishedCounts.corlab
	if not finiteNumber(count) or count < 0 or count % 1 ~= 0 then
		return nil
	end
	return count
end

function OpeningTracker.new(adapter, context)
	return setmetatable({
		adapter = adapter,
		context = context,
		lastTeamID = nil,
		lastContextId = nil,
		lastGameTime = nil,
		factoryIdleSince = nil,
	}, OpeningTracker)
end

function OpeningTracker:reset()
	self.lastTeamID = nil
	self.lastContextId = nil
	self.lastGameTime = nil
	self.factoryIdleSince = nil
end

function OpeningTracker:invalidate()
	self.factoryIdleSince = nil
end

function OpeningTracker:observe(teamID, gameTime, energyState)
	if type(self.adapter) ~= "table" or type(self.adapter.collect) ~= "function" then
		return nil, "adapter unavailable"
	end

	local contextId = type(self.context) == "table" and self.context.id or nil
	local identityChanged = self.lastTeamID ~= nil and self.lastTeamID ~= teamID
		or self.lastContextId ~= nil and self.lastContextId ~= contextId
	local timeRewound = finiteNumber(self.lastGameTime)
		and finiteNumber(gameTime)
		and gameTime < self.lastGameTime
	if identityChanged or timeRewound then
		self:reset()
	end

	local observation = self.adapter:collect(teamID, self.context, gameTime)
	if type(observation) ~= "table" then
		return nil, "adapter observation invalid"
	end
	observation.recovery = type(observation.recovery) == "table" and observation.recovery or {}
	observation.recovery.energyState = type(energyState) == "string" and energyState or nil
	observation.factory = type(observation.factory) == "table" and observation.factory or {}

	local factoryCount = finishedFactoryCount(observation)
	local supported = observation.contextStatus == "supported" and observation.contextId == contextId
	if not supported or not finiteNumber(gameTime) or factoryCount == nil or factoryCount == 0 then
		self.factoryIdleSince = nil
		observation.factory.idleDuration = nil
	elseif observation.factory.active == true then
		self.factoryIdleSince = nil
		observation.factory.idleDuration = 0
	elseif observation.factory.active == false then
		if not finiteNumber(self.factoryIdleSince) then
			self.factoryIdleSince = gameTime
		end
		observation.factory.idleDuration = math.max(0, gameTime - self.factoryIdleSince)
	else
		self.factoryIdleSince = nil
		observation.factory.idleDuration = nil
	end

	self.lastTeamID = teamID
	self.lastContextId = contextId
	self.lastGameTime = finiteNumber(gameTime) and gameTime or nil
	return observation, nil
end

return OpeningTracker
