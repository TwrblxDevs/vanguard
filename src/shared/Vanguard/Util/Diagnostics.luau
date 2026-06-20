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

export type Diagnostics = {}


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

	self:Sync()
	return self
end

return Diagnostics
