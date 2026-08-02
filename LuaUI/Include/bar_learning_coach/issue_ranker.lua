local IssueRanker = {}

local TYPE_PRIORITY = {
	energy_stall = 1,
	factory_idle = 2,
	late_expansion = 3,
}

local SUMMARIES = {
	energy_stall = "Продолжительный подтверждённый дефицит энергии.",
	factory_idle = "Продолжительная потеря производственного времени первой Bot Lab.",
	late_expansion = "Первое расширение произошло позднее контрольного окна этого lesson.",
}

local function relatedFactoryIdle(episode, episodes, relationWindow)
	if episode.type ~= "factory_idle" then
		return false
	end
	for i = 1, #episodes do
		local candidate = episodes[i]
		if candidate.type == "energy_stall"
			and episode.endedAt >= candidate.endedAt
			and episode.startedAt <= candidate.endedAt + relationWindow
			and episode.startedAt >= candidate.startedAt
		then
			return true
		end
	end
	return false
end

function IssueRanker.rank(episodes, relationWindow)
	if type(episodes) ~= "table" or #episodes == 0 then
		return {
			primaryIssue = nil,
			supportingEpisodes = {},
			reason = "no confirmed episodes",
		}
	end

	local groups = {}
	for i = 1, #episodes do
		local episode = episodes[i]
		if episode.confidence == "confirmed" and TYPE_PRIORITY[episode.type] then
			local group = groups[episode.type] or {
				type = episode.type,
				count = 0,
				totalDuration = 0,
				earliestAt = episode.startedAt,
				related = false,
			}
			group.count = group.count + 1
			group.totalDuration = group.totalDuration + (episode.duration or 0)
			group.earliestAt = math.min(group.earliestAt, episode.startedAt)
			group.related = group.related or relatedFactoryIdle(episode, episodes, relationWindow or 0)
			groups[episode.type] = group
		end
	end

	local ranked = {}
	for _, group in pairs(groups) do
		ranked[#ranked + 1] = group
	end
	if #ranked == 0 then
		return {
			primaryIssue = nil,
			supportingEpisodes = {},
			reason = "no rankable confirmed episodes",
		}
	end
	table.sort(ranked, function(a, b)
		if a.related ~= b.related then
			return a.related
		end
		if a.totalDuration ~= b.totalDuration then
			return a.totalDuration > b.totalDuration
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		if a.earliestAt ~= b.earliestAt then
			return a.earliestAt < b.earliestAt
		end
		return TYPE_PRIORITY[a.type] < TYPE_PRIORITY[b.type]
	end)

	local winner = ranked[1]
	local supporting = {}
	local sortedEpisodes = {}
	for i = 1, #episodes do
		sortedEpisodes[i] = episodes[i]
	end
	table.sort(sortedEpisodes, function(a, b)
		if a.type == winner.type and b.type ~= winner.type then
			return true
		end
		if b.type == winner.type and a.type ~= winner.type then
			return false
		end
		if a.duration ~= b.duration then
			return a.duration > b.duration
		end
		return a.startedAt < b.startedAt
	end)
	for i = 1, math.min(3, #sortedEpisodes) do
		supporting[i] = sortedEpisodes[i]
	end

	return {
		primaryIssue = {
			type = winner.type,
			confidence = "confirmed",
			summary = SUMMARIES[winner.type],
			episodeCount = winner.count,
			totalDuration = winner.totalDuration,
			relatedConsequence = winner.related,
		},
		supportingEpisodes = supporting,
	}
end

return IssueRanker
