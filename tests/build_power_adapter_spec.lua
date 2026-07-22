local loadModule = VFS and VFS.Include or dofile
local Adapter = loadModule("LuaUI/Include/bar_learning_coach/build_power_adapter.lua")

describe("BuildPowerAdapter", function()
	it("reads only own team units and preserves an idle worker task", function()
		local requestedTeamID = nil
		local spring = {
			GetTeamUnits = function(teamID)
				requestedTeamID = teamID
				return { 10, 20 }
			end,
			GetUnitDefID = function(unitID)
				return unitID == 10 and 1 or 2
			end,
			GetUnitIsStunned = function()
				return false, false, false
			end,
			GetUnitWorkerTask = function(unitID)
				if unitID == 10 then
					return -3, 50
				end
				return nil
			end,
			GetUnitCurrentBuildPower = function(unitID)
				return unitID == 10 and 0.75 or 0
			end,
		}
		local unitDefs = {
			[1] = { isBuilder = true, isFactory = false, buildSpeed = 100 },
			[2] = { isBuilder = false, isFactory = false, buildSpeed = 0 },
		}

		local raw = Adapter.new(spring, unitDefs):collect(7)

		assert.are.equal(7, requestedTeamID)
		assert.are.equal(true, raw.unitListKnown)
		assert.are.equal(2, #raw.units)
		assert.are.equal(-3, raw.units[1].taskCommandID)
		assert.are.equal(0.75, raw.units[1].nanoActivity)
		assert.are.equal(true, raw.units[2].taskKnown)
		assert.is_nil(raw.units[2].taskCommandID)
	end)

	it("marks the unit list unknown when the API is missing", function()
		local raw = Adapter.new({}, {}):collect(7)

		assert.are.equal(false, raw.unitListKnown)
		assert.are.equal("team unit list unavailable", raw.reason)
	end)

	it("preserves a failed per-unit lookup as unknown", function()
		local spring = {
			GetTeamUnits = function() return { 10 } end,
			GetUnitDefID = function() error("not visible") end,
		}

		local raw = Adapter.new(spring, {}):collect(7)

		assert.are.equal(false, raw.units[1].definitionKnown)
	end)
end)
