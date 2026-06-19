export type Promise = {
	andThen: (Promise, ((...any) -> any)?, ((...any) -> any)?) -> Promise,
	catch: (Promise, (...any) -> any) -> Promise,
	finally: (Promise, () -> any) -> Promise,
	await: (Promise) -> (boolean, ...any),
}

export type Executor = (resolve: (...any) -> (), reject: (...any) -> ()) -> ()

local Promise = {}
Promise.__index = Promise

Promise.Status = {
	Pending = "Pending",
	Fulfilled = "Fulfilled",
	Rejected = "Rejected",
}

local function pack(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function unpackPacked(values)
	return table.unpack(values, 1, values.n)
end

function Promise.is(value)
	return type(value) == "table" and getmetatable(value) == Promise
end

local function settle(self, status, ...)
	if self._status ~= Promise.Status.Pending then
		return
	end

	self._status = status
	self._values = pack(...)

	local queued = self._queued
	self._queued = nil

	for _, callback in queued do
		task.defer(callback)
	end
end

local function resolvePromise(self, ...)
	if select("#", ...) == 1 then
		local value = ...
		if Promise.is(value) then
			value:andThen(function(...)
				settle(self, Promise.Status.Fulfilled, ...)
			end, function(...)
				settle(self, Promise.Status.Rejected, ...)
			end)
			return
		end
	end

	settle(self, Promise.Status.Fulfilled, ...)
end

function Promise.new(executor)
	assert(type(executor) == "function", "Promise executor must be a function")

	local self = setmetatable({
		_status = Promise.Status.Pending,
		_values = nil,
		_queued = {},
	}, Promise)

	task.spawn(function()
		local ok, err = pcall(executor, function(...)
			resolvePromise(self, ...)
		end, function(...)
			settle(self, Promise.Status.Rejected, ...)
		end)

		if not ok then
			settle(self, Promise.Status.Rejected, err)
		end
	end)

	return self
end

function Promise.resolve(...)
	local values = pack(...)
	return Promise.new(function(resolve)
		resolve(unpackPacked(values))
	end)
end

function Promise.reject(...)
	local values = pack(...)
	return Promise.new(function(_, reject)
		reject(unpackPacked(values))
	end)
end

function Promise.all(promises)
	assert(type(promises) == "table", "Promise.all expects a table")

	return Promise.new(function(resolve, reject)
		local count = #promises
		if count == 0 then
			resolve({})
			return
		end

		local remaining = count
		local results = table.create(count)

		for index, promise in promises do
			Promise.resolve(promise):andThen(function(...)
				local values = pack(...)
				results[index] = if values.n == 1 then values[1] else values
				remaining -= 1

				if remaining == 0 then
					resolve(results)
				end
			end, reject)
		end
	end)
end

function Promise.fromEvent(event, predicate)
	return Promise.new(function(resolve)
		local connection
		connection = event:Connect(function(...)
			if predicate ~= nil and not predicate(...) then
				return
			end

			connection:Disconnect()
			resolve(...)
		end)
	end)
end

function Promise.delay(seconds)
	return Promise.new(function(resolve)
		task.delay(seconds, resolve)
	end)
end

function Promise:andThen(onFulfilled, onRejected)
	assert(onFulfilled == nil or type(onFulfilled) == "function", "andThen success callback must be a function or nil")
	assert(onRejected == nil or type(onRejected) == "function", "andThen failure callback must be a function or nil")

	return Promise.new(function(resolve, reject)
		local function run()
			local callback = if self._status == Promise.Status.Fulfilled then onFulfilled else onRejected

			if callback == nil then
				if self._status == Promise.Status.Fulfilled then
					resolve(unpackPacked(self._values))
				else
					reject(unpackPacked(self._values))
				end
				return
			end

			local results = pack(pcall(callback, unpackPacked(self._values)))
			local ok = results[1]

			if ok then
				resolve(table.unpack(results, 2, results.n))
			else
				reject(results[2])
			end
		end

		if self._status == Promise.Status.Pending then
			table.insert(self._queued, run)
		else
			task.defer(run)
		end
	end)
end

function Promise:catch(onRejected)
	return self:andThen(nil, onRejected)
end

function Promise:finally(callback)
	assert(type(callback) == "function", "finally callback must be a function")

	return self:andThen(function(...)
		callback()
		return ...
	end, function(...)
		callback()
		return Promise.reject(...)
	end)
end

function Promise:await()
	if self._status == Promise.Status.Pending then
		local thread = coroutine.running()

		self:andThen(function(...)
			task.spawn(thread, true, ...)
		end, function(...)
			task.spawn(thread, false, ...)
		end)

		return coroutine.yield()
	end

	return self._status == Promise.Status.Fulfilled, unpackPacked(self._values)
end

return Promise
