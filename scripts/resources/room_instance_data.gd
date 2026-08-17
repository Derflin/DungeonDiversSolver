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


@export var corridor_type: RoomCorridorType
@export var special_type: RoomSpecialType = null
@export var secret_type: RoomSecretType = null

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


func _init() -> void:
	corridor_type = GameData.room_corridor_types.get_default_type()
	instance_seed_value = randi()
		

func create(_corridor_type: RoomCorridorType, _special_type: RoomSpecialType = null, _secret_type: RoomSecretType = null, _connection_directions_mask: ConnectionDirectionFlags = ConnectionDirectionFlags.NONE, _barricade_directions_mask: BarricadeDirectionFlags = BarricadeDirectionFlags.NONE) -> void:
	corridor_type = _corridor_type
	special_type = _special_type
	secret_type = _secret_type
	
	connection_directions_mask = _connection_directions_mask
	barricade_directions_mask = _barricade_directions_mask
	

func get_room_floor_visual_data() -> ResolvedVisualData:
	var visual_data: ResolvedVisualData = null

	if corridor_type != null and secret_type == null:
		visual_data = ResolvedSpriteFramesVisualData.new()
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
			visual_data.animated_variants = secret_type.animated_background_random_frame
			visual_data.animation_timer_interval = secret_type.generate_secret_backround_icon_pair_timer_interval(refresh_room_id, frame_generated["triggered_base_frame"])
			
		
	return visual_data
	

func get_room_connections_visual_data() -> ResolvedVisualData:
	var visual_data: ResolvedVisualData = null

	if corridor_type != null:
		visual_data = ResolvedTextureVisualData.new()
		visual_data.texture = corridor_type.connections_texture
		visual_data.hframes = corridor_type.connections_texture_hframes
		visual_data.vframes = corridor_type.connections_texture_vframes
		visual_data.frame = -1
		visual_data.dictionary_frame_per_direction = corridor_type.CONNECTION_FRAME_BY_DIRECTION
	
	return visual_data
	
	
func get_room_barricades_visual_data() -> ResolvedVisualData:
	var visual_data: ResolvedVisualData = null

	if corridor_type != null:
		visual_data = ResolvedTextureVisualData.new()
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
			visual_data.animated_variants = secret_type.animated_icon_random_frame
			visual_data.animation_timer_interval = secret_type.generate_secret_backround_icon_pair_timer_interval(refresh_room_id, frame_generated["triggered_base_frame"])
		
	return visual_data


func has_connection(direction: ConnectionDirectionFlags) -> bool:
	return (connection_directions_mask & direction) != 0


## Enables all directions contained in [param directions_mask].
## Combine values from [enum ConnectionDirectionFlags] using the bitwise operators.
func enable_connection(directions_mask: int) -> void:
	connection_directions_mask |= directions_mask
	
	# Apply connection contraints on other room instance data parameters
	set_secret_type(RoomSecretType.Kind.NONE)


## Disables all directions contained in [param directions_mask].
## Combine values from [enum ConnectionDirectionFlags] using the bitwise operators.
func disable_connection(directions_mask: int) -> void:
	connection_directions_mask &= ~directions_mask


func disable_connections_all() -> void:
	connection_directions_mask = ConnectionDirectionFlags.NONE


func has_barricade(direction: BarricadeDirectionFlags) -> bool:
	return (barricade_directions_mask & direction) != 0


## Enables all directions contained in [param directions_mask].
## Combine values from [enum BarricadeDirectionFlags] using the bitwise operators.
func enable_barricade(directions_mask: int) -> void:
	barricade_directions_mask |= directions_mask
	
	# Apply barricade contraints on other room instance data parameters
	set_secret_type(RoomSecretType.Kind.NONE)


## Disables all directions contained in [param directions_mask].
## Combine values from [enum BarricadeDirectionFlags] using the bitwise operators.
func disable_barricade(directions_mask: int) -> void:
	barricade_directions_mask &= ~directions_mask


func disable_barricades_all() -> void:
	barricade_directions_mask = BarricadeDirectionFlags.NONE


func has_special_type_by_id(special_id: String) -> bool:
	return special_type != null and special_type.id == special_id 


func has_secret_type_by_id(secret_id: String) -> bool:
	return secret_type != null and secret_type.id == secret_id 


func set_special_type(special_kind: RoomSpecialType.Kind) -> bool:
	if (special_kind == null or special_kind == RoomSpecialType.Kind.NONE) and special_type == null:
		return false
	
	if special_kind == null or special_kind == RoomSpecialType.Kind.NONE:
		special_type = null
		return true
	
	if special_type == null or special_type.kind != special_kind:
		var room_special_type = GameData.room_special_types.get_type(special_kind)
		special_type = room_special_type
		
		# Apply special type contraints on other room instance data parameters
		set_secret_type(RoomSecretType.Kind.NONE)
		
		return true
	
	return false


func get_secret_type_kind() -> RoomSecretType.Kind:
	if secret_type == null:
		return RoomSecretType.Kind.NONE
	
	return secret_type.get_kind()


func set_secret_type(secret_kind: RoomSecretType.Kind) -> bool:
	if (secret_kind == null or secret_kind == RoomSecretType.Kind.NONE) and secret_type == null:
		return false
	
	if secret_kind == null or secret_kind == RoomSecretType.Kind.NONE:
		secret_type = null
		return true
	
	if secret_type == null or secret_type.kind != secret_kind:
		var room_secret_type = GameData.room_secret_types.get_type(secret_kind)
		secret_type = room_secret_type
		
		# Apply secret type contraints on other room instance data parameters
		disable_connections_all()
		disable_barricades_all()
		set_special_type(RoomSpecialType.Kind.NONE)
		
		return true
	
	return false

#TODO: remember to add constraints - if secret is set, remove connection + barricades + special, if any of them is changed, remove special
