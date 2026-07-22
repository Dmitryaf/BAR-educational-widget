local OpeningAdapter = {}
OpeningAdapter.__index = OpeningAdapter

local COUNT_FIELDS = { "cormex", "corwin", "corsolar", "corlab", "corck", "combatBots" }

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function call(fn, ...)
	if type(fn) ~= "function" then
		return false, nil, nil, nil
	end

	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		return false, nil, nil, nil
	end
	return true, a, b, c
end

local function emptyCounts()
	return {
		cormex = nil,
		corwin = nil,
		corsolar = nil,
		corlab = nil,
		corck = nil,
		combatBots = nil,
		expansionMex = nil,
	}
end

local function emptyObservation(context, gameTime, mapName)
	return {
		contextId = nil,
		contextStatus = "unknown",
		gameTime = finiteNumber(gameTime) and gameTime or nil,
		finishedCounts = emptyCounts(),
		factory = {
			active = nil,
			idleDuration = nil,
		},
		recovery = {
			energyState = nil,
		},
		evidence = {
			expectedContextId = type(context) == "table" and context.id or nil,
			mapName = mapName,
			unitCount = nil,
			unknownUnitCount = nil,
			commanderUnitDefNames = {},
			finishedMexPositions = {},
		},
	}
end

local function validContext(context)
	if type(context) ~= "table"
		or type(context.id) ~= "string"
		or type(context.mapName) ~= "string"
		or type(context.commanderUnitDefName) ~= "string"
		or type(context.factoryUnitDefName) ~= "string"
		or type(context.countGroups) ~= "table"
	then
		return false
	end
	for i = 1, #COUNT_FIELDS do
		local group = context.countGroups[COUNT_FIELDS[i]]
		if type(group) ~= "table" or #group == 0 then
			return false
		end
		for j = 1, #group do
			if type(group[j]) ~= "string" or group[j] == "" then
				return false
			end
		end
	end
	if #context.countGroups.corlab ~= 1 or context.countGroups.corlab[1] ~= context.factoryUnitDefName then
		return false
	end
	return true
end

