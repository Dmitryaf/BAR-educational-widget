local loadModule = VFS and VFS.Include or dofile
local ReplayContext = loadModule("LuaUI/Include/bar_learning_coach/replay_context.lua")
local HistoryBuffer = loadModule("LuaUI/Include/bar_learning_coach/history_buffer.lua")
local EnergyStall = loadModule("LuaUI/Include/bar_learning_coach/energy_stall.lua")
local EpisodeAggregator = loadModule("LuaUI/Include/bar_learning_coach/episode_aggregator.lua")
local IssueRanker = loadModule("LuaUI/Include/bar_learning_coach/issue_ranker.lua")
local TrainingTaskSelector = loadModule("LuaUI/Include/bar_learning_coach/training_task_selector.lua")
local ReplayReport = loadModule("LuaUI/Include/bar_learning_coach/replay_report.lua")
local ReplayReportPresentation = loadModule("LuaUI/Include/bar_learning_coach/replay_report_presentation.lua")
local ReplaySession = loadModule("LuaUI/Include/bar_learning_coach/replay_session.lua")
local fixturePath = VFS
	and "LuaUI/Include/bar_learning_coach/tests/replay_fixtures.lua"
	or "tests/replay_fixtures.lua"
local Fixtures = loadModule(fixturePath)

local context = ReplayContext.get()

local function newSession()
	return ReplaySession.new(context, {
		HistoryBuffer = HistoryBuffer,
		EnergyStall = EnergyStall,
		EpisodeAggregator = EpisodeAggregator,
		IssueRanker = IssueRanker,
		TrainingTaskSelector = TrainingTaskSelector,
		ReplayReport = ReplayReport,
	})
end

local function reportTypes(report)
	local types = {}
	for i = 1, #report.supportingEpisodes do
		types[report.supportingEpisodes[i].type] = true
	end
	return types
end

