local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Learning Coach Debug",
		desc = "Shows resource snapshot data for the BAR Learning Coach technical spike",
		author = "Dmitry / Codex",
		date = "2026-07-18",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = false,
	}
end

local UPDATE_INTERVAL = 0.5
local DEFAULT_X = 0.66
local DEFAULT_Y = 0.70
local DEFAULT_SCALE = 1.0
local CONFIG_VERSION = 1

local panel = {
	x = DEFAULT_X,
	y = DEFAULT_Y,
	scale = DEFAULT_SCALE,
}

local api = {}
local apiStatus = {}
local loggedErrors = {}
local snapshot = {
	gameFrame = nil,
	gameTime = nil,
	lastSnapshotTime = nil,
	lastValidSnapshotTime = nil,
	teamID = nil,
	resources = {
		metal = {},
		energy = {},
	},
}

local updateElapsed = UPDATE_INTERVAL
local initialized = false

local function logFirstError(name, detail)
	if loggedErrors[name] then
		return
	end

	loggedErrors[name] = true
	if Spring and type(Spring.Echo) == "function" then
		Spring.Echo("[BAR Learning Coach Debug] " .. name .. ": " .. tostring(detail))
	end
end

local function statusHasError(status)
	return status.available == false or status.callOk == false or status.dataValid == false
end

local function setStatus(name, fields)
	local status = apiStatus[name] or {}
	if fields.available ~= nil then
		status.available = fields.available == true
	end
	if fields.callOk ~= nil then
		status.callOk = fields.callOk == true
	end
	if fields.dataValid ~= nil then
		status.dataValid = fields.dataValid == true
	end
	if fields.detail ~= nil then
		status.detail = fields.detail
	end

	apiStatus[name] = status

	if statusHasError(status) then
		logFirstError(name, status.detail or "unknown")
	end
end

local function setAvailability(name, available, detail)
	setStatus(name, {
		available = available,
		detail = detail,
	})
end

local function setDataStatus(name, valid, detail)
	setStatus(name, {
		dataValid = valid,
		detail = detail,
	})
end

local function safeCall(name, fn, ...)
	if type(fn) ~= "function" then
		setStatus(name, {
			available = false,
			callOk = false,
			dataValid = false,
			detail = "api missing",
		})
		return nil
	end

	local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
	if not ok then
		setStatus(name, {
			available = true,
			callOk = false,
			dataValid = false,
			detail = tostring(a),
		})
		return nil
	end

	setStatus(name, {
		available = true,
		callOk = true,
		detail = "ok",
	})
	return a, b, c, d, e, f, g, h, i
end

local function fmtNumber(value)
	if type(value) ~= "number" then
		return "unknown"
	end

	return string.format("%.1f", value)
end

local function fmtInteger(value)
	if type(value) ~= "number" then
		return "unknown"
	end

	return tostring(math.floor(value + 0.5))
end

local function fmtTime(seconds)
	if type(seconds) ~= "number" then
		return "unknown"
	end

	local total = math.max(0, math.floor(seconds + 0.5))
	local minutes = math.floor(total / 60)
	local rest = total - minutes * 60
	return string.format("%02d:%02d", minutes, rest)
end

local function fmtAge(seconds)
	if type(seconds) ~= "number" then
		return "unknown"
	end

	return string.format("%.1fs", math.max(0, seconds))
end

local function detectApi()
	api.getGameFrame = Spring and Spring.GetGameFrame
	api.getGameSeconds = Spring and Spring.GetGameSeconds
	api.getTeamResources = Spring and Spring.GetTeamResources
	api.getViewGeometry = Spring and Spring.GetViewGeometry

	if Spring and type(Spring.GetMyTeamID) == "function" then
		api.getTeamID = Spring.GetMyTeamID
		api.teamIDName = "GetMyTeamID"
	elseif Spring and type(Spring.GetLocalTeamID) == "function" then
		api.getTeamID = Spring.GetLocalTeamID
		api.teamIDName = "GetLocalTeamID"
	else
		api.getTeamID = nil
		api.teamIDName = "missing"
	end

	setAvailability("GetGameFrame", type(api.getGameFrame) == "function", type(api.getGameFrame) == "function" and "ok" or "missing")
	setAvailability("GetGameSeconds", type(api.getGameSeconds) == "function", type(api.getGameSeconds) == "function" and "ok" or "missing")
	setAvailability("GetTeamResources", type(api.getTeamResources) == "function", type(api.getTeamResources) == "function" and "ok" or "missing")
	setAvailability("GetViewGeometry", type(api.getViewGeometry) == "function", type(api.getViewGeometry) == "function" and "ok" or "missing")
	setAvailability("TeamID", type(api.getTeamID) == "function", api.teamIDName)
	setAvailability("GameTimeFallback", true, "available")
