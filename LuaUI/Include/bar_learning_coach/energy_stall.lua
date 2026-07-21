local EnergyStall = {}
EnergyStall.__index = EnergyStall

local DEFAULT_CONFIG = {
	storageRatioEnter = 0.10,
	storageRatioExit = 0.15,
	minimumDeficitEnter = 25,
	minimumDeficitExit = 10,
	candidateDuration = 15,
	resolveDuration = 8,
	cooldown = 90,
	trendWindow = 5,
}

local function copyConfig(overrides)
	local config = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		config[key] = value
	end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end
	return config
end

local function finiteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validate(snapshot)
	if type(snapshot) ~= "table" then
		return false, "snapshot missing"
	end
	if not finiteNumber(snapshot.gameTime) then
		return false, "game time missing"
	end
	if type(snapshot.energy) ~= "table" then
		return false, "energy data missing"
	end

	local required = { "current", "storage", "pull", "income" }
	for i = 1, #required do
		local field = required[i]
		if not finiteNumber(snapshot.energy[field]) then
			return false, "energy " .. field .. " missing"
		end
	end

	if snapshot.energy.storage <= 0 then
		return false, "energy storage is not positive"
	end

	return true, nil
end

local function storageTrend(history, now, window)
	local latest = history and history:latest() or nil
	if not latest or not latest.energy or not finiteNumber(latest.energy.current) then
		return nil
	end

	local oldest = nil
	for i = history:size(), 1, -1 do
		local item = history:get(i)
		if item and finiteNumber(item.gameTime) and item.energy and finiteNumber(item.energy.current) then
			oldest = item
			if now - item.gameTime >= window then
				break
			end
		end
	end

	if not oldest or oldest == latest or now <= oldest.gameTime then
		return nil
	end

	return (latest.energy.current - oldest.energy.current) / (now - oldest.gameTime)
end

function EnergyStall.new(config)
	return setmetatable({
		config = copyConfig(config),
		state = "inactive",
		stateSince = nil,
		episodeSince = nil,
		cooldownUntil = nil,
	}, EnergyStall)
end

function EnergyStall:resetLifecycle(clearCooldown)
	self.state = "inactive"
	self.stateSince = nil
	self.episodeSince = nil
	if clearCooldown then
		self.cooldownUntil = nil
	end
end

function EnergyStall:setState(state, now)
	if self.state ~= state then
		self.state = state
		self.stateSince = now
	end
end

function EnergyStall:evaluate(snapshot, history)
	local valid, invalidReason = validate(snapshot)
	if not valid then
		self:resetLifecycle()
		return {
			state = "unknown",
			reason = invalidReason,
			storageRatio = nil,
			deficit = nil,
			storageTrend = nil,
			duration = 0,
			episodeDuration = 0,
			cooldownRemaining = 0,
		}
	end

	local now = snapshot.gameTime
	local energy = snapshot.energy
	local storageRatio = energy.current / energy.storage
	local deficit = energy.pull - energy.income
	local enterCondition = storageRatio <= self.config.storageRatioEnter
		and deficit >= self.config.minimumDeficitEnter
	local clearCondition = storageRatio >= self.config.storageRatioExit
		or deficit <= self.config.minimumDeficitExit
	local reason

	if self.cooldownUntil and now < self.cooldownUntil then
		self:setState("cooldown", self.stateSince or now)
		reason = "cooldown active"
	elseif self.state == "cooldown" or self.state == "resolved" then
		self.cooldownUntil = nil
		self.episodeSince = nil
		self:setState("inactive", now)
	end

	if self.state ~= "cooldown" then
		if self.state == "inactive" then
			if enterCondition then
				self.episodeSince = now
				self:setState("candidate", now)
			else
				self.episodeSince = nil
				reason = storageRatio > self.config.storageRatioEnter
					and "storage ratio above enter threshold"
					or "energy deficit below enter threshold"
			end
		elseif self.state == "candidate" then
			if not enterCondition then
				self.episodeSince = nil
				self:setState("inactive", now)
				reason = "candidate condition interrupted"
			elseif now - self.stateSince >= self.config.candidateDuration then
				self:setState("active", now)
			end
		elseif self.state == "active" then
			if clearCondition then
				self:setState("resolving", now)
			end
		elseif self.state == "resolving" then
			if not clearCondition then
				self:setState("active", now)
				reason = "recovery interrupted"
			elseif now - self.stateSince >= self.config.resolveDuration then
				self:setState("resolved", now)
				self.cooldownUntil = now + self.config.cooldown
			end
		end
	end

	local duration = self.stateSince and math.max(0, now - self.stateSince) or 0
	local episodeDuration = self.episodeSince and math.max(0, now - self.episodeSince) or 0
	local cooldownRemaining = self.cooldownUntil and math.max(0, self.cooldownUntil - now) or 0

	return {
		state = self.state,
		reason = reason,
		storageRatio = storageRatio,
		deficit = deficit,
		storageTrend = storageTrend(history, now, self.config.trendWindow),
		duration = duration,
		episodeDuration = episodeDuration,
		cooldownRemaining = cooldownRemaining,
		enterCondition = enterCondition,
		clearCondition = clearCondition,
	}
end

return EnergyStall
