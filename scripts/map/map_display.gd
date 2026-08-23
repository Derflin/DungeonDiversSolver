extends Node2D


#TODO: look through defined functions and check if any of them could be renamed to internal (_ at the begginging of the function names)
#TODO: add readme file and mark TODOs in it
#TODO: add comments
#TODO: add asserts if everything needed is assigned on the start (mostly in case of export variables that need to be populated for everything to work correctly)

#TODO: implement scripts for checking, hinting and solving each secret room type based on the current map
#TODO: --- add overlay hud menu for triggering hinting and solving each secret room type for the current map
#TODO: --- --- the overlay should be placed at the top of the screen, it should consist of 3 buttons (preview placement locations, preview weight, preview placement percentage)
#TODO: --- --- --- each button should display a list of secret types to choose from, which would trigger different mapsolver modes
#TODO: --- --- apart from that underneath it should be 2 labels, one for displaying room solver current state, second for some option description (for example how many rooms found etc.)
#TODO: --- add variables to gamestate in order to keep track of mapsolver mode, results and displayed label with description under
#TODO: --- --- also add some signals for them
#TODO: --- basically when the user changes the mapsolver mode, it should set appropriate gamestate variables
#TODO: --- this would trigger correct signals, which would be listened to for example in gridspace
#TODO: --- gridspace when receiving this signal or if any room was changed/added/removed, would check the gamestate variables for the mapsolver and trigger func from it
#TODO: --- after receiving the results, it should save them inside the gamestate variable along with the messages to display in label and it's description under buttons
#TODO: --- at the same time or shortly after it, it should try to initialize MapSolverCursors (not yet existing) that would display appropriate mapsolver results on map
#TODO: --- --- these results can consist of simply highlighting grid cells or also displaying some colored weights or percentages
#TODO: --- after setting mapsolver label and description inside gamestate, it should trigger a signal listened by mapsolver UI and populate label and it's description with saved results

#TODO: add map validation based on some rules (rules defined in cataloge or something, displayed on screen to show which failed and which succeeded)
#TODO: add option to save/load current map into a file
#TODO: ---	add option to load in map state from game screenshot (most likey would need to analyze the image and assume that the whole map is visible on it)
#TODO: add some audio system for placing the rooms
#TODO: add some map builder system for animating placing the rooms and for map solver


@onready var grid_space: Node2D = $GridSpace
@onready var map_camera_manager: Node2D = $MapCameraManager


func _ready() -> void:
	map_camera_manager.set_grid_rect(grid_space.get_map_rect())
	var instant = true
	map_camera_manager.fit_map_to_view(instant)


func _on_grid_space_grid_space_parameters_changed() -> void:
	map_camera_manager.set_grid_rect(grid_space.get_map_rect())
	map_camera_manager.fit_map_to_view()


func _on_grid_space_selected_room_changed(room_center_position: Vector2) -> void:
	map_camera_manager.center_camera_at_position(room_center_position)
