local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Learning Coach Tests",
		desc = "Runs BAR Learning Coach domain specs in the Recoil Lua runtime",
		author = "Dmitry / Codex",
		date = "2026-07-21",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local SPEC_ROOT = "LuaUI/Include/bar_learning_coach/tests/"

local function echo(message)
	Spring.Echo("[BAR Learning Coach Tests] " .. message)
end

local function createHarness()
	local baseAssert = assert
	local failures = 0
	local successes = 0

	local function fail(message)
		error(message, 3)
	end

	local testAssert = setmetatable({
		are = {
			equal = function(expected, actual)
				if expected ~= actual then
					fail("expected " .. tostring(expected) .. ", got " .. tostring(actual))
				end
			end,
		},
		is_nil = function(value)
			if value ~= nil then
				fail("expected nil, got " .. tostring(value))
			end
		end,
		is_false = function(value)
			if value ~= false then
				fail("expected false, got " .. tostring(value))
			end
		end,
	}, {
		__call = function(_, ...)
			return baseAssert(...)
		end,
	})

	local environment = {
		assert = testAssert,
		describe = function(name, fn)
			echo(name)
			fn()
		end,
		it = function(name, fn)
			local ok, detail = pcall(fn)
			if ok then
				successes = successes + 1
				echo("ok - " .. name)
			else
				failures = failures + 1
				echo("not ok - " .. name .. ": " .. tostring(detail))
			end
		end,
	}
	setmetatable(environment, { __index = getfenv() })

	return {
		run = function(path)
			local ok, detail = pcall(VFS.Include, path, environment)
			if not ok then
				failures = failures + 1
				echo("spec load failed - " .. path .. ": " .. tostring(detail))
			end
		end,
		result = function()
			return successes, failures
		end,
	}
end

function widget:Initialize()
	local harness = createHarness()
	harness.run(SPEC_ROOT .. "history_buffer_spec.lua")
	harness.run(SPEC_ROOT .. "energy_stall_spec.lua")
	harness.run(SPEC_ROOT .. "energy_stall_recommendation_spec.lua")
	harness.run(SPEC_ROOT .. "build_power_adapter_spec.lua")
	harness.run(SPEC_ROOT .. "build_power_snapshot_spec.lua")

	local successes, failures = harness.result()
	echo(string.format("%d successes / %d failures", successes, failures))
	if failures > 0 then
		error("BAR Learning Coach domain specs failed")
	end
end
