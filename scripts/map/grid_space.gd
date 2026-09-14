class_name GridSpace
extends Node2D


signal selected_room_changed(room_center_position: Vector2)


const _room_cell_scene: PackedScene = preload("res://scenes/map/room_cell.tscn")
var room_cells: Dictionary[Vector2i, RoomCell] = {}


@onready var grid_lines: Node2D = $GridBackground/GridLines
@onready var rooms_container: Node2D = $Rooms
@onready var grid_interaction_overlay: Node2D = $GridInteractionOverlay
@onready var map_solver_results_container: Node2D = $MapSolverResultsContainer


func _ready() -> void:
	_initialize_room_cells()


func _initialize_room_cells() -> void:
	var all_room_coords := GameState.map_state.get_all_room_coords()
	for room_coords in all_room_coords:
		create_room_cell(room_coords, GameState.map_state.get_room_instance(room_coords))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_clear_map_cursor()


func redraw_grid_lines() -> void:
	if grid_lines != null:
		grid_lines.queue_redraw()


func update_all_room_cells_positions() -> void:
	# Update each room cell display
	for room_coords in room_cells:
		update_room_position(room_cells[room_coords])


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_map_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_select"):
		handle_input_map_select()
		get_viewport().set_input_as_handled()


func _update_hovered_map_cursor() -> void:
	if grid_interaction_overlay.is_map_cursor_locked():
		return
	
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		_clear_map_cursor()
		return
	
	var mouse_position = get_local_mouse_position()
	
	if is_local_position_on_grid_lines(mouse_position):
		grid_interaction_overlay.hide_map_cursor()
		return
		
	var coords = get_coords_at_local_position(mouse_position)
	var map_cursor_position = get_room_center_from_coords(coords)
	
	grid_interaction_overlay.show_map_cursor(map_cursor_position, is_valid_coords(coords))


func handle_input_map_select() -> void:
	# Prepare mouse position based details that will be used for handling the input
	var mouse_position = get_local_mouse_position()
	var position_on_grid_lines = is_local_position_on_grid_lines(mouse_position)
	var coords = get_coords_at_local_position(mouse_position)
	
	# Create new rooms if the coords are valid and don't contain any existing rooms, otherwise update selected room cursor accordingly
	if not position_on_grid_lines and is_valid_coords(coords) and not GameState.map_state.has_room_coords(coords):
		# Create a secret room if the map solver result exists for a given coordinates, otherwise create an empty default room
		if map_solver_results_container.has_result_cursor_coords(coords):
			var secret_room_kind = GameState.get_map_solver_secret_kind()
			GameState.map_state.create_and_save_secret_room(coords, secret_room_kind)
		else:
			GameState.map_state.create_and_save_empty_room(coords)
	else:
		_update_selected_room_cursor()


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
	return grid_lines.get_map_rect()


## Creates room cell instance for the provided [param room_instance_data] in the provided [param room_coords] coordinates.
func create_room_cell(room_coords: Vector2i, room_instance_data: RoomInstanceData) -> void:
	# Create room cell instance
	var room_cell_instance = _room_cell_scene.instantiate()
	
	# Update room cell position
	room_cell_instance.room_coords = room_coords
	update_room_position(room_cell_instance)
	
	# Initialize room cell instance with the room instance data
	room_cell_instance.create(room_instance_data)
	
	# Save the room cell instance inside the room cells dictionary and append it to the room cell container
	room_cells[room_coords] = room_cell_instance
	append_room(room_cell_instance)


## Deletes room cell instance for the provided [param room_coords] coordinates.
func delete_room_cell(room_coords: Vector2i) -> void:
	# Filter out processing if the room_coords not found inside the instantiated room cells
	if not has_room_cell_coords(room_coords):
		return
	
	# Delete room cell instance
	var room_cell = room_cells[room_coords]
	room_cells.erase(room_coords)
	room_cell.queue_free()


## Updates room cell instance visuals for the provided [param room_coords] coordinates.
func update_room_cell(room_coords: Vector2i) -> void:
	# Filter out processing if the room_coords not found inside the instantiated room cells
	if not has_room_cell_coords(room_coords):
		return
	
	# Refresh visuals for the room cell
	var room_cell := room_cells[room_coords]
	room_cell.refresh_visuals()


## Checks if the room cell exists for the provided [param room_coords] coordinates.
func has_room_cell_coords(room_coords: Vector2i) -> bool:
	return room_coords in room_cells and room_cells[room_coords] != null


## Updates [param room_cell_instance] position based on the room coordinates saved in it's room_coords parameter.
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


func _clear_map_cursor() -> void:
	# Hide map cursor unless the map cursor is locked
	var is_map_cursor_locked = grid_interaction_overlay.is_map_cursor_locked()
	if not is_map_cursor_locked:
		grid_interaction_overlay.hide_map_cursor()


## Prepare all the necessary data about map solver results coords, calculate result coords positions on map and call map solver results container to update the displayed results.
func update_map_solver_results() -> void:
	# Prepare variables for 
	var map_solver_result := GameState.map_solver_result
	var result_coords_to_position: Dictionary[Vector2i, Vector2] = {}
	
	# Calculate each result coords position on map
	if map_solver_result != null:
		var results_coords := map_solver_result.get_result_coords()
		for result_coords in results_coords:
			result_coords_to_position[result_coords] = get_room_center_from_coords(result_coords)
	
	# Call grid interaction overlay to update the map solver results
	map_solver_results_container.update_map_solver_results(map_solver_result, result_coords_to_position)


func _on_room_editor_menu_outside_click_menu_closed() -> void:
	hide_selected_room_cursor()


func _on_room_editor_menu_inside_click_menu_closed() -> void:
	hide_selected_room_cursor()


func _on_room_editor_container_room_editor_action_delete_triggered() -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	GameState.map_state.delete_room(selected_room_cell.room_coords)

	hide_selected_room_cursor()


func _on_room_editor_container_room_editor_action_barricade_change_triggered(barricade_direction: RoomInstanceData.BarricadeDirectionFlags, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	GameState.map_state.update_room_set_barricade(selected_room_cell.room_coords, barricade_direction, state)
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_editor_container_room_editor_action_connection_change_triggered(connection_direction: RoomInstanceData.ConnectionDirectionFlags, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	GameState.map_state.update_room_set_connection(selected_room_cell.room_coords, connection_direction, state)
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_editor_container_room_editor_action_special_set_triggered(special_room_kind: RoomSpecialType.Kind, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	GameState.map_state.update_room_set_special_type(selected_room_cell.room_coords, special_room_kind, state)
	
	grid_interaction_overlay.update_selected_room_cell()


func _on_room_editor_container_room_editor_action_secret_set_triggered(secret_room_kind: RoomSecretType.Kind, state: bool) -> void:
	var selected_room_cell = grid_interaction_overlay.selected_room_cell
	if selected_room_cell == null:
		return
	
	GameState.map_state.update_room_set_secret_type(selected_room_cell.room_coords, secret_room_kind, state)
	
	grid_interaction_overlay.update_selected_room_cell()
