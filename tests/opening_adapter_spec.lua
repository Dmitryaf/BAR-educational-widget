local loadModule = VFS and VFS.Include or dofile
local OpeningAdapter = loadModule("LuaUI/Include/bar_learning_coach/opening_adapter.lua")
local OpeningContext = loadModule("LuaUI/Include/bar_learning_coach/opening_context.lua")
local OpeningProgress = loadModule("LuaUI/Include/bar_learning_coach/opening_progress.lua")

local context = OpeningContext.get()

local unitDefs = {
	[1] = { name = "corcom", customParams = { iscommander = true } },
	[2] = { name = "cormex", customParams = {} },
	[3] = { name = "corwin", customParams = {} },
	[4] = { name = "corsolar", customParams = {} },
	[5] = { name = "corlab", customParams = {} },
	[6] = { name = "corck", customParams = {} },
	[7] = { name = "corak", customParams = {} },
	[8] = { name = "corstorm", customParams = {} },
	[9] = { name = "armcom", customParams = { iscommander = true } },
	[10] = { name = "untracked", customParams = {} },
}

local function fakeSpring(config)
	config = config or {}
	local spring = {}

	if config.teamUnitsAvailable ~= false then
		function spring.GetTeamUnits(teamID)
			config.requestedTeamID = teamID
			return config.unitIDs or {}
		end
	end

	if config.unitDefAvailable ~= false then
		function spring.GetUnitDefID(unitID)
			return config.defByUnit and config.defByUnit[unitID] or nil
		end
	end

	if config.buildStateAvailable ~= false then
		function spring.GetUnitIsBeingBuilt(unitID)
			if config.beingBuiltByUnit then
				return config.beingBuiltByUnit[unitID]
			end
			return false
		end
	end

	if config.workerTaskAvailable ~= false then
		function spring.GetUnitWorkerTask(unitID)
			local task = config.taskByUnit and config.taskByUnit[unitID] or nil
			if task then
				return task[1], task[2]
			end
			return nil
		end
	end

	if config.positionAvailable ~= false then
		function spring.GetUnitPosition(unitID)
			local position = config.positionByUnit and config.positionByUnit[unitID] or nil
			if position then
				return position[1], position[2], position[3]
			end
			return nil
		end
	end

	return spring
end

local function collect(config, mapName)
	local spring = fakeSpring(config)
	local adapter = OpeningAdapter.new(spring, unitDefs, {
		mapName = mapName or context.mapName,
	})
	return adapter:collect(7, context, 42), config
end