local function buildGroupIndex(context)
	local index = {}
	for i = 1, #COUNT_FIELDS do
		local field = COUNT_FIELDS[i]
		local names = context.countGroups[field]
		for j = 1, #names do
			local name = names[j]
			if type(name) == "string" then
				index[name] = index[name] or {}
				index[name][#index[name] + 1] = field
			end
		end
	end
	return index
end

local function addCommander(evidence, unitDefName)
	for i = 1, #evidence.commanderUnitDefNames do
		if evidence.commanderUnitDefNames[i] == unitDefName then
			return
		end
	end
	evidence.commanderUnitDefNames[#evidence.commanderUnitDefNames + 1] = unitDefName
end

local function contains(values, expected)
	for i = 1, #values do
		if values[i] == expected then
			return true
		end
	end
	return false
end

function OpeningAdapter.new(springApi, unitDefs, gameInfo)
	return setmetatable({
		spring = springApi or {},
		unitDefs = unitDefs,
		gameInfo = gameInfo or {},
	}, OpeningAdapter)
end

function OpeningAdapter:collect(teamID, context, gameTime)
	local mapName = type(self.gameInfo) == "table" and self.gameInfo.mapName or nil
	local observation = emptyObservation(context, gameTime, mapName)
	observation.evidence.api = {
		getTeamUnits = type(self.spring.GetTeamUnits) == "function",
		getUnitDefID = type(self.spring.GetUnitDefID) == "function",
		getUnitIsBeingBuilt = type(self.spring.GetUnitIsBeingBuilt) == "function",
		getUnitWorkerTask = type(self.spring.GetUnitWorkerTask) == "function",
		getUnitPosition = type(self.spring.GetUnitPosition) == "function",
		unitDefs = type(self.unitDefs) == "table",
	}
	if not validContext(context) then
		observation.reason = "context invalid"
		return observation
	end
	if type(mapName) ~= "string" then
		observation.reason = "map name unavailable"
		return observation
	end
	if mapName ~= context.mapName then
		observation.contextStatus = "unsupported"
		observation.reason = "map unsupported"
		return observation
	end
	if not finiteNumber(teamID) then
		observation.reason = "team id unavailable"
		return observation
	end

	observation.evidence.teamID = teamID
	local unitsOk, unitIDs = call(self.spring.GetTeamUnits, teamID)
	if not unitsOk or type(unitIDs) ~= "table" then
		observation.reason = unitsOk and "team unit list invalid" or "team unit list unavailable"
		return observation
	end

	observation.evidence.unitCount = #unitIDs
	observation.evidence.unknownUnitCount = 0
	local groupIndex = buildGroupIndex(context)
	local counts = {}
	local countKnown = {}
	for i = 1, #COUNT_FIELDS do
		counts[COUNT_FIELDS[i]] = 0
		countKnown[COUNT_FIELDS[i]] = true
	end

	local anyDefinitionUnknown = false
	local supportedCommanderFound = false
	local foreignCommanderFound = false
	local factoryTaskUnknown = false
	local factoryActive = false

	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		local defOk, unitDefID = call(self.spring.GetUnitDefID, unitID)
		local unitDef = defOk and finiteNumber(unitDefID) and type(self.unitDefs) == "table"
			and self.unitDefs[unitDefID]
			or nil
		if type(unitDef) ~= "table" or type(unitDef.name) ~= "string" then
			anyDefinitionUnknown = true
			observation.evidence.unknownUnitCount = observation.evidence.unknownUnitCount + 1
		else
			local unitDefName = unitDef.name
			local customParams = type(unitDef.customParams) == "table" and unitDef.customParams or {}
			if customParams.iscommander then
				addCommander(observation.evidence, unitDefName)
				if unitDefName == context.commanderUnitDefName then
					supportedCommanderFound = true
				else
					foreignCommanderFound = true
				end
			end

			local groups = groupIndex[unitDefName]
			if groups then
				local buildOk, beingBuilt = call(self.spring.GetUnitIsBeingBuilt, unitID)
				if not buildOk or type(beingBuilt) ~= "boolean" then
					for j = 1, #groups do
						countKnown[groups[j]] = false
					end
					if unitDefName == context.factoryUnitDefName then
						factoryTaskUnknown = true
					end
				elseif beingBuilt == false then
					for j = 1, #groups do
						counts[groups[j]] = counts[groups[j]] + 1
					end

					if contains(groups, "cormex") then
						local positionOk, x, _, z = call(self.spring.GetUnitPosition, unitID)
						observation.evidence.finishedMexPositions[#observation.evidence.finishedMexPositions + 1] = {
							unitID = unitID,
							positionKnown = positionOk and finiteNumber(x) and finiteNumber(z),
							x = positionOk and finiteNumber(x) and x or nil,
							z = positionOk and finiteNumber(z) and z or nil,
						}
					end

					if unitDefName == context.factoryUnitDefName then
						local taskOk, commandID, targetID = call(self.spring.GetUnitWorkerTask, unitID)
						if taskOk and (commandID == nil or finiteNumber(commandID)) then
							if type(commandID) == "number" and commandID < 0 then
								if finiteNumber(targetID) then
									factoryActive = true
								else
									factoryTaskUnknown = true
								end
							end
						else
							factoryTaskUnknown = true
						end
					end
				end
			end
		end
	end

	if anyDefinitionUnknown then
		for i = 1, #COUNT_FIELDS do
			countKnown[COUNT_FIELDS[i]] = false
		end
	end
	for i = 1, #COUNT_FIELDS do
		local field = COUNT_FIELDS[i]
		observation.finishedCounts[field] = countKnown[field] and counts[field] or nil
	end
	observation.finishedCounts.expansionMex = nil

	if observation.finishedCounts.corlab == 0 then
		observation.factory.active = false
	elseif observation.finishedCounts.corlab == nil then
		observation.factory.active = nil
	elseif factoryActive then
		observation.factory.active = true
	elseif factoryTaskUnknown then
		observation.factory.active = nil
	else
		observation.factory.active = false
	end

	if anyDefinitionUnknown then
		observation.reason = "unit definition incomplete"
	elseif supportedCommanderFound and foreignCommanderFound then
		observation.reason = "multiple commander factions"
	elseif foreignCommanderFound then
		observation.contextStatus = "unsupported"
		observation.reason = "faction unsupported"
	elseif not supportedCommanderFound then
		observation.reason = "commander context unavailable"
	else
		observation.contextId = context.id
		observation.contextStatus = "supported"
		observation.reason = "context confirmed"
	end

	return observation
end

return OpeningAdapter
