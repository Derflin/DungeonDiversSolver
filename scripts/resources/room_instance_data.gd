class_name RoomInstanceData
extends Resource

enum ConnectionDirectionFlags {
	NONE = 0,
	UP = 1 << 0,
	DOWN = 1 << 1,
	LEFT = 1 << 2,
	RIGHT = 1 << 3,
	UPPER_LEFT = 1 << 4,
	UPPER_RIGHT = 1 << 5,
	DOWN_LEFT = 1 << 6,
	DOWN_RIGHT = 1 << 7,
}

enum BarricadeDirectionFlags {
	NONE = 0,
	UP = 1 << 0,
	DOWN = 1 << 1,
	LEFT = 1 << 2,
	RIGHT = 1 << 3,
}


var instance_seed_value: int = -1
var old_special_type: RoomSpecialType = null
var old_secret_type: RoomSecretType = null


@export var corridor_type: RoomCorridorType
@export var special_type: RoomSpecialType = null:
	set(value):
		if special_type == value:
			return
			
		special_type = value
		if value == null:
			if old_secret_type != null and secret_type == null:
				secret_type = old_secret_type
				old_secret_type = null
		else:
			old_secret_type = secret_type
			secret_type = null
@export var secret_type: RoomSecretType = null:
	set(value):
		if secret_type == value:
			return
			
		secret_type = value
		if value == null:
			if old_special_type != null and special_type == null:
				special_type = old_special_type
				old_special_type = null
		else:
			old_special_type = special_type
			special_type = null

@export_group("Connections", "connection_")
@export_flags(
	"Up:1",
	"Down:2",
	"Left:4",
	"Right:8",
	"Upper Left:16",
	"Upper Right:32",
	"Down Left:64",
	"Down Right:128",
)
var connection_directions_mask: int = ConnectionDirectionFlags.NONE

@export_group("Barricades", "barricade_")
@export_flags(
	"Up:1",
	"Down:2",
	"Left:4",
	"Right:8",
)
var barricade_directions_mask: int = BarricadeDirectionFlags.NONE


func _ready() -> void:
	corridor_type = GameData.room_corridor_types.get_default_type()
	instance_seed_value = randi()
		

func create(_corridor_type: RoomCorridorType, _special_type: RoomSpecialType = null, _secret_type: RoomSecretType = null, _connection_directions_mask: ConnectionDirectionFlags = ConnectionDirectionFlags.NONE, _barricade_directions_mask: BarricadeDirectionFlags = BarricadeDirectionFlags.NONE) -> void:
	corridor_type = _corridor_type
	special_type = _special_type
	secret_type = _secret_type
	
	connection_directions_mask = _connection_directions_mask
	barricade_directions_mask = _barricade_directions_mask
	

func get_room_floor_visual_data() -> ResolvedVisualData:
	var visual_data = ResolvedSpriteFramesVisualData.new()
	visual_data.sprite_frames = corridor_type.floor_variants
	visual_data.animation_name = "default"
	visual_data.frame = corridor_type.get_floor_variant_frame_index(instance_seed_value)
	visual_data.animated_variants = false
	
	return visual_data
	
	
func get_room_background_visual_data(refresh_room_id: int) -> ResolvedVisualData:
	var visual_data: ResolvedVisualData = null
	
	if special_type != null:
		visual_data = ResolvedTextureVisualData.new()
		visual_data.texture = special_type.background
		visual_data.hframes = special_type.background_hframes
		visual_data.vframes = special_type.background_vframes
		visual_data.frame = special_type.background_frame
		
	if secret_type != null:
		if secret_type.animated_background == null:
			visual_data = ResolvedTextureVisualData.new()
			visual_data.texture = secret_type.background
			visual_data.hframes = secret_type.background_hframes
			visual_data.vframes = secret_type.background_vframes
			visual_data.frame = secret_type.background_frame
			
		else:
			visual_data = ResolvedSpriteFramesVisualData.new()
			visual_data.sprite_frames = secret_type.animated_background
			visual_data.animation_name = "default"
			var frame_generated = secret_type.generate_secret_background_icon_pair_frames(refresh_room_id, true, false)
			visual_data.frame = frame_generated["frame"]
			visual_data.animated_variants = secret_type.animated_background_variants
			visual_data.animation_timer_interval = secret_type.generate_secret_backround_icon_pair_timer_interval(refresh_room_id, frame_generated["triggered_base_frame"])
			
		
	return visual_data
	

func get_room_connections_visual_data() -> ResolvedVisualData:
	var visual_data = ResolvedTextureVisualData.new()
	visual_data.texture = corridor_type.connections_texture
	visual_data.hframes = corridor_type.connections_texture_hframes
	visual_data.vframes = corridor_type.connections_texture_vframes
	visual_data.frame = -1
	visual_data.dictionary_frame_per_direction = corridor_type.CONNECTION_FRAME_BY_DIRECTION
	
	return visual_data
	
	
func get_room_barricades_visual_data() -> ResolvedVisualData:
	var visual_data = ResolvedTextureVisualData.new()
	visual_data.texture = corridor_type.barricades_texture
	visual_data.hframes = corridor_type.barricades_texture_hframes
	visual_data.vframes = corridor_type.barricades_texture_vframes
	visual_data.frame = -1
	visual_data.dictionary_frame_per_direction = corridor_type.BARRICADE_FRAME_BY_DIRECTION
	
	return visual_data

	
func get_room_icon_visual_data(refresh_room_id: int) -> ResolvedVisualData:
	var visual_data: ResolvedVisualData = null
	
	if special_type != null:
		visual_data = ResolvedTextureVisualData.new()
		visual_data.texture = special_type.icon
		visual_data.hframes = special_type.icon_hframes
		visual_data.vframes = special_type.icon_vframes
		visual_data.frame = special_type.icon_frame
		
	if secret_type != null:
		if secret_type.animated_icon == null:
			visual_data = ResolvedTextureVisualData.new()
			visual_data.texture = secret_type.icon
			visual_data.hframes = secret_type.icon_hframes
			visual_data.vframes = secret_type.icon_vframes
			visual_data.frame = secret_type.icon_frame
			
		else:
			visual_data = ResolvedSpriteFramesVisualData.new()
			visual_data.sprite_frames = secret_type.animated_icon
			visual_data.animation_name = "default"
			var frame_generated = secret_type.generate_secret_background_icon_pair_frames(refresh_room_id, false, true)
			visual_data.frame = frame_generated["frame"]
			visual_data.animated_variants = secret_type.animated_icon_variants
			visual_data.animation_timer_interval = secret_type.generate_secret_backround_icon_pair_timer_interval(refresh_room_id, frame_generated["triggered_base_frame"])
		
	return visual_data


func has_connection(direction: ConnectionDirectionFlags) -> bool:
	return (connection_directions_mask & direction) != 0
	
	
func enable_connection(direction: ConnectionDirectionFlags) -> void:
	connection_directions_mask |= direction
	
	
func disable_connection(direction: ConnectionDirectionFlags) -> void:
	connection_directions_mask &= ~direction
	
	
func has_barricade(direction: BarricadeDirectionFlags) -> bool:
	return (barricade_directions_mask & direction) != 0
	
	
func enable_barricade(direction: BarricadeDirectionFlags) -> void:
	barricade_directions_mask |= direction
	
	
func disable_barricade(direction: BarricadeDirectionFlags) -> void:
	barricade_directions_mask &= ~direction
	
