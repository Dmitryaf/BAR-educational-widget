local EpisodeAggregator = {}
EpisodeAggregator.__index = EpisodeAggregator

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

function EpisodeAggregator.new(minimumDurations)
	return setmetatable({
		minimumDurations = type(minimumDurations) == "table" and copy(minimumDurations) or {},
		active = {},
		episodes = {},
	}, EpisodeAggregator)
end

function EpisodeAggregator:close(episodeType, endedAt)
	local current = self.active[episodeType]
	if current == nil then
		return
	end
	self.active[episodeType] = nil
	endedAt = finiteNumber(endedAt) and endedAt or current.lastConfirmedAt
	if not finiteNumber(endedAt) or endedAt < current.startedAt then
		return
	end
	local duration = endedAt - current.startedAt
	local minimumDuration = self.minimumDurations[episodeType] or 0
	if duration < minimumDuration then
		return
	end
	self.episodes[#self.episodes + 1] = {
		type = episodeType,
		startedAt = current.startedAt,
		endedAt = endedAt,
		duration = duration,
		severity = duration,
		confidence = "confirmed",
		evidence = copy(current.evidence),
	}
end

function EpisodeAggregator:update(episodeType, active, gameTime, options)
	if type(episodeType) ~= "string" or not finiteNumber(gameTime) then
		return
	end
	options = type(options) == "table" and options or {}
	if active == true then
		local current = self.active[episodeType]
		if current == nil then
			local startedAt = finiteNumber(options.startedAt) and options.startedAt or gameTime
			startedAt = math.min(startedAt, gameTime)
			current = {
				startedAt = startedAt,
				lastConfirmedAt = gameTime,
				evidence = copy(options.evidence or {}),
			}
			self.active[episodeType] = current
		else
			current.lastConfirmedAt = gameTime
			if type(options.evidence) == "table" then
				current.evidence = copy(options.evidence)
			end
		end
	elseif active == false then
		self:close(episodeType, options.endedAt or gameTime)
	else
		local current = self.active[episodeType]
		self:close(episodeType, current and current.lastConfirmedAt or gameTime)
	end
end

function EpisodeAggregator:finish(gameTime)
	local types = {}
	for episodeType in pairs(self.active) do
		types[#types + 1] = episodeType
	end
	for i = 1, #types do
		self:close(types[i], gameTime)
	end
end

function EpisodeAggregator:getEpisodes()
	return copy(self.episodes)
end

function EpisodeAggregator:confirmedCount(gameTime)
	local count = #self.episodes
	for episodeType, current in pairs(self.active) do
		local minimumDuration = self.minimumDurations[episodeType] or 0
		if finiteNumber(gameTime) and gameTime - current.startedAt >= minimumDuration then
			count = count + 1
		end
	end
	return count
end

return EpisodeAggregator
