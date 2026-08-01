local CoachPresentation = {}

local function findMilestone(context, milestoneId)
	if type(context) ~= "table" or type(context.milestones) ~= "table" then
		return nil
	end
	for i = 1, #context.milestones do
		local milestone = context.milestones[i]
		if type(milestone) == "table" and milestone.id == milestoneId then
			return milestone
		end
	end
	return nil
end

local function copyActions(actions)
	if type(actions) ~= "table" then
		return nil
	end
	local result = {}
	for i = 1, #actions do
		if type(actions[i]) == "string" and actions[i] ~= "" then
			result[#result + 1] = actions[i]
		end
	end
	return #result > 0 and result or nil
end

local function unsupportedCard(context)
	local mapName = type(context) == "table" and context.mapName or "Ravaged Remake v1.2"
	local faction = type(context) == "table" and context.faction or "Cortex"
	return {
		kind = "unsupported_setup",
		title = "Этот lesson здесь недоступен",
		detail = "Поддерживается " .. mapName .. " за " .. faction .. ".",
	}
end

local function unavailableCard()
	return {
		kind = "temporarily_unavailable",
		title = "Подсказка временно недоступна",
		detail = "Не удалось подтвердить данные текущего lesson. Продолжай матч самостоятельно.",
	}
end

function CoachPresentation.build(context, observation, progress, recoveryRecommendation)
	if type(progress) ~= "table" or type(progress.presentation) ~= "string" then
		return { kind = "none" }
	end

	local presentation = progress.presentation
	if presentation == "unsupported_setup" then
		return unsupportedCard(context)
	end
	if presentation == "temporarily_unavailable" then
		return unavailableCard()
	end
	if presentation == "lesson_complete" then
		return {
			kind = "lesson_complete",
			title = "Opening завершён",
			detail = "Базовый T1-цикл запущен. Продолжай матч самостоятельно.",
		}
	end

	if type(observation) ~= "table"
		or observation.contextStatus ~= "supported"
		or type(context) ~= "table"
		or observation.contextId ~= context.id
	then
		return unavailableCard()
	end

	if presentation == "recovery" then
		if type(recoveryRecommendation) ~= "table" then
			return unavailableCard()
		end
		return {
			kind = "recovery",
			title = recoveryRecommendation.title,
			action = recoveryRecommendation.fact,
			detail = recoveryRecommendation.explanation,
			possibleActions = copyActions(recoveryRecommendation.possibleActions),
		}
	end

	if presentation == "milestone" then
		local milestone = findMilestone(context, progress.nextMilestoneId)
		if type(milestone) ~= "table"
			or type(milestone.title) ~= "string"
			or type(milestone.action) ~= "string"
			or type(milestone.doneWhen) ~= "string"
		then
			return unavailableCard()
		end
		return {
			kind = "milestone",
			title = milestone.title,
			action = milestone.action,
			doneWhen = milestone.doneWhen,
		}
	end

	return { kind = "none" }
end

return CoachPresentation
