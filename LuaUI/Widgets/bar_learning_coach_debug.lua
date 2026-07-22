local widget = widget

function widget:GetInfo()
	return {
		name = "BAR Learning Coach",
		desc = "Explains sustained economy problems without playing for the user",
		author = "Dmitry / Codex",
		date = "2026-07-18",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = false,
	}
end

local UPDATE_INTERVAL = 0.5
local BUILD_POWER_INTERVAL = 2.0
local OPENING_INTERVAL = 2.0
local HISTORY_CAPACITY = 240
local DEFAULT_X = 0.66
local DEFAULT_Y = 0.70
local DEFAULT_SCALE = 1.0
local CONFIG_VERSION = 2

local MODULE_ROOT = "LuaUI/Include/bar_learning_coach/"
local HistoryBuffer = VFS.Include(MODULE_ROOT .. "history_buffer.lua")
local EnergyStall = VFS.Include(MODULE_ROOT .. "energy_stall.lua")
local EnergyStallRecommendation = VFS.Include(MODULE_ROOT .. "energy_stall_recommendation.lua")
local SnapshotCollector = VFS.Include(MODULE_ROOT .. "snapshot_collector.lua")
local BuildPowerAdapter = VFS.Include(MODULE_ROOT .. "build_power_adapter.lua")
local BuildPowerSnapshot = VFS.Include(MODULE_ROOT .. "build_power_snapshot.lua")
local OpeningContext = VFS.Include(MODULE_ROOT .. "opening_context.lua")
local OpeningAdapter = VFS.Include(MODULE_ROOT .. "opening_adapter.lua")
local OpeningTracker = VFS.Include(MODULE_ROOT .. "opening_tracker.lua")
local OpeningProgress = VFS.Include(MODULE_ROOT .. "opening_progress.lua")

local panel = {
	x = DEFAULT_X,
	y = DEFAULT_Y,
	scale = DEFAULT_SCALE,
}
local debugPanelEnabled = false

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
local history = HistoryBuffer.new(HISTORY_CAPACITY)
local energyStall = EnergyStall.new()
local snapshotCollector = SnapshotCollector.new(history, energyStall)
local buildPowerAdapter = BuildPowerAdapter.new(Spring, UnitDefs)
local openingContext = OpeningContext.get()
local openingAdapter = OpeningAdapter.new(Spring, UnitDefs, Game)
local openingTracker = OpeningTracker.new(openingAdapter, openingContext)
local lastBuildPowerCollectionTime = nil
local lastOpeningCollectionTime = nil
local openingDirty = true
local buildPower = BuildPowerSnapshot.fromRaw(nil)
local openingObservation = nil
local openingProgress = nil
local energyDiagnostic = {
	state = "unknown",
	reason = "no snapshot yet",
}
local activeRecommendation = nil

local function updateRecommendation()
	activeRecommendation = EnergyStallRecommendation.fromDiagnostic(energyDiagnostic)
end

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

local function fmtRatio(value)
	if type(value) ~= "number" then
		return "unknown"
	end

	return string.format("%.1f%%", value * 100)
end

local function fmtSigned(value, suffix)
	if type(value) ~= "number" then
		return "unknown"
	end

	return string.format("%+.1f%s", value, suffix or "")
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

local function collectBuildPower(force)
	if not force
		and type(snapshot.gameTime) == "number"
		and type(lastBuildPowerCollectionTime) == "number"
		and snapshot.gameTime - lastBuildPowerCollectionTime < BUILD_POWER_INTERVAL
	then
		return
	end

	buildPower = BuildPowerSnapshot.fromRaw(buildPowerAdapter:collect(snapshot.teamID))
	lastBuildPowerCollectionTime = snapshot.gameTime
end

