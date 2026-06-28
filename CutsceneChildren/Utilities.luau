--// SERVICES \\--
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

--// DEPENDENCIES \\--
local Types = require(script.Parent.Types)
local EasingFunctions = require(script.EasingFunctions) -- this is under the CutsceneChildren folder as the name "EasingFunctions.luau"

--// MODULE \\--
local Utilities = {}

--// REFERENCES \\--
local VFXFolder = RunService:IsClient() and Players.LocalPlayer.PlayerGui or StarterGui

--// UTILITIES \\---
Utilities.EasingFunctions = EasingFunctions

---// SAVE RETRIEVAL/DECODING
function Utilities.DecodeMoonSave(save: StringValue): Types.MoonSave
	local json = save.Value
	local decoded = HttpService:JSONDecode(json)
	
	return decoded
end

function Utilities.GetSaveInformation(save: StringValue): Types.save_info
	local save = Utilities.DecodeMoonSave(save)
	return save.Information
end

--// KEYFRAME (logic from https://devforum.roblox.com/t/module-script-moon-animator-2-to-in-game-animations/3178584)
local function LerpNumber(StartValue, EndValue, Alpha)
	return StartValue + (EndValue - StartValue) * Alpha
end

local function LerpString(StartValue, EndValue, Alpha)
	return Alpha >= 0.5 and EndValue or StartValue
end

local function LerpBoolean(StartValue, EndValue, Alpha)
	return Alpha >= 0.5 and EndValue or StartValue
end

local function BuiltinLerp(StartValue, EndValue, Alpha)
	return StartValue:Lerp(EndValue, Alpha)
end

local function MotorLerp(StartValue, EndValue, Alpha, Default)
	return ((StartValue:ToObjectSpace(Default)):Lerp(EndValue:ToObjectSpace(Default), Alpha) * Default:Inverse()):Inverse()
end

local InterpolationFunctions = {
	number = LerpNumber,
	string = LerpString,
	boolean = LerpBoolean
}

function Utilities.LerpKeyframe(obj: Instance, ease_info: Types.KeyframeEase, alpha: number, prop: string, start_val: any, end_val: any, extra: any?)
	local lerp_func
	
	if obj:IsA("Motor6D") then
		lerp_func = MotorLerp
	else
		lerp_func = InterpolationFunctions[typeof(end_val)] or BuiltinLerp
	end
	
	local ease_alpha = ease_info.EasingFunction(alpha, ease_info.Extra_1, ease_info.Extra_2)
	local lerp_val = lerp_func(start_val, end_val, ease_alpha, extra)
	
	obj[prop] = lerp_val
end

function Utilities.LerpValue(obj: Instance, ease_info: Types.KeyframeEase, alpha: number, start_val: any, end_val: any, extra: any?)
	local lerp_func

	if obj:IsA("Motor6D") then
		lerp_func = MotorLerp
	else
		lerp_func = InterpolationFunctions[typeof(end_val)] or BuiltinLerp
	end

	local ease_alpha = ease_info.EasingFunction(alpha, ease_info.Extra_1, ease_info.Extra_2)
	local lerp_val = lerp_func(start_val, end_val, ease_alpha, extra)
	
	return lerp_val
end

function Utilities.GetTweenInfo(frame: Types.MoonKeyframe, next_frame: Types.MoonKeyframe, fr: number): Types.KeyframeEase
	if next_frame == nil then
		return {
			Time = 1,
			EasingFunction = EasingFunctions.LinearIn
		}
	end
	
	local ease_time = (next_frame.Position-frame.Position)/fr
	local KeyframeEase: Types.KeyframeEase = {Time = ease_time, EasingFunction = EasingFunctions.LinearIn}
	
	local values = frame.Values
	if values == nil then
		return KeyframeEase
	end
	
	local eases = frame.Folder:FindFirstChild("Eases") :: Folder
	if eases == nil then
		return KeyframeEase
	end
	
	local all_values = values:GetChildren()
	if #all_values == 0 then
		return KeyframeEase
	end
	
	local def = all_values[1]
	local ease = eases:FindFirstChild(def.Name)
	
	if ease ~= nil then
		local ease_type = ease:FindFirstChild("Type")
		local ease_style = (ease and ease_type.Value) or "Linear"

		local ease_params = ease:FindFirstChild("Params")
		local ease_dir = "In"
		local Extra1, Extra2

		if ease_params then -- all of this from previously mentioned module
			local Direction = ease_params:FindFirstChild("Direction")
			if Direction then ease_dir = Direction.Value end

			local Overshoot = ease_params:FindFirstChild("Overshoot")
			local Amplitude = ease_params:FindFirstChild("Amplitude")
			local Period = ease_params:FindFirstChild("Period")

			if Overshoot then Extra1 = Overshoot.Value end
			if Amplitude then Extra1 = Amplitude.Value end
			if Period then Extra2 = Period.Value end
		end
		
		KeyframeEase = {
			Time = ease_time,
			EasingFunction = EasingFunctions[ease_style .. ease_dir] or EasingFunctions.LinearIn,
			Extra_1 = Extra1,
			Extra_2 = Extra2
		}
	end
	
	return KeyframeEase
