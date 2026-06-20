local Stats = game:GetService("Stats")
local VanguardError = require("./Error")

local function RaiseMTD(func_needed: string)
	VanguardError.raise("VG-DIAG-001",`Function {func_needed}() requires memory tracking but memory tracking is not availiable.`,`Roblox`)
end

type CountBase = {
	DrawcallCount: number,
	TriangleCount: number
}

export type RenderDiag = {
	Frametime: {
		CPU: number,
		GPU: number
	},

	Scene: CountBase,

	Shadows: CountBase,

	UI2D: CountBase,
	UI3D: CountBase,
	
	Physics: {
		Networking: {
			RX: number,
			TX: number
		},

		StepTime: number
	},

	Sync: (self: RenderDiag) -> RenderDiag
}

export type MemoryDiag = {
	TotalMemoryUsage: number,

	RobloxMemoryTags: {
		Internal: number,
		HttpCache: number,
		Instances: number,
		Signals: number,
		LuaHeap: number,
		Script: number,
		PhysicsCollision: number,
		BasePasrts: number,

		Graphics: {
			SolidModels: number,
			MeshParts: number,
			Particles: number,
			Parts: number,
			SpatialHash: number,
			Terrain: number,
			Texture: {
				Texture: number,
				Character: number
			},
			SlimModels: number
		},

		Sounds: {
			Sounds: number,
			Streaming: number
		},

		TerrainVoxels: number,
		Gui: number,
		Animation: number,
		Navigation: number,
		GeometryCSG: number,
	},

	Sync: (self: MemoryDiag) -> MemoryDiag
}

export type Diagnostics = {
	Render: () -> RenderDiag,
	Memory: () -> MemoryDiag,
}

local Diagnostics = {}
Diagnostics.__index = Diagnostics

function update_render(self: RenderDiag)
	self.Frametime.GPU = Stats.RenderGPUFrameTime
	self.Frametime.CPU = Stats.RenderCPUFrameTime

	self.Scene.TriangleCount = Stats.SceneTriangleCount
	self.Scene.DrawcallCount = Stats.SceneDrawcallCount

	self.Shadows.TriangleCount = Stats.ShadowsTriangleCount
	self.Shadows.DrawcallCount = Stats.ShadowsDrawcallCount

	self.UI2D.TriangleCount = Stats.UI2DTriangleCount
	self.UI2D.DrawcallCount = Stats.UI2DDrawcallCount

	self.UI3D.TriangleCount = Stats.UI3DTriangleCount
	self.UI3D.DrawcallCount = Stats.UI3DDrawcallCount

	self.Physics.Networking.TX = Stats.PhysicsSendKbps
	self.Physics.Networking.RX = Stats.PhysicsReceiveKbps
	self.Physics.StepTime = Stats.PhysicsStepTime
end

function Diagnostics.Render() : RenderDiag
	local self: RenderDiag = nil 

	self.Sync = update_render

	return self:Sync()
end

local function tag(t: Enum.DeveloperMemoryTag)
	return Stats:GetMemoryUsageMbForTag(t)
end

local DMT = Enum.DeveloperMemoryTag

function update_memory(self: MemoryDiag) : MemoryDiag
	if Stats.MemoryTrackingEnabled == false then
		RaiseMTD("update_memory() - from Diagnostics.Render()")
	end

	self.TotalMemoryUsage = Stats:GetTotalMemoryUsageMb()

	self.RobloxMemoryTags.Internal = tag(DMT.Internal)
	self.RobloxMemoryTags.HttpCache = tag(DMT.HttpCache)
	self.RobloxMemoryTags.Instances = tag(DMT.Instances)
	self.RobloxMemoryTags.Signals = tag(DMT.Signals)
	self.RobloxMemoryTags.LuaHeap = tag(DMT.LuaHeap)
	self.RobloxMemoryTags.Script = tag(DMT.Script)
	self.RobloxMemoryTags.PhysicsCollision = tag(DMT.PhysicsCollision)
	self.RobloxMemoryTags.BasePasrts = tag(DMT.BaseParts)

	self.RobloxMemoryTags.Graphics.SolidModels = tag(DMT.GraphicsSolidModels)
	self.RobloxMemoryTags.Graphics.SlimModels = tag(DMT.GraphicsSlimModels)
	self.RobloxMemoryTags.Graphics.MeshParts = tag(DMT.GraphicsMeshParts)
	self.RobloxMemoryTags.Graphics.Particles = tag(DMT.GraphicsParticles)
	self.RobloxMemoryTags.Graphics.Parts = tag(DMT.GraphicsParts)
	self.RobloxMemoryTags.Graphics.SpatialHash = tag(DMT.GraphicsSpatialHash)
	self.RobloxMemoryTags.Graphics.Terrain = tag(DMT.GraphicsTerrain)
	
	self.RobloxMemoryTags.Graphics.Texture.Texture = tag(DMT.GraphicsTexture)
	self.RobloxMemoryTags.Graphics.Texture.Character = tag(DMT.GraphicsTextureCharacter)

	self.RobloxMemoryTags.Sounds.Sounds = tag(DMT.Sounds)
	self.RobloxMemoryTags.Sounds.Streaming = tag(DMT.StreamingSounds)
	self.RobloxMemoryTags.TerrainVoxels = tag(DMT.TerrainVoxels)
	self.RobloxMemoryTags.Gui = tag(DMT.Gui)
	self.RobloxMemoryTags.Animation = tag(DMT.Animation)
	self.RobloxMemoryTags.Navigation = tag(DMT.Navigation)
	self.RobloxMemoryTags.GeometryCSG = tag(DMT.GeometryCSG)

	return self
end

function Diagnostics.Memory() : MemoryDiag
	local self: MemoryDiag = nil

	update_memory(self)
	self.Sync = update_memory

	return self:Sync()
end

return Diagnostics :: Diagnostics 
