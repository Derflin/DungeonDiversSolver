extends Node2D


@onready var grid_space: Node2D = $GridSpace
@onready var map_camera_manager: Node2D = $MapCameraManager


func _ready() -> void:
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)
	GameSettings.map_grid_room_size_parameter_changed.connect(_on_game_settings_map_grid_room_size_parameter_changed)
	
	update_map_camera_manager_display(true)


func update_grid_space_display(update_each_room_cell: bool = false) -> void:
	if update_each_room_cell:
		grid_space.update_all_room_cells_positions()
	
	# Hide selected room cursor
	grid_space.hide_selected_room_cursor()
	
	grid_space.redraw_grid_lines()


func update_map_camera_manager_display(instant_fit_map_to_view: bool = false) -> void:
	map_camera_manager.set_grid_rect(grid_space.get_map_rect())
	map_camera_manager.fit_map_to_view(instant_fit_map_to_view)


func _on_game_settings_map_grid_size_parameter_changed(_map_grid_size: Vector2i) -> void:
	update_grid_space_display(false)
	
	update_map_camera_manager_display(false)


func _on_game_settings_map_grid_room_size_parameter_changed(_map_grid_room_size: Vector2i) -> void:
	update_grid_space_display(true)
	
	update_map_camera_manager_display(false)


func _on_grid_space_selected_room_changed(room_center_position: Vector2) -> void:
	map_camera_manager.center_camera_at_position(room_center_position)
