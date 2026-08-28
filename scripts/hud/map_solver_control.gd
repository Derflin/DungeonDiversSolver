class_name MapSolverControl
extends Control


const MENU_BUTTON_DISPLAY_TEXTS_CLOSED = {
	GameState.MapSolverState.PLACEMENT_HINT: "Hint Placement ▼",
	GameState.MapSolverState.WEIGHT_HINT: "Hint Weight ▼",
	GameState.MapSolverState.SOLUTION_SHOW: "Show Solution ▼",
}
const MENU_BUTTON_DISPLAY_TEXTS_OPENED = {
	GameState.MapSolverState.PLACEMENT_HINT: "Hint Placement ▲",
	GameState.MapSolverState.WEIGHT_HINT: "Hint Weight ▲",
	GameState.MapSolverState.SOLUTION_SHOW: "Show Solution ▲",
}


var _menu_effective_ui_scale: int = 1


@onready var menu_root: Control = $MenuAnchor/MenuRoot
@onready var menu_contents: Control = $MenuAnchor/MenuRoot/MenuContents

@onready var menu_button_placement_hint: MenuButton = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/PlacementHintButton
@onready var menu_button_weight_hint: MenuButton = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/WeightHintButton
@onready var menu_button_solution_show: MenuButton = $MenuAnchor/MenuRoot/MenuContents/MenuPanel/MarginContainer/ButtonsRow/SolutionShowButton

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
	# Populate menu buttons
	_setup_menu_button(menu_button_placement_hint, GameState.MapSolverState.PLACEMENT_HINT)
	_setup_menu_button(menu_button_weight_hint, GameState.MapSolverState.WEIGHT_HINT)
	_setup_menu_button(menu_button_solution_show, GameState.MapSolverState.SOLUTION_SHOW)
	
	# Attach node resized signal to handle resizing and refreshing menu layout
	resized.connect(_on_control_resized)
	
	# Refresh menu layout after initializing all the map parameter entries 
	call_deferred("_refresh_menu_layout")


func _setup_menu_button(menu: MenuButton, menu_type: GameState.MapSolverState) -> void:
	# Initialize button display text
	if menu_type in MENU_BUTTON_DISPLAY_TEXTS_CLOSED:
		menu.text = MENU_BUTTON_DISPLAY_TEXTS_CLOSED[menu_type]
	
	# Get menu button popup
	var popup := menu.get_popup()
	
	# Clear exisiting options in the popup menu
	popup.clear()
	
	# Populate popup menu with data about secret room types
	var secret_room_kinds := GameData.room_secret_types.get_all_kinds()
	for secret_room_kind in secret_room_kinds:
		var secret_room_type := GameData.room_secret_types.get_type(secret_room_kind)
		
		popup.add_item(secret_room_type.get_display_name(), secret_room_kind as int)
	
	# Connect menu button toggled state to function and add menu type as it's parameter
	menu.toggled.connect(
		_on_menu_button_toggled.bind(menu, menu_type)
	)
	
	# Connect popup menu option pressed to function and add menu type as it's parameter
	popup.id_pressed.connect(
		_on_menu_button_option_pressed.bind(menu_type)
	)


func _on_menu_button_toggled(toggle_on: bool, menu_button: MenuButton, menu_type: GameState.MapSolverState) -> void:
	print("========================")
	print(toggle_on)
	print(menu_button)
	print(menu_type)
	if toggle_on:
		if menu_type in MENU_BUTTON_DISPLAY_TEXTS_OPENED:
			menu_button.text = MENU_BUTTON_DISPLAY_TEXTS_OPENED[menu_type]
	if not toggle_on:
		if menu_type in MENU_BUTTON_DISPLAY_TEXTS_CLOSED:
			menu_button.text = MENU_BUTTON_DISPLAY_TEXTS_CLOSED[menu_type] 


func _on_menu_button_option_pressed(option_id: int, menu_type: GameState.MapSolverState) -> void:
	#TODO: add some signals inside GameState and connect them here
	print("Menu: ", menu_type)
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
