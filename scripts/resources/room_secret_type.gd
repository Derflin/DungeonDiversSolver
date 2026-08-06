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
@export var animated_icon_default_frame: int = 0
@export var animated_icon_random_frame: bool = false

@export_group("Animated Background", "animated_")
@export var animated_background: SpriteFrames
@export var animated_background_default_frame: int = 0
@export var animated_background_random_frame: bool = false

@export_group("Animation Parameters", "animation_")
@export var animation_random_interval: bool = false
@export_range(0.01, 2.0, 0.01)
var animation_static_timer_interval: float = 1.0
@export_range(0.01, 2.0, 0.01)
var animation_random_min_timer_interval: float = 0.25
@export_range(0.01, 2.0, 0.01)
var animation_random_max_timer_interval: float = 2.0


func generate_secret_background_icon_pair_frames(seed_id: int, background_check: bool = false, icon_check: bool = false) -> Dictionary:
	var result_dict = {"frame": -1, "triggered_base_frame": false}
	
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_id
	
	if background_check and (animated_background == null or animated_background.get_frame_count("default") == 1):
		result_dict["frame"] = animated_background_default_frame
		return result_dict
		
	if icon_check and (animated_icon == null or animated_icon.get_frame_count("default") == 1):
		result_dict["frame"] = animated_icon_default_frame
		return result_dict
		
	if background_check and (animated_icon == null or animated_icon.get_frame_count("default") == 1):
		result_dict["frame"] = rng.randi_range(0, animated_background.get_frame_count("default") - 1)
		return result_dict
		
	if icon_check and (animated_background == null or animated_background.get_frame_count("default") == 1):
		result_dict["frame"] = rng.randi_range(0, animated_icon.get_frame_count("default") - 1)
		return result_dict
		
	background_frame = rng.randi_range(0, animated_background.get_frame_count("default") - 1)
	icon_frame = rng.randi_range(0, animated_icon.get_frame_count("default") - 1)
	
	if background_frame == animated_background_default_frame or icon_frame == animated_icon_default_frame:
		background_frame = animated_background_default_frame
		icon_frame = animated_icon_default_frame
		result_dict["triggered_base_frame"] = true
		
	result_dict["frame"] = background_frame if background_check else icon_frame
	return result_dict
	
	
func generate_secret_backround_icon_pair_timer_interval(seed_id: int, triggered_base_frame: bool) -> float:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_id
	
	if animation_random_interval:
		var random_interval = rng.randf_range(animation_random_min_timer_interval, animation_random_max_timer_interval)
		if triggered_base_frame:
			random_interval += animation_static_timer_interval
		return random_interval
	else:
		return animation_static_timer_interval
