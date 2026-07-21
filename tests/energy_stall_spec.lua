local loadModule = VFS and VFS.Include or dofile
local HistoryBuffer = loadModule("LuaUI/Include/bar_learning_coach/history_buffer.lua")
local EnergyStall = loadModule("LuaUI/Include/bar_learning_coach/energy_stall.lua")
local SnapshotCollector = loadModule("LuaUI/Include/bar_learning_coach/snapshot_collector.lua")

local function createCollector(config)
	local history = HistoryBuffer.new(20)
	local detector = EnergyStall.new(config)
	return SnapshotCollector.new(history, detector), history
end

local function snapshot(time, current, storage, pull, income, expense)
	return {
		gameTime = time,
		resources = {
			energy = {
				current = current,
				storage = storage,
				pull = pull,
				income = income,
				expense = expense or pull,
			},
		},
	}
end

describe("ENERGY_STALL diagnostic", function()
	it("returns unknown when required data is missing", function()
		local collector = createCollector()
		local result = collector:record({ gameTime = 10, resources = { energy = {} } })

		assert.are.equal("unknown", result.state)
		assert.are.equal("energy current missing", result.reason)
	end)

	it("restarts candidate timing after data becomes unknown", function()
		local collector = createCollector()
		assert.are.equal("candidate", collector:record(snapshot(0, 50, 1000, 140, 100)).state)
		assert.are.equal("unknown", collector:record({ gameTime = 10, resources = { energy = {} } }).state)
		assert.are.equal("candidate", collector:record(snapshot(20, 40, 1000, 150, 100)).state)
		assert.are.equal("candidate", collector:record(snapshot(34, 30, 1000, 160, 100)).state)
		assert.are.equal("active", collector:record(snapshot(35, 20, 1000, 170, 100)).state)
	end)

	it("treats non-positive storage as unknown", function()
		local collector = createCollector()
		local result = collector:record(snapshot(10, 0, 0, 140, 100))

		assert.are.equal("unknown", result.state)
		assert.are.equal("energy storage is not positive", result.reason)
	end)

	it("stays inactive when storage is available", function()
		local collector = createCollector()
		local result = collector:record(snapshot(10, 500, 1000, 140, 100))

		assert.are.equal("inactive", result.state)
		assert.is_false(result.enterCondition)
	end)

	it("rejects a short deficit spike", function()
		local collector = createCollector()
		assert.are.equal("candidate", collector:record(snapshot(0, 50, 1000, 140, 100)).state)
		assert.are.equal("inactive", collector:record(snapshot(5, 300, 1000, 140, 100)).state)
	end)

	it("activates after a sustained low-storage demand gap", function()
		local collector = createCollector()
		assert.are.equal("candidate", collector:record(snapshot(0, 50, 1000, 140, 100)).state)
		assert.are.equal("candidate", collector:record(snapshot(14, 40, 1000, 150, 100)).state)
		local result = collector:record(snapshot(15, 30, 1000, 160, 100))

		assert.are.equal("active", result.state)
		assert.are.equal(0.03, result.storageRatio)
		assert.are.equal(60, result.deficit)
		assert.are.equal(15, result.episodeDuration)
	end)

	it("keeps episode duration while active and resolving", function()
		local collector = createCollector()
		collector:record(snapshot(2, 50, 1000, 140, 100))
		local active = collector:record(snapshot(17, 30, 1000, 160, 100))
		local resolving = collector:record(snapshot(20, 160, 1000, 105, 100))

		assert.are.equal(15, active.episodeDuration)
		assert.are.equal(18, resolving.episodeDuration)
	end)

	it("requires sustained recovery before resolving", function()
		local collector = createCollector()
		collector:record(snapshot(0, 50, 1000, 140, 100))
		collector:record(snapshot(15, 30, 1000, 160, 100))
		assert.are.equal("resolving", collector:record(snapshot(16, 40, 1000, 105, 100)).state)
		assert.are.equal("resolving", collector:record(snapshot(23, 160, 1000, 105, 100)).state)
		assert.are.equal("resolved", collector:record(snapshot(24, 180, 1000, 105, 100)).state)
	end)

	it("returns to active when recovery is interrupted", function()
		local collector = createCollector()
		collector:record(snapshot(0, 50, 1000, 140, 100))
		collector:record(snapshot(15, 30, 1000, 160, 100))
		collector:record(snapshot(16, 160, 1000, 105, 100))

		local result = collector:record(snapshot(18, 40, 1000, 150, 100))
		assert.are.equal("active", result.state)
		assert.are.equal("recovery interrupted", result.reason)
	end)

	it("keeps active inside enter and exit hysteresis", function()
		local collector = createCollector()
		collector:record(snapshot(0, 50, 1000, 140, 100))
		collector:record(snapshot(15, 30, 1000, 160, 100))

		local result = collector:record(snapshot(16, 120, 1000, 120, 100))
		assert.are.equal("active", result.state)
		assert.is_false(result.enterCondition)
		assert.is_false(result.clearCondition)
	end)

	it("suppresses a repeated stall during cooldown", function()
		local collector = createCollector()
		collector:record(snapshot(0, 50, 1000, 140, 100))
		collector:record(snapshot(15, 30, 1000, 160, 100))
		collector:record(snapshot(16, 160, 1000, 105, 100))
		collector:record(snapshot(24, 180, 1000, 105, 100))

		local result = collector:record(snapshot(25, 20, 1000, 180, 100))
		assert.are.equal("cooldown", result.state)
		assert.are.equal(89, result.cooldownRemaining)
	end)

	it("starts a new candidate when cooldown expires", function()
		local collector = createCollector()
		collector:record(snapshot(0, 50, 1000, 140, 100))
		collector:record(snapshot(15, 30, 1000, 160, 100))
		collector:record(snapshot(16, 160, 1000, 105, 100))
		collector:record(snapshot(24, 180, 1000, 105, 100))
		assert.are.equal("cooldown", collector:record(snapshot(113, 20, 1000, 180, 100)).state)

		local result = collector:record(snapshot(114, 20, 1000, 180, 100))
		assert.are.equal("candidate", result.state)
		assert.are.equal(0, result.duration)
	end)

	it("clears history and cooldown on collector reset", function()
		local collector, history = createCollector()
		collector:record(snapshot(0, 50, 1000, 140, 100))
		collector:record(snapshot(15, 30, 1000, 160, 100))
		collector:record(snapshot(16, 160, 1000, 105, 100))
		collector:record(snapshot(24, 180, 1000, 105, 100))
		collector:record(snapshot(25, 20, 1000, 180, 100))

		collector:reset()
		assert.are.equal(0, history:size())
		assert.are.equal("candidate", collector:record(snapshot(26, 20, 1000, 180, 100)).state)
	end)

	it("does not activate while values oscillate around the enter threshold", function()
		local collector = createCollector()
		assert.are.equal("candidate", collector:record(snapshot(0, 90, 1000, 140, 100)).state)
		assert.are.equal("inactive", collector:record(snapshot(10, 110, 1000, 140, 100)).state)
		assert.are.equal("candidate", collector:record(snapshot(11, 90, 1000, 140, 100)).state)
		assert.are.equal("candidate", collector:record(snapshot(25, 95, 1000, 140, 100)).state)
	end)

	it("does not confuse full storage with a stall", function()
		local collector = createCollector()
		local result = collector:record(snapshot(10, 1000, 1000, 6, 204, 6))

		assert.are.equal("inactive", result.state)
		assert.is_false(result.enterCondition)
		assert.are.equal(-198, result.deficit)
	end)

	it("keeps only normalized resource values in history", function()
		local collector, history = createCollector()
		collector:record(snapshot(10, 100, 1000, 120, 100))

		assert.are.equal(1, history:size())
		assert.are.equal(100, history:latest().energy.current)
		assert.is_nil(history:latest().resources)
	end)
end)
