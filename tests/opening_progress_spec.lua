local loadModule = VFS and VFS.Include or dofile
local OpeningContext = loadModule("LuaUI/Include/bar_learning_coach/opening_context.lua")
local OpeningProgress = loadModule("LuaUI/Include/bar_learning_coach/opening_progress.lua")

local context = OpeningContext.get()

local function observation(overrides)
	local value = {
		contextId = context.id,
		finishedCounts = {
			cormex = 0,
			corwin = 0,
			corsolar = 0,
			corlab = 0,
			corck = 0,
			combatBots = 0,
			expansionMex = 0,
		},
		factory = {
			active = false,
			idleDuration = 60,
		},
		recovery = {
			energyState = "inactive",
		},
	}

	if type(overrides) == "table" then
		for key, item in pairs(overrides) do
			value[key] = item
		end
	end
	return value
end

local function readyCounts()
	return {
		cormex = 3,
		corwin = 2,
		corsolar = 0,
		corlab = 1,
		corck = 1,
		combatBots = 5,
		expansionMex = 1,
	}
end

describe("opening progress", function()
	it("returns unknown when observation is missing", function()
		local evaluated = OpeningProgress.evaluate(context, nil)

		assert.are.equal("unknown", evaluated.lessonState)
		assert.are.equal("observation missing", evaluated.reason)
	end)

	it("returns unknown for a different context", function()
		local value = observation()
		value.contextId = "another_opening"

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("unknown", evaluated.lessonState)
		assert.are.equal("unsupported context", evaluated.reason)
	end)

	it("returns unknown instead of throwing for an invalid context", function()
		local invalidContext = OpeningContext.get()
		invalidContext.thresholds.baseMex = nil

		local evaluated = OpeningProgress.evaluate(invalidContext, observation())
		assert.are.equal("unknown", evaluated.lessonState)
		assert.are.equal("context invalid", evaluated.reason)
	end)

	it("keeps a missing required count unknown", function()
		local value = observation()
		value.finishedCounts.cormex = nil

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("unknown", evaluated.lessonState)
		assert.are.equal("base_income", evaluated.nextMilestoneId)
		assert.are.equal("unknown", evaluated.milestones[1].state)
		assert.are.equal("none", evaluated.presentation)
	end)

	it("starts with the base income milestone", function()
		local evaluated = OpeningProgress.evaluate(context, observation())

		assert.are.equal("in_progress", evaluated.lessonState)
		assert.are.equal("base_income", evaluated.nextMilestoneId)
		assert.are.equal("not_started", evaluated.milestones[1].state)
		assert.are.equal("milestone", evaluated.presentation)
	end)

	it("recognizes partial base income", function()
		local value = observation()
		value.finishedCounts.cormex = 1

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("in_progress", evaluated.milestones[1].state)
	end)

	it("accepts solar as an energy alternative even when wind data is missing", function()
		local value = observation()
		value.finishedCounts.cormex = 2
		value.finishedCounts.corwin = nil
		value.finishedCounts.corsolar = 1

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("complete", evaluated.milestones[1].state)
		assert.are.equal("bot_lab", evaluated.nextMilestoneId)
	end)

	it("does not treat out-of-order factory completion as an error", function()
		local value = observation()
		value.finishedCounts.corlab = 1

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("base_income", evaluated.nextMilestoneId)
		assert.are.equal("complete", evaluated.milestones[2].state)
	end)

	it("requires both a constructor and initial combat bots", function()
		local value = observation()
		value.finishedCounts.cormex = 2
		value.finishedCounts.corwin = 1
		value.finishedCounts.corlab = 1
		value.finishedCounts.corck = 1
		value.finishedCounts.combatBots = 2

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("production_cycle", evaluated.nextMilestoneId)
		assert.are.equal("in_progress", evaluated.milestones[3].state)

		value.finishedCounts.combatBots = 3
		evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("complete", evaluated.milestones[3].state)
		assert.are.equal("first_expansion", evaluated.nextMilestoneId)
	end)

	it("keeps expansion unknown without context-specific evidence", function()
		local counts = readyCounts()
		counts.expansionMex = nil

		local evaluated = OpeningProgress.evaluate(context, observation({ finishedCounts = counts }))
		assert.are.equal("unknown", evaluated.lessonState)
		assert.are.equal("first_expansion", evaluated.nextMilestoneId)
		assert.are.equal("unknown", evaluated.milestones[4].state)
	end)

	it("lets active energy recovery override the next card without losing progress", function()
		local value = observation()
		value.finishedCounts.cormex = 1
		value.recovery.energyState = "active"

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("base_income", evaluated.nextMilestoneId)
		assert.are.equal("recovery", evaluated.presentation)
		assert.are.equal("blocked", evaluated.milestones[1].state)
		assert.are.equal("in_progress", evaluated.milestones[1].progressState)
	end)

	it("does not show recovery during a candidate", function()
		local value = observation()
		value.recovery.energyState = "candidate"

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("milestone", evaluated.presentation)
		assert.are.equal("not_started", evaluated.milestones[1].state)
	end)

	it("keeps the final milestone in progress while factory is idle too long", function()
		local value = observation({ finishedCounts = readyCounts() })

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("t1_loop", evaluated.nextMilestoneId)
		assert.are.equal("in_progress", evaluated.milestones[5].state)
	end)

	it("completes the lesson with expansion, army and recent factory activity", function()
		local value = observation({
			finishedCounts = readyCounts(),
			factory = { active = true, idleDuration = nil },
		})

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("complete", evaluated.lessonState)
		assert.is_nil(evaluated.nextMilestoneId)
		assert.are.equal("none", evaluated.presentation)
		assert.are.equal("complete", evaluated.milestones[5].state)
	end)

	it("does not complete the final milestone during active energy recovery", function()
		local value = observation({
			finishedCounts = readyCounts(),
			factory = { active = true, idleDuration = nil },
			recovery = { energyState = "active" },
		})

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("in_progress", evaluated.lessonState)
		assert.are.equal("t1_loop", evaluated.nextMilestoneId)
		assert.are.equal("recovery", evaluated.presentation)
		assert.are.equal("blocked", evaluated.milestones[5].state)
		assert.are.equal("in_progress", evaluated.milestones[5].progressState)
	end)

	it("treats an invalid negative count as unknown", function()
		local value = observation()
		value.finishedCounts.cormex = -1

		local evaluated = OpeningProgress.evaluate(context, value)
		assert.are.equal("unknown", evaluated.milestones[1].state)
	end)
end)
