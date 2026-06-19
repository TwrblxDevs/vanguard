export type CleanerTask = RBXScriptConnection | Instance | (() -> ()) | {
	Destroy: ((any) -> ())?,
	Cleanup: ((any) -> ())?,
	Disconnect: ((any) -> ())?,
}

export type Cleaner = {
	Add: <T>(Cleaner, taskItem: T) -> T,
	GiveTask: <T>(Cleaner, taskItem: T) -> T,
	Connect: (Cleaner, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	GivePromise: (Cleaner, promise: any) -> (),
	Cleanup: (Cleaner) -> (),
	Destroy: (Cleaner) -> (),
}

local Cleaner = {}
Cleaner.__index = Cleaner

local function cleanupTask(taskItem)
	local taskType = typeof(taskItem)

	if taskType == "RBXScriptConnection" then
		taskItem:Disconnect()
	elseif taskType == "Instance" then
		taskItem:Destroy()
	elseif type(taskItem) == "function" then
		taskItem()
	elseif type(taskItem) == "table" then
		if type(taskItem.Destroy) == "function" then
			taskItem:Destroy()
		elseif type(taskItem.Cleanup) == "function" then
			taskItem:Cleanup()
		elseif type(taskItem.Disconnect) == "function" then
			taskItem:Disconnect()
		end
	end
end

function Cleaner.new()
	return setmetatable({
		_tasks = {},
		_cleaned = false,
	}, Cleaner)
end

function Cleaner:Add(taskItem)
	assert(not self._cleaned, "Cannot add tasks to a cleaned Cleaner")
	table.insert(self._tasks, taskItem)
	return taskItem
end

Cleaner.GiveTask = Cleaner.Add

function Cleaner:Connect(signal, callback)
	return self:Add(signal:Connect(callback))
end

function Cleaner:GivePromise(promise)
	return self:Add(function()
		if type(promise.cancel) == "function" then
			promise:cancel()
		elseif type(promise.Cancel) == "function" then
			promise:Cancel()
		end
	end)
end

function Cleaner:Cleanup()
	if self._cleaned then
		return
	end

	self._cleaned = true

	for index = #self._tasks, 1, -1 do
		cleanupTask(self._tasks[index])
		self._tasks[index] = nil
	end
end

Cleaner.Destroy = Cleaner.Cleanup

return Cleaner
