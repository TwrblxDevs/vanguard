export type Definition = {
	Title: string,
	Summary: string,
}

export type VanguardError = {
	Code: string,
	Title: string,
	Message: string,
	DocsUrl: string,
	Cause: any?,
}

local Error = {}

local DOCS_BASE_URL = "https://twrblxdevs.github.io/vanguard-docs/errors/"

local DEFINITIONS: { [string]: Definition } = {
	["VG-CORE-001"] = {
		Title = "Invalid framework usage",
		Summary = "A Vanguard API received an invalid value or was used outside its documented contract.",
	},
	["VG-CORE-002"] = {
		Title = "Wrong runtime",
		Summary = "A server-only or client-only Vanguard module was required from the wrong runtime.",
	},
	["VG-CONFIG-001"] = {
		Title = "Invalid configuration",
		Summary = "A Vanguard start or bootstrap option has an invalid type or value.",
	},
	["VG-LIFE-001"] = {
		Title = "Invalid lifecycle state",
		Summary = "A lifecycle API was called at an unsupported time or a lifecycle callback failed.",
	},
	["VG-MODULE-001"] = {
		Title = "Module discovery failure",
		Summary = "A discovered ModuleScript failed to load or register and was skipped.",
	},
	["VG-REG-001"] = {
		Title = "Duplicate registration",
		Summary = "A different object is already registered under the requested Vanguard name.",
	},
	["VG-REG-002"] = {
		Title = "Registration not found",
		Summary = "The requested service, controller, component, or class is not registered.",
	},
	["VG-CLASS-001"] = {
		Title = "Invalid class definition",
		Summary = "A Vanguard class definition, base class, constructor, or member group is invalid.",
	},
	["VG-CLASS-002"] = {
		Title = "Class member conflict",
		Summary = "A class member is declared in incompatible public, private, static, or reserved locations.",
	},
	["VG-NET-001"] = {
		Title = "Network protocol mismatch",
		Summary = "The client and server use incompatible Vanguard network protocols.",
	},
	["VG-NET-002"] = {
		Title = "Remote discovery timeout",
		Summary = "The client could not discover the Vanguard remote container or requested service in time.",
	},
	["VG-NET-003"] = {
		Title = "Invalid network configuration",
		Summary = "A network rule, remote declaration, or guard option is invalid.",
	},
	["VG-NET-101"] = {
		Title = "Request rate limited",
		Summary = "An inbound request exceeded its per-player rolling-window budget.",
	},
	["VG-NET-102"] = {
		Title = "Invalid request payload",
		Summary = "An inbound request failed its configured payload validator.",
	},
	["VG-NET-103"] = {
		Title = "Request unauthenticated",
		Summary = "An inbound request failed a server-owned authentication policy.",
	},
	["VG-NET-104"] = {
		Title = "Request unverified",
		Summary = "An inbound request was not authorized against current server state.",
	},
	["VG-NET-105"] = {
		Title = "Network guard failure",
		Summary = "A validator, limiter, authentication callback, or verification callback threw an error.",
	},
	["VG-MATH-001"] = {
		Title = "Invalid math argument",
		Summary = "A Vanguard Math helper received a non-number or unsupported numeric option.",
	},
	["VG-MATH-002"] = {
		Title = "Invalid math range",
		Summary = "A Vanguard Math helper received an empty, reversed, or otherwise invalid range.",
	},
	["VG-SWITCH-001"] = {
		Title = "Invalid switch definition",
		Summary = "A Vanguard Switch case, case collection, or handler is invalid.",
	},
	["VG-UTIL-001"] = {
		Title = "Invalid utility usage",
		Summary = "A Vanguard utility received an invalid argument or was used after cleanup.",
	},
	["VG-DIAG-001"] = {
		Title = "Memory tracking disabled",
		Summary = "Vanguard attempted to use a function which was disabled because memory tracking is disabled on the client."
	}
}

local NETWORK_REJECTION_CODES = {
	RATE_LIMITED = "VG-NET-101",
	INVALID_PAYLOAD = "VG-NET-102",
	UNAUTHENTICATED = "VG-NET-103",
	UNVERIFIED = "VG-NET-104",
	GUARD_ERROR = "VG-NET-105",
}

local ErrorObject = {}
ErrorObject.__index = ErrorObject

local function normalizeCode(code)
	if type(code) ~= "string" or #code == 0 then
		return "VG-CORE-001"
	end

	return string.upper(code)
end

local function anchorForCode(code)
	return string.lower(code)
end

function Error.getDefinition(code: string): Definition?
	return DEFINITIONS[normalizeCode(code)]
end

function Error.getDefinitions(): { [string]: Definition }
	local definitions = {}
	for code, definition in DEFINITIONS do
		definitions[code] = {
			Title = definition.Title,
			Summary = definition.Summary,
		}
	end

	return definitions
end

function Error.getDocsUrl(code: string): string
	local normalizedCode = normalizeCode(code)
	return `{DOCS_BASE_URL}#{anchorForCode(normalizedCode)}`
end

function Error.getNetworkErrorCode(rejectionCode: string): string
	return NETWORK_REJECTION_CODES[rejectionCode] or "VG-NET-003"
end

function Error.new(code: string, message: string?, cause: any?): VanguardError
	local normalizedCode = normalizeCode(code)
	local definition = DEFINITIONS[normalizedCode]
	local title = if definition == nil then "Unknown Vanguard error" else definition.Title
	local resolvedMessage = message

	if resolvedMessage == nil or #resolvedMessage == 0 then
		resolvedMessage = if definition == nil then "An undocumented Vanguard error occurred." else definition.Summary
	end

	return setmetatable({
		Code = normalizedCode,
		Title = title,
		Message = resolvedMessage,
		DocsUrl = Error.getDocsUrl(normalizedCode),
		Cause = cause,
	}, ErrorObject) :: any
end

function ErrorObject:__tostring()
	local cause = if self.Cause == nil then "" else `\nCause: {tostring(self.Cause)}`
	return `[Vanguard {self.Code}] {self.Message}{cause}\nDocs: {self.DocsUrl}`
end

function Error.is(value): boolean
	return type(value) == "table" and getmetatable(value) == ErrorObject
end

function Error.format(code: string, message: string?, cause: any?): string
	return tostring(Error.new(code, message, cause))
end

function Error.raise(code: string, message: string?, cause: any?, level: number?)
	error(Error.format(code, message, cause), (level or 1) + 1)
end

function Error.assert<T>(condition: T, code: string, message: string?, level: number?): T
	if condition then
		return condition
	end

	Error.raise(code, message, nil, (level or 1) + 1)
end

return Error
