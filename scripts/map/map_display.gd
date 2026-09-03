extends Node2D


@onready var grid_space: Node2D = $GridSpace
@onready var map_camera_manager: Node2D = $MapCameraManager


func _ready() -> void:
	# Connect game settings map grid parameter changed signals to handle updating map display
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)
	GameSettings.map_grid_room_size_parameter_changed.connect(_on_game_settings_map_grid_room_size_parameter_changed)
	
	# Connect map state room signals to handle their visuals
	GameState.map_state.room_created.connect(_on_game_state_map_state_room_created)
	GameState.map_state.room_deleted.connect(_on_game_state_map_state_room_deleted)
	GameState.map_state.room_updated.connect(_on_game_state_map_state_room_updated)
	
	# Initialize map camera manager display
	update_map_camera_manager_display(true)


## Updates grid space display elements that would be affected by the game settings grid parameter changes.
func update_grid_space_display(update_each_room_cell: bool = false) -> void:
	# Update room cells instance positions
	if update_each_room_cell:
		grid_space.update_all_room_cells_positions()
	
	# Hide selected room cursor
	grid_space.hide_selected_room_cursor()
	
	# Redraw grid lines visible in the background
	grid_space.redraw_grid_lines()


## Updates map camera maanger display elements that would be affected by the game settings grid parameter changes.
func update_map_camera_manager_display(instant_fit_map_to_view: bool = false) -> void:
	# Update map camera manager handled grid rect based on the grid space map rect
	map_camera_manager.set_grid_rect(grid_space.get_map_rect())
	# Update camera parameters/settings to fit map to view
	map_camera_manager.fit_map_to_view(instant_fit_map_to_view)


## After game settings map grid room size parameter change was triggered, update all the affected by it elements. This includes grid space and the camera manager.
func _on_game_settings_map_grid_size_parameter_changed() -> void:
	update_grid_space_display(false)
	update_map_camera_manager_display(false)


## After game settings map grid room size parameter change was triggered, update all the affected by it elements. This includes grid space and all of it's room cells and the camera manager.
func _on_game_settings_map_grid_room_size_parameter_changed() -> void:
	update_grid_space_display(true)
	update_map_camera_manager_display(false)


## After game state map state room create was triggered, create a new room cell instance to display it.
func _on_game_state_map_state_room_created(room_coords: Vector2i, room_instance_data: RoomInstanceData) -> void:
	grid_space.create_room_cell(room_coords, room_instance_data)


## After game state map state room delete was triggered, delete an existing room cell instance to stop displaying it.
func _on_game_state_map_state_room_deleted(room_coords: Vector2i) -> void:
	grid_space.delete_room_cell(room_coords)


## After game state map state room update was triggered, update an existing room cell instance to update it's display.
func _on_game_state_map_state_room_updated(room_coords: Vector2i) -> void:
	grid_space.update_room_cell(room_coords)


## After grid space selected room change was triggered, center camera on it.
func _on_grid_space_selected_room_changed(room_center_position: Vector2) -> void:
	map_camera_manager.center_camera_at_position(room_center_position)
