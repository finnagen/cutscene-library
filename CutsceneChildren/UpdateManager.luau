--// REFERENCES \\--
local InstanceClasses = script.InstanceClasses -- folder under CutsceneChildren

--// DEPENDENCIES \\--
local Types = require(script.Parent.Types)
local Utils = require(script.Parent.Utilities)

local Classes = {
	Base = require(InstanceClasses.Base),
	Model = require(InstanceClasses.Model),
	Camera = require(InstanceClasses.Camera),
	MarkerTrack = require(InstanceClasses.MarkerTrack),
	Rig = require(InstanceClasses.Rig),
}

--// MODULE \\--
local UpdateManager = {}

--// REGISTRY FUNCTIONS \\--
function UpdateManager._RegisterInstance(item: Types.item, save: StringValue, pos: number, replacements: {[string]: Instance}): Types.GenericInstanceClass?
	local path = item.Path
	
	local obj 

	local replacement = replacements[path.InstanceNames[#path.InstanceNames]]
	if replacement ~= nil then
		obj = replacement
	else
		obj = Utils.GetItemByPath(path, true)

		if obj == nil then
			return
		end
	end	
	
	local item_type = path.ItemType
	local mod = Classes[item_type]
	
	if mod == nil then
		mod = Classes.Base
	end
	
	return mod.New(obj, save, pos)
end

function UpdateManager.RegisterInstances(cutscene: Types.Cutscene): {Types.GenericInstanceClass}
	local save = cutscene._save
	local decoded_save = Utils.DecodeMoonSave(save)
	local classes = {}
	
	for i, item in ipairs(decoded_save.Items) do
		local class = UpdateManager._RegisterInstance(item, save, i, cutscene._replacements)
		if class ~= nil then
			table.insert(classes, class)
		end
	end
	
	for _, marker in ipairs(save:GetDescendants()) do
		if marker.Name == "MarkerTrack" and marker:IsA("Folder") then
			table.insert(classes, Classes.MarkerTrack.New(marker, save))
		end
	end
	
	return classes
end

--// CLASS FUNCTIONS \\--
function UpdateManager.InitializeClasses(cutscene: Types.Cutscene)
	local classes = cutscene._classes
	for _, class in classes do
		class:Init(cutscene)
	end
end

function UpdateManager.UpdateClasses(classes: {Types.GenericInstanceClass})
	for _, class in classes do
		class:Update()
	end
end

function UpdateManager.DestroyClasses(classes: {Types.GenericInstanceClass})
	for _, class in classes do
		class:Destroy()
	end
end

function UpdateManager.DefaultClasses(classes: {Types.GenericInstanceClass})
	for _, class in classes do
		class:ToDefault()
	end
end

return UpdateManager