end

local function isResourceDataValid(data)
	return type(data.current) == "number"
		and type(data.storage) == "number"
		and type(data.pull) == "number"
		and type(data.income) == "number"
		and type(data.expense) == "number"
end

local function readResource(resourceName)
	local statusName = "GetTeamResources:" .. resourceName
	local current, storage, pull, income, expense, share, sent, received, excess =
		safeCall(statusName, api.getTeamResources, snapshot.teamID, resourceName)

	if current == nil then
		setDataStatus(statusName, false, "no current value")
		return {
			current = nil,
			storage = nil,
			pull = nil,
			income = nil,
			expense = nil,
			share = nil,
			sent = nil,
			received = nil,
			excess = nil,
		}
	end

	local data = {
		current = current,
		storage = storage,
		pull = pull,
		income = income,
		expense = expense,
		share = share,
		sent = sent,
		received = received,
		excess = excess,
	}

	setDataStatus(statusName, isResourceDataValid(data), isResourceDataValid(data) and "resource values ok" or "resource values invalid")
	return data
end

local function collectSnapshot()
	local teamID = safeCall("TeamID", api.getTeamID)
	snapshot.teamID = type(teamID) == "number" and teamID or nil
	setDataStatus("TeamID", snapshot.teamID ~= nil, snapshot.teamID ~= nil and "team id ok" or "team id invalid")

	local frame = safeCall("GetGameFrame", api.getGameFrame)
	snapshot.gameFrame = type(frame) == "number" and frame or nil
	setDataStatus("GetGameFrame", snapshot.gameFrame ~= nil, snapshot.gameFrame ~= nil and "frame ok" or "frame invalid")

	local seconds = safeCall("GetGameSeconds", api.getGameSeconds)
	setDataStatus("GetGameSeconds", type(seconds) == "number", type(seconds) == "number" and "seconds ok" or "seconds invalid")
	if type(seconds) ~= "number" and type(snapshot.gameFrame) == "number" then
		seconds = snapshot.gameFrame / 30
		setStatus("GameTimeFallback", {
			callOk = true,
			dataValid = true,
			detail = "frame/30",
		})
	elseif type(seconds) == "number" then
		setStatus("GameTimeFallback", {
			callOk = true,
			dataValid = true,
			detail = "not used",
		})
	else
		setStatus("GameTimeFallback", {
			callOk = true,
			dataValid = false,
			detail = "frame unavailable",
		})
	end
	snapshot.gameTime = type(seconds) == "number" and seconds or nil
	snapshot.lastSnapshotTime = snapshot.gameTime

	if snapshot.teamID == nil then
		snapshot.resources.metal = {}
		snapshot.resources.energy = {}
		return
	end

	snapshot.resources.metal = readResource("metal")
	snapshot.resources.energy = readResource("energy")
	if snapshot.gameTime ~= nil
		and isResourceDataValid(snapshot.resources.metal)
		and isResourceDataValid(snapshot.resources.energy)
	then
		snapshot.lastValidSnapshotTime = snapshot.gameTime
	end
end

