--[[ all dependencies either open-source or made by me. they can be found in the "CutsceneChildren" folder :3
"signal": sletnik on https://sleitnick.github.io/RbxUtil/api/Signal/
the rest are made by yours truly]]

--// SERVICES \\--
local RunService = game:GetService("RunService")

--// DEPENDENCIES \\--
local types = require(script.Types)
local utils = require(script.Utilities)
local signal = require(script.Signal) 

local UpdateManager = require(script.UpdateManager)

--// TYPES \\--
export type Cutscene = types.Cutscene

--// MODULE \\--
local CutsceneLib = {}
local CutsceneMethods: types.cutscene_methods = {}
CutsceneMethods.__index = CutsceneMethods

--// STATIC VARIABLES \\--
local DEFAULT_FRAME_RATE = 30

--// METHODS \\--
function CutsceneMethods._FrameUpdate(self: Cutscene, dt: number)
	if self.Frame >= self.MaxFrames then
		self:End()
	elseif self.Playing == true then
		UpdateManager.UpdateClasses(self._classes)
	end
	
	self.Frame += self.FrameRate * dt
end

function CutsceneMethods._Cleanup(self: Cutscene, camera: boolean?)
	for k, t in self._tasks do
		t:Disconnect()
	end
	
	table.clear(self._tasks)
end

function CutsceneMethods._ProcessMarker(self: Cutscene, event: string, event_type: "begin" | "end")
	if self._marker_reached_listeners[event] then
		for _, callback in self._marker_reached_listeners[event] do
			callback(event_type)
		end
	end
end

function CutsceneMethods.Start(self: Cutscene)
	if self.Playing == true then
		return
	end
	
	self.Playing = true
	self.Frame = 0
	
	self._tasks._timer_conn = RunService.PreRender:Connect(function(dt)
		self:_FrameUpdate(dt)
	end)

	UpdateManager.InitializeClasses(self)
end

function CutsceneMethods.End(self: Cutscene, force: boolean)
	if self.Playing ~= true then
		return
	end
	
	self.Playing = false

	self:_Cleanup()
	self.Frame = 0
	
	if self.HoldAtEnd ~= true then
		UpdateManager.DefaultClasses(self._classes)
	end

	self.Ended:Fire()
	if self.Looped == true and force ~= true then
		self:Start()
	end
end

function CutsceneMethods.Destroy(self: Cutscene)
	if self.Playing == true then
		self:End(true)
	end

	table.clear(self._marker_reached_listeners)
	self._marker_reached_connection:Disconnect()
	
	self._marker_reached_signal:Destroy()
	self.Ended:Destroy()
	
	UpdateManager.DestroyClasses(self._classes)
	table.clear(self._classes)
end

function CutsceneMethods.MarkerReached(self: Cutscene, event: string, callback: (event_type: "begin" | "end") -> ())
	if self._marker_reached_listeners[event] == nil then
		self._marker_reached_listeners[event] = {}
	end
	
	table.insert(self._marker_reached_listeners[event], callback)
end

--// CONSTRUCTOR \\--
function CutsceneLib.New(moon_save: StringValue, args: {FrameRate: number?, Replacements: {[string]: Instance}?}?, HoldAtEnd: boolean?): Cutscene
	args = args or {}
	
	local save_info = utils.GetSaveInformation(moon_save)
	local cutscene_props: types.cutscene_props = {
		Playing = false,
		Looped = save_info.Looped,
		
		Ended = signal.new(),
		
		FrameRate = args.FrameRate or DEFAULT_FRAME_RATE,
		Frame = 0,
		MaxFrames = save_info.Length,
		
		HoldAtEnd = HoldAtEnd == true,
		
		_replacements = args.Replacements or {},
		
		_marker_reached_signal = signal.new(),
		_marker_reached_listeners = {},
		_save = moon_save,
		
		_tasks = {}
	}
	
	local self: Cutscene = setmetatable(cutscene_props, CutsceneMethods)

	self._marker_reached_connection = self._marker_reached_signal:Connect(function(event, event_type)
		self:_ProcessMarker(event, event_type)
	end)
	self._classes = UpdateManager.RegisterInstances(self)
	
	return self
end

return CutsceneLib
