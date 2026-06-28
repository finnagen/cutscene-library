--// REFERENCES \\--
local Source = script.Parent.Parent.Parent

--// DEPENDENCIES \\--
local Types = require(Source.Types)
local Utils = require(Source.Utilities)

--// MODULE \\--
local Model = {}

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
		if next_frame == nil and last_frame ~= nil and property == "CFrame" then
			self.item:PivotTo(last_frame.Values["0"].Value) 
			continue
		elseif next_frame == nil then
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
		
		local alpha
		if last_frame.Position == next_frame.Position then
			alpha = 1 
		else
			alpha = math.clamp((frame-pos) / (next_frame.Position - pos), 0, 1)
		end
		
		if property == "Scale" then
			self.item:ScaleTo(Utils.LerpValue(self.item, last_frame.TweenInfo, alpha, value, next_frame.Values["0"].Value))
		elseif property == "CFrame" then
 			self.item:PivotTo(Utils.LerpValue(self.item, last_frame.TweenInfo, alpha, value, next_frame.Values["0"].Value))
		else
			for _, part in self.item:GetDescendants() do
				if part:IsA("BasePart") then
					pcall(function()
						if property == "Transparency" then
							Utils.LerpKeyframe(part, last_frame.TweenInfo, alpha, "LocalTransparencyModifier", value, next_frame.Values["0"].Value)
						else
							Utils.LerpKeyframe(part, last_frame.TweenInfo, alpha, property, value, next_frame.Values["0"].Value)
						end
					end)
				end
			end
		end
	end
end

function ClassMethods.ToDefault(self: Class)
	for prop, default in self.properties do
		if prop == "CFrame" then
			self.item:PivotTo(default.Value)
		elseif prop == "Scale" then
			self.item:ScaleTo(default.Value)
		else
			for _, part in self.item:GetDescendants() do
				if part:IsA("BasePart") then
					pcall(function()
						if prop == "Transparency" then
							part.LocalTransparencyModifier = default.Value
						else
							part[prop] = default.Value
						end
					end)
				end
			end
		end
	end
end

function ClassMethods.Init(self: Class, cutscene: Types.Cutscene)
	self.cutscene = cutscene
	RegisterFrames(self)

	self.running = true
end

function ClassMethods.Destroy(self: Class)
	if self.running == true then
		self:ToDefault()
		self.running = false	
	end

	table.clear(self.keyframes)
	table.clear(self.properties)
	table.clear(self.unique_props)

	self.cutscene = nil
end

--// CONSTRUCTOR \\--
function Model.New(item: Instance, save: StringValue, pos: number): Class
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

return Model
