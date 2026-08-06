class_name RoomSpecialType
extends Resource


enum Kind {
	ARENA = 10,
	BOSS = 20,
	ENTRANCE = 30,
	LIBRARY = 40,
	SHOP = 50,
	TREASURE = 60,
}


@export var kind: Kind
@export var id: StringName
@export var display_name: String

@export_group("Icon")
@export var icon: Texture2D
@export_range(1.0, 128.0, 1.0)
var icon_hframes: int = 1
@export_range(1.0, 128.0, 1.0)
var icon_vframes: int = 1
@export_range(0.0, 127.0, 1.0)
var icon_frame: int = 0

@export_group("Background")
@export var background: Texture2D
@export_range(1.0, 128.0, 1.0)
var background_hframes: int = 1
@export_range(1.0, 128.0, 1.0)
var background_vframes: int = 1
@export_range(0.0, 127.0, 1.0)
var background_frame: int = 0
