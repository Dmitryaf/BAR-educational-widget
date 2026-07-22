local BuildPowerSnapshot = {}

local function newTarget(targetID)
	return {
		targetID = targetID,
		activeBuildPower = 0,
		contributors = 0,
		factoryContributors = 0,
	}
end

function BuildPowerSnapshot.fromRaw(raw)
	local result = {
		status = "unknown",
		reason = "build power data unavailable",
		unitCount = nil,
		knownBuilderCount = 0,
		unknownUnitCount = 0,
		knownTotalBuildPower = 0,
		knownActiveBuildPower = 0,
		totalBuildPower = nil,
		activeBuildPower = nil,
		activeBuilderCount = nil,
		inactiveBuilderCount = nil,
		unavailableBuilderCount = nil,
		nonConstructionTaskCount = nil,
		targets = {},
	}

	if type(raw) ~= "table" or raw.unitListKnown ~= true or type(raw.units) ~= "table" then
		return result
	end

	result.unitCount = #raw.units
	local totalComplete = true
	local activeComplete = true
	local activeBuilders = 0
	local inactiveBuilders = 0
	local unavailableBuilders = 0
	local nonConstructionTasks = 0
	local targetsByID = {}

	for i = 1, #raw.units do
		local unit = raw.units[i]
		if type(unit) ~= "table" or unit.definitionKnown ~= true then
			totalComplete = false
			activeComplete = false
			result.unknownUnitCount = result.unknownUnitCount + 1
		elseif unit.isBuilder then
			result.knownBuilderCount = result.knownBuilderCount + 1
			if type(unit.buildSpeed) ~= "number" or unit.buildSpeed < 0 then
				totalComplete = false
				activeComplete = false
				result.unknownUnitCount = result.unknownUnitCount + 1
			elseif unit.stateKnown ~= true then
				totalComplete = false
				activeComplete = false
				result.unknownUnitCount = result.unknownUnitCount + 1
			else
				if not unit.beingBuilt then
					result.knownTotalBuildPower = result.knownTotalBuildPower + unit.buildSpeed
				end

				if unit.beingBuilt or unit.stunned then
					unavailableBuilders = unavailableBuilders + 1
				elseif unit.taskKnown ~= true then
					activeComplete = false
					result.unknownUnitCount = result.unknownUnitCount + 1
				elseif type(unit.taskCommandID) == "number" and unit.taskCommandID < 0
					and type(unit.taskTargetID) ~= "number"
				then
					activeComplete = false
					result.unknownUnitCount = result.unknownUnitCount + 1
				elseif type(unit.taskCommandID) == "number" and unit.taskCommandID < 0 then
					activeBuilders = activeBuilders + 1
					result.knownActiveBuildPower = result.knownActiveBuildPower + unit.buildSpeed
					local target = targetsByID[unit.taskTargetID]
					if target == nil then
						target = newTarget(unit.taskTargetID)
						targetsByID[unit.taskTargetID] = target
						result.targets[#result.targets + 1] = target
					end
					target.activeBuildPower = target.activeBuildPower + unit.buildSpeed
					target.contributors = target.contributors + 1
					if unit.isFactory then
						target.factoryContributors = target.factoryContributors + 1
					end
				else
					inactiveBuilders = inactiveBuilders + 1
					if type(unit.taskCommandID) == "number" and unit.taskCommandID > 0 then
						nonConstructionTasks = nonConstructionTasks + 1
					end
				end
			end
		end
	end

	table.sort(result.targets, function(a, b)
		return a.targetID < b.targetID
	end)

	if totalComplete then
		result.totalBuildPower = result.knownTotalBuildPower
	end
	if activeComplete then
		result.activeBuildPower = result.knownActiveBuildPower
		result.activeBuilderCount = activeBuilders
		result.inactiveBuilderCount = inactiveBuilders
		result.unavailableBuilderCount = unavailableBuilders
		result.nonConstructionTaskCount = nonConstructionTasks
	else
		result.targets = {}
	end

	if totalComplete and activeComplete then
		result.status = "complete"
		result.reason = "all own units classified"
	else
		result.status = "partial"
		if not totalComplete then
			result.reason = "total and active build power are incomplete"
		else
			result.reason = "active build power is incomplete"
		end
	end

	return result
end

return BuildPowerSnapshot
