class_name MapSolverControl
extends Control


const DROPDOWNS_DISPLAY_TEXTS_CLOSED = {
	GameState.MapSolverState.PLACEMENT_HINT: "Hint Placement ▼",
	GameState.MapSolverState.WEIGHT_HINT: "Hint Weight ▼",
	GameState.MapSolverState.SOLUTION_SHOW: "Show Solution ▼",
}
const DROPDOWNS_DISPLAY_TEXTS_OPENED = {
	GameState.MapSolverState.PLACEMENT_HINT: "Hint Placement ▲",
	GameState.MapSolverState.WEIGHT_HINT: "Hint Weight ▲",
	GameState.MapSolverState.SOLUTION_SHOW: "Show Solution ▲",
}


var _menu_effective_ui_scale: int = 1
var _dropdowns: Dictionary[MapSolverDropdown, GameState.MapSolverState]


@onready var menu_root: Control = $MenuAnchor/MenuRoot
@onready var menu_contents: Control = $MenuAnchor/MenuRoot/MenuContents

@onready var menu_button_placement_hint: MapSolverDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/PlacementHintButton
@onready var menu_button_weight_hint: MapSolverDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/WeightHintButton
@onready var menu_button_solution_show: MapSolverDropdown = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/SolutionShowButton

@onready var label_solver_mode: Label = $MenuAnchor/MenuRoot/MenuContents/ModeLabel
@onready var label_solver_description: Label = $MenuAnchor/MenuRoot/MenuContents/DescriptionLabel


@export_group("Menu Layout", "menu_")
@export_range(0, 1, 0.01)
var menu_max_width_coverage: float = 0.8
@export_range(1, 4, 1)
var menu_preferred_ui_scale: int = 2
@export_range(1, 4, 1)
var menu_minimum_ui_scale: int = 2


func _ready() -> void:
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


func _setup_dropdowns() -> void:
	for dropdown_instance in _dropdowns:
		var dropdown_state := _dropdowns[dropdown_instance]
		
		# Initialize dropdown button text
		if dropdown_state in DROPDOWNS_DISPLAY_TEXTS_CLOSED:
			dropdown_instance.text = DROPDOWNS_DISPLAY_TEXTS_CLOSED[dropdown_state]
		
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
	if toggle_on:
		if dropdown_state in DROPDOWNS_DISPLAY_TEXTS_OPENED:
			dropdown_instance.text = DROPDOWNS_DISPLAY_TEXTS_OPENED[dropdown_state]
	if not toggle_on:
		if dropdown_state in DROPDOWNS_DISPLAY_TEXTS_CLOSED:
			dropdown_instance.text = DROPDOWNS_DISPLAY_TEXTS_CLOSED[dropdown_state] 


func _on_dropdown_option_pressed(option_id, dropdown_state: GameState.MapSolverState) -> void:
	#TODO: add some signals inside GameState and connect them here
	print("Menu: ", dropdown_state)
	print("Option: ", option_id)


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
