local Fixtures = {}

local GOOD_ENERGY = {
	current = 500,
	storage = 1000,
	pull = 40,
	income = 60,
	expense = 35,
}

local BAD_ENERGY = {
	current = 50,
	storage = 1000,
	pull = 100,
	income = 20,
	expense = 20,
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

function Fixtures.observation(gameTime, overrides)
	overrides = type(overrides) == "table" and overrides or {}
	local energy = copy(overrides.energy or GOOD_ENERGY)
	if overrides.energy == false then
		energy = nil
	end
	local expansionMex = overrides.expansionMex or 0
	if overrides.expansionMex == false then
		expansionMex = nil
	end
	return {
		contextId = "cortex_bot_ravaged_replay_v1",
		contextStatus = overrides.contextStatus or "supported",
		contextReason = overrides.contextReason or "context confirmed",
		gameTime = gameTime,
		teamID = overrides.teamID or 1,
		energy = energy,
		metal = copy(overrides.metal or {
			current = 200,
			storage = 1000,
			pull = 20,
			income = 25,
			expense = 18,
		}),
		factories = copy(overrides.factories or {
			{
				unitID = 100,
				finished = true,
				buildStateKnown = true,
				activityKnown = true,
				active = true,
			},
		}),
		factoryListKnown = overrides.factoryListKnown ~= false,
		expansionMex = expansionMex,
	}
end

function Fixtures.goodEnergy()
	return copy(GOOD_ENERGY)
end

function Fixtures.badEnergy()
	return copy(BAD_ENERGY)
end

function Fixtures.factory(active, activityKnown)
	local confirmed = activityKnown ~= false
	local activeValue = active
	if not confirmed then
		activeValue = nil
	end
	return {
		{
			unitID = 100,
			finished = true,
			buildStateKnown = true,
			activityKnown = confirmed,
			active = activeValue,
		},
	}
end

return Fixtures
