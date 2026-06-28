local signal_temp = require(script.Parent.Signal)
type event_signal = signal_temp.Signal<string, "begin" | "end">
type ended_signal = signal_temp.Signal<>
type connection = signal_temp.Connection
signal_temp = nil -- signal defining

-- CUTSCENE --
export type cutscene_props = {
	Playing: boolean,
	Looped: boolean,
	
	Ended: ended_signal,
	
	FrameRate: number,
	Frame: number,
	MaxFrames: number,
	
	HoldAtEnd: boolean,
	
	_save: StringValue,
	_classes: {GenericInstanceClass},
	
	_replacements: {[string]: Instance},
	
	_marker_reached_signal: event_signal,
	_marker_reached_connection: connection,
	_marker_reached_listeners: {[string]: {("begin" | "end") -> ()}},
	
	_tasks: {
		_timer_conn: any?,
	},
}
export type cutscene_methods = {
	_FrameUpdate: (self: Cutscene, dt: number) -> (),
	_Cleanup: (self: Cutscene) -> (),
	_ProcessMarker: (self: Cutscene, event: string, event_type: "begin" | "end") -> (),
	
	Start: (self: Cutscene) -> (),
	End: (self: Cutscene, force: boolean?) -> (),
	Destroy: (self: Cutscene) -> (),
	
	MarkerReached: (self: Cutscene, event: string, callback: (event_type: "begin" | "end") -> ()) -> (),
}

export type Cutscene = cutscene_props & cutscene_methods

-- MOON SAVE STRUCTURE --
export type save_info = {
	Created: number,
	Modified: number,
	
	Length: number,
	Looped: boolean,
	
	ExportPriority: number,
}

export type item_path = {
	InstanceTypes: {string},
	InstanceNames: {string},
	
	ItemType: string,
}

export type item = {
	Path: item_path
}

export type MoonSave = {
	Information: save_info,
	Items: {item}
}

-- INSTANCE CLASS --
export type MoonKeyframe = {
	Property: string,
	Values: Folder,
	Folder: Folder,
	Position: number,
	TweenInfo: KeyframeEase,
}

export type MoonEvent = {
	Position: number,
	Name: string,
	Width: number,
	
	Begin: boolean,
	End: boolean,
	
	Activated: boolean,
}

export type DefaultKeyframe = {
	Value: any,
	TweenInfo: KeyframeEase,
}

export type RigJointKeyframe = {
	Position: number,
	Folder: Folder,
	Values: Folder,
	TweenInfo: KeyframeEase,
}

export type RigJoint = {
	Keyframes: {RigJointKeyframe},
	Joint: Motor6D | Bone,
	UseBone: boolean,
	Default: CFrame,
}

export type KeyframeEase = {
	Time: number,  
	EasingFunction: (...any) -> ...any,
	Extra_1: any?, 
	Extra_2: any?
}

export type generic_class_props = {
	item: Instance,
	save: StringValue,
	pos: number,
	
	running: boolean,
	cutscene: Cutscene,
	
	properties: {[string]: DefaultKeyframe},
	keyframes: {MoonKeyframe},
	unique_props: {[string]: any}
}

export type generic_class_methods = {
	Update: (self: GenericInstanceClass, ...any) -> (),
	ToDefault: (self: GenericInstanceClass) -> (),
	
	Destroy: (self: GenericInstanceClass) -> (),
	Init: (self: GenericInstanceClass, cutscene: Cutscene) -> (),
}

export type GenericInstanceClass = generic_class_props & generic_class_methods

return {}
