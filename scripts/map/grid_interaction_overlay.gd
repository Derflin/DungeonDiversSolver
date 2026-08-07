extends Node2D


enum CursorKind {
	VALID = 0,
	INVALID = 1,
}


@onready var map_cursor: Sprite2D = $MapCursor
@onready var map_cursor_animation_player: AnimationPlayer = $MapCursor/CursorAnimation

@onready var cursor_kinds_texture_frames: Dictionary = {
	CursorKind.VALID: 0,
	CursorKind.INVALID: 1,
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
	map_cursor.frame = cursor_kinds_texture_frames[CursorKind.VALID if valid_position else CursorKind.INVALID]
	map_cursor.visible = true
	
	if not map_cursor_animation_player.is_playing():
		map_cursor_animation_player.play("default")
