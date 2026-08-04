extends Node

@export_group("Room Catalogs")
@export var room_corridor_types: RoomCorridorCatalog
@export var room_secret_types: RoomSecretCatalog
@export var room_special_types: RoomSpecialCatalog


func _ready() -> void:
	assert(
		room_corridor_types != null,
		"GameData is missing its RoomCorridorCatalog"
	)
	assert(
		room_secret_types != null,
		"GameData is missing its RoomSecretCatalog"
	)
	assert(
		room_special_types != null,
		"GameData is missing its RoomSpecialCatalog"
	)
