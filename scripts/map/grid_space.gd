class_name GridSpace
extends Node2D

signal grid_space_parameters_changed
signal selected_room_changed(room_center_position: Vector2)


var _room_cell_scene
var room_instances: Dictionary[Vector2i, RoomInstanceData] = {}
var room_cells: Dictionary[Vector2i, RoomCell] = {}


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


func _ready() -> void:
	#TODO: remove it later
	_room_cell_scene = preload("res://scenes/map/room_cell.tscn")
	var test_room = RoomInstanceData.new()
	#test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.UP)
	#test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.LEFT | RoomInstanceData.BarricadeDirectionFlags.RIGHT)
	#test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.UP | RoomInstanceData.BarricadeDirectionFlags.LEFT | RoomInstanceData.BarricadeDirectionFlags.RIGHT)
	test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.UP | RoomInstanceData.BarricadeDirectionFlags.DOWN | RoomInstanceData.BarricadeDirectionFlags.RIGHT)
	#test_room.special_type = GameData.room_special_types.get_type(RoomSpecialType.Kind.ARENA)
	#test_room.special_type = GameData.room_special_types.get_type(RoomSpecialType.Kind.ENTRANCE)
	#test_room.special_type = GameData.room_special_types.get_type(RoomSpecialType.Kind.LIBRARY)
	#test_room.secret_type = GameData.room_secret_types.get_type(RoomSecretType.Kind.ERROR_ROOM)
	room_instances[Vector2i(5, 5)] = test_room
	for room_coords in room_instances:
		create_room(room_coords)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_map_cursor()
		
	elif event.is_action_pressed("map_select"):
		handle_input_map_select()
		get_viewport().set_input_as_handled()


func _update_hovered_map_cursor() -> void:
	if grid_interaction_overlay.is_map_cursor_locked():
		return
	
	var mouse_position = get_local_mouse_position()
	
	if is_local_position_on_grid_lines(mouse_position):
		grid_interaction_overlay.hide_map_cursor()
		return
		
	var coords = get_coords_at_local_position(mouse_position)
	var map_cursor_position = get_room_center_from_coords(coords)
	
	grid_interaction_overlay.show_map_cursor(map_cursor_position, is_valid_coords(coords))


func handle_input_map_select() -> void:
	var mouse_position = get_local_mouse_position()
	var position_on_grid_lines = is_local_position_on_grid_lines(mouse_position)
	var coords = get_coords_at_local_position(mouse_position)
	
	if not position_on_grid_lines and is_valid_coords(coords) and coords not in room_instances:
		create_and_save_empty_room(coords)
	else:
		_update_selected_room_cursor()


func create_and_save_empty_room(room_coords: Vector2i) -> void:
	room_instances[room_coords] = RoomInstanceData.new()
	create_room(room_coords)


func _update_selected_room_cursor() -> void:
	if grid_interaction_overlay.is_room_selection_cursor_locked():
		return
	
	var mouse_position = get_local_mouse_position()
	
	var was_selected_room_cursor_visible = hide_selected_room_cursor()
	
	if is_local_position_on_grid_lines(mouse_position):
		return
		
	var coords = get_coords_at_local_position(mouse_position)
	var map_cursor_position = get_room_center_from_coords(coords)
	
	var is_selected_coords_valid = is_valid_coords(coords)
	if is_selected_coords_valid and (not was_selected_room_cursor_visible or not grid_interaction_overlay.is_room_selection_cursor_position(map_cursor_position)):
		grid_interaction_overlay.set_selected_room_cell(room_cells[coords])
		
		grid_interaction_overlay.show_room_selection_cursor(map_cursor_position)
		grid_interaction_overlay.show_room_editor_menu(map_cursor_position)
		
		selected_room_changed.emit(map_cursor_position)


func hide_selected_room_cursor() -> bool:
	var is_selected_room_cursor_visible = grid_interaction_overlay.is_room_selection_cursor_visible()
	if is_selected_room_cursor_visible:
		grid_interaction_overlay.hide_room_selection_cursor()
		
		grid_interaction_overlay.set_selected_room_cell(null)
	return is_selected_room_cursor_visible


func get_map_rect() -> Rect2:
	return Rect2(
		grid_lines.position - grid_lines.get_grid_offset(),
		grid_lines.get_grid_size(),
	)


func create_room(room_coords: Vector2i) -> RoomCell:
	var room_cell_instance = _room_cell_scene.instantiate()
	
	room_cell_instance.room_coords = room_coords
	room_cell_instance.position = get_room_center_from_coords(room_coords)
	
	var room_cell_room_instance_data = room_instances[room_coords]
	room_cell_instance.create(room_cell_room_instance_data)
	
	room_cells[room_coords] = room_cell_instance
	
	append_room(room_cell_instance)
	
	return room_cell_instance


func delete_room(room_coords: Vector2i) -> void:
	var room_cell = room_cells[room_coords]
	room_cells[room_coords] = null
	
	room_cell.queue_free()
	
	room_instances[room_coords] = null


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


func _on_room_editor_menu_outside_click_menu_closed() -> void:
	hide_selected_room_cursor()


func _on_room_editor_menu_inside_click_menu_closed() -> void:
	hide_selected_room_cursor()


func _on_room_editor_container_room_editor_action_delete_triggered() -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	delete_room(selected_room_cell.room_coords)

	grid_interaction_overlay.hide_room_selection_cursor()
	grid_interaction_overlay.set_selected_room_cell(null)


func _on_room_editor_container_room_editor_action_barricade_change_triggered(barricade_direction: RoomInstanceData.BarricadeDirectionFlags, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	var changed: bool = false
	var room_instance_data = selected_room_cell.room_instance_data
	
	if state and not room_instance_data.has_barricade(barricade_direction):
		room_instance_data.enable_barricade(barricade_direction)
		changed = true
	elif not state and room_instance_data.has_barricade(barricade_direction):
		room_instance_data.disable_barricade(barricade_direction)
		changed = true
	
	if changed:
		selected_room_cell.refresh_visuals()
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_editor_container_room_editor_action_connection_change_triggered(connection_direction: RoomInstanceData.ConnectionDirectionFlags, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	var changed: bool = false
	var room_instance_data = selected_room_cell.room_instance_data
	
	if state and not room_instance_data.has_connection(connection_direction):
		room_instance_data.enable_connection(connection_direction)
		changed = true
	elif not state and room_instance_data.has_connection(connection_direction):
		room_instance_data.disable_connection(connection_direction)
		changed = true
	
	if changed:
		selected_room_cell.refresh_visuals()
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_editor_container_room_editor_action_special_set_triggered(special_room_kind: RoomSpecialType.Kind, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	var changed: bool = false
	var room_instance_data = selected_room_cell.room_instance_data
	
	changed = room_instance_data.set_special_type(RoomSpecialType.Kind.NONE if not state else special_room_kind)
	
	if changed:
		selected_room_cell.refresh_visuals()
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_editor_container_room_editor_action_secret_set_triggered(secret_room_kind: RoomSecretType.Kind, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	var changed: bool = false
	var room_instance_data = selected_room_cell.room_instance_data
	
	changed = room_instance_data.set_secret_type(RoomSecretType.Kind.NONE if not state else secret_room_kind)
	
	if changed:
		selected_room_cell.refresh_visuals()
	
	grid_interaction_overlay.update_selected_room_cell()
