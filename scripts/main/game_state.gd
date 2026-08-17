extends Node


signal map_secrets_count_current_changed(kind: RoomSecretType.Kind, value: int)


var map_secrets_count_current: Dictionary[RoomSecretType.Kind, int]


func _ready() -> void:
	# Initialize map_secrets_count_max variable
	var secret_types_kinds = GameData.room_secret_types.get_all_kinds()
	for secret_type_kind in secret_types_kinds:
		map_secrets_count_current[secret_type_kind] = 0


func set_map_secrets_count_current(kind: RoomSecretType.Kind, value: int) -> void:
	if kind not in map_secrets_count_current or map_secrets_count_current[kind] != value:
		map_secrets_count_current[kind] = value
		map_secrets_count_current_changed.emit(kind, value)