end

--// INSTANCE
function Utilities.GetItemByPath(path: Types.item_path, wait_for_instance: boolean?, timeout: number?): Instance?
	if path.ItemType == "Camera" then
		return workspace.CurrentCamera
	end
	
	local instance_names = path.InstanceNames
	local instance_types = path.InstanceTypes
	
	local curr_instance = game
	for i=2, #instance_names do
		local name = instance_names[i]
		local i_type = instance_types[i]
		
		--- add effects handling
		
		local found
		if wait_for_instance == true then
			found = curr_instance:WaitForChild(name, timeout or 5)
		else
			found = curr_instance:FindFirstChild(name)
		end
		
		if found ~= nil and found:IsA(i_type) then
			curr_instance = found
		else
			return
		end
	end
	
	return curr_instance
end

function Utilities._GetJointByPathInternal(root: Model, p1_name: string, p0_name: string?)
	for _, desc in root:GetDescendants() do
		if desc:IsA("Motor6D") then
			local p0 = desc.Part0.Name
			local p1 = desc.Part1.Name

			local p0_exists = p0_name ~= nil
			local is_motor = p0_exists and (p0 == p0_name and p1 == p1_name) or p1 == p1_name

			if is_motor then
				return desc
			end
		end
	end
end

function Utilities.GetJointByPath(root: Model, hier: string, max_attempts: number?, wait_time: number?): Motor6D?
	local p_table = string.split(hier, ".")
	
	local p0_name
	local p1_name
	
	if #p_table == 1 then
		p1_name = p_table[1]
	elseif #p_table > 1 then
		p0_name = p_table[#p_table - 1]
		p1_name = p_table[#p_table]
	else
		return
	end
	
	max_attempts = max_attempts or 10
	wait_time = wait_time or 0.5
	
	local attempts = 1
	local found_motor = Utilities._GetJointByPathInternal(root, p1_name, p0_name)
	
	while found_motor == nil and attempts < max_attempts do
		task.wait(wait_time)
		found_motor = Utilities._GetJointByPathInternal(root, p1_name, p0_name)
		
		attempts += 1
	end
	
	return found_motor
end

function Utilities.FindBone(root: Instance, hier: string)
	local found_bone
	if hier:find("%.") then
		local bone_name = hier:match("([^%.]+)$")
		found_bone = root:FindFirstChild(bone_name, true) or root:FindFirstChild("Bone."..bone_name, true)
		
		if found_bone == nil then
			local path = hier:gsub("^[^%.]+%.", "")
			found_bone = root:FindFirstChild(path, true) or root:FindFirstChild("Bone."..path, true)
			
			if found_bone == nil then
				local parts = hier:split(".")
				for i = #parts, 1, -1 do
					local partial_bone_name = table.concat(parts, ".", i)
					found_bone = root:FindFirstChild(partial_bone_name, true) or root:FindFirstChild("Bone."..partial_bone_name, true)
					
					if found_bone ~= nil then
						break
					end
				end
			end
		end
	else
		local parts = string.split(hier, ".")
		local bone_name = parts[#parts]

		found_bone = root:FindFirstChild(bone_name, true) or root:FindFirstChild("Bone."..bone_name, true)
	end
	
	return found_bone
end

return Utilities
