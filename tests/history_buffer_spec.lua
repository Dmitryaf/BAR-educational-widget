local loadModule = VFS and VFS.Include or dofile
local HistoryBuffer = loadModule("LuaUI/Include/bar_learning_coach/history_buffer.lua")

describe("HistoryBuffer", function()
	it("keeps a fixed number of newest values", function()
		local history = HistoryBuffer.new(3)
		history:push("one")
		history:push("two")
		history:push("three")
		history:push("four")

		assert.are.equal(3, history:size())
		assert.are.equal("two", history:get(1))
		assert.are.equal("four", history:latest())
	end)

	it("can be cleared", function()
		local history = HistoryBuffer.new(2)
		history:push("value")
		history:clear()

		assert.are.equal(0, history:size())
		assert.is_nil(history:latest())
	end)
end)
