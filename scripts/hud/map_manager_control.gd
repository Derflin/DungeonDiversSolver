class_name MapManagerControl
extends PanelContainer


@export var save_manager_control: SaveManagerControl


@onready var save_button: Button = $MarginContainer/Buttons/SaveButton
@onready var load_button: Button = $MarginContainer/Buttons/LoadButton


func _ready() -> void:
	# Make sure that the required exported save manager control field has been assigned.
	assert(save_manager_control != null, "MapManagerControl: SaveManagerControl scene has not been assigned.")
	
	# Handle save manager buttons pressed signal by connecting them to appropriate local functions.
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)


## Handles save button pressed signal to open the save manager display in save mode.
func _on_save_button_pressed() -> void:
	# Filter out processing if the save manager control hasn't been assigned.
	if save_manager_control == null:
		return
	
	# Filter out processing if the save manager control is already opened.
	if save_manager_control.visible:
		return
	
	# Capture current game screenshot.
	var screenshot := await _capture_game_screenshot()
	
	# Open save manager display in save mode with the prepared screenshot.
	save_manager_control.open_save_mode(screenshot)


## Handles load button pressed signal to open the save manager display in load mode.
func _on_load_button_pressed() -> void:
	# Filter out processing if the save manager control hasn't been assigned.
	if save_manager_control == null:
		return
	
	# Filter out processing if the save manager control is already opened.
	if save_manager_control.visible:
		return
	
	# Open save manager display in load mode.
	save_manager_control.open_load_mode()


## Returns a game screenshot based on the current viewport state.
func _capture_game_screenshot() -> Image:
	# Await for when the current frame will be finished rendering.
	await RenderingServer.frame_post_draw
	
	# Return current viewport screenshot as game screenshot.
	return get_viewport().get_texture().get_image()
