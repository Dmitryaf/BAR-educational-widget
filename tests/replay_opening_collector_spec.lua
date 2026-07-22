local loadModule = VFS and VFS.Include or dofile
local ReplayOpeningCollector = loadModule("LuaUI/Include/bar_learning_coach/replay_opening_collector.lua")

local unitDefs = {
	[1] = {
		name = "armcom",
		isBuilder = true,
		isFactory = false,
		buildSpeed = 300,
		customParams = { iscommander = true },
	},
	[2] = {
		name = "armmex",
		isBuilder = false,
		isFactory = false,
		buildSpeed = 0,
		customParams = {},
	},
	[3] = {
		name = "armlab",
		isBuilder = true,
		isFactory = true,
		buildSpeed = 100,
		customParams = {},
	},
}

describe("replay opening collector", function()
	it("reads only the configured target team and keeps exact unit names", function()
		local requestedTeamID = nil
		local spring = {
			GetTeamResources = function(teamID, resourceName)
				assert.are.equal(4, teamID)
				return resourceName == "metal" and 100 or 200, 1000, 12, 15, 11, 0.99, 0, 0, 0
			end,
			GetTeamUnits = function(teamID)
				requestedTeamID = teamID
				return { 10, 20, 30 }
			end,
			GetUnitDefID = function(unitID)
				return ({ [10] = 1, [20] = 2, [30] = 3 })[unitID]
			end,
			GetUnitIsBeingBuilt = function(unitID)
				return unitID == 30
			end,
			GetUnitPosition = function(unitID)
				return unitID, 5, unitID + 1
			end,
			GetUnitWorkerTask = function()
				return -3, 99
			end,
		}

		local snapshot = ReplayOpeningCollector.new(spring, unitDefs, 4):collect(120, 3600)

		assert.are.equal(4, requestedTeamID)
		assert.are.equal(true, snapshot.unitListKnown)
		assert.are.equal(3, snapshot.unitCount)
		assert.are.equal(1, snapshot.countsByName.armcom)
		assert.are.equal(1, snapshot.finishedCountsByName.armmex)
		assert.is_nil(snapshot.finishedCountsByName.armlab)
		assert.are.equal("armcom", snapshot.commanderNames[1])
		assert.are.equal(false, snapshot.units[2].isBuilder)
		assert.are.equal(false, snapshot.units[2].isFactory)
		assert.are.equal(100, snapshot.resources.metal.current)
		assert.are.equal(200, snapshot.resources.energy.current)
		assert.are.equal(-3, snapshot.units[3].taskCommandID)
		assert.are.equal(99, snapshot.units[3].taskTargetID)
	end)

	it("preserves unknown unit definitions without turning them into zero counts", function()
		local spring = {
			GetTeamResources = function() return 1, 2, 3, 4 end,
			GetTeamUnits = function() return { 10, 999 } end,
			GetUnitDefID = function(unitID) return unitID == 10 and 2 or nil end,
			GetUnitIsBeingBuilt = function() return false end,
		}

		local snapshot = ReplayOpeningCollector.new(spring, unitDefs, 4):collect(5, 150)

		assert.are.equal(1, snapshot.unknownUnitCount)
		assert.are.equal(false, snapshot.units[2].definitionKnown)
		assert.are.equal(1, snapshot.finishedCountsByName.armmex)
		assert.is_nil(snapshot.finishedCountsByName.armwin)
	end)

	it("does not fall back to the observer team when target team is missing", function()
		local called = false
		local spring = {
			GetTeamUnits = function()
				called = true
				return {}
			end,
		}

		local snapshot = ReplayOpeningCollector.new(spring, unitDefs, nil):collect(5, 150)

		assert.are.equal("target team id unavailable", snapshot.reason)
		assert.are.equal(false, snapshot.unitListKnown)
		assert.are.equal(false, called)
	end)

	it("keeps resources and unit list unknown when APIs fail", function()
		local spring = {
			GetTeamResources = function() error("not visible") end,
			GetTeamUnits = function() error("not visible") end,
		}

		local snapshot = ReplayOpeningCollector.new(spring, unitDefs, 4):collect(5, 150)

		assert.are.equal(false, snapshot.resources.metal.known)
		assert.are.equal(false, snapshot.resources.energy.known)
		assert.are.equal(false, snapshot.unitListKnown)
		assert.is_nil(snapshot.unknownUnitCount)
	end)

	it("uses a supplied event definition without querying hidden teams", function()
		local queried = false
		local spring = {
			GetUnitDefID = function()
				queried = true
				return nil
			end,
			GetUnitIsBeingBuilt = function() return true end,
			GetUnitPosition = function() return 10, 2, 20 end,
		}

		local item = ReplayOpeningCollector.new(spring, unitDefs, 4):describeUnit(50, 3)

		assert.are.equal(false, queried)
		assert.are.equal("armlab", item.name)
		assert.are.equal(true, item.beingBuilt)
		assert.are.equal(true, item.positionKnown)
	end)
end)
