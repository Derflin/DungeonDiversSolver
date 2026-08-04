class_name RoomCorridorCatalog
extends Resource

@export var room_types: Array[RoomCorridorType] = []


func get_type(kind: RoomCorridorType.Kind) -> RoomCorridorType:
	for room_type in room_types:
		if room_type == null:
			continue
			
		if room_type.kind == kind:
			return room_type
			
	push_error(
		"%s does not contain room type: %d" % [get_script().get_global_name(), kind]
	)
	return null


func has_type(kind: RoomCorridorType.Kind) -> bool:
	return get_type(kind) != null
	

func get_all() -> Array[RoomCorridorType]:
	return room_types.duplicate()
 

func get_all_kinds() -> Array[RoomCorridorType.Kind]:
	var result = []
	for room_type in room_types:
		if room_type == null:
			continue
			
		if room_type.kind not in result:
			result.append(room_type.kind)
			
	return result
