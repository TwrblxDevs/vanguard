local VanguardError = if script ~= nil then require(script.Parent.Error) else require("./Error")

local function assert(condition, message)
	return VanguardError.assert(condition, "VG-UTIL-001", message, 3)
end

export type Options = {
	DefaultTTL: number?,
	MaxSize: number?,
	Clock: (() -> number)?,
}

export type Cache = {
	Set: (Cache, key: any, value: any, ttl: number?) -> any,
	Get: (Cache, key: any) -> (any, boolean),
	Peek: (Cache, key: any) -> (any, boolean),
	Has: (Cache, key: any) -> boolean,
	GetOrSet: (Cache, key: any, producer: (any) -> any, ttl: number?) -> (any, boolean),
	Remove: (Cache, key: any) -> (any, boolean),
	Prune: (Cache) -> number,
	Clear: (Cache) -> (),
	Count: (Cache) -> number,
	Keys: (Cache) -> { any },
	Destroy: (Cache) -> (),
}

type Entry = {
	Value: any,
	ExpiresAt: number?,
	LastAccess: number,
}

local Cache = {}
Cache.__index = Cache

local function validateTTL(ttl)
	assert(ttl == nil or (type(ttl) == "number" and ttl >= 0), "Cache TTL must be a non-negative number or nil")
end

function Cache.new(options: Options?)
	options = options or {}

	assert(type(options) == "table", `Cache options must be a table or nil; got {type(options)}`)
	validateTTL(options.DefaultTTL)
	assert(
		options.MaxSize == nil
			or (type(options.MaxSize) == "number" and options.MaxSize >= 1 and options.MaxSize % 1 == 0),
		"Cache MaxSize must be a positive integer or nil"
	)
	assert(options.Clock == nil or type(options.Clock) == "function", "Cache Clock must be a function or nil")

	return setmetatable({
		_entries = {} :: { [any]: Entry },
		_count = 0,
		_accessCounter = 0,
		_defaultTTL = options.DefaultTTL,
		_maxSize = options.MaxSize,
		_clock = options.Clock or os.clock,
	}, Cache)
end

function Cache:_touch(entry)
	self._accessCounter += 1
	entry.LastAccess = self._accessCounter
end

function Cache:_remove(key)
	local entry = self._entries[key]
	if entry == nil then
		return nil, false
	end

	self._entries[key] = nil
	self._count -= 1
	return entry.Value, true
end

function Cache:_read(key, touch)
	local entry = self._entries[key]
	if entry == nil then
		return nil, false
	end

	if entry.ExpiresAt ~= nil and self._clock() >= entry.ExpiresAt then
		self:_remove(key)
		return nil, false
	end

	if touch then
		self:_touch(entry)
	end

	return entry.Value, true
end

function Cache:_evictOverflow()
	while self._maxSize ~= nil and self._count > self._maxSize do
		local oldestKey = nil
		local oldestAccess = math.huge

		for key, entry in self._entries do
			if entry.LastAccess < oldestAccess then
				oldestKey = key
				oldestAccess = entry.LastAccess
			end
		end

		if oldestKey == nil then
			break
		end

		self:_remove(oldestKey)
	end
end

function Cache:Set(key, value, ttl)
	assert(key ~= nil, "Cache keys cannot be nil")
	ttl = if ttl == nil then self._defaultTTL else ttl
	validateTTL(ttl)

	self:Prune()

	if ttl == 0 then
		self:_remove(key)
		return value
	end

	local now = self._clock()
	local entry = self._entries[key]
	if entry == nil then
		entry = {} :: Entry
		self._entries[key] = entry
		self._count += 1
	end

	entry.Value = value
	entry.ExpiresAt = if ttl == nil then nil else now + ttl
	self:_touch(entry)
	self:_evictOverflow()

	return value
end

function Cache:Get(key)
	return self:_read(key, true)
end

function Cache:Peek(key)
	return self:_read(key, false)
end

function Cache:Has(key)
	local _, found = self:Get(key)
	return found
end

function Cache:GetOrSet(key, producer, ttl)
	assert(type(producer) == "function", "Cache producer must be a function")

	local value, found = self:Get(key)
	if found then
		return value, true
	end

	value = producer(key)
	self:Set(key, value, ttl)
	return value, false
end

function Cache:Remove(key)
	return self:_remove(key)
end

function Cache:Prune()
	local now = self._clock()
	local removed = 0

	for key, entry in self._entries do
		if entry.ExpiresAt ~= nil and now >= entry.ExpiresAt then
			self:_remove(key)
			removed += 1
		end
	end

	return removed
end

function Cache:Clear()
	table.clear(self._entries)
	self._count = 0
end

function Cache:Count()
	self:Prune()
	return self._count
end

function Cache:Keys()
	self:Prune()

	local keys = table.create(self._count)
	for key in self._entries do
		table.insert(keys, key)
	end

	return keys
end

Cache.Destroy = Cache.Clear

return Cache
