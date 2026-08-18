class_name GridSpace
extends Node2D

signal grid_space_parameters_changed
signal selected_room_changed(room_center_position: Vector2)
signal room_state_changed()


var _room_cell_scene
var room_instances: Dictionary[Vector2i, RoomInstanceData] = {}
var room_cells: Dictionary[Vector2i, RoomCell] = {}


@onready var grid_lines: Node2D = $GridBackground/GridLines
@onready var rooms_container: Node2D = $Rooms
@onready var grid_interaction_overlay: Node2D = $GridInteractionOverlay


func _ready() -> void:
	# Connect map_grid_size and map_grid_room_size settings parameters changed signals
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)
	GameSettings.map_grid_room_size_parameter_changed.connect(_on_game_settings_map_grid_room_size_parameter_changed)
	
	#TODO: remove it later
	_room_cell_scene = preload("res://scenes/map/room_cell.tscn")
	var test_room := RoomInstanceData.new()
	#test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.UP)
	#test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.LEFT | RoomInstanceData.BarricadeDirectionFlags.RIGHT)
	#test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.UP | RoomInstanceData.BarricadeDirectionFlags.LEFT | RoomInstanceData.BarricadeDirectionFlags.RIGHT)
	test_room.enable_barricade(RoomInstanceData.BarricadeDirectionFlags.UP | RoomInstanceData.BarricadeDirectionFlags.DOWN | RoomInstanceData.BarricadeDirectionFlags.RIGHT)
	#test_room.special_type = GameData.room_special_types.get_type(RoomSpecialType.Kind.ARENA)
	#test_room.special_type = GameData.room_special_types.get_type(RoomSpecialType.Kind.ENTRANCE)
	#test_room.special_type = GameData.room_special_types.get_type(RoomSpecialType.Kind.LIBRARY)
	#test_room.secret_type = GameData.room_secret_types.get_type(RoomSecretType.Kind.ERROR_ROOM)
	var room_coords := Vector2i(5, 5)
	create_room(room_coords, test_room)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_clear_map_cursor()


func _on_game_settings_map_grid_size_parameter_changed(_map_grid_size: Vector2i) -> void:
	# Delete any room that would be placed outside the map grid
	for room_coords in room_instances:
		if room_coords.x >= _map_grid_size.x or room_coords.y >= _map_grid_size.y:
			delete_room(room_coords)
	
	# Hide selected room cursor
	hide_selected_room_cursor()
	
	# Redraw background grid lines
	if grid_lines != null:
		grid_lines.queue_redraw()
		grid_space_parameters_changed.emit()


func _on_game_settings_map_grid_room_size_parameter_changed(_map_grid_room_size: Vector2i) -> void:
	# Update each room cell display
	for room_coords in room_cells:
		update_room_position(room_cells[room_coords])
	
	# Hide selected room cursor
	hide_selected_room_cursor()
	
	# Redraw background grid lines
	if grid_lines != null:
		grid_lines.queue_redraw()
		grid_space_parameters_changed.emit()


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
	var default_room_instance_data = RoomInstanceData.new()
	create_room(room_coords, default_room_instance_data)


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


func create_room(room_coords: Vector2i, room_instance_data: RoomInstanceData) -> RoomCell:
	var room_cell_instance = _room_cell_scene.instantiate()
	
	room_cell_instance.room_coords = room_coords
	update_room_position(room_cell_instance)
	
	room_cell_instance.create(room_instance_data)
	
	room_instances[room_coords] = room_instance_data
	room_cells[room_coords] = room_cell_instance
	
	append_room(room_cell_instance)
	
	room_state_changed.emit()
	
	return room_cell_instance


func delete_room(room_coords: Vector2i) -> void:
	var room_cell = room_cells[room_coords]
	room_cells.erase(room_coords)
	
	room_cell.queue_free()
	
	room_instances.erase(room_coords)
	
	room_state_changed.emit()


## This function updates passed RoomCell position based on the room coordinates saved in it's room_coords parameter
func update_room_position(room_cell_instance: RoomCell) -> void:
	room_cell_instance.position = get_room_center_from_coords(room_cell_instance.room_coords)


