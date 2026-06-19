export type Options = {
	Limit: number,
	Window: number,
	Clock: (() -> number)?,
	WeakKeys: boolean?,
}

export type RateLimiter = {
	Check: (RateLimiter, key: any?, cost: number?) -> (boolean, number),
	Allow: (RateLimiter, key: any?, cost: number?) -> (boolean, number),
	GetRemaining: (RateLimiter, key: any?) -> (number, number),
	Reset: (RateLimiter, key: any?) -> (),
	Prune: (RateLimiter) -> number,
	Clear: (RateLimiter) -> (),
	Destroy: (RateLimiter) -> (),
}

type Entry = {
	Time: number,
	Cost: number,
}

type Bucket = {
	Entries: { Entry },
	Used: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

local GLOBAL_KEY = {}

local function normalizeKey(key)
	return if key == nil then GLOBAL_KEY else key
end

local function pruneBucket(bucket: Bucket, cutoff: number)
	local firstActive = 1

	while firstActive <= #bucket.Entries and bucket.Entries[firstActive].Time <= cutoff do
		bucket.Used -= bucket.Entries[firstActive].Cost
		firstActive += 1
	end

	if firstActive > 1 then
		local activeEntries = table.create(#bucket.Entries - firstActive + 1)
		for index = firstActive, #bucket.Entries do
			table.insert(activeEntries, bucket.Entries[index])
		end
		bucket.Entries = activeEntries
	end
end

function RateLimiter.new(options: Options)
	assert(type(options) == "table", `RateLimiter options must be a table; got {type(options)}`)
	assert(type(options.Limit) == "number" and options.Limit > 0, "RateLimiter Limit must be greater than zero")
	assert(type(options.Window) == "number" and options.Window > 0, "RateLimiter Window must be greater than zero")
	assert(options.Clock == nil or type(options.Clock) == "function", "RateLimiter Clock must be a function or nil")
	assert(options.WeakKeys == nil or type(options.WeakKeys) == "boolean", "RateLimiter WeakKeys must be a boolean or nil")

	local buckets = {}
	if options.WeakKeys then
		setmetatable(buckets, { __mode = "k" })
	end

	return setmetatable({
		_limit = options.Limit,
		_window = options.Window,
		_clock = options.Clock or os.clock,
		_buckets = buckets,
	}, RateLimiter)
end

function RateLimiter:_getBucket(key, now)
	key = normalizeKey(key)

	local bucket = self._buckets[key]
	if bucket ~= nil then
		pruneBucket(bucket, now - self._window)
		if #bucket.Entries == 0 then
			self._buckets[key] = nil
			bucket = nil
		end
	end

	return key, bucket
end

function RateLimiter:_getRetryAfter(bucket, cost, now)
	local amountToFree = bucket.Used + cost - self._limit
	local freed = 0

	for _, entry in bucket.Entries do
		freed += entry.Cost
		if freed >= amountToFree then
			return math.max(0, entry.Time + self._window - now)
		end
	end

	return self._window
end

function RateLimiter:Check(key, cost)
	cost = cost or 1
	assert(type(cost) == "number" and cost > 0, "RateLimiter cost must be greater than zero")

	if cost > self._limit then
		return false, self._window
	end

	local now = self._clock()
	local normalizedKey, bucket = self:_getBucket(key, now)

	if bucket == nil then
		bucket = {
			Entries = {},
			Used = 0,
		}
		self._buckets[normalizedKey] = bucket
	end

	if bucket.Used + cost > self._limit then
		return false, self:_getRetryAfter(bucket, cost, now)
	end

	table.insert(bucket.Entries, {
		Time = now,
		Cost = cost,
	})
	bucket.Used += cost

	return true, 0
end

RateLimiter.Allow = RateLimiter.Check

function RateLimiter:GetRemaining(key)
	local now = self._clock()
	local _, bucket = self:_getBucket(key, now)
	if bucket == nil then
		return self._limit, 0
	end

	local resetAfter = math.max(0, bucket.Entries[1].Time + self._window - now)
	return math.max(0, self._limit - bucket.Used), resetAfter
end

function RateLimiter:Reset(key)
	self._buckets[normalizeKey(key)] = nil
end

function RateLimiter:Prune()
	local now = self._clock()
	local removed = 0

	for key, bucket in self._buckets do
		pruneBucket(bucket, now - self._window)
		if #bucket.Entries == 0 then
			self._buckets[key] = nil
			removed += 1
		end
	end

	return removed
end

function RateLimiter:Clear()
	table.clear(self._buckets)
end

RateLimiter.Destroy = RateLimiter.Clear

return RateLimiter
