local OpeningProgress = {}

local RECOVERY_STATES = {
	active = true,
	resolving = true,
}

local function finiteNonNegativeNumber(value)
	return type(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
end

local function nonNegativeInteger(value)
	return finiteNonNegativeNumber(value) and value % 1 == 0
end

local function count(finishedCounts, field)
	if type(finishedCounts) ~= "table" then
		return nil
	end
	local value = finishedCounts[field]
	if not nonNegativeInteger(value) then
		return nil
	end
	return value
end

local function result(id, state, reason)
	return {
		id = id,
		state = state,
		reason = reason,
	}
end

local function binaryCountState(id, value, threshold)
	if value == nil then
		return result(id, "unknown", "required count missing")
	end
	if value >= threshold then
		return result(id, "complete")
	end
	if value > 0 then
		return result(id, "in_progress")
	end
	return result(id, "not_started")
end

local function evaluateBaseIncome(context, finishedCounts)
	local mex = count(finishedCounts, "cormex")
	local wind = count(finishedCounts, "corwin")
	local solar = count(finishedCounts, "corsolar")

	if mex == nil then
		return result("base_income", "unknown", "cormex count missing")
	end

	local energyComplete = (wind ~= nil and wind >= context.thresholds.baseEnergy)
		or (solar ~= nil and solar >= context.thresholds.baseEnergy)
	if mex >= context.thresholds.baseMex and energyComplete then
		return result("base_income", "complete")
	end

	if wind == nil and solar == nil then
		return result("base_income", "unknown", "energy counts missing")
	end
	if wind == nil and not (solar and solar >= context.thresholds.baseEnergy) then
		return result("base_income", "unknown", "corwin count missing")
	end
	if solar == nil and not (wind and wind >= context.thresholds.baseEnergy) then
		return result("base_income", "unknown", "corsolar count missing")
	end

	if mex > 0 or (wind and wind > 0) or (solar and solar > 0) then
		return result("base_income", "in_progress")
	end
	return result("base_income", "not_started")
end

local function evaluateProduction(context, finishedCounts)
	local constructors = count(finishedCounts, "corck")
	local combatBots = count(finishedCounts, "combatBots")

	if constructors ~= nil
		and constructors >= 1
		and combatBots ~= nil
		and combatBots >= context.thresholds.initialCombatBots
	then
		return result("production_cycle", "complete")
	end

	if constructors == nil then
		return result("production_cycle", "unknown", "corck count missing")
	end
	if combatBots == nil then
		return result("production_cycle", "unknown", "combatBots count missing")
	end
	if constructors > 0 or combatBots > 0 then
		return result("production_cycle", "in_progress")
	end
	return result("production_cycle", "not_started")
end

local function allComplete(results, lastIndex)
	for i = 1, lastIndex do
		local state = results[i].state
		if state ~= "complete" and state ~= "skipped_validly" then
			return false
		end
	end
	return true
end

local function evaluateT1Loop(context, observation, milestones)
	if not allComplete(milestones, #milestones) then
		return result("t1_loop", "not_started", "earlier milestone incomplete")
	end
	if type(observation.recovery) ~= "table" or type(observation.recovery.energyState) ~= "string" then
		return result("t1_loop", "unknown", "energy recovery state missing")
	end
	if RECOVERY_STATES[observation.recovery.energyState] then
		return result("t1_loop", "in_progress", "energy recovery active")
	end

	local combatBots = count(observation.finishedCounts, "combatBots")
	if combatBots == nil then
		return result("t1_loop", "unknown", "combatBots count missing")
	end

	local factory = observation.factory
	if type(factory) ~= "table" then
		return result("t1_loop", "unknown", "factory state missing")
	end

	local recentlyActive = factory.active == true
	if not recentlyActive then
		if not finiteNonNegativeNumber(factory.idleDuration) then
			return result("t1_loop", "unknown", "factory idle duration missing")
		end
		recentlyActive = factory.idleDuration <= context.thresholds.factoryIdleLimit
	end

	if combatBots >= context.thresholds.stableCombatBots and recentlyActive then
		return result("t1_loop", "complete")
	end
	return result("t1_loop", "in_progress")
end

local function unknownEvaluation(contextId, reason)
	return {
		contextId = contextId,
		lessonState = "unknown",
		nextMilestoneId = nil,
		presentation = "none",
		milestones = {},
		reason = reason,
	}
end

local function validContext(context)
	if type(context) ~= "table"
		or type(context.id) ~= "string"
		or type(context.thresholds) ~= "table"
		or type(context.milestones) ~= "table"
	then
		return false
	end

	local requiredThresholds = {
		"baseMex",
		"baseEnergy",
		"initialCombatBots",
		"expansionMex",
		"stableCombatBots",
		"factoryIdleLimit",
	}
	for i = 1, #requiredThresholds do
		local value = context.thresholds[requiredThresholds[i]]
		if not nonNegativeInteger(value) or value == 0 then
			return false
		end
	end

	for i = 1, #context.milestones do
		if type(context.milestones[i]) ~= "table" or type(context.milestones[i].id) ~= "string" then
			return false
		end
	end
	return #context.milestones > 0
end

function OpeningProgress.evaluate(context, observation)
	if type(context) ~= "table" or type(context.id) ~= "string" then
		return unknownEvaluation(nil, "context missing")
	end
	if not validContext(context) then
		return unknownEvaluation(context.id, "context invalid")
	end
	if type(observation) ~= "table" then
		return unknownEvaluation(context.id, "observation missing")
	end
	if observation.contextId ~= context.id then
		return unknownEvaluation(context.id, "unsupported context")
	end
	if type(observation.finishedCounts) ~= "table" then
		return unknownEvaluation(context.id, "finished counts missing")
	end

	local evaluators = {
		base_income = function()
			return evaluateBaseIncome(context, observation.finishedCounts)
		end,
		bot_lab = function()
			return binaryCountState("bot_lab", count(observation.finishedCounts, "corlab"), 1)
		end,
		production_cycle = function()
			return evaluateProduction(context, observation.finishedCounts)
		end,
		first_expansion = function()
			return binaryCountState(
				"first_expansion",
				count(observation.finishedCounts, "expansionMex"),
				context.thresholds.expansionMex
			)
		end,
	}
	local milestones = {}
	for i = 1, #context.milestones do
		local milestoneId = context.milestones[i].id
		if milestoneId == "t1_loop" then
			milestones[i] = evaluateT1Loop(context, observation, milestones)
		elseif evaluators[milestoneId] then
			milestones[i] = evaluators[milestoneId]()
		else
			milestones[i] = result(milestoneId, "unknown", "milestone evaluator missing")
		end
	end

	local nextMilestoneIndex = nil
	for i = 1, #milestones do
		local state = milestones[i].state
		if state ~= "complete" and state ~= "skipped_validly" then
			nextMilestoneIndex = i
			break
		end
	end

	local lessonState = nextMilestoneIndex and "in_progress" or "complete"
	local presentation = nextMilestoneIndex and "milestone" or "none"
	local recoveryState = observation.recovery and observation.recovery.energyState or nil
	if nextMilestoneIndex and RECOVERY_STATES[recoveryState] then
		local blocked = milestones[nextMilestoneIndex]
		blocked.progressState = blocked.state
		blocked.state = "blocked"
		blocked.reason = "energy recovery active"
		presentation = "recovery"
	end

	if nextMilestoneIndex and milestones[nextMilestoneIndex].state == "unknown" then
		lessonState = "unknown"
		presentation = "none"
	end

	return {
		contextId = context.id,
		lessonState = lessonState,
		nextMilestoneId = nextMilestoneIndex and milestones[nextMilestoneIndex].id or nil,
		presentation = presentation,
		milestones = milestones,
		recoveryState = recoveryState,
	}
end

return OpeningProgress
