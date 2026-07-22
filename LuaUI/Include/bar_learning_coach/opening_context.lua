local OpeningContext = {}

local DEFAULT_ID = "cortex_bot_ravaged_1v1_practice"

local CONTEXT = {
	id = DEFAULT_ID,
	mapName = "Ravaged Remake v1.2",
	mode = "local_1v1_practice",
	faction = "Cortex",
	commanderUnitDefName = "corcom",
	factoryUnitDefName = "corlab",
	countGroups = {
		cormex = { "cormex" },
		corwin = { "corwin" },
		corsolar = { "corsolar" },
		corlab = { "corlab" },
		corck = { "corck" },
		combatBots = { "corak", "corstorm", "corthud", "corcrash" },
	},
	thresholds = {
		baseMex = 2,
		baseEnergy = 1,
		initialCombatBots = 3,
		expansionMex = 1,
		stableCombatBots = 5,
		factoryIdleLimit = 15,
	},
	milestones = {
		{
			id = "base_income",
			title = "Запусти базовый доход",
			action = "Закончи два mex и добавь раннюю генерацию энергии.",
		},
		{
			id = "bot_lab",
			title = "Запусти производство",
			action = "Закончи Cortex Bot Lab.",
		},
		{
			id = "production_cycle",
			title = "Начни производственный цикл",
			action = "Выпусти constructor и первые combat bots.",
		},
		{
			id = "first_expansion",
			title = "Начни расширение",
			action = "Закончи mex вне подтверждённой стартовой зоны.",
		},
		{
			id = "t1_loop",
			title = "Закрепи T1-производство",
			action = "Продолжай выпуск units и не оставляй factory без работы.",
		},
	},
}

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

local function positiveInteger(value)
	return type(value) == "number"
		and value == value
		and value > 0
		and value < math.huge
		and value % 1 == 0
end

local function nonEmptyStringArray(value)
	if type(value) ~= "table" or #value == 0 then
		return false
	end
	for i = 1, #value do
		if type(value[i]) ~= "string" or value[i] == "" then
			return false
		end
	end
	return true
end

function OpeningContext.validate(context)
	if type(context) ~= "table" then
		return false, "context missing"
	end

	local requiredStrings = {
		"id",
		"mapName",
		"mode",
		"faction",
		"commanderUnitDefName",
		"factoryUnitDefName",
	}
	for i = 1, #requiredStrings do
		local field = requiredStrings[i]
		if type(context[field]) ~= "string" or context[field] == "" then
			return false, "context " .. field .. " missing"
		end
	end

	if type(context.countGroups) ~= "table" then
		return false, "context countGroups missing"
	end
	local requiredCountGroups = { "cormex", "corwin", "corsolar", "corlab", "corck", "combatBots" }
	for i = 1, #requiredCountGroups do
		local group = requiredCountGroups[i]
		if not nonEmptyStringArray(context.countGroups[group]) then
			return false, "context countGroups " .. group .. " invalid"
		end
	end
	if #context.countGroups.corlab ~= 1 or context.countGroups.corlab[1] ~= context.factoryUnitDefName then
		return false, "context factory count group mismatch"
	end
	if type(context.thresholds) ~= "table" then
		return false, "context thresholds missing"
	end
	if type(context.milestones) ~= "table" or #context.milestones == 0 then
		return false, "context milestones missing"
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
		local field = requiredThresholds[i]
		if not positiveInteger(context.thresholds[field]) then
			return false, "context threshold " .. field .. " invalid"
		end
	end

	local requiredMilestoneIds = {
		"base_income",
		"bot_lab",
		"production_cycle",
		"first_expansion",
		"t1_loop",
	}
	if #context.milestones ~= #requiredMilestoneIds then
		return false, "context milestone count invalid"
	end

	local milestoneIds = {}
	for i = 1, #context.milestones do
		local milestone = context.milestones[i]
		if type(milestone) ~= "table"
			or type(milestone.id) ~= "string"
			or milestone.id == ""
			or type(milestone.title) ~= "string"
			or milestone.title == ""
			or type(milestone.action) ~= "string"
			or milestone.action == ""
		then
			return false, "context milestone invalid"
		end
		if milestone.id ~= requiredMilestoneIds[i] then
			return false, "context milestone order invalid"
		end
		if milestoneIds[milestone.id] then
			return false, "context milestone duplicated"
		end
		milestoneIds[milestone.id] = true
	end

	return true, nil
end

function OpeningContext.get(id)
	if id ~= nil and id ~= DEFAULT_ID then
		return nil
	end
	return copy(CONTEXT)
end

function OpeningContext.defaultId()
	return DEFAULT_ID
end

return OpeningContext
