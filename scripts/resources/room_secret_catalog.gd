class_name RoomSecretCatalog
extends Resource

@export var room_types: Array[RoomSecretType] = []


func get_type(kind: RoomSecretType.Kind) -> RoomSecretType:
	if kind == RoomSecretType.Kind.NONE:
		return null
	
	for room_type in room_types:
		if room_type == null:
			continue
			
		if room_type.kind == kind:
			return room_type
			
	push_error(
		"%s does not contain room type: %d" % [get_script().get_global_name(), kind]
	)
	return null


func get_type_by_id(type_id: String) -> RoomSecretType:
	for room_type in room_types:
		if room_type == null:
			continue
			
		if room_type.id == type_id:
			return room_type
			
	push_error(
		"%s does not contain room type with id: %d" % [get_script().get_global_name(), type_id]
	)
	return null


func has_type(kind: RoomSecretType.Kind) -> bool:
	return get_type(kind) != null
	

func get_all() -> Array[RoomSecretType]:
	return room_types.duplicate()
 

func get_all_kinds() -> Array[RoomSecretType.Kind]:
	var result: Array[RoomSecretType.Kind] = []
	for room_type in room_types:
		if room_type == null:
			continue
			
		if room_type.kind not in result:
			result.append(room_type.kind)
			
	return result
