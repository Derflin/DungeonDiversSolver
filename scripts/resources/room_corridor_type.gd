class_name RoomCorridorType
extends Resource

enum Kind {
	BASE = 10,
}


@export var kind: Kind

@export var id: StringName
@export var display_name: String

@export_group("Floor", "floor_")
@export var floor_variants: SpriteFrames

@export_group("Connections", "connections_")
@export var connections_texture: Texture2D
@export_range(1.0, 128.0, 1.0)
var connections_texture_hframes: int = 8
@export_range(1.0, 128.0, 1.0)
var connections_texture_vframes: int = 1

@export_group("Barricades", "barricades_")
@export var barricades_texture: Texture2D
@export_range(1.0, 128.0, 1.0)
var barricades_texture_hframes: int = 4
@export_range(1.0, 128.0, 1.0)
var barricades_texture_vframes: int = 1


const CONNECTION_FRAME_BY_DIRECTION: Dictionary[RoomInstanceData.ConnectionDirectionFlags, int] = {
	RoomInstanceData.ConnectionDirectionFlags.UP: 0,
	RoomInstanceData.ConnectionDirectionFlags.DOWN: 1,
	RoomInstanceData.ConnectionDirectionFlags.LEFT: 2,
	RoomInstanceData.ConnectionDirectionFlags.RIGHT: 3,
	RoomInstanceData.ConnectionDirectionFlags.UPPER_LEFT: 4,
	RoomInstanceData.ConnectionDirectionFlags.UPPER_RIGHT: 5,
	RoomInstanceData.ConnectionDirectionFlags.DOWN_LEFT: 6,
	RoomInstanceData.ConnectionDirectionFlags.DOWN_RIGHT: 7,
}

const BARRICADE_FRAME_BY_DIRECTION: Dictionary[RoomInstanceData.BarricadeDirectionFlags, int] = {
	RoomInstanceData.BarricadeDirectionFlags.UP: 0,
	RoomInstanceData.BarricadeDirectionFlags.DOWN: 2,
	RoomInstanceData.BarricadeDirectionFlags.LEFT: 3,
	RoomInstanceData.BarricadeDirectionFlags.RIGHT: 1,
}


func get_floor_variant_frame_index(seed_value: int) -> int:
	if seed_value == -1 or seed_value == null:
		seed_value = randi()
		
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	return rng.randi_range(0, floor_variants.get_frame_count("default") - 1)
	
