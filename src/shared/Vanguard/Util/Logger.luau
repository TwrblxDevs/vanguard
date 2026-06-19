export type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "silent" | number

export type Logger = {
	SetLevel: (Logger, LogLevel?) -> (),
	GetLevel: (Logger) -> number,
	IsEnabled: (Logger, LogLevel?) -> boolean,
	ForScope: (Logger, scope: string) -> Logger,
	Trace: (Logger, ...any) -> (),
	Debug: (Logger, ...any) -> (),
	Info: (Logger, ...any) -> (),
	Warn: (Logger, ...any) -> (),
	Error: (Logger, ...any) -> (),
	trace: (Logger, ...any) -> (),
	debug: (Logger, ...any) -> (),
	info: (Logger, ...any) -> (),
	warn: (Logger, ...any) -> (),
	error: (Logger, ...any) -> (),
}

local Logger = {}
Logger.__index = Logger

local LEVELS = {
	trace = 1,
	debug = 2,
	info = 3,
	warn = 4,
	error = 5,
	silent = 6,
}

local LEVEL_NAMES = {
	"TRACE",
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
	"SILENT",
}

local function normalizeLevel(level)
	if level == nil then
		return LEVELS.info
	end

	if type(level) == "number" then
		return math.floor(math.clamp(level, LEVELS.trace, LEVELS.silent))
	end

	local normalized = string.lower(tostring(level))
	return LEVELS[normalized] or LEVELS.info
end

local function stringify(...)
	local values = table.create(select("#", ...))

	for index = 1, select("#", ...) do
		values[index] = tostring(select(index, ...))
	end

	return table.concat(values, " ")
end

function Logger.new(scope, level)
	return setmetatable({
		_scope = scope or "Vanguard",
		_level = normalizeLevel(level),
	}, Logger)
end

function Logger:SetLevel(level)
	self._level = normalizeLevel(level)
end

function Logger:GetLevel()
	return self._level
end

function Logger:IsEnabled(level)
	return normalizeLevel(level) >= self._level
end

function Logger:ForScope(scope)
	return Logger.new(`{self._scope}.{scope}`, self._level)
end

function Logger:_write(level, ...)
	local levelValue = normalizeLevel(level)
	if levelValue < self._level or self._level == LEVELS.silent then
		return
	end

	local message = `[{self._scope}] [{LEVEL_NAMES[levelValue]}] {stringify(...)}`

	if levelValue >= LEVELS.warn then
		warn(message)
	else
		print(message)
	end
end

function Logger:Trace(...)
	self:_write("trace", ...)
end

function Logger:Debug(...)
	self:_write("debug", ...)
end

function Logger:Info(...)
	self:_write("info", ...)
end

function Logger:Warn(...)
	self:_write("warn", ...)
end

function Logger:Error(...)
	self:_write("error", ...)
end

Logger.trace = Logger.Trace
Logger.debug = Logger.Debug
Logger.info = Logger.Info
Logger.warn = Logger.Warn
Logger.error = Logger.Error

return Logger
