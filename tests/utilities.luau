local Cache = require("../src/shared/Vanguard/Util/Cache")
local Class = require("../src/shared/Vanguard/Util/Class")
local VanguardError = require("../src/shared/Vanguard/Util/Error")
local Math = require("../src/shared/Vanguard/Util/Math")
local NetworkGuard = require("../src/shared/Vanguard/Util/NetworkGuard")
local RateLimiter = require("../src/shared/Vanguard/Util/RateLimiter")
local Switch = require("../src/shared/Vanguard/Util/Switch")
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

local Account
Account = Class.create({
	Name = "Account",
	Private = {
		Balance = 0,
		Metadata = { Deposits = 0 },
		Constructor = function(_self, private, openingBalance)
			private.Balance = openingBalance
		end,
		ApplyDeposit = function(_self, private, amount)
			private.Balance += amount
			private.Metadata.Deposits += 1
		end,
	},
	Public = {
		Deposit = function(_self, private, amount)
			private:ApplyDeposit(amount)
		end,
		GetBalance = function(_self, private)
			return private.Balance
		end,
		GetDepositCount = function(_self, private)
			return private.Metadata.Deposits
		end,
	},
	Static = {
		Currency = "Credits",
		Open = function(openingBalance)
			return Account(openingBalance)
		end,
	},
})

local firstAccount = Account.Open(10)
local secondAccount = Account.Open(2)
firstAccount:Deposit(5)
assert(firstAccount:GetBalance() == 15, "Public methods should receive private instance state")
assert(firstAccount:GetDepositCount() == 1, "Private methods should update private state")
assert(secondAccount:GetBalance() == 2 and secondAccount:GetDepositCount() == 0, "Private defaults must be isolated")
assert(firstAccount.Balance == nil and firstAccount.ApplyDeposit == nil, "Private members must not be externally visible")
assert(Account.Currency == "Credits" and firstAccount.Currency == nil, "Static members must only be visible on the class")

local PremiumAccount = Account:Extend({
	Name = "PremiumAccount",
	Private = {
		Tier = "Gold",
	},
	Public = {
		GetTier = function(_self, private)
			return private.Tier
		end,
	},
	Static = {
		Category = "Premium",
	},
})

local premium = PremiumAccount(25)
premium:Deposit(5)
assert(premium:GetBalance() == 30 and premium:GetTier() == "Gold", "Inherited public methods should use owner private state")
assert(PremiumAccount.Currency == "Credits" and PremiumAccount.Category == "Premium", "Static members should inherit on classes")
assert(premium.Currency == nil and premium.Category == nil, "Inherited static members must stay hidden from instances")

local formattedError = VanguardError.format("VG-CLASS-001", "Example class failure")
assert(string.find(formattedError, "VG-CLASS-001", 1, true) ~= nil, "Errors should include stable codes")
assert(string.find(formattedError, "https://", 1, true) ~= nil, "Errors should include documentation links")

assert(Math.round(1.2345, 2) == 1.23, "Math.round should support decimal places")
assert(Math.lerp(10, 20, 0.25) == 12.5, "Math.lerp should interpolate numbers")
assert(Math.inverseLerp(10, 20, 12.5) == 0.25, "Math.inverseLerp should calculate normalized progress")
assert(Math.map(5, 0, 10, 0, 100) == 50, "Math.map should remap ranges")
assert(Math.map(20, 0, 10, 0, 100, true) == 100, "Math.map should optionally clamp output")
assert(Math.approximatelyEqual(0.1 + 0.2, 0.3), "Math.approximatelyEqual should tolerate floating-point drift")
assert(Math.wrap(12, 0, 10) == 2, "Math.wrap should wrap values into a range")
assert(Math.pingPong(7, 5) == 3, "Math.pingPong should reflect values across a length")
assert(Math.smoothstep(0, 10, 5) == 0.5, "Math.smoothstep should ease normalized values")
assert(Math.moveTowards(0, 10, 3) == 3, "Math.moveTowards should cap movement")
assert(Math.snap(12, 5) == 10, "Math.snap should quantize values")
assert(Math.average(2, 4, 6) == 4, "Math.average should average variadic values")

local invalidRangeOk, invalidRangeError = pcall(function()
	Math.map(1, 5, 5, 0, 1)
end)
assert(not invalidRangeOk, "Math helpers should reject empty ranges")
assert(string.find(invalidRangeError, "VG-MATH-002", 1, true) ~= nil, "Math errors should use documented codes")

local switchResult = Switch.new("playing")
	:Case("paused", "Pause")
	:Cases({ "playing", "resuming" }, function(value, suffix)
		return value .. suffix
	end)
	:Default("Unknown")
	:Run("-state")
assert(switchResult == "playing-state", "Switch should execute the first matching case")
assert(Switch.new("missing"):Default("fallback"):Run() == "fallback", "Switch should execute its default")
assert(Switch.match("admin", { admin = "allowed" }, "denied") == "allowed", "Switch.match should support direct maps")
assert(Switch.match("guest", { admin = "allowed" }, "denied") == "denied", "Switch.match should return its default")

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
