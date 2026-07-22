local ReplayOpeningCollector = {}
ReplayOpeningCollector.__index = ReplayOpeningCollector

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return false
	end

	return pcall(fn, ...)
end

local function commanderFlag(unitDef)
	if type(unitDef) ~= "table" or type(unitDef.customParams) ~= "table" then
		return nil
	end

	local value = unitDef.customParams.iscommander
	if value == nil then
		return false
	end
	return value == true or value == 1 or value == "1" or value == "true"
end

local function readResource(springApi, teamID, resourceName)
	local resource = {
		known = false,
	}
	local ok, current, storage, pull, income, expense, share, sent, received, excess =
		safeCall(springApi.GetTeamResources, teamID, resourceName)
	if not ok then
		return resource
	end

	resource.known = true
	resource.current = finiteNumber(current) and current or nil
	resource.storage = finiteNumber(storage) and storage or nil
	resource.pull = finiteNumber(pull) and pull or nil
	resource.income = finiteNumber(income) and income or nil
	resource.expense = finiteNumber(expense) and expense or nil
	resource.share = finiteNumber(share) and share or nil
	resource.sent = finiteNumber(sent) and sent or nil
	resource.received = finiteNumber(received) and received or nil
	resource.excess = finiteNumber(excess) and excess or nil
	return resource
end

local function definition(unitDefs, unitDefID)
	if type(unitDefs) ~= "table" or not finiteNumber(unitDefID) then
		return nil
	end
	local unitDef = unitDefs[unitDefID]
	return type(unitDef) == "table" and unitDef or nil
end

function ReplayOpeningCollector.new(springApi, unitDefs, targetTeamID)
	return setmetatable({
		spring = springApi or {},
		unitDefs = unitDefs,
		targetTeamID = finiteNumber(targetTeamID) and targetTeamID or nil,
	}, ReplayOpeningCollector)
end

function ReplayOpeningCollector:describeUnit(unitID, suppliedUnitDefID)
	local item = {
		unitID = finiteNumber(unitID) and unitID or nil,
		definitionKnown = false,
		buildStateKnown = false,
		positionKnown = false,
	}
	if item.unitID == nil then
		return item
	end

	local unitDefID = finiteNumber(suppliedUnitDefID) and suppliedUnitDefID or nil
	if unitDefID == nil then
		local defOk, observedUnitDefID = safeCall(self.spring.GetUnitDefID, item.unitID)
		unitDefID = defOk and finiteNumber(observedUnitDefID) and observedUnitDefID or nil
	end
	local unitDef = definition(self.unitDefs, unitDefID)
	if unitDef ~= nil and type(unitDef.name) == "string" then
		item.unitDefID = unitDefID
		item.name = unitDef.name
		item.definitionKnown = true
		item.isCommander = commanderFlag(unitDef)
		item.isFactory = unitDef.isFactory == true
		item.isBuilder = unitDef.isBuilder == true
		item.buildSpeed = finiteNumber(unitDef.buildSpeed) and unitDef.buildSpeed or nil
	end

	local buildOk, beingBuilt = safeCall(self.spring.GetUnitIsBeingBuilt, item.unitID)
	if buildOk and type(beingBuilt) == "boolean" then
		item.buildStateKnown = true
		item.beingBuilt = beingBuilt
	end

	local positionOk, x, y, z = safeCall(self.spring.GetUnitPosition, item.unitID)
	if positionOk and finiteNumber(x) and finiteNumber(y) and finiteNumber(z) then
		item.positionKnown = true
		item.x = x
		item.y = y
		item.z = z
	end

	if item.isFactory == true then
		local taskOk, commandID, targetID = safeCall(self.spring.GetUnitWorkerTask, item.unitID)
		if taskOk and (commandID == nil or finiteNumber(commandID)) then
			item.taskKnown = true
			item.taskCommandID = commandID
			item.taskTargetID = finiteNumber(targetID) and targetID or nil
		else
			item.taskKnown = false
		end
	end

	return item
end

function ReplayOpeningCollector:collect(gameTime, gameFrame)
	local snapshot = {
		targetTeamID = self.targetTeamID,
		gameTime = finiteNumber(gameTime) and gameTime or nil,
		gameFrame = finiteNumber(gameFrame) and gameFrame or nil,
		unitListKnown = false,
		units = {},
		countsByName = {},
		finishedCountsByName = {},
		commanderNames = {},
		unknownUnitCount = 0,
		api = {
			getTeamResources = type(self.spring.GetTeamResources) == "function",
			getTeamUnits = type(self.spring.GetTeamUnits) == "function",
			getUnitDefID = type(self.spring.GetUnitDefID) == "function",
			getUnitIsBeingBuilt = type(self.spring.GetUnitIsBeingBuilt) == "function",
			getUnitPosition = type(self.spring.GetUnitPosition) == "function",
			getUnitWorkerTask = type(self.spring.GetUnitWorkerTask) == "function",
			unitDefs = type(self.unitDefs) == "table",
		},
	}

	if self.targetTeamID == nil then
		snapshot.reason = "target team id unavailable"
		return snapshot
	end

	snapshot.resources = {
		metal = readResource(self.spring, self.targetTeamID, "metal"),
		energy = readResource(self.spring, self.targetTeamID, "energy"),
	}

	local unitsOk, unitIDs = safeCall(self.spring.GetTeamUnits, self.targetTeamID)
	if not unitsOk or type(unitIDs) ~= "table" then
		snapshot.reason = unitsOk and "team unit list invalid" or "team unit list unavailable"
		snapshot.unknownUnitCount = nil
		return snapshot
	end

	snapshot.unitListKnown = true
	snapshot.unitCount = #unitIDs
	local commanderSet = {}
	for i = 1, #unitIDs do
		local item = self:describeUnit(unitIDs[i])
		snapshot.units[#snapshot.units + 1] = item
		if item.definitionKnown then
			snapshot.countsByName[item.name] = (snapshot.countsByName[item.name] or 0) + 1
			if item.buildStateKnown and item.beingBuilt == false then
				snapshot.finishedCountsByName[item.name] = (snapshot.finishedCountsByName[item.name] or 0) + 1
			end
			if item.isCommander == true and not commanderSet[item.name] then
				commanderSet[item.name] = true
				snapshot.commanderNames[#snapshot.commanderNames + 1] = item.name
			end
		else
			snapshot.unknownUnitCount = snapshot.unknownUnitCount + 1
		end
	end
	table.sort(snapshot.commanderNames)
	return snapshot
end

return ReplayOpeningCollector
