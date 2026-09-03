class_name MapSolverResultCursor
extends Node2D


const CORNERS_ANIMATION_NAME := &"default"


var _map_solver_result_coord: MapSolverResultCoord = null
var _map_solver_result_solve_stage: MapSolverResult.SolveStage


@onready var value_label_root: Node2D = $ValueLabelRoot
@onready var value_label: ScrambleLabel = $ValueLabelRoot/ValueLabel
@onready var corners_sprite: Sprite2D = $Corners
@onready var corners_animation_player: AnimationPlayer = $Corners/AnimationPlayer


@export_group("Value Label", "value_label_")
## Target area into which value label will be downscaled into to fit it's text parameter.
@export var value_label_area_size: Vector2 = Vector2(15.0, 15.0)
## Base font size used for value label before downscaling it to fit into [member value_label_area_size].
@export var value_label_base_font_size: int = 20
## Text padding used during value label downscaling to add some space between [member value_label_area_size] edges.
@export var value_label_padding: int = 2
## Visual offset used for value label applied to it's position parameter after fitting value label text in it.
@export var value_label_visual_offset := Vector2(0.0, -1.0)


func _ready() -> void:
	# Initialize the animation player for corners sprite
	_initialize_corners_animation_player()
	
	# Update value label if it was initialized before ready function
	if _map_solver_result_coord != null:
		_update_value_label()


## Initialize result cursor with the map solver result coord that it's based on.
func update_data(map_solver_result_coord: MapSolverResultCoord, result_solve_stage: MapSolverResult.SolveStage) -> void:
	# Update map solver result coord data
	_map_solver_result_coord = map_solver_result_coord
	_map_solver_result_solve_stage = result_solve_stage
	
	# Update value label if the node is ready
	if is_node_ready():
		_update_value_label()


## Updates value label text and visibilty based on the map solver result coord and solve stage member parameters.
func _update_value_label() -> void:	
	# Prepare label text based on the solve stage and the map solver result coord
	var label_text: String = ""
	if _map_solver_result_solve_stage == MapSolverResult.SolveStage.CALCULATED_WEIGHTS:
		label_text = str(_map_solver_result_coord.calculated_weight)
	elif _map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_SOLUTION:
		label_text = str(roundi(_map_solver_result_coord.possibility * 100)) + "%"
	
	# Update value label visibility and text
	value_label.visible = label_text.length() > 0
	set_value_label_text(label_text, value_label.visible)


## Initializes corners sprite animation player with correct animation and it's state.
func _initialize_corners_animation_player() -> void:
	corners_animation_player.play(CORNERS_ANIMATION_NAME)
	
	var animation_length := corners_animation_player.current_animation_length
	var global_time := Time.get_ticks_msec() / 1000.0
	var animation_time := fmod(global_time, animation_length)
	
	corners_animation_player.seek(animation_time, true)


## Set value label text to provided [param value_text] value and adjusts the font size to try and fit the text inside the value label restricted size.
func set_value_label_text(value_text: String, adjust_font_size: bool = true) -> void:
	value_label.change_text(value_text)
	
	if adjust_font_size:
		_fit_value_label_text(value_text)


## Sets value label size and position and then scales down it's root node to fit into target restricted area.
func _fit_value_label_text(value_text: String) -> void:
	# Get value label theme font
	var font := value_label.get_theme_font("font")
	
	# Initialize value label font size
	value_label.add_theme_font_size_override("font_size", value_label_base_font_size)
	
	# Calculate text size
	var text_width := font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, value_label_base_font_size).x
	var text_height := font.get_height(value_label_base_font_size)
	var text_size := Vector2(text_width, text_height)
	if text_size.x <= 0.0 or text_size.y <= 0.0:
		return
	
	# Set visual label size and position based on calculated text size and value label visual offset parameter
	value_label.size = text_size
	value_label.position = -text_size / 2.0 + value_label_visual_offset
	
	# Calculate scale factor for value label root node to fully fit the new text
	var available_size := value_label_area_size - Vector2.ONE * value_label_padding * 2.0
	var scale_factor: float = min(
		available_size.x / text_size.x,
		available_size.y / text_size.y,
		1.0
	)
	
	# Scale down the value label root node
	value_label_root.scale = Vector2.ONE * scale_factor
