local loadModule = VFS and VFS.Include or dofile
local OpeningTracker = loadModule("LuaUI/Include/bar_learning_coach/opening_tracker.lua")

local function observation(factoryCount, factoryActive, contextStatus)
	local status = contextStatus or "supported"
	return {
		contextId = status == "supported" and "lesson" or nil,
		contextStatus = status,
		finishedCounts = { corlab = factoryCount },
		factory = { active = factoryActive, idleDuration = nil },
		recovery = { energyState = nil },
	}
end

local function fakeAdapter(values)
	local index = 0
	return {
		collect = function(_, teamID, context, gameTime)
			index = index + 1
			local current = values[index] or values[#values]
			current.observedTeamID = teamID
			current.observedContextId = context and context.id or nil
			current.gameTime = gameTime
			return current
		end,
	}
end

local context = { id = "lesson" }

describe("opening tracker", function()
	it("returns an explicit error when adapter is unavailable", function()
		local tracker = OpeningTracker.new(nil, context)
		local result, reason = tracker:observe(1, 10, "inactive")

		assert.is_nil(result)
		assert.are.equal("adapter unavailable", reason)
	end)

	it("injects the recovery state without inventing a missing value", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(0, false),
			observation(0, false),
		}), context)
		local first = tracker:observe(1, 10, "active")

		assert.are.equal("active", first.recovery.energyState)
		local second = tracker:observe(1, 15, nil)
		assert.is_nil(second.recovery.energyState)
	end)

	it("starts idle duration at the first confirmed idle factory sample", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(1, false),
			observation(1, false),
		}), context)

		local first = tracker:observe(1, 20, "inactive")
		local second = tracker:observe(1, 27.5, "inactive")

		assert.are.equal(0, first.factory.idleDuration)
		assert.are.equal(7.5, second.factory.idleDuration)
	end)

	it("resets idle duration when factory becomes active", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(1, false),
			observation(1, true),
			observation(1, false),
		}), context)

		tracker:observe(1, 10, "inactive")
		local active = tracker:observe(1, 20, "inactive")
		local idleAgain = tracker:observe(1, 30, "inactive")

		assert.are.equal(0, active.factory.idleDuration)
		assert.are.equal(0, idleAgain.factory.idleDuration)
	end)

	it("does not report idle duration before a finished factory exists", function()
		local tracker = OpeningTracker.new(fakeAdapter({ observation(0, false) }), context)
		local result = tracker:observe(1, 20, "inactive")

		assert.is_nil(result.factory.idleDuration)
	end)

	it("breaks idle certainty when factory activity becomes unknown", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(1, false),
			observation(1, nil),
			observation(1, false),
		}), context)

		tracker:observe(1, 10, "inactive")
		local unknown = tracker:observe(1, 20, "inactive")
		local confirmedAgain = tracker:observe(1, 30, "inactive")

		assert.is_nil(unknown.factory.idleDuration)
		assert.are.equal(0, confirmedAgain.factory.idleDuration)
	end)

	it("resets idle history when team changes", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(1, false),
			observation(1, false),
		}), context)

		tracker:observe(1, 10, "inactive")
		local changed = tracker:observe(2, 30, "inactive")

		assert.are.equal(0, changed.factory.idleDuration)
	end)

	it("resets idle history when game time rewinds", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(1, false),
			observation(1, false),
		}), context)

		tracker:observe(1, 30, "inactive")
		local rewound = tracker:observe(1, 5, "inactive")

		assert.are.equal(0, rewound.factory.idleDuration)
	end)

	it("does not accumulate idle history for unsupported context", function()
		local tracker = OpeningTracker.new(fakeAdapter({ observation(1, false, "unsupported") }), context)
		local result = tracker:observe(1, 20, "inactive")

		assert.is_nil(result.factory.idleDuration)
	end)

	it("invalidate drops only temporal certainty", function()
		local tracker = OpeningTracker.new(fakeAdapter({
			observation(1, false),
			observation(1, false),
		}), context)

		tracker:observe(1, 10, "inactive")
		tracker:invalidate()
		local result = tracker:observe(1, 30, "inactive")

		assert.are.equal(0, result.factory.idleDuration)
	end)
end)
