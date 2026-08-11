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


var _merged_static_texture: Texture2D


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


func get_id() -> StringName:
	return id


func get_display_name() -> String:
	return display_name


func get_static_texture() -> Texture2D:
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
