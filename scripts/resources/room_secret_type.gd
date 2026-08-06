class_name RoomSecretType
extends Resource

enum Kind {
	COMMON_ROOM = 10,
	HERMIT_ROOM = 20,
	GUEST_ROOM = 30,
	BARRICADE_ROOM = 40,
	ANGEL_ROOM = 50,
	DEVIL_ROOM = 60,
	BOULDER_ROOM = 70,
	PORTAL_ROOM = 80,
	BLACK_MARKET = 90,
	OUTSIDER_ROOM = 100,
	RED_ROOM = 110,
	ERROR_ROOM = 120,
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

@export_group("Animated Icon", "animated_")
@export var animated_icon: SpriteFrames
@export var animated_icon_variants: bool = true

@export_group("Animated Background", "animated_")
@export var animated_background: SpriteFrames
@export var animated_background_variants: bool = true
