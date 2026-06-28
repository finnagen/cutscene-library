--// REFERENCES \\--
local Source = script.Parent.Parent.Parent

--// DEPENDENCIES \\--
local Types = require(Source.Types)
local Utils = require(Source.Utilities)

--// MODULE \\--
local Rig = {}

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

local function RegisterFrame(class: Class, frame: Folder, property: string)
	local pos = tonumber(frame.Name)
	if pos == nil then
		return
	end
	
	local kf: Types.MoonKeyframe = {
		Position = pos,
		Property = property,
		Folder = frame,
		Values = frame.Values,
	}
	
	table.insert(class.keyframes, kf)
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

	for _, kf in property:GetChildren() do
		if kf:IsA("Folder") then
			RegisterFrame(class, kf, str_prop)
		end
	end

	for _, kf in class.keyframes do
		kf.TweenInfo = Utils.GetTweenInfo(kf, GetNextKeyframe(kf, class.keyframes), class.cutscene.FrameRate)
	end
end

local function CreateJointKeyframes(keyframes: Folder,fr: number): {Types.RigJointKeyframe}
	local frames: {Types.RigJointKeyframe} = {}
	
	for _, frame in keyframes:GetChildren() do
		if frame:IsA("Folder") ~= true then
			continue
		end
		
		local num = tonumber(frame.Name)
		if num == nil then
			continue
		end
		
		local values = frame:FindFirstChild("Values")
		if values == nil then
			continue
		end
		
		local kf: Types.RigJointKeyframe = {
			Position = num,
			Values = values,
			Folder = frame,
		}
		
		table.insert(frames, kf)
	end
	
	for _, kf in frames do
		kf.TweenInfo = Utils.GetTweenInfo(kf, GetNextKeyframe(kf, frames), fr)
	end
	
	return frames
end

local function CreateJoint(joint: Folder, root: Model, fr: number): Types.RigJoint
	local hier = joint:FindFirstChild("_hier") :: StringValue?
	if hier == nil then
		return
	end
	
	local keyframes = joint:FindFirstChild("_keyframes") :: Folder?
	if keyframes == nil then
		return
	end
	
	local default = joint:FindFirstChild("default") :: CFrameValue?
	if default == nil then
		return
	end
	
	local joint = Utils.GetJointByPath(root, hier.Value, 1, 0.2)
	local use_bone = false
	if joint == nil or not joint:IsA("Motor6D") then
		use_bone = true
		
		joint = Utils.FindBone(root, hier.Value)
		
		if joint == nil or joint:IsA("Bone") == false then
			return
		end
	end
	
	local rig_joint: Types.RigJoint = {
		Default = default.Value,
		Joint = joint,
		UseBone = use_bone,
		Keyframes = CreateJointKeyframes(keyframes, fr),
	}
	
	return rig_joint
end

local function HandleRig(class: Class, rig: Folder)
	local joints: {Types.RigJoint} = {}
	
	for _, joint in rig:GetChildren() do
		if joint:IsA("Folder") then
			local rig_joint = CreateJoint(joint, class.item, class.cutscene.FrameRate)
			if rig_joint == nil then
				continue
			end
			
			table.insert(joints, rig_joint)
		end
	end
	
	class.unique_props.rig_joints = joints
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
		if property.Name == "Rig" then
			HandleRig(class, property)
		else
			HandleProperty(class, property)
		end
	end
end

local function GetEdgeGroup(group: {CFrameValue}, frame: number): (CFrameValue?, CFrameValue?)
	local last = nil
	local next_f = nil

	for _, val in group do
		local frame_pos = tonumber(val.Name)
		if frame_pos == nil then
			continue
		end
		
		if frame_pos <= frame and (last == nil or tonumber(last.Name) < frame_pos) then
			last = val
		elseif frame_pos >= frame and (next_f == nil or tonumber(next_f.Name) > frame_pos) then
			next_f  = val
		end
	end

	return last, next_f
end