describe("opening adapter", function()
	it("returns unknown instead of throwing for an invalid context", function()
		local invalidContext = OpeningContext.get()
		invalidContext.countGroups.corlab = nil
		local adapter = OpeningAdapter.new(fakeSpring({}), unitDefs, { mapName = context.mapName })

		local observation = adapter:collect(7, invalidContext, 42)
		assert.are.equal("unknown", observation.contextStatus)
		assert.are.equal("context invalid", observation.reason)
	end)

	it("collects exact finished counts for the supported context", function()
		local observation, config = collect({
			unitIDs = { 101, 102, 103, 104, 105, 106, 107, 108, 109 },
			defByUnit = {
				[101] = 1,
				[102] = 2,
				[103] = 2,
				[104] = 3,
				[105] = 5,
				[106] = 6,
				[107] = 7,
				[108] = 8,
				[109] = 10,
			},
			beingBuiltByUnit = {
				[102] = false,
				[103] = true,
				[104] = false,
				[105] = false,
				[106] = false,
				[107] = false,
				[108] = false,
			},
			taskByUnit = { [105] = { -7, 700 } },
			positionByUnit = { [102] = { 100, 5, 200 } },
		})

		assert.are.equal(7, config.requestedTeamID)
		assert.are.equal(context.id, observation.contextId)
		assert.are.equal("supported", observation.contextStatus)
		assert.are.equal(42, observation.gameTime)
		assert.are.equal(1, observation.finishedCounts.cormex)
		assert.are.equal(1, observation.finishedCounts.corwin)
		assert.are.equal(0, observation.finishedCounts.corsolar)
		assert.are.equal(1, observation.finishedCounts.corlab)
		assert.are.equal(1, observation.finishedCounts.corck)
		assert.are.equal(2, observation.finishedCounts.combatBots)
		assert.is_nil(observation.finishedCounts.expansionMex)
		assert.are.equal(true, observation.factory.active)
		assert.are.equal(1, #observation.evidence.finishedMexPositions)
		assert.are.equal(true, observation.evidence.finishedMexPositions[1].positionKnown)
	end)

	it("rejects a different map before reading team units", function()
		local observation, config = collect({ unitIDs = { 101 }, defByUnit = { [101] = 1 } }, "Another Map")

		assert.are.equal("unsupported", observation.contextStatus)
		assert.are.equal("map unsupported", observation.reason)
		assert.is_nil(observation.contextId)
		assert.is_nil(config.requestedTeamID)
	end)

	it("rejects a confirmed foreign commander", function()
		local observation = collect({
			unitIDs = { 901 },
			defByUnit = { [901] = 9 },
		})

		assert.are.equal("unsupported", observation.contextStatus)
		assert.are.equal("faction unsupported", observation.reason)
		assert.is_nil(observation.contextId)
	end)

	it("keeps multiple commander factions unknown", function()
		local observation = collect({
			unitIDs = { 101, 901 },
			defByUnit = { [101] = 1, [901] = 9 },
		})

		assert.are.equal("unknown", observation.contextStatus)
		assert.are.equal("multiple commander factions", observation.reason)
		assert.is_nil(observation.contextId)
	end)

	it("does not infer another faction when commander evidence is absent", function()
		local observation = collect({
			unitIDs = { 102 },
			defByUnit = { [102] = 2 },
			beingBuiltByUnit = { [102] = false },
		})

		assert.are.equal("unknown", observation.contextStatus)
		assert.are.equal("commander context unavailable", observation.reason)
		assert.are.equal(1, observation.finishedCounts.cormex)
	end)

	it("makes all exact counts unknown when a unit definition is missing", function()
		local observation = collect({
			unitIDs = { 101, 102, 999 },
			defByUnit = { [101] = 1, [102] = 2 },
			beingBuiltByUnit = { [102] = false },
		})

		assert.are.equal("unknown", observation.contextStatus)
		assert.are.equal("unit definition incomplete", observation.reason)
		assert.are.equal(1, observation.evidence.unknownUnitCount)
		assert.is_nil(observation.finishedCounts.cormex)
		assert.is_nil(observation.finishedCounts.corlab)
	end)

	it("limits an unknown build state to its count group", function()
		local observation = collect({
			unitIDs = { 101, 102, 104 },
			defByUnit = { [101] = 1, [102] = 2, [104] = 3 },
			beingBuiltByUnit = { [104] = false },
		})

		assert.are.equal("supported", observation.contextStatus)
		assert.is_nil(observation.finishedCounts.cormex)
		assert.are.equal(1, observation.finishedCounts.corwin)
		assert.are.equal(0, observation.finishedCounts.combatBots)
	end)

	it("keeps factory activity unknown when worker task API is missing", function()
		local observation = collect({
			unitIDs = { 101, 105 },
			defByUnit = { [101] = 1, [105] = 5 },
			beingBuiltByUnit = { [105] = false },
			workerTaskAvailable = false,
		})

		assert.are.equal(1, observation.finishedCounts.corlab)
		assert.is_nil(observation.factory.active)
	end)

	it("keeps a negative factory task unknown without its target", function()
		local observation = collect({
			unitIDs = { 101, 105 },
			defByUnit = { [101] = 1, [105] = 5 },
			beingBuiltByUnit = { [105] = false },
			taskByUnit = { [105] = { -7, nil } },
		})

		assert.are.equal(1, observation.finishedCounts.corlab)
		assert.is_nil(observation.factory.active)
	end)

	it("knows that no factory cannot be active without task API", function()
		local observation = collect({
			unitIDs = { 101 },
			defByUnit = { [101] = 1 },
			workerTaskAvailable = false,
		})

		assert.are.equal(0, observation.finishedCounts.corlab)
		assert.are.equal(false, observation.factory.active)
	end)

	it("keeps a finished mex position unknown when position API is missing", function()
		local observation = collect({
			unitIDs = { 101, 102 },
			defByUnit = { [101] = 1, [102] = 2 },
			beingBuiltByUnit = { [102] = false },
			positionAvailable = false,
		})

		assert.are.equal(1, #observation.evidence.finishedMexPositions)
		assert.are.equal(false, observation.evidence.finishedMexPositions[1].positionKnown)
		assert.is_nil(observation.finishedCounts.expansionMex)
	end)

	it("keeps all counts unknown when team unit API is missing", function()
		local observation = collect({ teamUnitsAvailable = false })

		assert.are.equal("unknown", observation.contextStatus)
		assert.are.equal("team unit list unavailable", observation.reason)
		assert.are.equal(false, observation.evidence.api.getTeamUnits)
		assert.is_nil(observation.finishedCounts.cormex)
		assert.is_nil(observation.evidence.unitCount)
	end)

	it("feeds confirmed early milestones into opening progress", function()
		local observation = collect({
			unitIDs = { 101, 102, 103, 104, 105, 106, 107, 108, 110 },
			defByUnit = {
				[101] = 1,
				[102] = 2,
				[103] = 2,
				[104] = 3,
				[105] = 5,
				[106] = 6,
				[107] = 7,
				[108] = 7,
				[110] = 8,
			},
			beingBuiltByUnit = {
				[102] = false,
				[103] = false,
				[104] = false,
				[105] = false,
				[106] = false,
				[107] = false,
				[108] = false,
				[110] = false,
			},
			taskByUnit = { [105] = { -7, 700 } },
		})

		observation.recovery.energyState = "inactive"
		local evaluated = OpeningProgress.evaluate(context, observation)

		assert.are.equal("complete", evaluated.milestones[1].state)
		assert.are.equal("complete", evaluated.milestones[2].state)
		assert.are.equal("complete", evaluated.milestones[3].state)
		assert.are.equal("first_expansion", evaluated.nextMilestoneId)
		assert.are.equal("unknown", evaluated.lessonState)
	end)
end)
