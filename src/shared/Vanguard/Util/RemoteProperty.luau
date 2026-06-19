local Players = game:GetService("Players")

local Signal = require(script.Parent.Signal)

export type Disconnectable = {
	Disconnect: (Disconnectable) -> (),
}

export type ServerRemoteProperty = {
	Changed: Signal.Signal,
	Get: (ServerRemoteProperty, player: Player?) -> any,
	GetFor: (ServerRemoteProperty, player: Player?) -> any,
	Set: (ServerRemoteProperty, value: any) -> (),
	SetFor: (ServerRemoteProperty, player: Player, value: any) -> (),
	ClearFor: (ServerRemoteProperty, player: Player) -> (),
	Observe: (ServerRemoteProperty, callback: (Player?, any) -> ()) -> RBXScriptConnection,
	Destroy: (ServerRemoteProperty) -> (),
}

export type ClientRemoteProperty = {
	Changed: Signal.Signal,
	Get: (ClientRemoteProperty) -> any,
	Observe: (ClientRemoteProperty, callback: (any) -> ()) -> Disconnectable,
	Destroy: (ClientRemoteProperty) -> (),
}

export type RemoteProperty = ServerRemoteProperty | ClientRemoteProperty

local RemoteProperty = {}

local ServerRemoteProperty = {}
ServerRemoteProperty.__index = ServerRemoteProperty

local ClientRemoteProperty = {}
ClientRemoteProperty.__index = ClientRemoteProperty

local function pack(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function unpackPacked(values)
	return table.unpack(values, 1, values.n)
end

local function getMethodArg(self, first, second)
	if first == self then
		return second
	end

	return first
end

local function getMethodArgs(self, first, second, third)
	if first == self then
		return second, third
	end

	return first, second
end

function ServerRemoteProperty.new(folder, initialValue, inboundGuard)
	assert(inboundGuard == nil or type(inboundGuard) == "function", "Remote property guard must be a function or nil")

	local self = setmetatable({
		_folder = folder,
		_getRemote = folder:WaitForChild("_Get"),
		_changedRemote = folder:WaitForChild("_Changed"),
		_value = pack(initialValue),
		_playerValues = {},
		_playerRemoving = nil,
		Changed = Signal.new(),
	}, ServerRemoteProperty)

	self.Get = function(first, second)
		return ServerRemoteProperty.Get(self, getMethodArg(self, first, second))
	end

	self.GetFor = self.Get

	self.Set = function(first, second)
		return ServerRemoteProperty.Set(self, getMethodArg(self, first, second))
	end

	self.SetFor = function(first, second, third)
		local player, value = getMethodArgs(self, first, second, third)
		return ServerRemoteProperty.SetFor(self, player, value)
	end

	self.ClearFor = function(first, second)
		return ServerRemoteProperty.ClearFor(self, getMethodArg(self, first, second))
	end

	self.Observe = function(first, second)
		return ServerRemoteProperty.Observe(self, getMethodArg(self, first, second))
	end

	self.Destroy = function()
		return ServerRemoteProperty.Destroy(self)
	end

	self._getRemote.OnServerInvoke = function(player)
		if inboundGuard ~= nil then
			local guardOk, allowed, message = pcall(inboundGuard, player)
			if not guardOk then
				error("[VanguardNetwork/GUARD_ERROR] A server network guard failed", 0)
			end

			if allowed ~= true then
				error(message or "[VanguardNetwork/REJECTED] Property read rejected", 0)
			end
		end

		return self:Get(player)
	end

	self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
		self._playerValues[player] = nil
	end)

	return self
end

function ServerRemoteProperty:Get(player)
	if player ~= nil then
		local playerValue = self._playerValues[player]
		if playerValue ~= nil then
			return unpackPacked(playerValue)
		end
	end

	return unpackPacked(self._value)
end

ServerRemoteProperty.GetFor = ServerRemoteProperty.Get

function ServerRemoteProperty:Set(value)
	self._value = pack(value)
	self._changedRemote:FireAllClients(value)
	self.Changed:Fire(nil, value)
end

function ServerRemoteProperty:SetFor(player, value)
	self._playerValues[player] = pack(value)
	self._changedRemote:FireClient(player, value)
	self.Changed:Fire(player, value)
end

function ServerRemoteProperty:ClearFor(player)
	self._playerValues[player] = nil
	local value = self:Get()
	self._changedRemote:FireClient(player, value)
	self.Changed:Fire(player, value)
end

function ServerRemoteProperty:Observe(callback)
	return self.Changed:Connect(callback)
end

function ServerRemoteProperty:Destroy()
	if self._playerRemoving ~= nil then
		self._playerRemoving:Disconnect()
		self._playerRemoving = nil
	end

	self.Changed:Destroy()
	self._folder:Destroy()
end

function ClientRemoteProperty.new(folder)
	local self = setmetatable({
		_folder = folder,
		_getRemote = folder:WaitForChild("_Get"),
		_changedRemote = folder:WaitForChild("_Changed"),
		Changed = Signal.new(),
		_current = nil,
		_connection = nil,
	}, ClientRemoteProperty)

	self.Get = function()
		return ClientRemoteProperty.Get(self)
	end

	self.Observe = function(first, second)
		return ClientRemoteProperty.Observe(self, getMethodArg(self, first, second))
	end

	self.Destroy = function()
		return ClientRemoteProperty.Destroy(self)
	end

	self._connection = self._changedRemote.OnClientEvent:Connect(function(...)
		self._current = pack(...)
		self.Changed:Fire(...)
	end)

	return self
end

function ClientRemoteProperty:Get()
	local values = pack(self._getRemote:InvokeServer())
	self._current = values
	return unpackPacked(values)
end

function ClientRemoteProperty:Observe(callback)
	assert(type(callback) == "function", "Property observer must be a function")

	local alive = true
	local connection = self.Changed:Connect(function(...)
		if alive then
			callback(...)
		end
	end)

	task.spawn(function()
		local ok, result = pcall(function()
			return pack(self:Get())
		end)

		if alive and ok then
			callback(unpackPacked(result))
		elseif alive then
			warn(result)
		end
	end)

	return {
		Disconnect = function()
			alive = false
			connection:Disconnect()
		end,
	}
end

function ClientRemoteProperty:Destroy()
	if self._connection ~= nil then
		self._connection:Disconnect()
		self._connection = nil
	end

	self.Changed:Destroy()
end

RemoteProperty.Server = ServerRemoteProperty
RemoteProperty.Client = ClientRemoteProperty

return RemoteProperty
