local Cache = require("../src/shared/Vanguard/Util/Cache")
local Class = require("../src/shared/Vanguard/Util/Class")
local NetworkGuard = require("../src/shared/Vanguard/Util/NetworkGuard")
local RateLimiter = require("../src/shared/Vanguard/Util/RateLimiter")
local Validator = require("../src/shared/Vanguard/Util/Validator")

local now = 0
local function clock()
	return now
end

local cache = Cache.new({
	DefaultTTL = 5,
	MaxSize = 2,
	Clock = clock,
})

cache:Set("nil-value", nil)
local nilValue, nilFound = cache:Get("nil-value")
assert(nilValue == nil and nilFound, "Cache should distinguish cached nil values from misses")

cache:Set("second", 2)
cache:Get("nil-value")
cache:Set("third", 3)
assert(not cache:Has("second"), "Cache should evict the least recently used entry")
assert(cache:Has("nil-value") and cache:Has("third"), "Cache should retain recently used entries")

now = 5
assert(cache:Count() == 0, "Cache should prune expired entries")

local produceCount = 0
local producedValue, wasCached = cache:GetOrSet("produced", function(key)
	produceCount += 1
	return key .. "-value"
end)
assert(producedValue == "produced-value" and not wasCached, "GetOrSet should report a newly produced value")

local cachedValue, secondWasCached = cache:GetOrSet("produced", function()
	produceCount += 1
	return "unexpected"
end)
assert(cachedValue == "produced-value" and secondWasCached, "GetOrSet should return an existing value")
assert(produceCount == 1, "GetOrSet should only run the producer on a miss")

local constructorOrder = {}
local Base = Class.create({
	Name = "Base",
	Constructor = function(self, id)
		table.insert(constructorOrder, "base")
		self.Id = id
	end,
	GetId = function(self)
		return self.Id
	end,
	__tostring = function(self)
		return self.Id
	end,
})

local Child = Base:Extend({
	Name = "Child",
	Constructor = function(self, _id, kind)
		table.insert(constructorOrder, "child")
		self.Kind = kind
	end,
})

local child = Child("entity-1", "player")
assert(constructorOrder[1] == "base" and constructorOrder[2] == "child", "Constructors should run base-first")
assert(child:GetId() == "entity-1" and child.Kind == "player", "Instances should inherit base methods")
assert(child:IsA(Base) and child:IsA("Child"), "Instances should match class objects and names")
assert(Class.isInstance(child, Child), "Class.isInstance should recognize instances")
assert(tostring(child) == "entity-1", "Child classes should inherit base metamethods")

now = 0
local limiter = RateLimiter.new({
	Limit = 2,
	Window = 1,
	Clock = clock,
})

assert(limiter:Check("player"), "The first request should be allowed")
assert(limiter:Check("player"), "The second request should be allowed")
local allowed, retryAfter = limiter:Check("player")
assert(not allowed and retryAfter == 1, "The limiter should reject requests beyond the limit")

now = 0.5
local stillAllowed, shorterRetry = limiter:Check("player")
assert(not stillAllowed and shorterRetry == 0.5, "Retry time should decrease as the window advances")

now = 1
assert(limiter:Check("player"), "Requests should be allowed after the rolling window expires")
local remaining = limiter:GetRemaining("player")
assert(remaining == 1, "GetRemaining should report unused capacity")

local payloadValidator = Validator.tuple(
	Validator.string({ MinLength = 2, MaxLength = 16 }),
	Validator.integer({ Min = 1, Max = 10 }),
	Validator.optional(Validator.boolean())
)

assert(payloadValidator("item", 2), "Tuple validators should accept valid payloads")
local payloadValid, payloadError = payloadValidator("x", 2)
assert(not payloadValid and string.find(payloadError, "argument 1") ~= nil, "Tuple errors should identify the argument")
assert(not payloadValidator("item", 2, true, "extra"), "Tuple validators should reject extra arguments")

local objectValidator = Validator.shape({
	Name = Validator.string({ MinLength = 1 }),
	Count = Validator.integer({ Min = 0 }),
})
assert(objectValidator({ Name = "Potion", Count = 3 }), "Shape validators should accept matching tables")
assert(not objectValidator({ Name = "Potion", Count = 3, Trusted = true }), "Shapes should reject extra keys by default")

local optionalArray = Validator.array(Validator.optional(Validator.string()))
assert(not optionalArray({ [1] = "first", [3] = "third" }), "Arrays should reject sparse numeric keys")

now = 0
local networkLimiter = RateLimiter.new({
	Limit = 2,
	Window = 1,
	Clock = clock,
})
local networkGuard = NetworkGuard.new({
	Authenticate = function(player)
		return player.Authenticated, "Session is not authenticated"
	end,
	Rule = {
		Validate = payloadValidator,
		RateLimit = networkLimiter,
		Verify = function(_player, _context, itemName)
			return itemName ~= "blocked", "Item is not permitted"
		end,
	},
})

local networkContext = {
	Player = { Authenticated = true },
}
local requestAllowed = networkGuard:Check(networkContext, "item", 2)
assert(requestAllowed, "Network guards should accept authenticated, valid, verified requests")

local invalidAllowed, invalidRejection = networkGuard:Check(networkContext, "x", 2)
assert(not invalidAllowed and invalidRejection.Code == "INVALID_PAYLOAD", "Network guards should reject invalid payloads")

now = 1
networkContext.Player.Authenticated = false
local authAllowed, authRejection = networkGuard:Check(networkContext, "item", 2)
assert(not authAllowed and authRejection.Code == "UNAUTHENTICATED", "Network guards should reject unauthenticated players")

now = 2
networkContext.Player.Authenticated = true
local verified, verifyRejection = networkGuard:Check(networkContext, "blocked", 2)
assert(not verified and verifyRejection.Code == "UNVERIFIED", "Network guards should reject unverified actions")

now = 3
assert(networkGuard:Check(networkContext, "item", 2), "A fresh network window should accept a request")
assert(networkGuard:Check(networkContext, "item", 2), "A second request inside the limit should pass")
local limited, rateRejection = networkGuard:Check(networkContext, "item", 2)
assert(not limited and rateRejection.Code == "RATE_LIMITED", "Network guards should enforce rate limits")

print("Vanguard utility tests passed")
