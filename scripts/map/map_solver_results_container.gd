class_name MapSolverResultsContainer
extends Node2D


const _result_cursor_scene: PackedScene = preload("res://scenes/map/map_solver_result_cursor.tscn")


var result_cursors: Dictionary[Vector2i, MapSolverResultCursor] = {}
var result_cursors_deleted: Array[MapSolverResultCursor] = []


@onready var active_container: Node2D = $ActiveContainer
@onready var transition_container: Node2D = $TransitionContainer 


## Update map solver result cursors assigned as this container node children to reflect map solver result.
func update_map_solver_results(map_solver_result: MapSolverResult, results_coords_to_map_position: Dictionary[Vector2i, Vector2]) -> void:
	# Prepare map solver variables based on the map solver result state
	var result_solve_stage := map_solver_result.stage if map_solver_result != null else MapSolverResult.SolveStage.NONE
	var map_solver_result_coords: Array[MapSolverResultCoord] = []
	if map_solver_result != null:
		map_solver_result_coords = map_solver_result.result_coords
	
	# Create new and update existing result cursors for the map solver result
	var processed_room_coords: Array[Vector2i] = []
	for result_coord: MapSolverResultCoord in map_solver_result_coords:
		var cur_room_coords := result_coord.coords
		
		# Mark each processed room coords
		processed_room_coords.append(cur_room_coords)
		
		# Create a new result cursor if it doesn't already exist for the room coords, otherwise update existing one
		if not has_result_cursor_coords(cur_room_coords):
			_create_result_cursor(result_coord, results_coords_to_map_position[cur_room_coords], result_solve_stage)
		else:
			_update_result_cursor(cur_room_coords, result_coord, result_solve_stage)
	
	# Look through existing result cursors and mark any that weren't processed during creating and updating result cursors based on the map solver result
	var room_coords_to_delete: Array[Vector2i] = []
	for cur_room_coords: Vector2i in result_cursors:
		if cur_room_coords not in processed_room_coords:
			room_coords_to_delete.append(cur_room_coords)
	
	# Delete every marked result cursor that wasn't processed
	room_coords_to_delete.reverse()
	for cur_room_coords: Vector2i in room_coords_to_delete:
		_delete_result_cursor(cur_room_coords)


## Creates result cursor instance for the provided [param map_solver_result_coord] and places it in the [param cursor_position].
func _create_result_cursor(map_solver_result_coord: MapSolverResultCoord, cursor_position: Vector2, result_solve_stage: MapSolverResult.SolveStage) -> void:
	# Create result cursor instance
	var result_cursor_instance = _result_cursor_scene.instantiate()
	
	# Update result cursor position
	_update_result_cursor_position(result_cursor_instance, cursor_position)
	
	# Initialize data inside result cursor instance with the map solver result coord
	result_cursor_instance.update_data(map_solver_result_coord, result_solve_stage)
	
	# Update result cursor instance name
	result_cursor_instance.name = "%s %.0v" % [result_cursor_instance.get_script().get_global_name(), map_solver_result_coord.coords]
	
	# Save the result cursor instance inside the result cursors dictionary and add it as child to the current node
	result_cursors[map_solver_result_coord.coords] = result_cursor_instance
	active_container.add_child(result_cursor_instance)
	
	# Show result cursor
	result_cursor_instance.show_cursor()


## Deletes result cursor instance for the provided [param room_coords] coordinates.
func _delete_result_cursor(room_coords: Vector2i):
	# Filter out processing if the room_coords not found inside the instantiated result cursors
	if not has_result_cursor_coords(room_coords):
		return
	
	# Hide result cursor
	var result_cursor = result_cursors[room_coords]
	result_cursor.hide_cursor()
	
	# Delete result cursor instance from it's active container and reparent it to the transition container along with connecting it's signal to later handle it's full deletion
	result_cursors.erase(room_coords)
	result_cursor.reparent(transition_container)
	result_cursors_deleted.append(result_cursor)
	result_cursor.cursor_hidden.connect(_on_result_cursor_hidden)


## Removes the result cursor from temporary array for storing it during transition from active to deleted state and queues it's deletion.
func _on_result_cursor_hidden(result_cursor: MapSolverResultCursor) -> void:
	result_cursors_deleted.erase(result_cursor)
	result_cursor.queue_free()


## Updates result cursor instance for the provided [param room_coords] coordinates and updates it's map solver result coord.
func _update_result_cursor(room_coords: Vector2i, map_solver_result_coord: MapSolverResultCoord, result_solve_stage: MapSolverResult.SolveStage) -> void:
	# Filter out processing if the room_coords not found inside the instantiated result cursors
	if not has_result_cursor_coords(room_coords):
		return
	
	# Update data inside result cursor instance with the map solver result coord
	var result_cursor = result_cursors[room_coords]
	result_cursor.update_data(map_solver_result_coord, result_solve_stage)


## Checks if the result cursor exists for the provided [param room_coords] coordinates.
func has_result_cursor_coords(room_coords: Vector2i) -> bool:
	return room_coords in result_cursors and result_cursors[room_coords] != null


## Updates [param room_cell_instance] position based on the room coordinates saved in it's room_coords parameter.
func _update_result_cursor_position(result_cursor_instance: MapSolverResultCursor, cursor_position: Vector2) -> void:
	result_cursor_instance.position = cursor_position
