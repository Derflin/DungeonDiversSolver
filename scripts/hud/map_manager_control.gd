class_name MapManagerControl
extends Control


@export var save_manager_control: SaveManagerControl

@export_group("Menu Layout", "menu_")
@export_range(0, 1, 0.01)
var menu_max_width_coverage: float = 0.8
@export_range(1, 4, 1)
var menu_preferred_ui_scale: int = 2
@export_range(1, 4, 1)
var menu_minimum_ui_scale: int = 2


var _menu_effective_ui_scale: int = 1


@onready var menu_root: Control = $MenuAnchor/MenuRoot
@onready var menu_contents: Control = $MenuAnchor/MenuRoot/MenuContents

@onready var save_button: Button = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/Buttons/SaveButton
@onready var load_button: Button = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/Buttons/LoadButton


func _ready() -> void:
	# Make sure that the required exported save manager control field has been assigned.
	assert(save_manager_control != null, "MapManagerControl: SaveManagerControl scene has not been assigned.")
	
	# Attach node resized signal to handle resizing and refreshing menu layout.
	resized.connect(_on_control_resized)
	
	# Refresh menu layout.
	call_deferred("_refresh_menu_layout")
	
	# Handle save manager buttons pressed signal by connecting them to appropriate local functions.
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)


## Refreshes menu layout by adjusting it's scale and it's position.
func _refresh_menu_layout() -> void:
	# Check if node was already initialized.
	if not is_node_ready():
		return
	
	# Set base menu scale.
	menu_root.scale = Vector2.ONE
	
	# Calculate total height.
	var natural_menu_panel_size := _get_natural_menu_size()
	
	# Calculate effective menu scale.
	_menu_effective_ui_scale = _calculate_ui_scale(natural_menu_panel_size)
	
	# Set calculated effective menu scale.
	menu_root.scale = Vector2.ONE * float(_menu_effective_ui_scale)
	
	# Position menu root based on the menu scale.
	_position_menu_root()


## Returns menu contents combined minimum size.
func _get_natural_menu_size() -> Vector2:
	return menu_contents.get_combined_minimum_size()


## Calculates and returns menu scale based on the provided unscaled size and checking the available scales set in the class parameters.
func _calculate_ui_scale(total_size_1x: Vector2) -> int:
	# Calculate menu size.
	var available_size := size
	available_size.x *= menu_max_width_coverage
	
	# Get menu minimum ui scale.
	var menu_minimum_scale := mini(menu_minimum_ui_scale, menu_preferred_ui_scale)
	
	# Check which biggest ui scale would fit the calculated menu size after scaling it up.
	for scale_candidate in range(menu_preferred_ui_scale, menu_minimum_scale - 1, -1):
		if total_size_1x.x * scale_candidate <= available_size.x and total_size_1x.y * scale_candidate <= available_size.y:
			return scale_candidate
	
	# Return fallback ui scale value.
	return menu_minimum_scale


## Positions menu root by adjusting it's position to ensure that it will be fully displayed according to the menu node anchor position.
func _position_menu_root() -> void:
	# Prepare scale factor
	var scale_factor := float(_menu_effective_ui_scale)
	
	# Adjust menu root position
	menu_root.position = Vector2(
		0,
		-menu_contents.size.y * scale_factor,
	)


## Handles menu resize by refreshing menu layout to fit the resized control node.
func _on_control_resized() -> void:
	call_deferred("_refresh_menu_layout")


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
