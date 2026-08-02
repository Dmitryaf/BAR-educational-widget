local ReplayObservation = {}

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function knownResource(resource)
	if type(resource) ~= "table" or resource.known ~= true then
		return nil
	end
	local required = { "current", "storage", "income", "expense", "pull" }
	for i = 1, #required do
		if not finiteNumber(resource[required[i]]) then
			return nil
		end
	end
	return {
		current = resource.current,
		storage = resource.storage,
		income = resource.income,
		expense = resource.expense,
		pull = resource.pull,
	}
end

local function contains(values, expected)
	for i = 1, #(values or {}) do
		if values[i] == expected then
			return true
		end
	end
	return false
end

local function contextStatus(context, raw, mapName)
	if type(mapName) ~= "string" then
		return "unknown", "map name unavailable"
	end
	if mapName ~= context.mapName then
		return "unsupported", "map unsupported"
	end
	if type(raw) ~= "table" or raw.unitListKnown ~= true then
		return "unknown", "team unit list unavailable"
	end
	if contains(raw.commanderNames, context.commanderUnitDefName) then
		return "supported", "context confirmed"
	end
	if type(raw.commanderNames) == "table" and #raw.commanderNames > 0 then
		return "unsupported", "faction unsupported"
	end
	return "unknown", "commander context unavailable"
end

local function factoryObservation(item)
	local activityKnown = item.taskKnown == true
	local active = nil
	if activityKnown then
		if type(item.taskCommandID) == "number" and item.taskCommandID < 0 then
			if finiteNumber(item.taskTargetID) then
				active = true
			else
				activityKnown = false
			end
		else
			active = false
		end
	end
	return {
		unitID = item.unitID,
		finished = item.buildStateKnown == true and item.beingBuilt == false,
		buildStateKnown = item.buildStateKnown == true,
		activityKnown = activityKnown,
		active = active,
	}
end

local function collectFactories(context, raw)
	local factories = {}
	local known = raw.unitListKnown == true and raw.unknownUnitCount == 0
	for i = 1, #(raw.units or {}) do
		local item = raw.units[i]
		if item.definitionKnown == true and item.name == context.factoryUnitDefName then
			factories[#factories + 1] = factoryObservation(item)
			if item.buildStateKnown ~= true then
				known = false
			end
		end
	end
	table.sort(factories, function(a, b)
		return (a.unitID or math.huge) < (b.unitID or math.huge)
	end)
	return factories, known
end

local function expansionCount(context, raw)
	if raw.unitListKnown ~= true
		or raw.unknownUnitCount ~= 0
		or type(raw.startPosition) ~= "table"
		or raw.startPosition.known ~= true
	then
		return nil
	end

	local count = 0
	for i = 1, #(raw.units or {}) do
		local item = raw.units[i]
		if item.definitionKnown == true
			and item.name == context.mexUnitDefName
			and item.buildStateKnown == true
			and item.beingBuilt == false
		then
			if item.positionKnown ~= true then
				return nil
			end
			local dx = item.x - raw.startPosition.x
			local dz = item.z - raw.startPosition.z
			if math.sqrt(dx * dx + dz * dz) > context.expansionRadius then
				count = count + 1
			end
		end
	end
	return count
end

function ReplayObservation.normalize(context, raw, environment)
	if type(context) ~= "table" or type(raw) ~= "table" then
		return nil, "context or raw snapshot missing"
	end
	environment = type(environment) == "table" and environment or {}
	local status, reason = contextStatus(context, raw, environment.mapName)
	local factories, factoryListKnown = collectFactories(context, raw)
	return {
		contextId = context.id,
		contextStatus = status,
		contextReason = reason,
		gameTime = finiteNumber(raw.gameTime) and raw.gameTime or nil,
		teamID = finiteNumber(raw.targetTeamID) and raw.targetTeamID or nil,
		energy = knownResource(raw.resources and raw.resources.energy),
		metal = knownResource(raw.resources and raw.resources.metal),
		factories = factories,
		factoryListKnown = factoryListKnown,
		expansionMex = expansionCount(context, raw),
	}, nil
end

return ReplayObservation