describe("replay analysis", function()
	it("records one confirmed energy stall", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { energy = Fixtures.badEnergy() }))
		session:record(Fixtures.observation(20, { energy = Fixtures.badEnergy() }))
		session:record(Fixtures.observation(25, { energy = Fixtures.goodEnergy() }))
		session:record(Fixtures.observation(35, { energy = Fixtures.goodEnergy() }))
		local report = session:finish("Player")

		assert.are.equal("energy_stall", report.primaryIssue.type)
		assert.are.equal(true, reportTypes(report).energy_stall)
	end)

	it("ignores several short energy fluctuations", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { energy = Fixtures.badEnergy() }))
		session:record(Fixtures.observation(10, { energy = Fixtures.goodEnergy() }))
		session:record(Fixtures.observation(20, { energy = Fixtures.badEnergy() }))
		session:record(Fixtures.observation(30, { energy = Fixtures.goodEnergy() }))
		local report = session:finish("Player")

		assert.is_nil(report.primaryIssue)
		assert.are.equal("no_significant_issue", report.status)
	end)

	it("relates factory idle that continues after an energy stall", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { energy = Fixtures.badEnergy() }))
		session:record(Fixtures.observation(20, { energy = Fixtures.badEnergy() }))
		session:record(Fixtures.observation(25, {
			energy = Fixtures.goodEnergy(),
			factories = Fixtures.factory(false),
		}))
		session:record(Fixtures.observation(35, {
			energy = Fixtures.goodEnergy(),
			factories = Fixtures.factory(false),
		}))
		session:record(Fixtures.observation(60, {
			energy = Fixtures.goodEnergy(),
			factories = Fixtures.factory(true),
		}))
		local report = session:finish("Player")

		assert.are.equal("factory_idle", report.primaryIssue.type)
		assert.are.equal(true, report.primaryIssue.relatedConsequence)
		assert.are.equal(true, reportTypes(report).energy_stall)
		assert.are.equal(true, reportTypes(report).factory_idle)
	end)

	it("records factory idle without an energy stall", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { factories = Fixtures.factory(false) }))
		session:record(Fixtures.observation(20, { factories = Fixtures.factory(false) }))
		session:record(Fixtures.observation(25, { factories = Fixtures.factory(true) }))
		local report = session:finish("Player")

		assert.are.equal("factory_idle", report.primaryIssue.type)
		assert.are.equal(false, report.primaryIssue.relatedConsequence)
	end)

	it("records expansion after the context control window", function()
		local session = newSession()
		session:record(Fixtures.observation(0))
		session:record(Fixtures.observation(242))
		session:record(Fixtures.observation(270, { expansionMex = 1 }))
		local report = session:finish("Player")

		assert.are.equal("late_expansion", report.primaryIssue.type)
		assert.are.equal(30, report.supportingEpisodes[1].duration)
	end)

	it("returns a neutral report for a normal sequence", function()
		local session = newSession()
		session:record(Fixtures.observation(0))
		session:record(Fixtures.observation(180, { expansionMex = 1 }))
		session:record(Fixtures.observation(300, { expansionMex = 1 }))
		local report = session:finish("Player")

		assert.is_nil(report.primaryIssue)
		assert.are.equal("no_significant_issue", report.status)
	end)

	it("does not force an issue when data is insufficient", function()
		local session = newSession()
		session:record(Fixtures.observation(0))
		local report = session:finish("Player")

		assert.is_nil(report.primaryIssue)
		assert.are.equal("insufficient_data", report.status)
	end)

	it("returns an unsupported report for another map or faction", function()
		local session = newSession()
		session:record(Fixtures.observation(0, {
			contextStatus = "unsupported",
			contextReason = "map unsupported",
		}))
		local report = session:finish("Player")

		assert.are.equal("unsupported", report.status)
		assert.is_nil(report.primaryIssue)
	end)

	it("resets all episodes when the selected team changes", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { factories = Fixtures.factory(false) }))
		session:record(Fixtures.observation(20, { factories = Fixtures.factory(false) }))
		local state = session:record(Fixtures.observation(30, { teamID = 2 }))

		assert.are.equal("team_changed", state.lastResetReason)
		assert.are.equal(0, state.episodeCount)
		assert.are.equal(2, state.teamID)
	end)

	it("resets the analysis timeline on replay rewind", function()
		local session = newSession()
		session:record(Fixtures.observation(30, { factories = Fixtures.factory(false) }))
		session:record(Fixtures.observation(50, { factories = Fixtures.factory(false) }))
		local state = session:record(Fixtures.observation(5))

		assert.are.equal("rewind", state.lastResetReason)
		assert.are.equal(0, state.episodeCount)
		assert.are.equal(1, state.sampleCount)
	end)

	it("closes an active confirmed episode at replay end", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { factories = Fixtures.factory(false) }))
		session:record(Fixtures.observation(20, { factories = Fixtures.factory(false) }))
		local report = session:finish("Player")

		assert.are.equal("factory_idle", report.primaryIssue.type)
		assert.are.equal(20, report.supportingEpisodes[1].duration)
	end)

	it("ranking chooses exactly one primary issue", function()
		local ranking = IssueRanker.rank({
			{ type = "energy_stall", startedAt = 10, endedAt = 50, duration = 40, confidence = "confirmed" },
			{ type = "factory_idle", startedAt = 100, endedAt = 120, duration = 20, confidence = "confirmed" },
		}, 30)

		assert.are.equal("energy_stall", ranking.primaryIssue.type)
		assert.are.equal(2, #ranking.supportingEpisodes)
	end)

	it("selects one training task for the primary issue", function()
		local task = TrainingTaskSelector.select({ type = "factory_idle" }, context)

		assert.are.equal("string", type(task))
		assert(task:find("15") ~= nil)
	end)

	it("does not turn unknown API state into an issue", function()
		local session = newSession()
		session:record(Fixtures.observation(0, {
			energy = false,
			factories = Fixtures.factory(false, false),
			expansionMex = false,
		}))
		session:record(Fixtures.observation(20, {
			energy = false,
			factories = Fixtures.factory(false, false),
			expansionMex = false,
		}))
		local report = session:finish("Player")

		assert.is_nil(report.primaryIssue)
		assert(report.limitations[4]:find("API") ~= nil)
	end)

	it("builds a presentation with one issue and one next task", function()
		local session = newSession()
		session:record(Fixtures.observation(0, { factories = Fixtures.factory(false) }))
		session:record(Fixtures.observation(20, { factories = Fixtures.factory(false) }))
		local report = session:finish("Player")
		local lines = ReplayReportPresentation.lines(report)
		local text = table.concat(lines, "\n")

		assert(text:find("Главная проблема") ~= nil)
		assert(text:find("Следующая тренировка") ~= nil)
		assert(text:find("Player") ~= nil)
	end)
end)
