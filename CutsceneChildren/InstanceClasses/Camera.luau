--// REFERENCES \\--
local Source = script.Parent.Parent.Parent

--// DEPENDENCIES \\--
local Types = require(Source.Types)
local Utils = require(Source.Utilities)

--// MODULE \\--
local Camera = {}

--// TYPES \\--
export type Class = Types.GenericInstanceClass

--// UNIQUE FUNCTIONS \\--
local function GetKeyframesInProperty(class: Class, property: string)
	local frames = {}
	
	for _, kf in class.keyframes do
		if kf.Property == property then
			table.insert(frames, kf)
		end
	end	
	
	return frames
end

local function GetKeyframes(class: Class, frame: number)
	local frames = {}
	
	for _, kf in class.keyframes do
		if kf.Position == frame then
			table.insert(frames, kf)
		end
	end
	
	return frames
end

local function GetNextKeyframe(frame: Types.MoonKeyframe, keyframes: {Types.MoonKeyframe}): Types.MoonKeyframe?
	local next_frame = nil
	
	for _, keyframe in keyframes do
		local pos = keyframe.Position
		if keyframe.Property == frame.Property and pos >= frame.Position and (next_frame == nil or pos < next_frame.Position) then
			next_frame = keyframe
		end
	end
	
	return next_frame
end

local function GetEdgeFrames(frames: {Types.MoonKeyframe}, pos: number): (Types.MoonKeyframe?, Types.MoonKeyframe?)
	local last = nil
	local next_f = nil
	
	for _, frame in frames do
		local frame_pos = frame.Position
		
		if frame_pos <= pos and (last == nil or last.Position < frame_pos) then
			last = frame
		elseif frame_pos >= pos and (next_f == nil or next_f.Position > frame_pos) then
			next_f  = frame
		end
	end
	
	return last, next_f
end

local function RegisterFrame(class: Class, kf: Folder, property: string) 
	local frame_num = tonumber(kf.Name)
	if frame_num == nil then
		return
	end
	
	local frame: Types.MoonKeyframe = {
		Property = property,
		Folder = kf,
		Values = kf.Values,
		Position = frame_num,
	}
	
	table.insert(class.keyframes, frame)
end

local function RegisterDefaultFrame(class: Class, default: ValueBase, property: string)
	local default_frame: Types.DefaultKeyframe = {
		Value = default.Value,
		TweenInfo = {Time = 1, EasingFunction = Utils.EasingFunctions.LinearIn}
	}
	
	class.properties[property] = default_frame
end

local function HandleProperty(class: Class, property: Folder)
	local str_prop = property.Name
	if str_prop == "MarkerTrack" then
		return
	end
	
	local default = property:FindFirstChild("default")
	
	if default ~= nil then
		RegisterDefaultFrame(class, default, str_prop)
	else
		class.properties[str_prop] = {}
	end
	
	if str_prop == "AttachToPart" or str_prop == "LookAtPart" then
		class.item.CameraType = Enum.CameraType.Scriptable
	end

	for _, kf in property:GetChildren() do
		if kf:IsA("Folder") then
			RegisterFrame(class, kf, str_prop)
		end
	end

	for _, kf in class.keyframes do
		kf.TweenInfo = Utils.GetTweenInfo(kf, GetNextKeyframe(kf, class.keyframes), class.cutscene.FrameRate)
	end
end

local function RegisterFrames(class: Class)
	if class.running == true then
		return
	end
	
	local frame = class.save:FindFirstChild(tostring(class.pos))
	if frame == nil then
		return
	end
	
	for _, property in frame:GetChildren() do
		HandleProperty(class, property)
	end
end

local function LookAtPart(camera: Camera, part: BasePart)
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, part.Position)
end

--// CLASS METHODS \\--
local ClassMethods: Types.generic_class_methods = {}
ClassMethods.__index = ClassMethods

function ClassMethods.Update(self: Class)
	if self.running == false then
		return
	end
	
	local frame = self.cutscene.Frame
	
	for property, default in self.properties do
		local frames = GetKeyframesInProperty(self, property)
		if #frames == 0 then
			continue
		end
		
		local last_frame, next_frame = GetEdgeFrames(frames, frame)
		if next_frame == nil and property ~= "AttachToPart" then
			continue
		elseif last_frame ~= nil and property == "AttachToPart" then
			self.item:PivotTo(last_frame.Values["0"].Value.CFrame)
			continue
		elseif last_frame ~= nil and property == "LookAtPart" then
			LookAtPart(self.item, last_frame.Values["0"].Value)
			continue
		end
		
		local pos
		local value
		
		if last_frame == nil then
			if default.Value == nil then
				continue
			end
			
			last_frame = default
			pos = 0
			value = default.Value
		else
			pos = last_frame.Position
			value = last_frame.Values["0"].Value
		end
		
		if property == "AttachToPart" and next_frame.Position == frame then
			self.item:PivotTo(next_frame.Values["0"].Value.CFrame)
			continue
		elseif property == "LookAtPart" and next_frame.Position == frame then
			LookAtPart(self.item, next_frame.Values["0"].Value)
			continue
		end
		
		local alpha
		if last_frame.Position == next_frame.Position then
			alpha = 1 
		else
			alpha = math.clamp((frame-pos) / (next_frame.Position - pos), 0, 1)
		end
		
		pcall(function()
			Utils.LerpKeyframe(self.item, last_frame.TweenInfo, alpha, property, value, next_frame.Values["0"].Value)
		end)
	end
end

function ClassMethods.ToDefault(self: Class)
	for property, default in self.properties do
		if property == "AttachToPart" or property == "LookAtPart" then
			self.item.CameraType = self.unique_props.CameraType or Enum.CameraType.Custom
			continue
		end
		
		pcall(function()
			self.item[property] = default.Value
		end)
	end
end

function ClassMethods.Init(self: Class, cutscene: Types.Cutscene)
	self.cutscene = cutscene
	self.unique_props.CameraType = self.item.CameraType
	RegisterFrames(self)

	self.running = true
end

function ClassMethods.Destroy(self: Class, to_default: boolean?)
	if self.running == true then
		self.running = false	
	end
	
	if self.running == true and to_default ~= false then
		self:ToDefault()
	end

	table.clear(self.keyframes)
	table.clear(self.properties)
	table.clear(self.unique_props)

	self.cutscene = nil
end

--// CONSTRUCTOR \\--
function Camera.New(item: Instance, save: StringValue, pos: number): Class
	local props: Types.generic_class_props = {
		item = item,
		save = save,
		pos = pos,
		
		running = false,
		
		properties = {},
		keyframes = {},
		unique_props = {},
	}
	
	return setmetatable(props, ClassMethods)
end

return Camera
