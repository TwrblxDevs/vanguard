export type Rejection = {
	Code: string,
	Message: string,
	Stage: string,
	RetryAfter: number?,
	Detail: any?,
}

export type Rule = {
	Validate: ((...any) -> (boolean, string?)) | false?,
	Authenticate: ((player: any, context: any) -> (boolean, string?)) | false?,
	Verify: ((player: any, context: any, ...any) -> (boolean, string?)) | false?,
	RateLimit: any?,
}

export type Options = {
	Rule: Rule?,
	Authenticate: ((player: any, context: any) -> (boolean, string?))?,
	Verify: ((player: any, context: any, ...any) -> (boolean, string?))?,
}

export type NetworkGuard = {
	Check: (NetworkGuard, context: any, ...any) -> (boolean, Rejection?),
}

local NetworkGuard = {}
NetworkGuard.__index = NetworkGuard

local function pack(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function rejection(code, message, stage, detail, retryAfter)
	return {
		Code = code,
		Message = message,
		Stage = stage,
		Detail = detail,
		RetryAfter = retryAfter,
	}
end

local function runGuard(callback, stage, rejectionCode, fallbackMessage, ...)
	local results = pack(pcall(callback, ...))
	if not results[1] then
		return false, rejection("GUARD_ERROR", "A server network guard failed", stage, results[2])
	end

	if results[2] == true then
		return true
	end

	local message = if results[3] == nil then fallbackMessage else tostring(results[3])
	return false, rejection(rejectionCode, message, stage)
end

function NetworkGuard.mergeRules(...)
	local merged = {}

	for index = 1, select("#", ...) do
		local rule = select(index, ...)
		if rule == nil then
			continue
		end

		assert(type(rule) == "table", `Network rule #{index} must be a table or nil`)
		for key, value in rule do
			merged[key] = value
		end
	end

	return merged
end

function NetworkGuard.new(options: Options?)
	options = options or {}
	assert(type(options) == "table", "NetworkGuard options must be a table or nil")
	assert(options.Rule == nil or type(options.Rule) == "table", "NetworkGuard Rule must be a table or nil")
	assert(
		options.Authenticate == nil or type(options.Authenticate) == "function",
		"NetworkGuard Authenticate must be a function or nil"
	)
	assert(options.Verify == nil or type(options.Verify) == "function", "NetworkGuard Verify must be a function or nil")

	local rule = options.Rule or {}
	assert(
		rule.Validate == nil or rule.Validate == false or type(rule.Validate) == "function",
		"Network rule Validate must be a function, false, or nil"
	)
	assert(
		rule.Authenticate == nil or rule.Authenticate == false or type(rule.Authenticate) == "function",
		"Network rule Authenticate must be a function, false, or nil"
	)
	assert(
		rule.Verify == nil or rule.Verify == false or type(rule.Verify) == "function",
		"Network rule Verify must be a function, false, or nil"
	)
	assert(
		rule.RateLimit == nil
			or rule.RateLimit == false
			or (type(rule.RateLimit) == "table" and type(rule.RateLimit.Check) == "function"),
		"Network rule RateLimit must expose :Check(), be false, or be nil"
	)

	return setmetatable({
		_rule = rule,
		_authenticate = options.Authenticate,
		_verify = options.Verify,
	}, NetworkGuard)
end

function NetworkGuard:Check(context, ...)
	assert(type(context) == "table", "Network guard context must be a table")
	assert(context.Player ~= nil, "Network guard context must include Player")

	local player = context.Player
	local rule = self._rule

	if rule.RateLimit ~= nil and rule.RateLimit ~= false then
		local results = pack(pcall(rule.RateLimit.Check, rule.RateLimit, player))
		if not results[1] then
			return false, rejection("GUARD_ERROR", "The server rate limiter failed", "RateLimit", results[2])
		end

		if results[2] ~= true then
			local retryAfter = if type(results[3]) == "number" then results[3] else nil
			return false, rejection("RATE_LIMITED", "Too many requests", "RateLimit", nil, retryAfter)
		end
	end

	if rule.Validate ~= nil and rule.Validate ~= false then
		local valid, rejected = runGuard(rule.Validate, "Validate", "INVALID_PAYLOAD", "Invalid request payload", ...)
		if not valid then
			return false, rejected
		end
	end

	if self._authenticate ~= nil then
		local authenticated, rejected = runGuard(
			self._authenticate,
			"Authenticate",
			"UNAUTHENTICATED",
			"Authentication failed",
			player,
			context
		)
		if not authenticated then
			return false, rejected
		end
	end

	if rule.Authenticate ~= nil and rule.Authenticate ~= false then
		local authenticated, rejected = runGuard(
			rule.Authenticate,
			"Authenticate",
			"UNAUTHENTICATED",
			"Authentication failed",
			player,
			context
		)
		if not authenticated then
			return false, rejected
		end
	end

	if self._verify ~= nil then
		local verified, rejected = runGuard(
			self._verify,
			"Verify",
			"UNVERIFIED",
			"Request verification failed",
			player,
			context,
			...
		)
		if not verified then
			return false, rejected
		end
	end

	if rule.Verify ~= nil and rule.Verify ~= false then
		local verified, rejected = runGuard(
			rule.Verify,
			"Verify",
			"UNVERIFIED",
			"Request verification failed",
			player,
			context,
			...
		)
		if not verified then
			return false, rejected
		end
	end

	return true
end

return NetworkGuard
