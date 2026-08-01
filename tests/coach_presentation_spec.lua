local loadModule = VFS and VFS.Include or dofile
local CoachPresentation = loadModule("LuaUI/Include/bar_learning_coach/coach_presentation.lua")
local OpeningContext = loadModule("LuaUI/Include/bar_learning_coach/opening_context.lua")

local context = OpeningContext.get()

local function observation(status)
	return {
		contextId = status == "supported" and context.id or nil,
		contextStatus = status,
	}
end

local function progress(presentation, milestoneId, lessonState)
	return {
		presentation = presentation,
		nextMilestoneId = milestoneId,
		lessonState = lessonState or "in_progress",
	}
end

local recovery = {
	title = "Энергии не хватает",
	fact = "Потребность в энергии устойчиво выше дохода.",
	explanation = "Текущей генерации не хватает для выбранной нагрузки.",
	possibleActions = { "Добавь доступную генерацию энергии" },
}

describe("coach presentation", function()
	it("returns the first milestone for a supported context", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("milestone", "base_income")
		)
		assert.are.equal("milestone", card.kind)
		assert.are.equal("Базовый доход", card.title)
	end)

	it("changes to the next milestone after completion", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("milestone", "bot_lab")
		)
		assert.are.equal("Bot Lab", card.title)
	end)

	it("returns recovery only for a recovery decision", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("recovery", "base_income"),
			recovery
		)
		assert.are.equal("recovery", card.kind)
		assert.are.equal(recovery.fact, card.action)
	end)

	it("does not show recovery for an unsupported context", function()
		local card = CoachPresentation.build(
			context,
			observation("unsupported"),
			progress("unsupported_setup", nil, "unsupported"),
			recovery
		)
		assert.are.equal("unsupported_setup", card.kind)
		assert.is_nil(card.possibleActions)
	end)

	it("does not show recovery after lesson completion", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("lesson_complete", nil, "complete"),
			recovery
		)
		assert.are.equal("lesson_complete", card.kind)
	end)

	it("describes an unsupported map or faction without gameplay advice", function()
		local card = CoachPresentation.build(
			context,
			observation("unsupported"),
			progress("unsupported_setup", nil, "unsupported")
		)
		assert.are.equal("unsupported_setup", card.kind)
		assert.is_nil(card.action)
	end)

	it("keeps missing evidence temporarily unavailable", function()
		local card = CoachPresentation.build(
			context,
			observation("unknown"),
			progress("temporarily_unavailable", nil, "unknown")
		)
		assert.are.equal("temporarily_unavailable", card.kind)
	end)

	it("returns a completion card for a complete lesson", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("lesson_complete", nil, "complete")
		)
		assert.are.equal("Opening завершён", card.title)
	end)

	it("returns exactly one card model", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("milestone", "base_income")
		)
		assert.are.equal("table", type(card))
		assert.is_nil(card.cards)
	end)

	it("includes title, action and completion condition for a milestone", function()
		local card = CoachPresentation.build(
			context,
			observation("supported"),
			progress("milestone", "base_income")
		)
		assert.are.equal("string", type(card.title))
		assert.are.equal("string", type(card.action))
		assert.are.equal("string", type(card.doneWhen))
	end)
end)
