extends Node


signal map_secrets_count_max_changed(kind: RoomSecretType.Kind, value: int)
signal map_grid_size_parameter_changed(_map_grid_size: Vector2i)
signal map_grid_room_size_parameter_changed(_map_grid_room_size: Vector2i)


var map_secrets_count_max: Dictionary[RoomSecretType.Kind, int]


@export_group("Map Grid Parameters", "map_grid_")
@export var map_grid_size: Vector2i = Vector2i(17, 17):
	set(value):
		map_grid_size = value
		
		map_grid_size_parameter_changed.emit(map_grid_size)
@export var map_grid_size_icon: Texture2D

@export var map_grid_room_size: Vector2i = Vector2i(15, 15):
	set(value): 
		map_grid_room_size = value
		
		map_grid_room_size_parameter_changed.emit(map_grid_room_size)


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
