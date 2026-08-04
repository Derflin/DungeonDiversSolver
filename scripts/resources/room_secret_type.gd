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
@export var icon: Texture2D
@export var background: Texture2D
@export var animated_icon: SpriteFrames
@export var animated_background: SpriteFrames
