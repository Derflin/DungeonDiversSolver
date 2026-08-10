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

@onready var room_selection_cursor: Sprite2D = $RoomSelectionCursor

@onready var room_editor_menu: RadialMenu = $RoomEditorContainer/RoomEditorMenu


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


func hide_room_selection_cursor() -> void:
	room_selection_cursor.visible = false
	
	hide_room_editor_menu()


func show_room_selection_cursor(cursor_position: Vector2) -> void:
	room_selection_cursor.position = cursor_position
	room_selection_cursor.visible = true
	
	show_room_editor_menu(cursor_position)


func is_room_selection_cursor_visible() -> bool:
	return room_selection_cursor.visible


func is_room_selection_cursor_position(cursor_position: Vector2) -> bool:
	return room_selection_cursor.position == cursor_position


func hide_room_editor_menu() -> void:
	room_editor_menu.visible = false


func show_room_editor_menu(cursor_position: Vector2) -> void:
	room_editor_menu.open_menu(cursor_position)
	
	
func is_map_cursor_locked() -> bool:
	return room_editor_menu.visible


func is_room_selection_cursor_locked() -> bool:
	return room_editor_menu.visible
