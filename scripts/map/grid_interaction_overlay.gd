extends Node2D


enum MapCursorKind {
	VALID = 0,
	INVALID = 1,
}


@onready var map_cursor: Sprite2D = $MapCursor
@onready var map_cursor_animation_player: AnimationPlayer = $MapCursor/CursorAnimation

@onready var map_cursor_kinds_texture_frames: Dictionary = {
	MapCursorKind.VALID: 0,
	MapCursorKind.INVALID: 1,
}


func _ready() -> void:
	map_cursor.hframes = 2
	map_cursor.vframes = 1


func hide_map_cursor() -> void:
	map_cursor.visible = false
	if map_cursor_animation_player.is_playing():
		map_cursor_animation_player.stop()


func show_map_cursor(cursor_position: Vector2, valid_position: bool) -> void:
	map_cursor.position = cursor_position
	map_cursor.frame = map_cursor_kinds_texture_frames[MapCursorKind.VALID if valid_position else MapCursorKind.INVALID]
	map_cursor.visible = true
	
	if not map_cursor_animation_player.is_playing():
		map_cursor_animation_player.play("default")
