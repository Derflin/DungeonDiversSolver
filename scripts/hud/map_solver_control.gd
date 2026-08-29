class_name MapSolverControl
extends Control

const MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS = {
	GameState.MapSolverState.PLACEMENT_HINT: "Hint Placement",
	GameState.MapSolverState.WEIGHT_HINT: "Hint Weight",
	GameState.MapSolverState.SOLUTION_SHOW: "Show Solution",
}
const DROPDOWNS_DISPLAY_TEXTS_CLOSED = "▼"

const DROPDOWNS_DISPLAY_TEXTS_OPENED = "▲"


var _menu_effective_ui_scale: int = 1
var _dropdowns: Dictionary[MapSolverDropdown, GameState.MapSolverState]
var _state_animation: Tween


@export_group("State Pannel Animation", "state_animation_")
@export var state_animation_enabled: bool = true
@export_range(0.0, 1.0, 0.01)
var state_animation_show_duration: float = 0.12
@export_range(0.0, 1.0, 0.01)
var state_animation_hide_duration: float = 0.12


@onready var menu_root: Control = $MenuAnchor/MenuRoot
@onready var menu_contents: Control = $MenuAnchor/MenuRoot/MenuContents

@onready var menu_button_placement_hint: MapSolverDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/PlacementHintButton
@onready var menu_button_weight_hint: MapSolverDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/WeightHintButton
@onready var menu_button_solution_show: MapSolverDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/SolutionShowButton

@onready var solver_state_panel: PanelContainer = $MenuAnchor/MenuRoot/MenuContents/StatePanel
@onready var solver_state_label: Label = $MenuAnchor/MenuRoot/MenuContents/StatePanel/MarginContainer/StateContainer/StateLabel
@onready var solver_state_icon: TextureRect = $MenuAnchor/MenuRoot/MenuContents/StatePanel/MarginContainer/StateContainer/StateIcon
@onready var solver_state_room_type_label: Label = $MenuAnchor/MenuRoot/MenuContents/StatePanel/MarginContainer/StateContainer/StateRoomTypeLabel


@export_group("Menu Layout", "menu_")
@export_range(0, 1, 0.01)
var menu_max_width_coverage: float = 0.8
@export_range(1, 4, 1)
var menu_preferred_ui_scale: int = 2
@export_range(1, 4, 1)
var menu_minimum_ui_scale: int = 2


func _ready() -> void:
	# Initialize state panel initial state
	solver_state_panel.hide()
	solver_state_panel.modulate.a = 0.0
	
	# Initialize dropdown instances
	_dropdowns = {
		menu_button_placement_hint: GameState.MapSolverState.PLACEMENT_HINT,
		menu_button_weight_hint: GameState.MapSolverState.WEIGHT_HINT,
		menu_button_solution_show: GameState.MapSolverState.SOLUTION_SHOW,
	}
	_setup_dropdowns()
	
	# Attach node resized signal to handle resizing and refreshing menu layout
	resized.connect(_on_control_resized)
	
	# Refresh menu layout after initializing all the map parameter entries 
	call_deferred("_refresh_menu_layout")
	
	# Attach signal listener when other submenu opens, to close this submenu if opened
	GameState.map_parameters_submenu_opened.connect(_on_other_menu_submenu_opened)
	
	# Attach signal listener when the map solver state changes
	GameState.map_solver_state_changed.connect(_on_game_state_map_solver_state_changed)


func _setup_dropdowns() -> void:
	for dropdown_instance in _dropdowns:
		var dropdown_state := _dropdowns[dropdown_instance]
		
		# Initialize dropdown button text
		if dropdown_state in MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS:
			dropdown_instance.text = " ".join([MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[dropdown_state], DROPDOWNS_DISPLAY_TEXTS_CLOSED])
		
		# Populate dropdown options
		_populate_dropdown(dropdown_instance)
		
		# Connect signals dropdown toggled and option selected signals and add relevant parameters to them
		dropdown_instance.toggled.connect(_on_dropdown_button_toggled.bind(dropdown_instance, dropdown_state))
		dropdown_instance.option_selected.connect(_on_dropdown_option_pressed.bind(dropdown_state))


func _populate_dropdown(dropdown_instance: MapSolverDropdown) -> void:
	# Make sure that a dropdown doesn't have any other options initialized
	dropdown_instance.clear_options()
	
	# Populate dropdown options with data about secret room types
	var secret_room_kinds := GameData.room_secret_types.get_all_kinds()
	for secret_room_kind in secret_room_kinds:
		var secret_room_type := GameData.room_secret_types.get_type(secret_room_kind)
		
		dropdown_instance.add_option(secret_room_kind as int, secret_room_type.get_display_name(), secret_room_type.get_static_texture())


func _on_dropdown_button_toggled(toggle_on: bool, dropdown_instance: MapSolverDropdown, dropdown_state: GameState.MapSolverState) -> void:
	# Update button text
	if toggle_on:
		if dropdown_state in MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS:
			dropdown_instance.text = " ".join([MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[dropdown_state], DROPDOWNS_DISPLAY_TEXTS_OPENED])
	if not toggle_on:
		if dropdown_state in MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS:
			dropdown_instance.text = " ".join([MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[dropdown_state], DROPDOWNS_DISPLAY_TEXTS_CLOSED])
	
	# Emit signal that map solver submenu was opened
	GameState.map_solver_submenu_opened.emit()


