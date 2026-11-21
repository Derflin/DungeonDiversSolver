class_name MapSolverControl
extends Control


const MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS = {
	GameState.MapSolverState.PLACEMENT_HINT: "Hint Placement",
	GameState.MapSolverState.WEIGHT_HINT: "Hint Weight",
	GameState.MapSolverState.SOLUTION_SHOW: "Show Solution",
}


@export_group("Menu Layout", "menu_")
## Maximum portion of the available width occupied by the menu.
@export_range(0.01, 1.0, 0.01) var menu_max_width_coverage: float = 0.8
## Maximum portion of the available height occupied by the menu.
@export_range(0.01, 1.0, 0.01) var menu_max_height_coverage: float = 1.0
## Enables the preferred maximum menu scale.
@export var menu_max_scale_enabled: bool = true
## Largest menu scale used when the maximum scale is enabled.
@export_range(0.1, 10.0, 0.05) var menu_max_scale: float = 2.0

@export_group("Status Layout", "status_")
## Maximum portion of the available width occupied by the status panel.
@export_range(0.01, 1.0, 0.01) var status_max_width_coverage: float = 0.8
## Maximum portion of the available height occupied by the status panel.
@export_range(0.01, 1.0, 0.01) var status_max_height_coverage: float = 1.0
## Enables the preferred maximum status panel scale.
@export var status_max_scale_enabled: bool = true
## Largest status panel scale used when the maximum scale is enabled.
@export_range(0.1, 10.0, 0.05) var status_max_scale: float = 2.0


var _menu_effective_ui_scale: float = 1.0
var _status_effective_ui_scale: float = 1.0
var _menu_dropdowns: Dictionary[MenuDropdown, GameState.MapSolverState]


@onready var menu_root: Control = $MenuAnchor/MenuRoot
@onready var menu_contents: Control = $MenuAnchor/MenuRoot/MenuContents
@onready var status_root: Control = $StatusAnchor/StatusRoot
@onready var status_contents: Control = $StatusAnchor/StatusRoot/StatusContents

@onready var menu_button_placement_hint: MenuDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/PlacementHintButton
@onready var menu_button_weight_hint: MenuDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/WeightHintButton
@onready var menu_button_solution_show: MenuDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/SolutionShowButton

@onready var solver_state_panel: PanelContainer = $MenuAnchor/MenuRoot/MenuContents/StatePanel
@onready var solver_status_panel: PanelContainer = $StatusAnchor/StatusRoot/StatusContents/StatusPanel


func _ready() -> void:
	# Initialize menu dropdown instances
	_menu_dropdowns = {
		menu_button_placement_hint: GameState.MapSolverState.PLACEMENT_HINT,
		menu_button_weight_hint: GameState.MapSolverState.WEIGHT_HINT,
		menu_button_solution_show: GameState.MapSolverState.SOLUTION_SHOW,
	}
	_setup_menu_dropdowns()
	
	# Attach node resized signal to handle resizing and refreshing menu layout
	resized.connect(_on_control_resized)
	
	# Keep status panel centered while its contents resize
	status_contents.resized.connect(_position_status_root)
	
	# Refresh menu layout after initializing all the map parameter entries 
	call_deferred("_refresh_menu_layout")
	
	# Attach signal listener when other submenu opens, to close this submenu if opened
	GameState.map_parameters_submenu_opened.connect(_on_other_menu_submenu_opened)
	
	# Attach signal listener when the map solver state changes
	GameState.map_solver_state_changed.connect(_on_game_state_map_solver_state_changed)


func _setup_menu_dropdowns() -> void:
	for menu_dropdown_instance in _menu_dropdowns:
		var menu_dropdown_state := _menu_dropdowns[menu_dropdown_instance]
		
		# Initialize menu dropdown button text
		if menu_dropdown_state in MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS:
			menu_dropdown_instance.change_dropdown_button_text(MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[menu_dropdown_state])
		
		# Populate menu dropdown options
		_populate_menu_dropdown(menu_dropdown_instance)
		
		# Connect signals menu dropdown toggled and option selected signals and add relevant parameters to them
		menu_dropdown_instance.toggled.connect(_on_menu_dropdown_button_toggled.bind(menu_dropdown_instance, menu_dropdown_state))
		menu_dropdown_instance.option_selected.connect(_on_menu_dropdown_option_pressed.bind(menu_dropdown_state))


func _populate_menu_dropdown(menu_dropdown_instance: MenuDropdown) -> void:
	# Make sure that a menu dropdown doesn't have any other options initialized
	menu_dropdown_instance.clear_options()
	
	# Populate menu dropdown options with data about secret room types
	var secret_room_type_kinds_ordered = RoomSecretType.ROOM_SECRET_TYPE_CREATE_ORDER
	for secret_room_type_kind in secret_room_type_kinds_ordered:
		# Check if secret room type exists in the current game data
		if not GameData.room_secret_types.has_type(secret_room_type_kind):
			continue
		
		var secret_room_type := GameData.room_secret_types.get_type(secret_room_type_kind)
		
		menu_dropdown_instance.add_option(secret_room_type_kind as int, secret_room_type.get_display_name(), secret_room_type.get_static_texture())


