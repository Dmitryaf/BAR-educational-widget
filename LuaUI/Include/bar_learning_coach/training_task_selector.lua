local TrainingTaskSelector = {}

function TrainingTaskSelector.select(primaryIssue, context)
	if type(primaryIssue) ~= "table"
		or type(context) ~= "table"
		or type(context.thresholds) ~= "table"
	then
		return nil
	end
	if primaryIssue.type == "energy_stall" then
		return "В следующей тренировке не допускай подтверждённый дефицит энергии дольше "
			.. tostring(context.thresholds.energyEpisodeDuration) .. " секунд."
	elseif primaryIssue.type == "factory_idle" then
		return "В следующей тренировке не оставляй первую Bot Lab без производства дольше "
			.. tostring(context.thresholds.factoryIdleDuration) .. " секунд."
	elseif primaryIssue.type == "late_expansion" then
		return "В следующей тренировке начни первое расширение сразу после появления рабочего производства T1."
	end
	return nil
end

return TrainingTaskSelector