func append_room(room: RoomCell) -> void:
	rooms_container.add_child(room)
	
	
func get_room_center_from_coords(coords: Vector2i) -> Vector2:
	return get_room_center(get_room_rect(coords))


func convert_coords_to_valid_grid_coords(coords: Vector2i) -> Vector2i:
	var new_coords = Vector2i(coords)
	new_coords.x = coords.x % GameSettings.map_grid_size.x
	new_coords.y = coords.y % GameSettings.map_grid_size.y
	
	return new_coords


func get_room_rect(coords: Vector2i) -> Rect2:
	var room_coords = coords
	#var room_coords = convert_coords_to_valid_grid_coords(coords)
	
	var room_position = Vector2(grid_lines.GRID_LINE_WIDTH, grid_lines.GRID_LINE_WIDTH)
	room_position.x += room_coords.x * (GameSettings.map_grid_room_size.x + grid_lines.GRID_LINE_WIDTH)
	room_position.y += room_coords.y * (GameSettings.map_grid_room_size.y + grid_lines.GRID_LINE_WIDTH)
	
	return Rect2(
		room_position,
		GameSettings.map_grid_room_size,
	)


func get_room_center(room_rect: Rect2) -> Vector2:
	return room_rect.position + room_rect.size / 2.0


func is_valid_coords(coords: Vector2i) -> bool:
	return (
		coords.x >= 0
		and coords.y >= 0
		and coords.x < GameSettings.map_grid_size.x
		and coords.y < GameSettings.map_grid_size.y
	)


func is_local_position_on_grid_lines(local_position: Vector2) -> bool:
	return int(local_position.x) % (GameSettings.map_grid_room_size.x + grid_lines.GRID_LINE_WIDTH) == 0 or int(local_position.y) % (GameSettings.map_grid_room_size.y + grid_lines.GRID_LINE_WIDTH) == 0


func get_coords_at_local_position(local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(local_position.x / (GameSettings.map_grid_room_size.x + grid_lines.GRID_LINE_WIDTH)),
		floori(local_position.y / (GameSettings.map_grid_room_size.y + grid_lines.GRID_LINE_WIDTH)),
	)


func _update_game_state() -> void:
	var secret_count: Dictionary[RoomSecretType.Kind, int] = {}
	
	for room_coords in room_instances:
		var room_instance_data: RoomInstanceData = room_instances[room_coords]
		var room_secret_type_kind = room_instance_data.get_secret_type_kind()
		if room_secret_type_kind != null and room_secret_type_kind != RoomSecretType.Kind.NONE:
			if room_secret_type_kind in secret_count:
				secret_count[room_secret_type_kind] += 1
			else:
				secret_count[room_secret_type_kind] = 1
	
	var all_secret_type_kinds = GameData.room_secret_types.get_all_kinds()
	for room_secret_type_kind in all_secret_type_kinds:
		if room_secret_type_kind in secret_count:
			GameState.set_map_secrets_count_current(room_secret_type_kind, secret_count[room_secret_type_kind])
		else:
			GameState.set_map_secrets_count_current(room_secret_type_kind, 0)


func _clear_map_cursor() -> void:
	# Hide map cursor unless the room selected cursor is also visible
	var is_selected_room_cursor_visible = grid_interaction_overlay.is_room_selection_cursor_visible()
	if not is_selected_room_cursor_visible:
		grid_interaction_overlay.hide_map_cursor()



func _on_room_editor_menu_outside_click_menu_closed() -> void:
	hide_selected_room_cursor()


func _on_room_editor_menu_inside_click_menu_closed() -> void:
	hide_selected_room_cursor()


func _on_room_editor_container_room_editor_action_delete_triggered() -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	delete_room(selected_room_cell.room_coords)

	hide_selected_room_cursor()


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
		room_state_changed.emit()
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
		room_state_changed.emit()
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
		room_state_changed.emit()
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
		room_state_changed.emit()
		selected_room_cell.refresh_visuals()
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_state_changed() -> void:
	_update_game_state()
