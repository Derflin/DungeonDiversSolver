class_name RoomCorridorType
extends Resource

enum Kind {
	BASE = 10,
}


@export var kind: Kind

@export var id: StringName
@export var display_name: String

@export_group("Floor")
@export var floor_variants: SpriteFrames

@export_group("Connections")
@export var connections_texture: Texture2D

@export_group("Barricades")
@export var barricades_texture: Texture2D
