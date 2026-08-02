local ReplayReport = {}

local EXPLANATIONS = {
	energy_stall = "Данные подтверждают длительный дефицит энергии. Он совпал с потерей темпа, но отчёт не доказывает, что это определило результат матча.",
	factory_idle = "Первая Bot Lab подтверждённо простаивала дольше контрольного порога. Соседние эпизоды могли увеличить потерю темпа, но данные не доказывают прямую причинность.",
	late_expansion = "В рамках текущего тренировочного сценария первое расширение произошло позднее контрольного окна. Этот порог не переносится на другие карты или lessons.",
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

function ReplayReport.build(context, state, ranking, trainingTask, playerName)
	state = type(state) == "table" and state or {}
	ranking = type(ranking) == "table" and ranking or {}
	local supportedSamples = type(state.supportedSamples) == "number" and state.supportedSamples or 0
	local unknownSamples = type(state.unknownSamples) == "number" and state.unknownSamples or 0
	local primaryIssue = ranking.primaryIssue
	local status = "complete"
	local summary = primaryIssue and primaryIssue.summary or "Значимая подтверждённая проблема не выбрана."
	if state.contextStatus == "unsupported" then
		status = "unsupported"
		summary = "Replay не относится к поддерживаемому контексту."
	elseif state.contextStatus ~= "supported" then
		status = "insufficient_data"
		summary = "Недостаточно данных для подтверждения replay context: "
			.. tostring(state.contextReason or "context unavailable") .. "."
	elseif supportedSamples < context.thresholds.minimumSupportedSamples then
		status = "insufficient_data"
		summary = "Недостаточно подтверждённых observations: нужно не менее "
			.. tostring(context.thresholds.minimumSupportedSamples) .. "."
	elseif primaryIssue == nil then
		status = "no_significant_issue"
	end

	local limitations = {
		"Анализ ограничен replay, выбранным team и одним exact context.",
		"Отчёт показывает последовательность наблюдений, а не доказанную причину результата матча.",
		"Контрольные пороги provisional и не являются универсальными таймингами BAR.",
	}
	if unknownSamples > 0 then
		limitations[#limitations + 1] = "Часть snapshots исключена из-за неполных или неизвестных API-данных."
	end

	return {
		kind = "replay_coaching_report",
		status = status,
		playerName = playerName or (state.teamID and ("Team " .. tostring(state.teamID)) or "Unknown team"),
		teamID = state.teamID,
		mapName = context.mapName,
		faction = context.faction,
		primaryIssue = copy(primaryIssue),
		summary = summary,
		supportingEpisodes = copy(ranking.supportingEpisodes or {}),
		explanation = primaryIssue and EXPLANATIONS[primaryIssue.type] or nil,
		trainingTask = primaryIssue and trainingTask or nil,
		limitations = limitations,
		generatedAtGameTime = state.lastGameTime,
	}
end

return ReplayReport
