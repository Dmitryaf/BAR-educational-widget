local loadModule = VFS and VFS.Include or dofile
local Snapshot = loadModule("LuaUI/Include/bar_learning_coach/build_power_snapshot.lua")

local function nonBuilder(id)
	return {
		unitID = id,
		definitionKnown = true,
		isBuilder = false,
		stateKnown = true,
		taskKnown = true,
	}
end

local function builder(id, speed, commandID, targetID, fields)
	fields = fields or {}
	return {
		unitID = id,
		definitionKnown = true,
		isBuilder = true,
		isFactory = fields.isFactory == true,
		buildSpeed = speed,
		stateKnown = fields.stateKnown ~= false,
		taskKnown = fields.taskKnown ~= false,
		beingBuilt = fields.beingBuilt == true,
		stunned = fields.stunned == true,
		taskCommandID = commandID,
		taskTargetID = targetID,
	}
end

describe("BuildPowerSnapshot", function()
	it("keeps exact zeroes when there is no active construction", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = { nonBuilder(1), builder(2, 100) },
		})

		assert.are.equal("complete", result.status)
		assert.are.equal(100, result.totalBuildPower)
		assert.are.equal(0, result.activeBuildPower)
		assert.are.equal(0, result.activeBuilderCount)
		assert.are.equal(1, result.inactiveBuilderCount)
	end)

	it("aggregates one builder constructing one target", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = { builder(1, 120, -45, 900) },
		})

		assert.are.equal(120, result.activeBuildPower)
		assert.are.equal(1, result.activeBuilderCount)
		assert.are.equal(1, #result.targets)
		assert.are.equal(900, result.targets[1].targetID)
		assert.are.equal(120, result.targets[1].activeBuildPower)
	end)

	it("groups factory production and assisting builders by target", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = {
				builder(10, 100, -77, 501, { isFactory = true }),
				builder(11, 80, -77, 501),
				builder(12, 60, -77, 501),
			},
		})

		assert.are.equal(240, result.totalBuildPower)
		assert.are.equal(240, result.activeBuildPower)
		assert.are.equal(3, result.targets[1].contributors)
		assert.are.equal(1, result.targets[1].factoryContributors)
	end)

	it("does not count repair or reclaim as construction", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = {
				builder(1, 100, 40, 500),
				builder(2, 80, 90, 600),
			},
		})

		assert.are.equal(0, result.activeBuildPower)
		assert.are.equal(2, result.nonConstructionTaskCount)
	end)

	it("excludes unfinished and stunned builders from active construction", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = {
				builder(1, 100, -4, 500, { beingBuilt = true }),
				builder(2, 80, -4, 500, { stunned = true }),
			},
		})

		assert.are.equal(80, result.totalBuildPower)
		assert.are.equal(0, result.activeBuildPower)
		assert.are.equal(2, result.unavailableBuilderCount)
	end)

	it("keeps total exact when only a current worker task is unknown", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = { builder(1, 100, nil, nil, { taskKnown = false }) },
		})

		assert.are.equal("partial", result.status)
		assert.are.equal(100, result.totalBuildPower)
		assert.is_nil(result.activeBuildPower)
	end)

	it("does not expose an exact aggregate when any own unit is unknown", function()
		local result = Snapshot.fromRaw({
			unitListKnown = true,
			units = {
				builder(1, 100, -4, 500),
				{ unitID = 2, definitionKnown = false },
			},
		})

		assert.are.equal("partial", result.status)
		assert.is_nil(result.totalBuildPower)
		assert.is_nil(result.activeBuildPower)
		assert.are.equal(100, result.knownTotalBuildPower)
		assert.are.equal(100, result.knownActiveBuildPower)
		assert.are.equal(0, #result.targets)
	end)

	it("keeps all aggregates unknown when the team unit API is unavailable", function()
		local result = Snapshot.fromRaw({ unitListKnown = false })

		assert.are.equal("unknown", result.status)
		assert.is_nil(result.unitCount)
		assert.is_nil(result.totalBuildPower)
		assert.is_nil(result.activeBuildPower)
	end)
end)
