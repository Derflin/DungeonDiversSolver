extends Node2D


#TODO: look through debugger warnings and check if any of them could be easily removed
#TODO: look through defined functions and check if any of them could be renamed to internal (_ at the begginging of the function names)
#TODO: add readme file and mark TODOs in it
#TODO: add comments
#TODO: add asserts if everything needed is assigned on the start (mostly in case of export variables that need to be populated for everything to work correctly)
#TODO: add room_cell_preview for testing out different textures/animations
#TODO: add map validation based on some rules (rules defined in cataloge or something, displayed on screen to show which failed and which succeeded)
#TODO: add option to save/load current map into a file
#TODO: add option to set map parameters like map size, types of secret rooms, their count and their order
#TODO: implement scripts for checking, hinting and solving each secret room type based on the current map
#TODO: add overlay hud menu for triggering hinting and solving each secret room type for the current map
#TODO: add option to load in map state from game screenshot (most likey would need to analyze the image and assume that the whole map is visible on it)


@onready var grid_space: Node2D = $GridSpace
@onready var map_camera_manager: Node2D = $MapCameraManager


func _ready() -> void:
	map_camera_manager.set_grid_rect(grid_space.get_map_rect())
	var instant = true
	map_camera_manager.fit_map_to_view(instant)


func _on_grid_space_grid_space_parameters_changed() -> void:
	map_camera_manager.fit_map_to_view()


func _on_grid_space_selected_room_changed(room_center_position: Vector2) -> void:
	map_camera_manager.center_camera_at_position(room_center_position)
