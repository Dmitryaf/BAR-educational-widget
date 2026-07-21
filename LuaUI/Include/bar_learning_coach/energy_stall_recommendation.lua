local EnergyStallRecommendation = {}

local CONTENT = {
	id = "energy_stall",
	title = "Энергии не хватает",
	explanation = "Текущей генерации не хватает для выбранной нагрузки.",
	possibleActions = {
		"Добавь доступную генерацию энергии",
		"Временно уменьши строительную нагрузку",
		"Приостанови менее важное производство",
	},
}

local function roundedSeconds(value)
	if type(value) ~= "number" or value ~= value or value < 0 then
		return nil
	end

	return math.floor(value + 0.5)
end

function EnergyStallRecommendation.fromDiagnostic(diagnostic)
	if type(diagnostic) ~= "table" or diagnostic.state ~= "active" then
		return nil
	end

	local seconds = roundedSeconds(diagnostic.episodeDuration)
	local fact = seconds
		and "Потребность в энергии выше дохода уже " .. tostring(seconds) .. " сек."
		or "Потребность в энергии устойчиво выше дохода."

	return {
		id = CONTENT.id,
		title = CONTENT.title,
		fact = fact,
		explanation = CONTENT.explanation,
		possibleActions = {
			CONTENT.possibleActions[1],
			CONTENT.possibleActions[2],
			CONTENT.possibleActions[3],
		},
	}
end

return EnergyStallRecommendation
