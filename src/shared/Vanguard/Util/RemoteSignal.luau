local Players = game:GetService("Players")
local VanguardError = require(script.Parent.Error)

local function assert(condition, message)
	return VanguardError.assert(condition, "VG-UTIL-001", message, 3)
end

export type ServerRemoteSignal = {
	Connect: (ServerRemoteSignal, callback: (Player, ...any) -> ()) -> RBXScriptConnection,
	Once: (ServerRemoteSignal, callback: (Player, ...any) -> ()) -> RBXScriptConnection,
	Wait: (ServerRemoteSignal) -> (Player, ...any),
	Fire: (ServerRemoteSignal, player: Player, ...any) -> (),
	FireFor: (ServerRemoteSignal, player: Player, ...any) -> (),
	FireAll: (ServerRemoteSignal, ...any) -> (),
	FireExcept: (ServerRemoteSignal, excludedPlayer: Player, ...any) -> (),
	FireWhere: (ServerRemoteSignal, predicate: (Player) -> boolean, ...any) -> (),
	Destroy: (ServerRemoteSignal) -> (),
}

export type ClientRemoteSignal = {
	Connect: (ClientRemoteSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Once: (ClientRemoteSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Wait: (ClientRemoteSignal) -> ...any,
	Fire: (ClientRemoteSignal, ...any) -> (),
	Destroy: (ClientRemoteSignal) -> (),
}

export type RemoteSignal = ServerRemoteSignal | ClientRemoteSignal

local RemoteSignal = {}

local ServerRemoteSignal = {}
ServerRemoteSignal.__index = ServerRemoteSignal

local ClientRemoteSignal = {}
ClientRemoteSignal.__index = ClientRemoteSignal

function ServerRemoteSignal.new(remote, inboundGuard)
	assert(inboundGuard == nil or type(inboundGuard) == "function", "Remote signal guard must be a function or nil")

	local self = setmetatable({
		_remote = remote,
		_inbound = Instance.new("BindableEvent"),
		_connection = nil,
		_destroyed = false,
	}, ServerRemoteSignal)

	self._connection = remote.OnServerEvent:Connect(function(...)
		if inboundGuard ~= nil then
			local guardOk, allowed = pcall(inboundGuard, ...)
			if not guardOk then
				warn(`[Vanguard] Remote signal guard failed: {allowed}`)
				return
			end

			if allowed ~= true then
				return
			end
		end

		if not self._destroyed then
			self._inbound:Fire(...)
		end
	end)

	return self
end

function ServerRemoteSignal:Connect(callback)
	assert(not self._destroyed, "Cannot connect to a destroyed remote signal")
	return self._inbound.Event:Connect(callback)
end

function ServerRemoteSignal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

function ServerRemoteSignal:Wait()
	assert(not self._destroyed, "Cannot wait on a destroyed remote signal")
	return self._inbound.Event:Wait()
end

function ServerRemoteSignal:Fire(player, ...)
	self._remote:FireClient(player, ...)
end

ServerRemoteSignal.FireFor = ServerRemoteSignal.Fire

function ServerRemoteSignal:FireAll(...)
	self._remote:FireAllClients(...)
end

function ServerRemoteSignal:FireExcept(excludedPlayer, ...)
	for _, player in Players:GetPlayers() do
		if player ~= excludedPlayer then
			self._remote:FireClient(player, ...)
		end
	end
end

function ServerRemoteSignal:FireWhere(predicate, ...)
	for _, player in Players:GetPlayers() do
		if predicate(player) then
			self._remote:FireClient(player, ...)
		end
	end
end

function ServerRemoteSignal:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	if self._connection ~= nil then
		self._connection:Disconnect()
		self._connection = nil
	end

	self._inbound:Destroy()
	self._remote:Destroy()
end

function ClientRemoteSignal.new(remote)
	return setmetatable({
		_remote = remote,
	}, ClientRemoteSignal)
end

function ClientRemoteSignal:Connect(callback)
	return self._remote.OnClientEvent:Connect(callback)
end

function ClientRemoteSignal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

function ClientRemoteSignal:Wait()
	return self._remote.OnClientEvent:Wait()
end

function ClientRemoteSignal:Fire(...)
	self._remote:FireServer(...)
end

function ClientRemoteSignal:Destroy()
	self._remote:Destroy()
end

RemoteSignal.Server = ServerRemoteSignal
RemoteSignal.Client = ClientRemoteSignal

return RemoteSignal
