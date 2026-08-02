local ReplayContext = {}

local CONTEXT = {
	id = "cortex_bot_ravaged_replay_v1",
	mapName = "Ravaged Remake v1.2",
	faction = "Cortex",
	commanderUnitDefName = "corcom",
	factoryUnitDefName = "corlab",
	mexUnitDefName = "cormex",
	expansionRadius = 900,
	sampleInterval = 2,
	thresholds = {
		energyEpisodeDuration = 20,
		factoryIdleDuration = 15,
		lateExpansionTime = 240,
		relationWindow = 30,
		minimumSupportedSamples = 3,
	},
	energy = {
		storageRatioEnter = 0.10,
		storageRatioExit = 0.15,
		minimumDeficitEnter = 25,
		minimumDeficitExit = 10,
		candidateDuration = 15,
		resolveDuration = 8,
		cooldown = 0,
		trendWindow = 5,
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

function ReplayContext.get()
	return copy(CONTEXT)
end

return ReplayContext
