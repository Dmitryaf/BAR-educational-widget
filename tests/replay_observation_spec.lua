local loadModule = VFS and VFS.Include or dofile
local ReplayContext = loadModule("LuaUI/Include/bar_learning_coach/replay_context.lua")
local ReplayObservation = loadModule("LuaUI/Include/bar_learning_coach/replay_observation.lua")

local context = ReplayContext.get()

local function resource()
	return {
		known = true,
		current = 100,
		storage = 1000,
		pull = 40,
		income = 50,
		expense = 35,
	}
end

local function rawSnapshot()
	return {
		targetTeamID = 4,
		gameTime = 120,
		unitListKnown = true,
		unknownUnitCount = 0,
		commanderNames = { "corcom" },
		resources = { metal = resource(), energy = resource() },
		startPosition = { known = true, x = 0, z = 0 },
		units = {
			{
				unitID = 10,
				definitionKnown = true,
				name = "corcom",
				buildStateKnown = true,
				beingBuilt = false,
				positionKnown = true,
				x = 0,
				z = 0,
			},
			{
				unitID = 20,
				definitionKnown = true,
				name = "corlab",
				buildStateKnown = true,
				beingBuilt = false,
				taskKnown = true,
				taskCommandID = -7,
				taskTargetID = 99,
				positionKnown = true,
				x = 100,
				z = 100,
			},
			{
				unitID = 30,
				definitionKnown = true,
				name = "cormex",
				buildStateKnown = true,
				beingBuilt = false,
				positionKnown = true,
				x = 1000,
				z = 0,
			},
		},
	}
end

describe("replay observation", function()
	it("normalizes only confirmed supported replay evidence", function()
		local observation = ReplayObservation.normalize(context, rawSnapshot(), {
			mapName = context.mapName,
		})

		assert.are.equal("supported", observation.contextStatus)
		assert.are.equal(4, observation.teamID)
		assert.are.equal(1, observation.expansionMex)
		assert.are.equal(1, #observation.factories)
		assert.are.equal(true, observation.factories[1].active)
	end)

	it("rejects an unsupported map before producing a supported context", function()
		local observation = ReplayObservation.normalize(context, rawSnapshot(), {
			mapName = "Another Map",
		})

		assert.are.equal("unsupported", observation.contextStatus)
		assert.are.equal("map unsupported", observation.contextReason)
	end)

	it("keeps unknown API evidence unknown instead of calling it idle", function()
		local raw = rawSnapshot()
		raw.units[2].taskKnown = false
		raw.startPosition.known = false
		local observation = ReplayObservation.normalize(context, raw, {
			mapName = context.mapName,
		})

		assert.are.equal(false, observation.factories[1].activityKnown)
		assert.is_nil(observation.factories[1].active)
		assert.is_nil(observation.expansionMex)
	end)

	it("rejects a confirmed different commander faction", function()
		local raw = rawSnapshot()
		raw.commanderNames = { "armcom" }
		local observation = ReplayObservation.normalize(context, raw, {
			mapName = context.mapName,
		})

		assert.are.equal("unsupported", observation.contextStatus)
		assert.are.equal("faction unsupported", observation.contextReason)
	end)
end)