local function HandleGroup(kf: Types.RigJointKeyframe, joint: Motor6D | Bone, default: CFrame?, group: {CFrameValue}, frame: number, use_bone: boolean)
	local last_val, next_val = GetEdgeGroup(group, frame - kf.Position)
	local tween_info = kf.TweenInfo
	
	if next_val == nil then
		return
	end
	
	local pos
	local val
	
	if last_val == nil then
		if default == nil then
			return
		end
		
		val = default
	else
		pos = tonumber(last_val.Name)
		val = last_val.Value
	end
	
	local alpha
	if pos == tonumber(next_val.Name) then
		alpha = 1 
	else
		alpha = math.clamp((frame-pos) / (tonumber(next_val.Name) - pos), 0, 1)
	end
	
	local prop = use_bone and "Transform" or "C1"
	Utils.LerpKeyframe(joint, tween_info, alpha, prop, val, next_val.Value, default)
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
		if next_frame == nil then
			next_frame = last_frame
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
		
		if property == "CFrame" then
			self.item:PivotTo(Utils.LerpValue(self.item, last_frame.TweenInfo, alpha, value, next_frame.Values["0"].Value))
		elseif property == "Scale" then
			self.item:ScaleTo(Utils.LerpValue(self.item, last_frame.TweenInfo, alpha, value, next_frame.Values["0"].Value))
		elseif property == "Transparency" then
			for _, part in self.item:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					Utils.LerpKeyframe(part, last_frame.TweenInfo, alpha, "LocalTransparencyModifier", value, next_frame.Values["0"].Value)
				end
			end
		else
			for _, part in self.item:GetDescendants() do
				if part:IsA("BasePart") then
					Utils.LerpKeyframe(part, last_frame.TweenInfo, alpha, property, value, next_frame.Values["0"].Value)
				end
			end
		end
	end
	
	for _, joint: Types.RigJoint in self.unique_props.rig_joints do
		local frames = joint.Keyframes
		if #frames == 0 then
			continue
		end
		
		local last_frame, next_frame = GetEdgeFrames(frames, frame)
		
		if last_frame and #last_frame.Values:GetChildren() > 1 then
			HandleGroup(last_frame, joint.Joint, joint.Default, last_frame.Values:GetChildren(), frame, joint.UseBone)
			continue
		end
		
		if next_frame == nil then
			continue
		end
		
		local pos
		local value
		local tween_info: Types.KeyframeEase
		
		local default = joint.Default

		if last_frame == nil then
			if default == nil then
				continue
			end

			pos = 0
			value = default
			tween_info = {Time = 0, EasingFunction = Utils.EasingFunctions.LinearOut}
		else
			tween_info = last_frame.TweenInfo
			pos = last_frame.Position
			value = last_frame.Values["0"].Value
		end

		local alpha
		if pos == next_frame.Position then
			alpha = 1 
		elseif next_frame then
			alpha = math.clamp((frame-pos) / (next_frame.Position - pos), 0, 1)
		end
		
		local prop = joint.UseBone and "Transform" or "C1"
		Utils.LerpKeyframe(joint.Joint, tween_info, alpha, prop, value, next_frame.Values["0"].Value, default)
	end
end

function ClassMethods.ToDefault(self: Class)
	for property, default in self.properties do
		if default == nil or default.Value == nil then
			continue
		end
		
		if property == "CFrame" then
			self.item:PivotTo(default.Value)
		elseif property == "Scale" then
			self.item:ScaleTo(default.Value)
		elseif property == "Transparency" then
			for _, part in self.item:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = default.Value
				end
			end
		else
			for _, part in self.item:GetDescendants() do
				if part:IsA("BasePart") then
					pcall(function()
						part[property] = default.Value
					end)
				end
			end
		end
	end
	
	for _, joint: Types.RigJoint in self.unique_props.rig_joints do
		if joint.Default == nil then
			continue
		end
		
		local property = joint.UseBone and "Transform" or "C1"
		joint.Joint[property] = joint.Default
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
function Rig.New(item: Instance, save: StringValue, pos: number): Class
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

return Rig
