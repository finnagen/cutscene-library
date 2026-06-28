--// REFERENCES \\--
local Source = script.Parent.Parent.Parent

--// DEPENDENCIES \\--
local Types = require(Source.Types)
local Utils = require(Source.Utilities)

--// MODULE \\--
local Marker = {}

--// TYPES \\--
export type Class = Types.GenericInstanceClass

--// UNIQUE FUNCTIONS \\--
local function GetEvent(keyframes: {Types.MoonEvent}, pos: number): Types.MoonEvent?
	local last_event: Types.MoonEvent? = nil
	local last_event_dif: number? = nil
	for _, keyframe in keyframes do
		if keyframe.Activated == true then
			continue
		end
		
		local diff = pos - keyframe.Position
		if keyframe.Position <= pos and last_event == nil then
			last_event = keyframe
			last_event_dif = diff
		elseif keyframe.Position <= pos and diff < last_event_dif then
			last_event = keyframe
			last_event_dif = diff
		end
	end	
	
	return last_event
end

local function RegisterKeyframe(class: Class, frame: Folder)
	local pos = tonumber(frame.Name)
	if pos == nil then
		return
	end
	
	local codeBegin = frame:FindFirstChild("codeBegin") :: StringValue?
	local codeEnd = frame:FindFirstChild("codeEnd") :: StringValue?
	
	local begin_signal = codeBegin ~= nil
	local end_signal = codeEnd ~= nil
	
	local width = frame:FindFirstChild("width") :: NumberValue
	if width == nil then
		return
	end
	
	local num_width = width.Value
	
	local name = frame:FindFirstChild("name") :: StringValue
	local str_name = name and name.Value or frame.Name
	
	local keyframe: Types.MoonEvent = {
		Position = pos,
		Width = num_width,
		Name = str_name,
		
		Begin = begin_signal,
		End = end_signal,
		
		Activated = false,
	}
	
	table.insert(class.keyframes, keyframe)
end

local function RegisterFrames(class: Class)
	if class.running == true then
		return
	end
	
	for _, kf in class.item:GetChildren() do
		if kf:IsA("Folder") then
			RegisterKeyframe(class, kf)
		end
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
	local event = GetEvent(self.keyframes, math.floor(frame))
	
	if event == nil then
		return
	end
	
	event.Activated = true
	
	if event.Begin == true then
		self.cutscene._marker_reached_signal:Fire(event.Name, "begin")
	end
	
	if event.Width ~= 0 and event.End == true then
		task.delay(event.Width/100, function()
			self.cutscene._marker_reached_signal:Fire(event.Name, "end")
		end)
	elseif event.End == true then
		self.cutscene._marker_reached_signal:Fire(event.Name, "end")
	end
end

function ClassMethods.ToDefault(self: Class)
	
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
function Marker.New(item: Instance, save: StringValue): Class
	local props: Types.generic_class_props = {
		item = item,
		save = save,
		
		running = false,
		
		properties = {},
		keyframes = {},
		unique_props = {},
	}
	
	return setmetatable(props, ClassMethods)
end

return Marker