func _on_dropdown_option_pressed(option_id, map_solver_state: GameState.MapSolverState) -> void:
	# Emit signal that map solver state was triggered to be changed
	var option_secret_room_kind := option_id as RoomSecretType.Kind
	GameState.map_solver_state_change_triggered.emit(map_solver_state, option_secret_room_kind)


func _refresh_menu_layout() -> void:
	# Check if node was already initialized
	if not is_node_ready():
		return
	
	# Set base menu scale
	menu_root.scale = Vector2.ONE
	
	# Calculate total height
	var natural_panel_size := _get_natural_menu_size()
	
	# Calculate effective menu scale
	_menu_effective_ui_scale = _calculate_ui_scale(natural_panel_size)
	
	# Set calculated effective menu scale
	menu_root.scale = Vector2.ONE * float(_menu_effective_ui_scale)
	
	# Position menu root based on the menu scale
	_position_menu_root()


func _position_menu_root() -> void:
	# Prepare scale factor
	var scale_factor := float(_menu_effective_ui_scale)
	
	# Adjust menu root position
	menu_root.position = Vector2(
		-menu_contents.size.x * scale_factor * 0.5,
		0,
	)


func _calculate_ui_scale(total_size_1x: Vector2) -> int:
	# Calculate menu size
	var available_size := size
	available_size.x *= menu_max_width_coverage
	
	# Get menu minimum ui scale
	var menu_minimum_scale := mini(menu_minimum_ui_scale, menu_preferred_ui_scale)
	
	# Check which biggest ui scale would fit the calculated menu size after scaling it up
	for scale_candidate in range(menu_preferred_ui_scale, menu_minimum_scale - 1, -1):
		if total_size_1x.x * scale_candidate <= available_size.x and total_size_1x.y * scale_candidate <= available_size.y:
			return scale_candidate
	
	# Return fallback ui scale value
	return menu_minimum_scale


func _get_natural_menu_size() -> Vector2:
	return menu_contents.get_combined_minimum_size()


func _on_control_resized() -> void:
	call_deferred("_refresh_menu_layout")


func _on_other_menu_submenu_opened() -> void:
	for dropdown_instance in _dropdowns:
		if dropdown_instance.is_dropdown_open():
			dropdown_instance.close_dropdown()


func _on_game_state_map_solver_state_changed() -> void:
	# Get data from game state regarding map solver state
	var cur_map_solver_state := GameState.map_solver_state
	var cur_map_solver_secret_kind := GameState.map_solver_secret_kind
	
	# Hide state panel if either the map solver state is none or map solver secret kind is none
	if cur_map_solver_secret_kind == RoomSecretType.Kind.NONE or cur_map_solver_state == GameState.MapSolverState.NONE:
		_hide_state_panel()
	else:
		# Gather data about secret room type
		var selected_secret_room_type: RoomSecretType = null
		if GameData.room_secret_types.has_type(cur_map_solver_secret_kind):
			selected_secret_room_type = GameData.room_secret_types.get_type(cur_map_solver_secret_kind)
		
		_show_state_panel(
			" - ".join(["Solver", MAP_SOLVER_STATE_MODE_DISPLAY_TEXTS[cur_map_solver_state], ""]).strip_edges(),
			selected_secret_room_type.get_static_texture(),
			selected_secret_room_type.get_display_name(),
		)


func _show_state_panel(state_text: String, state_icon: Texture, state_room_type_text: String) -> void:
	# Initialize state panel data
	solver_state_label.text = state_text
	solver_state_icon.texture = state_icon
	solver_state_room_type_label.text = state_room_type_text
	
	# Filter out processing if the state panel is already visible
	if solver_state_panel.visible:
		return
	
	# Show state panel
	solver_state_panel.show()
	
	# Stop existing animation
	_kill_state_animation()
	
	# If animation is disabled, then simply set the desired state
	if not state_animation_enabled:
		solver_state_panel.modulate.a = 1.0
		return
	
	# Initialize animation with animated opacity transition
	_state_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_animation.tween_property(solver_state_panel, "modulate:a", 1.0, state_animation_show_duration)


func _hide_state_panel() -> void:
	# Filter out processing if the state panel is already hidden
	if not solver_state_panel.visible:
		return
	
	# Stop existing animation
	_kill_state_animation()
	
	# If animation is disabled, then simply set the desired state
	if not state_animation_enabled:
		_on_state_panel_close_animation_finished()
		return
	
	# Initialize animation with animated opacity transition
	_state_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_state_animation.tween_property(solver_state_panel, "modulate:a", 0.0, state_animation_hide_duration)
	
	# Prepare signal connection after animation ends to finalize hiding submenu
	if _state_animation != null and _state_animation.is_valid():
		_state_animation.finished.connect(_on_state_panel_close_animation_finished)


func _on_state_panel_close_animation_finished() -> void:
	# Hide submenu panel and set it's state
	solver_state_panel.hide()
	solver_state_panel.modulate.a = 0.0


func _kill_state_animation() -> void:
	if _state_animation != null and _state_animation.is_valid():
		_state_animation.kill()
	
	_state_animation = null


func _on_cancel_button_pressed() -> void:
	# Emit signal that map solver state was triggered to reset
	GameState.map_solver_state_change_triggered.emit(GameState.MapSolverState.NONE, RoomSecretType.Kind.NONE)
