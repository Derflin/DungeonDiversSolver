extends Node


signal map_secrets_count_max_changed(kind: RoomSecretType.Kind, value: int)
signal map_grid_size_parameter_changed()
signal map_grid_room_size_parameter_changed()


var map_secrets_count_max: Dictionary[RoomSecretType.Kind, int]


@export_group("Map Grid Parameters", "map_grid_")
@export var map_grid_size: Vector2i = Vector2i(17, 17):
	set(value):
		map_grid_size = value
		
		map_grid_size_parameter_changed.emit()
@export var map_grid_size_icon: Texture2D

@export var map_grid_room_size: Vector2i = Vector2i(15, 15):
	set(value): 
		map_grid_room_size = value
		
		map_grid_room_size_parameter_changed.emit()


func _ready() -> void:
	# Initialize map_secrets_count_max variable
	var secret_types_kinds = GameData.room_secret_types.get_all_kinds()
	for secret_type_kind in secret_types_kinds:
		map_secrets_count_max[secret_type_kind] = 0


func set_map_secrets_count_max(kind: RoomSecretType.Kind, value: int) -> void:
	if kind not in map_secrets_count_max or map_secrets_count_max[kind] != value:
		map_secrets_count_max[kind] = value
		map_secrets_count_max_changed.emit(kind, value)


func set_map_grid_size(size: int) -> void:
	map_grid_size = Vector2i(size, size)


#region Save Provider
# These functions expose this object's persistent state to the save system.

## Returns the unique key used to identify this Save Provider in save data.
func get_save_key() -> StringName:
	return &"game_settings"


## Captures this Save Provider's current persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	return {
		"map_secrets_count_max": map_secrets_count_max.duplicate(),
		"map_grid_size": map_grid_size,
		"map_grid_room_size": map_grid_room_size,
	}

## Restores this Save Provider's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	map_secrets_count_max = data["map_secrets_count_max"].duplicate()
	map_grid_size = data["map_grid_size"]
	map_grid_room_size = data["map_grid_room_size"]


## Captures this Save Provider's current persistant state in form of summary metadata for save data.
func capture_save_metadata() -> Array[Dictionary]:
	var save_metadata: Array[Dictionary] = [
		{
			"key": &"map_size",
			"value": "%d x %d" % [map_grid_size.x, map_grid_size.y],
		},
	]
	
	return save_metadata

#endregion
