local HistoryBuffer = {}
HistoryBuffer.__index = HistoryBuffer

function HistoryBuffer.new(capacity)
	assert(type(capacity) == "number" and capacity >= 1, "history capacity must be a positive number")

	return setmetatable({
		capacity = math.floor(capacity),
		items = {},
		start = 1,
		count = 0,
	}, HistoryBuffer)
end

function HistoryBuffer:push(value)
	local index
	if self.count < self.capacity then
		index = ((self.start + self.count - 1) % self.capacity) + 1
		self.count = self.count + 1
	else
		index = self.start
		self.start = (self.start % self.capacity) + 1
	end

	self.items[index] = value
end

function HistoryBuffer:size()
	return self.count
end

function HistoryBuffer:get(offset)
	if type(offset) ~= "number" or offset < 1 or offset > self.count then
		return nil
	end

	local index = ((self.start + offset - 2) % self.capacity) + 1
	return self.items[index]
end

function HistoryBuffer:latest()
	return self:get(self.count)
end

function HistoryBuffer:clear()
	self.items = {}
	self.start = 1
	self.count = 0
end

return HistoryBuffer
