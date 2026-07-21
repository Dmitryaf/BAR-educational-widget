local SnapshotCollector = {}
SnapshotCollector.__index = SnapshotCollector

local function numberOrNil(value)
	if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
		return value
	end
	return nil
end

local function normalize(rawSnapshot)
	local rawEnergy = type(rawSnapshot) == "table"
		and type(rawSnapshot.resources) == "table"
		and type(rawSnapshot.resources.energy) == "table"
		and rawSnapshot.resources.energy
		or {}

	return {
		gameTime = numberOrNil(rawSnapshot and rawSnapshot.gameTime),
		energy = {
			current = numberOrNil(rawEnergy.current),
			storage = numberOrNil(rawEnergy.storage),
			pull = numberOrNil(rawEnergy.pull),
			income = numberOrNil(rawEnergy.income),
			expense = numberOrNil(rawEnergy.expense),
		},
	}
end

function SnapshotCollector.new(history, detector)
	assert(type(history) == "table" and type(history.push) == "function", "history buffer is required")
	assert(type(detector) == "table" and type(detector.evaluate) == "function", "detector is required")

	return setmetatable({
		history = history,
		detector = detector,
		lastSnapshot = nil,
		lastResult = nil,
	}, SnapshotCollector)
end

function SnapshotCollector:record(rawSnapshot)
	local normalized = normalize(rawSnapshot)
	self.history:push(normalized)
	self.lastSnapshot = normalized
	self.lastResult = self.detector:evaluate(normalized, self.history)
	return self.lastResult
end

function SnapshotCollector:reset()
	self.history:clear()
	self.detector:resetLifecycle(true)
	self.lastSnapshot = nil
	self.lastResult = nil
end

return SnapshotCollector
