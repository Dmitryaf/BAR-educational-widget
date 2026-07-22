local loadModule = VFS and VFS.Include or dofile
local OpeningContext = loadModule("LuaUI/Include/bar_learning_coach/opening_context.lua")

describe("opening context", function()
	it("provides one valid default context", function()
		local context = OpeningContext.get()
		local valid, reason = OpeningContext.validate(context)

		assert.are.equal(true, valid)
		assert.is_nil(reason)
		assert.are.equal("cortex_bot_ravaged_1v1_practice", context.id)
		assert.are.equal("Ravaged Remake v1.2", context.mapName)
		assert.are.equal("corlab", context.factoryUnitDefName)
	end)

	it("returns nil for an unsupported context", function()
		assert.is_nil(OpeningContext.get("another_opening"))
	end)

	it("returns an independent copy", function()
		local first = OpeningContext.get()
		first.thresholds.baseMex = 99
		first.unitDefNames.combatBots[1] = "changed"

		local second = OpeningContext.get()
		assert.are.equal(2, second.thresholds.baseMex)
		assert.are.equal("corak", second.unitDefNames.combatBots[1])
	end)

	it("rejects an invalid threshold", function()
		local context = OpeningContext.get()
		context.thresholds.initialCombatBots = 0

		local valid, reason = OpeningContext.validate(context)
		assert.are.equal(false, valid)
		assert.are.equal("context threshold initialCombatBots invalid", reason)
	end)

	it("rejects a missing unit group", function()
		local context = OpeningContext.get()
		context.unitDefNames.combatBots = {}

		local valid, reason = OpeningContext.validate(context)
		assert.are.equal(false, valid)
		assert.are.equal("context unitDefNames combatBots invalid", reason)
	end)

	it("keeps the stable context id explicit", function()
		assert.are.equal("cortex_bot_ravaged_1v1_practice", OpeningContext.defaultId())
	end)
end)