func _on_menu_dropdown_button_toggled(toggle_on: bool, menu_dropdown_instance: MenuDropdown, menu_dropdown_state: GameState.MapSolverState) -> void:
	# Update button text
	if toggle_on:
		if menu_dropdown_state in MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS:
			menu_dropdown_instance.change_dropdown_button_text(MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[menu_dropdown_state])
	if not toggle_on:
		if menu_dropdown_state in MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS:
			menu_dropdown_instance.change_dropdown_button_text(MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[menu_dropdown_state])
	
	# Emit signal that map solver submenu was opened
	GameState.map_solver_submenu_opened.emit()


func _on_menu_dropdown_option_pressed(option_id, map_solver_state: GameState.MapSolverState) -> void:
	# Emit signal that map solver state was triggered to be changed
	var option_secret_room_kind := option_id as RoomSecretType.Kind
	GameState.map_solver_state_change_triggered.emit(map_solver_state, option_secret_room_kind)


func _refresh_menu_layout() -> void:
	# Check if node was already initialized
	if not is_node_ready():
		return
	
	# Set base menu scale
	menu_root.scale = Vector2.ONE
	status_root.scale = Vector2.ONE
	
	# Calculate total height
	var natural_menu_panel_size := _get_natural_menu_size()
	var natural_status_panel_size := _get_natural_status_size()
	
	# Calculate effective menu scale
	_menu_effective_ui_scale = _calculate_menu_scale(natural_menu_panel_size)
	_status_effective_ui_scale = _calculate_status_scale(natural_status_panel_size)
	
	# Set calculated effective menu scale
	menu_root.scale = Vector2.ONE * float(_menu_effective_ui_scale)
	status_root.scale = Vector2.ONE * float(_status_effective_ui_scale)
	
	# Position menu root based on the menu scale
	_position_menu_root()
	_position_status_root()


func _position_menu_root() -> void:
	# Prepare scale factor
	var scale_factor := float(_menu_effective_ui_scale)
	
	# Adjust menu root position
	menu_root.position = Vector2(
		-menu_contents.size.x * scale_factor * 0.5,
		0,
	)


func _position_status_root() -> void:
	# Prepare scale factor
	var scale_factor := float(_status_effective_ui_scale)

	# Adjust status root position
	status_root.position = Vector2(
		-status_contents.size.x * scale_factor * 0.5,
		-1.0 * status_contents.size.y * scale_factor,
	)


## Calculates a uniform top menu scale from the provided [param total_size_1x] and available layout space.
func _calculate_menu_scale(total_size_1x: Vector2) -> float:
	# Calculate the top menu coverage limits.
	var coverage := Vector2(menu_max_width_coverage, menu_max_height_coverage)
	
	# Return the scale that fits the menu inside both layout limits.
	return UIScaleCalculator.calculate_scale(total_size_1x, size, coverage, menu_max_scale_enabled, menu_max_scale)


## Calculates a uniform status scale from the provided [param total_size_1x] and available layout space.
func _calculate_status_scale(total_size_1x: Vector2) -> float:
	# Calculate the status panel coverage limits.
	var coverage := Vector2(status_max_width_coverage, status_max_height_coverage)
	
	# Return the scale that fits the status panel inside both layout limits.
	return UIScaleCalculator.calculate_scale(total_size_1x, size, coverage, status_max_scale_enabled, status_max_scale)


func _get_natural_menu_size() -> Vector2:
	return menu_contents.get_combined_minimum_size()


func _get_natural_status_size() -> Vector2:
	return status_contents.get_combined_minimum_size()


func _on_control_resized() -> void:
	call_deferred("_refresh_menu_layout")


func _on_other_menu_submenu_opened() -> void:
	for menu_dropdown_instance in _menu_dropdowns:
		if menu_dropdown_instance.is_dropdown_open():
			menu_dropdown_instance.close_dropdown()


func _on_game_state_map_solver_state_changed() -> void:
	# Get data from game state regarding map solver state
	var cur_map_solver_state := GameState.map_solver_state
	var cur_map_solver_secret_kind := GameState.map_solver_secret_kind
	var cur_map_solver_result := GameState.map_solver_result
	
	# Hide state panel if either the map solver state is none or map solver secret kind is none
	if cur_map_solver_secret_kind == RoomSecretType.Kind.NONE or cur_map_solver_state == GameState.MapSolverState.NONE or cur_map_solver_result == null:
		solver_state_panel.hide_state_panel()
		solver_status_panel.hide_status_panel()
	else:
		# Gather data about secret room type
		var selected_secret_room_type: RoomSecretType = null
		if GameData.room_secret_types.has_type(cur_map_solver_secret_kind):
			selected_secret_room_type = GameData.room_secret_types.get_type(cur_map_solver_secret_kind)
		
		solver_state_panel.show_state_panel(
			MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[cur_map_solver_state],
			selected_secret_room_type.get_static_texture(),
			selected_secret_room_type.get_display_name(),
		)
		solver_status_panel.show_status_panel(cur_map_solver_result.get_status_message())


func _on_cancel_button_pressed() -> void:
	# Emit signal that map solver state was triggered to reset
	GameState.map_solver_state_change_triggered.emit(GameState.MapSolverState.NONE, RoomSecretType.Kind.NONE)


#region HUD Transition Wait Group

## Checks and returns a bool value indicating if there are currently any active tween transitions that would delay the creation of save screenshot.
func has_pending_hud_transition() -> bool:
	var has_active_animation_in_menu_dropdowns: bool = false
	for menu_dropdown: MenuDropdown in _menu_dropdowns.keys():
		if menu_dropdown.has_active_animation():
			has_active_animation_in_menu_dropdowns = true
			break
			
	return has_active_animation_in_menu_dropdowns

#endregion
