class_name RoomSecretType
extends RoomType

enum Kind {
	NONE = -1,
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


#TODO: needs to check where the RED_ROOM should be located (it could be set before OUTSIDER_ROOM, rest should be okay, but it would be good to fact check them
const ROOM_SECRET_TYPE_CREATE_ORDER: Array[Kind] = [
	Kind.PORTAL_ROOM,
	Kind.COMMON_ROOM,
	Kind.GUEST_ROOM,
	Kind.HERMIT_ROOM,
	Kind.BOULDER_ROOM,
	Kind.DEVIL_ROOM,
	Kind.ANGEL_ROOM,
	Kind.BLACK_MARKET,
	Kind.BARRICADE_ROOM,
	Kind.OUTSIDER_ROOM,
	Kind.ERROR_ROOM,
	Kind.RED_ROOM,
]


var _merged_static_texture: Texture2D


@export var kind: Kind = Kind.NONE

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

@export_group("Placement Config", "placement_")
@export var placement_config: SecretPlacementConfig = null


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


func get_kind() -> Kind:
	return kind


func get_id() -> StringName:
	return id


func get_display_name() -> String:
	return display_name


func get_static_texture(just_icon: bool = false) -> Texture2D:
	if just_icon:
		return icon
	
	if _merged_static_texture == null:
		_merged_static_texture = _create_merged_static_texture()

	return _merged_static_texture


func _create_merged_static_texture() -> Texture2D:
	if icon == null or background == null:
		return icon if icon != null else background

	var image_icon := icon.get_image()
	var image_background := background.get_image()

	image_icon.convert(Image.FORMAT_RGBA8)
	image_background.convert(Image.FORMAT_RGBA8)

	var blended_size := Vector2i(
		max(image_icon.get_width(), image_background.get_width()),
		max(image_icon.get_height(), image_background.get_height())
	)

	var image := Image.create(
		blended_size.x,
		blended_size.y,
		false,
		Image.FORMAT_RGBA8
	)

	image.blend_rect(
		image_background,
		Rect2i(Vector2i.ZERO, image_background.get_size()),
		Vector2i(
			roundi(abs(image_icon.get_width() - image_background.get_width()) / 2.0) if image_background.get_width() < image_icon.get_width() else 0, 
			roundi(abs(image_icon.get_height() - image_background.get_height()) / 2.0) if image_background.get_height() < image_icon.get_height() else 0,
		),
	)

	image.blend_rect(
		image_icon,
		Rect2i(Vector2i.ZERO, image_icon.get_size()),
		Vector2i(
			roundi(abs(image_icon.get_width() - image_background.get_width()) / 2.0) if image_icon.get_width() < image_background.get_width() else 0, 
			roundi(abs(image_icon.get_height() - image_background.get_height()) / 2.0) if image_icon.get_height() < image_background.get_height() else 0,
		),
	)

	return ImageTexture.create_from_image(image)