local function append(lines, label, value)
	lines[#lines + 1] = label .. ": " .. value
end

local function resourceLine(name, data)
	local current = fmtNumber(data.current)
	local storage = fmtNumber(data.storage)
	return name .. ": " .. current .. " / " .. storage
end

local function resourceFlowLine(name, data)
	return name .. " income / expense / pull: "
		.. fmtNumber(data.income) .. " / "
		.. fmtNumber(data.expense) .. " / "
		.. fmtNumber(data.pull)
end

local function fmtFlag(value, okLabel, badLabel)
	if value == nil then
		return "-"
	end

	return value and okLabel or badLabel
end

local function statusLine(name)
	local status = apiStatus[name]
	if not status then
		return "  " .. name .. ": available=- succeeded=- valid=-"
	end

	return "  " .. name
		.. ": available=" .. fmtFlag(status.available, "yes", "no")
		.. " succeeded=" .. fmtFlag(status.callOk, "yes", "no")
		.. " valid=" .. fmtFlag(status.dataValid, "yes", "no")
		.. " (" .. tostring(status.detail or "-") .. ")"
end

local function validSnapshotAge()
	if type(snapshot.gameTime) ~= "number" or type(snapshot.lastValidSnapshotTime) ~= "number" then
		return nil
	end

	return snapshot.gameTime - snapshot.lastValidSnapshotTime
end

local function buildLines()
	local lines = {}
	append(lines, "BAR Learning Coach", "debug")
	append(lines, "Game time", fmtTime(snapshot.gameTime))
	append(lines, "Game frame", fmtInteger(snapshot.gameFrame))
	append(lines, "Team API", api.teamIDName or "unknown")
	append(lines, "Team ID", fmtInteger(snapshot.teamID))
	lines[#lines + 1] = resourceLine("Metal", snapshot.resources.metal)
	lines[#lines + 1] = resourceFlowLine("Metal", snapshot.resources.metal)
	lines[#lines + 1] = resourceLine("Energy", snapshot.resources.energy)
	lines[#lines + 1] = resourceFlowLine("Energy", snapshot.resources.energy)
	append(lines, "Last snapshot", fmtTime(snapshot.lastSnapshotTime))
	append(lines, "Valid snapshot age", fmtAge(validSnapshotAge()))
	append(lines, "Status", "available / succeeded / valid")

	local names = {
		"TeamID",
		"GetGameFrame",
		"GetGameSeconds",
		"GetTeamResources",
		"GetTeamResources:metal",
		"GetTeamResources:energy",
		"GetViewGeometry",
		"GameTimeFallback",
	}

	for i = 1, #names do
		lines[#lines + 1] = statusLine(names[i])
	end

	return lines
end

local function getViewGeometry()
	local vsx, vsy = safeCall("GetViewGeometry", api.getViewGeometry)
	local valid = type(vsx) == "number" and type(vsy) == "number"
	setDataStatus("GetViewGeometry", valid, valid and "viewport ok" or "viewport invalid")
	if not valid then
		return 1920, 1080
	end

	return vsx, vsy
end

local function drawPanel()
	if not initialized then
		return
	end

	local glColor = gl and gl.Color
	local glRect = gl and gl.Rect
	local glText = gl and gl.Text
	if type(glColor) ~= "function" or type(glRect) ~= "function" or type(glText) ~= "function" then
		return
	end

	local vsx, vsy = getViewGeometry()
	local scale = panel.scale or DEFAULT_SCALE
	local width = 520 * scale
	local lineHeight = 16 * scale
	local padding = 10 * scale
	local lines = buildLines()
	local height = (#lines * lineHeight) + padding * 2
	local x1 = math.max(0, math.min(vsx - width, panel.x * vsx))
	local y1 = math.max(0, math.min(vsy - height, panel.y * vsy))
	local x2 = x1 + width
	local y2 = y1 + height

	glColor(0.04, 0.05, 0.06, 0.82)
	glRect(x1, y1, x2, y2)
	glColor(0.20, 0.24, 0.28, 0.95)
	glRect(x1, y2 - 2 * scale, x2, y2)

	for i = 1, #lines do
		local y = y2 - padding - i * lineHeight
		if i == 1 then
			glColor(0.86, 0.94, 1.00, 1.0)
		elseif string.sub(lines[i], 1, 2) == "  " then
			glColor(0.70, 0.75, 0.80, 0.95)
		else
			glColor(0.96, 0.96, 0.92, 1.0)
		end
		glText(lines[i], x1 + padding, y, 12 * scale, "o")
	end

	glColor(1, 1, 1, 1)
end

function widget:Initialize()
	detectApi()
	initialized = true
	collectSnapshot()
end

function widget:Shutdown()
	initialized = false
	api = {}
	apiStatus = {}
	loggedErrors = {}
end

function widget:Update(dt)
	updateElapsed = updateElapsed + (dt or 0)
	if updateElapsed < UPDATE_INTERVAL then
		return
	end

	updateElapsed = 0
	collectSnapshot()
end

function widget:DrawScreen()
	drawPanel()
end

function widget:GetConfigData()
	return {
		version = CONFIG_VERSION,
		panel = {
			x = panel.x,
			y = panel.y,
			scale = panel.scale,
		},
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" or type(data.panel) ~= "table" then
		return
	end

	if type(data.panel.x) == "number" then
		panel.x = math.max(0, math.min(1, data.panel.x))
	end

	if type(data.panel.y) == "number" then
		panel.y = math.max(0, math.min(1, data.panel.y))
	end

	if type(data.panel.scale) == "number" then
		panel.scale = math.max(0.7, math.min(1.6, data.panel.scale))
	end
end
