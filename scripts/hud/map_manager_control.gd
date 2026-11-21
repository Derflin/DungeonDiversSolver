class_name MapManagerControl
extends Control


signal map_manager_reset_map_state_requested()
signal map_manager_reset_map_settings_requested()


const HUD_TRANSITION_WAIT_GROUP: StringName = &"hud_transition_wait"
const MAX_TRANSITION_WAIT_MS: int = 1500


@export var save_manager_control: SaveManagerControl

@export_group("Menu Layout", "menu_")
## Maximum portion of the available width occupied by the menu.
@export_range(0.01, 1.0, 0.01) var menu_max_width_coverage: float = 0.8
## Maximum portion of the available height occupied by the menu.
@export_range(0.01, 1.0, 0.01) var menu_max_height_coverage: float = 1.0
## Enables the preferred maximum menu scale.
@export var menu_max_scale_enabled: bool = true
## Largest menu scale used when the maximum scale is enabled.
@export_range(0.1, 10.0, 0.05) var menu_max_scale: float = 2.0


var _menu_effective_ui_scale: float = 1.0


@onready var menu_root: Control = $MenuAnchor/MenuRoot
@onready var menu_contents: Control = $MenuAnchor/MenuRoot/MenuContents

@onready var reset_map_state_button: Button = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/Buttons/MapManagerContainer/VBoxContainer/ResetMapStateButton
@onready var reset_map_settings_button: Button = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/Buttons/MapManagerContainer/VBoxContainer/ResetMapSettingsButton
@onready var save_button: Button = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/Buttons/SaveManagerContainer/VBoxContainer/SaveButton
@onready var load_button: Button = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/Buttons/SaveManagerContainer/VBoxContainer/LoadButton


func _ready() -> void:
	# Make sure that the required exported save manager control field has been assigned.
	assert(save_manager_control != null, "MapManagerControl: SaveManagerControl scene has not been assigned.")
	
	# Attach node resized signal to handle resizing and refreshing menu layout.
	resized.connect(_on_control_resized)
	
	# Refresh menu layout.
	call_deferred("_refresh_menu_layout")
	
	# Handle map manager buttons pressed signal by connecting them to appropriate local functions.
	reset_map_state_button.pressed.connect(_on_reset_map_state_button_pressed)
	reset_map_settings_button.pressed.connect(_on_reset_map_settings_button_pressed)
	
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


## Calculates a uniform menu scale from the provided [param total_size_1x] and the available layout area.
func _calculate_ui_scale(total_size_1x: Vector2) -> float:
	# Calculate the menu coverage limits inside the parent control.
	var coverage := Vector2(menu_max_width_coverage, menu_max_height_coverage)
	
	# Return the scale that fits the menu inside both layout limits.
	return UIScaleCalculator.calculate_scale(total_size_1x, size, coverage, menu_max_scale_enabled, menu_max_scale)


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


## Handles propagating the reset map state requested signal.
func _on_reset_map_state_button_pressed() -> void:
	map_manager_reset_map_state_requested.emit()


## Handles propagating the reset map settings requested signal.
func _on_reset_map_settings_button_pressed() -> void:
	map_manager_reset_map_settings_requested.emit()


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
	
	# Wait fr pending hud transitions before opening a menu that pauses the scene tree.
	await _wait_for_hud_transitions()
	
	# Open save manager display in load mode.
	save_manager_control.open_load_mode()


## Returns a game screenshot based on the current viewport state.
func _capture_game_screenshot() -> Image:
	# Wait for all the game screenshot related transitions to end before starting to prepare a screenshot.
	await _wait_for_hud_transitions()
	
	# Await for when the current frame will be finished rendering.
	await RenderingServer.frame_post_draw
	
	# Return current viewport screenshot as game screenshot.
	return get_viewport().get_texture().get_image()


#region HUD Transition Wait Group

## Checks and returns a bool value indicating if there are currently any active tween transitions that would delay the creation of save screenshot.
func has_pending_hud_transition() -> bool:
	return false


## Check related nodes in the HUD_TRANSITION_WAIT_GROUP group and waits until all their pending save screenshot has passed.
## If the waiting time would exceed the static value defined in MAX_TRANSITION_WAIT_MS static variable, it will automatically stop waiting.
func _wait_for_hud_transitions() -> void:
	# Get current time.
	var start_time := Time.get_ticks_msec()
	
	# Wait until all related transitions affecting save screenshot would pass or if the MAX_TRANSITION_WAIT_MS would pass in the meantime.
	while true:
		var has_pending_transition := false
		
		# Check if any of the nodes assigned to the HUD_TRANSITION_WAIT_GROUP has some pending transitions.
		for node in get_tree().get_nodes_in_group(HUD_TRANSITION_WAIT_GROUP):
			# Filter out processing if the node doesn't have appropriate function for checking pending transitions and push warnign for it.
			if not node.has_method("has_pending_hud_transition"):
				push_warning("Missing transition check method on: " + node.name)
				continue
			
			# Check pending transitions for the node.
			if node.call("has_pending_hud_transition"):
				has_pending_transition = true
				break
		
		# Return from the current function if all the relevant transitions have finished.
		if not has_pending_transition:
			return
		
		# Break current loop if MAX_TRANSITION_WAIT_MS time has already passed from the start of the function.
		if Time.get_ticks_msec() - start_time >= MAX_TRANSITION_WAIT_MS:
			return
		
		# Check pending transitions again on the next frame.
		await get_tree().process_frame

#endregion
