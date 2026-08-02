local ReplayReportPresentation = {}

local EPISODE_LABELS = {
	energy_stall = "Подтверждённый дефицит энергии",
	factory_idle = "Простой первой Bot Lab",
	late_expansion = "Позднее первое расширение",
}

local function formatTime(seconds)
	if type(seconds) ~= "number" then
		return "unknown"
	end
	local rounded = math.max(0, math.floor(seconds + 0.5))
	return string.format("%02d:%02d", math.floor(rounded / 60), rounded % 60)
end

function ReplayReportPresentation.lines(report)
	if type(report) ~= "table" then
		return { "BAR Replay Coach", "Отчёт недоступен." }
	end
	local lines = {
		"BAR Replay Coach",
		"Игрок: " .. tostring(report.playerName or "Unknown team"),
		"Карта: " .. tostring(report.mapName or "unknown"),
		"Фракция: " .. tostring(report.faction or "unknown"),
		"",
		"Главная проблема",
		tostring(report.summary or "Недостаточно данных."),
	}

	if type(report.supportingEpisodes) == "table" and #report.supportingEpisodes > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Ключевые эпизоды"
		for i = 1, math.min(3, #report.supportingEpisodes) do
			local episode = report.supportingEpisodes[i]
			lines[#lines + 1] = formatTime(episode.startedAt)
				.. "–" .. formatTime(episode.endedAt)
				.. " — " .. tostring(EPISODE_LABELS[episode.type] or episode.type)
				.. ", " .. tostring(math.floor((episode.duration or 0) + 0.5)) .. " сек."
		end
	end

	if type(report.explanation) == "string" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Что это означает"
		lines[#lines + 1] = report.explanation
	end
	if type(report.trainingTask) == "string" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Следующая тренировка"
		lines[#lines + 1] = report.trainingTask
	end
	if type(report.limitations) == "table" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Ограничения"
		for i = 1, #report.limitations do
			lines[#lines + 1] = "— " .. report.limitations[i]
		end
	end
	return lines
end

return ReplayReportPresentation
