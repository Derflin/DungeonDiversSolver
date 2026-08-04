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
@export var icon: Texture2D
@export var background: Texture2D
