local loadModule = VFS and VFS.Include or dofile
local Recommendation = loadModule("LuaUI/Include/bar_learning_coach/energy_stall_recommendation.lua")

describe("ENERGY_STALL recommendation", function()
	it("returns no card without a diagnostic", function()
		assert.is_nil(Recommendation.fromDiagnostic(nil))
	end)

	it("returns a card only while the diagnostic is active", function()
		local hiddenStates = { "unknown", "inactive", "candidate", "resolving", "resolved", "cooldown" }
		for i = 1, #hiddenStates do
			assert.is_nil(Recommendation.fromDiagnostic({ state = hiddenStates[i] }))
		end

		local card = Recommendation.fromDiagnostic({ state = "active", episodeDuration = 18 })
		assert.are.equal("energy_stall", card.id)
	end)

	it("describes the observed duration without asking a question", function()
		local card = Recommendation.fromDiagnostic({ state = "active", episodeDuration = 15.6 })

		assert.are.equal("Потребность в энергии выше дохода уже 16 сек.", card.fact)
		assert.is_nil(card.question)
	end)

	it("provides one explanation and no more than three possible actions", function()
		local card = Recommendation.fromDiagnostic({ state = "active", episodeDuration = 20 })

		assert.are.equal("Текущей генерации не хватает для выбранной нагрузки.", card.explanation)
		assert.are.equal(3, #card.possibleActions)
		assert.are.equal("Добавь доступную генерацию энергии", card.possibleActions[1])
		assert.are.equal("Временно уменьши строительную нагрузку", card.possibleActions[2])
		assert.are.equal("Приостанови менее важное производство", card.possibleActions[3])
	end)
end)
