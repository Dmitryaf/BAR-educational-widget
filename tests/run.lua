local baseAssert = assert
local failures = 0
local successes = 0

local function fail(message)
	error(message, 3)
end

assert = setmetatable({
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

function describe(name, fn)
	print(name)
	fn()
end

function it(name, fn)
	local ok, detail = pcall(fn)
	if ok then
		successes = successes + 1
		print("  ok - " .. name)
	else
		failures = failures + 1
		print("  not ok - " .. name)
		print("    " .. tostring(detail))
	end
end

dofile("tests/history_buffer_spec.lua")
dofile("tests/energy_stall_spec.lua")
dofile("tests/energy_stall_recommendation_spec.lua")

print(string.format("%d successes / %d failures", successes, failures))
if failures > 0 then
	os.exit(1)
end
