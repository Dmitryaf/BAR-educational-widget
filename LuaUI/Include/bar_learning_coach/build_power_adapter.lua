local BuildPowerAdapter = {}
BuildPowerAdapter.__index = BuildPowerAdapter

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

function BuildPowerAdapter.new(springApi, unitDefs)
	return setmetatable({
		spring = springApi or {},
		unitDefs = unitDefs,
	}, BuildPowerAdapter)
end

function BuildPowerAdapter:collect(teamID)
	local raw = {
		teamID = finiteNumber(teamID) and teamID or nil,
		unitListKnown = false,
		units = {},
		api = {
			getTeamUnits = type(self.spring.GetTeamUnits) == "function",
			getUnitDefID = type(self.spring.GetUnitDefID) == "function",
			getUnitIsStunned = type(self.spring.GetUnitIsStunned) == "function",
			getUnitWorkerTask = type(self.spring.GetUnitWorkerTask) == "function",
			getUnitCurrentBuildPower = type(self.spring.GetUnitCurrentBuildPower) == "function",
			unitDefs = type(self.unitDefs) == "table",
		},
	}

	if raw.teamID == nil then
		raw.reason = "team id unavailable"
		return raw
	end

	local unitsOk, unitIDs = call(self.spring.GetTeamUnits, raw.teamID)
	if not unitsOk or type(unitIDs) ~= "table" then
		raw.reason = unitsOk and "team unit list invalid" or "team unit list unavailable"
		return raw
	end

	raw.unitListKnown = true
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		local unit = {
			unitID = finiteNumber(unitID) and unitID or nil,
			definitionKnown = false,
			stateKnown = false,
			taskKnown = false,
		}
		raw.units[#raw.units + 1] = unit

		if unit.unitID ~= nil then
			local defOk, unitDefID = call(self.spring.GetUnitDefID, unit.unitID)
			local unitDef = defOk and finiteNumber(unitDefID) and type(self.unitDefs) == "table"
				and self.unitDefs[unitDefID]
				or nil
			if type(unitDef) == "table" and type(unitDef.isBuilder) == "boolean" then
				unit.unitDefID = unitDefID
				unit.isBuilder = unitDef.isBuilder
				unit.isFactory = unitDef.isFactory == true
				unit.definitionKnown = unit.isBuilder == false or finiteNumber(unitDef.buildSpeed)
				unit.buildSpeed = unit.definitionKnown and unit.isBuilder and unitDef.buildSpeed or nil
			end

			if unit.definitionKnown and unit.isBuilder then
				local stateOk, stunnedOrBuilt, stunned, beingBuilt = call(self.spring.GetUnitIsStunned, unit.unitID)
				if stateOk and type(stunned) == "boolean" and type(beingBuilt) == "boolean" then
					unit.stunnedOrBuilt = stunnedOrBuilt == true
					unit.stunned = stunned
					unit.beingBuilt = beingBuilt
					unit.stateKnown = true
				end

				local taskOk, cmdID, targetID = call(self.spring.GetUnitWorkerTask, unit.unitID)
				if taskOk and (cmdID == nil or finiteNumber(cmdID)) then
					unit.taskKnown = true
					unit.taskCommandID = cmdID
					unit.taskTargetID = finiteNumber(targetID) and targetID or nil
				end

				local activityOk, activity = call(self.spring.GetUnitCurrentBuildPower, unit.unitID)
				if activityOk and finiteNumber(activity) and activity >= 0 and activity <= 1 then
					unit.nanoActivity = activity
				end
			elseif unit.definitionKnown then
				unit.stateKnown = true
				unit.taskKnown = true
			end
		end
	end

	return raw
end

return BuildPowerAdapter
