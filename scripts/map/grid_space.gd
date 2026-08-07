class_name GridSpace
extends Node2D

signal grid_space_parameters_changed


@onready var grid_lines: Node2D = $GridBackground/GridLines
@onready var rooms_container: Node2D = $Rooms
@onready var grid_interaction_overlay: Node2D = $GridInteractionOverlay


@export_group("Grid Parameters")
@export var grid_size: Vector2i = Vector2i(17, 17):
	set(value): 
		grid_size = value
		if grid_lines != null:
			grid_lines.grid_size = grid_size
			grid_lines.queue_redraw()
			grid_space_parameters_changed.emit()

@export var grid_room_size: Vector2i = Vector2i(15, 15):
	set(value): 
		grid_room_size = value
		if grid_lines != null:
			grid_lines.grid_room_size = grid_room_size
			grid_lines.queue_redraw()
			grid_space_parameters_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_map_cursor()


func _update_hovered_map_cursor() -> void:
	var mouse_position = get_local_mouse_position()
	
	if is_local_position_on_grid_lines(mouse_position):
		grid_interaction_overlay.hide_map_cursor()
		return
		
	var coords = get_coords_at_local_position(mouse_position)
	var map_cursor_position = get_room_center_from_coords(coords)
	
	grid_interaction_overlay.show_map_cursor(map_cursor_position, is_valid_coords(coords))


func get_map_rect() -> Rect2:
	return Rect2(
		grid_lines.position - grid_lines.get_grid_offset(),
		grid_lines.get_grid_size(),
	)


func append_room(room: RoomCell) -> void:
	rooms_container.add_child(room)
	
	
func get_room_center_from_coords(coords: Vector2i) -> Vector2:
	return get_room_center(get_room_rect(coords))


func convert_coords_to_valid_grid_coords(coords: Vector2i) -> Vector2i:
	var new_coords = Vector2i(coords)
	new_coords.x = coords.x % grid_size.x
	new_coords.y = coords.y % grid_size.y
	
	return new_coords
	
	
func get_room_rect(coords: Vector2i) -> Rect2:
	var room_coords = coords
	#var room_coords = convert_coords_to_valid_grid_coords(coords)
	
	var room_position = Vector2(grid_lines.GRID_LINE_WIDTH, grid_lines.GRID_LINE_WIDTH)
	room_position.x += room_coords.x * (grid_room_size.x + grid_lines.GRID_LINE_WIDTH)
	room_position.y += room_coords.y * (grid_room_size.y + grid_lines.GRID_LINE_WIDTH)
	
	return Rect2(
		room_position,
		grid_room_size,
	)


func get_room_center(room_rect: Rect2) -> Vector2:
	return room_rect.position + room_rect.size / 2.0


func is_valid_coords(coords: Vector2i) -> bool:
	return (
		coords.x >= 0
		and coords.y >= 0
		and coords.x < grid_size.x
		and coords.y < grid_size.y
	)


func is_local_position_on_grid_lines(local_position: Vector2) -> bool:
	return int(local_position.x) % (grid_room_size.x + grid_lines.GRID_LINE_WIDTH) == 0 or int(local_position.y) % (grid_room_size.y + grid_lines.GRID_LINE_WIDTH) == 0

func get_coords_at_local_position(local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(local_position.x / (grid_room_size.x + grid_lines.GRID_LINE_WIDTH)),
		floori(local_position.y / (grid_room_size.y + grid_lines.GRID_LINE_WIDTH)),
	)