local function collectOpening(force)
	if not force
		and not openingDirty
		and type(snapshot.gameTime) == "number"
		and type(lastOpeningCollectionTime) == "number"
		and snapshot.gameTime >= lastOpeningCollectionTime
		and snapshot.gameTime - lastOpeningCollectionTime < OPENING_INTERVAL
	then
		return
	end

	openingObservation = openingTracker:observe(snapshot.teamID, snapshot.gameTime, energyDiagnostic.state)
	openingProgress = OpeningProgress.evaluate(openingContext, openingObservation)
	lastOpeningCollectionTime = snapshot.gameTime
	openingDirty = false
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
		collectBuildPower(true)
		energyDiagnostic = snapshotCollector:record(snapshot)
		updateRecommendation()
		collectOpening(true)
		return
	end

	snapshot.resources.metal = readResource("metal")
	snapshot.resources.energy = readResource("energy")
	collectBuildPower(false)
	if snapshot.gameTime ~= nil
		and isResourceDataValid(snapshot.resources.metal)
		and isResourceDataValid(snapshot.resources.energy)
	then
		snapshot.lastValidSnapshotTime = snapshot.gameTime
	end

	energyDiagnostic = snapshotCollector:record(snapshot)
	updateRecommendation()
	collectOpening(false)
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
	append(lines, "ENERGY_STALL state", tostring(energyDiagnostic.state or "unknown"))
	append(lines, "  storage ratio", fmtRatio(energyDiagnostic.storageRatio))
	append(lines, "  pull - income", fmtSigned(energyDiagnostic.deficit))
	append(lines, "  storage trend", fmtSigned(energyDiagnostic.storageTrend, "/s"))
	append(lines, "  state duration", fmtAge(energyDiagnostic.duration))
	append(lines, "  episode duration", fmtAge(energyDiagnostic.episodeDuration))
	append(lines, "  cooldown remaining", fmtAge(energyDiagnostic.cooldownRemaining))
	append(lines, "  history samples", tostring(history:size()))
	append(lines, "  evidence", tostring(energyDiagnostic.reason or "condition tracked"))
	append(lines, "Active recommendation", activeRecommendation and activeRecommendation.id or "none")
	append(lines, "Build power status", tostring(buildPower.status))
	append(lines, "  total / active", fmtNumber(buildPower.totalBuildPower) .. " / " .. fmtNumber(buildPower.activeBuildPower))
	append(lines, "  known builders", fmtInteger(buildPower.knownBuilderCount))
	append(lines, "  active / inactive", fmtInteger(buildPower.activeBuilderCount) .. " / " .. fmtInteger(buildPower.inactiveBuilderCount))
	append(lines, "  construction targets", fmtInteger(#buildPower.targets))
	append(lines, "  unknown units", fmtInteger(buildPower.unknownUnitCount))
	append(lines, "  evidence", tostring(buildPower.reason))
	append(lines, "Opening context", openingObservation and tostring(openingObservation.contextStatus) or "unknown")
	append(lines, "  reason", openingObservation and tostring(openingObservation.reason) or "no observation")
	append(lines, "  mex / wind / solar", openingObservation and (
		fmtInteger(openingObservation.finishedCounts.cormex) .. " / "
			.. fmtInteger(openingObservation.finishedCounts.corwin) .. " / "
			.. fmtInteger(openingObservation.finishedCounts.corsolar)
	) or "unknown / unknown / unknown")
	append(lines, "  lab / constructor / combat", openingObservation and (
		fmtInteger(openingObservation.finishedCounts.corlab) .. " / "
			.. fmtInteger(openingObservation.finishedCounts.corck) .. " / "
			.. fmtInteger(openingObservation.finishedCounts.combatBots)
	) or "unknown / unknown / unknown")
	append(lines, "  factory active / idle", openingObservation and (
		fmtFlag(openingObservation.factory.active, "yes", "no") .. " / "
			.. fmtAge(openingObservation.factory.idleDuration)
	) or "- / unknown")
	append(lines, "Opening lesson", openingProgress and tostring(openingProgress.lessonState) or "unknown")
	append(lines, "  next milestone", openingProgress and tostring(openingProgress.nextMilestoneId or "none") or "none")
	append(lines, "  presentation", openingProgress and tostring(openingProgress.presentation) or "none")
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

local function drawRecommendationCard()
	if not initialized or activeRecommendation == nil then
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
	local width = 480 * scale
	local lineHeight = 19 * scale
	local padding = 14 * scale
	local lines = {
		{ activeRecommendation.title, "title" },
		{ activeRecommendation.fact, "fact" },
		{ activeRecommendation.explanation, "detail" },
		{ "Возможные действия:", "detail" },
	}

	for i = 1, #activeRecommendation.possibleActions do
		lines[#lines + 1] = { "— " .. activeRecommendation.possibleActions[i], "action" }
	end

	local height = (#lines * lineHeight) + padding * 2
	local x1 = math.max(0, vsx - width - 28 * scale)
	local y1 = math.max(0, math.min(vsy - height, vsy * 0.16))
	local x2 = x1 + width
	local y2 = y1 + height
	glColor(0.07, 0.08, 0.09, 0.94)
	glRect(x1, y1, x2, y2)
	glColor(0.95, 0.70, 0.20, 1.0)
	glRect(x1, y2 - 3 * scale, x2, y2)

	for i = 1, #lines do
		local text = lines[i][1]
		local kind = lines[i][2]
		local y = y2 - padding - i * lineHeight
		if kind == "title" then
			glColor(1.00, 0.84, 0.48, 1.0)
		elseif kind == "action" then
			glColor(0.82, 0.88, 0.82, 1.0)
		else
			glColor(0.94, 0.94, 0.91, 1.0)
		end
		glText(text, x1 + padding, y, (kind == "title" and 15 or 13) * scale, "o")
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
	snapshotCollector:reset()
	energyDiagnostic = {
		state = "unknown",
		reason = "widget stopped",
	}
	activeRecommendation = nil
	lastBuildPowerCollectionTime = nil
	lastOpeningCollectionTime = nil
	openingDirty = true
	buildPower = BuildPowerSnapshot.fromRaw(nil)
	openingTracker:reset()
	openingObservation = nil
	openingProgress = nil
	api = {}
	apiStatus = {}
	loggedErrors = {}
end

local function isOwnFactory(unitDefID, firstTeamID, secondTeamID)
	local ownTeamID = snapshot.teamID
	if type(ownTeamID) ~= "number" or (firstTeamID ~= ownTeamID and secondTeamID ~= ownTeamID) then
		return false
	end
	local unitDef = type(UnitDefs) == "table" and UnitDefs[unitDefID] or nil
	return type(unitDef) == "table" and unitDef.name == openingContext.factoryUnitDefName
end

local function invalidateOpeningForFactory(unitDefID, firstTeamID, secondTeamID)
	if not isOwnFactory(unitDefID, firstTeamID, secondTeamID) then
		return
	end
	openingTracker:invalidate()
	openingDirty = true
end

function widget:UnitCreated(_, unitDefID, unitTeam)
	invalidateOpeningForFactory(unitDefID, unitTeam, nil)
end

function widget:UnitFinished(_, unitDefID, unitTeam)
	invalidateOpeningForFactory(unitDefID, unitTeam, nil)
end

function widget:UnitDestroyed(_, unitDefID, unitTeam)
	invalidateOpeningForFactory(unitDefID, unitTeam, nil)
end

function widget:UnitGiven(_, unitDefID, newTeam, oldTeam)
	invalidateOpeningForFactory(unitDefID, newTeam, oldTeam)
end

function widget:UnitTaken(_, unitDefID, oldTeam, newTeam)
	invalidateOpeningForFactory(unitDefID, oldTeam, newTeam)
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
	if debugPanelEnabled then
		drawPanel()
	end
	drawRecommendationCard()
end

function widget:GetConfigData()
	return {
		version = CONFIG_VERSION,
		debug = debugPanelEnabled,
		panel = {
			x = panel.x,
			y = panel.y,
			scale = panel.scale,
		},
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end

	if type(data.debug) == "boolean" then
		debugPanelEnabled = data.debug
	end

	if type(data.panel) ~= "table" then
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
