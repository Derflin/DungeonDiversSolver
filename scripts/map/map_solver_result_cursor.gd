class_name MapSolverResultCursor
extends Node2D


## Signal for communicating that the result cursor has been fully hidden, so that the parent container could optionally manage it's state. 
## Sent along with the [param result_cursor] reference to itself. 
signal cursor_hidden(result_cursor: MapSolverResultCursor)


const CORNERS_ANIMATION_NAME := &"default"

const HOVER_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, 1), # Default: Down
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]


@export_group("Value Label", "value_label_")
## Target area into which value label will be downscaled into to fit it's text parameter.
@export var value_label_area_size: Vector2 = Vector2(15.0, 15.0)
## Base font size used for value label before downscaling it to fit into [member value_label_area_size].
@export var value_label_base_font_size: int = 20
## Text padding used during value label downscaling to add some space between [member value_label_area_size] edges.
@export var value_label_padding: int = 2
## Visual offset used for value label applied to it's position parameter after fitting value label text in it.
@export var value_label_visual_offset := Vector2(0.0, -1.0)

@export_group("Cursor Animation", "cursor_animation_")
## Enables the cursor animation for handling it's show/hide states.
@export var cursor_animation_enabled: bool = true
## Show animation duration in seconds.
@export_range(0.0, 1.0, 0.01)
var cursor_animation_show_duration: float = 0.2
## Hide animation duration in seconds.
@export_range(0.0, 1.0, 0.01)
var cursor_animation_hide_duration: float = 0.2

@export_group("Hover Details", "hover_details_")
@export var hover_details_enabled: bool = true
@export var hover_details_default_room_name: String = "Secret Room"
@export var hover_details_gap: float = 5.0
@export var hover_details_viewport_margin: float = 8.0
@export var hover_details_animation_duration: float = 0.16
@export var hover_details_visual_scale: float = 0.5


var _cursor_animation: Tween
var _map_solver_result_coord: MapSolverResultCoord = null
var _map_solver_result_solve_stage: MapSolverResult.SolveStage

var _hover_details_tween: Tween
var _hover_details_active: bool = false
var _hover_details_final_position: Vector2 = Vector2.ZERO
var _hover_room_name: String = "Secret Room"


@onready var value_label_root: Node2D = $ValueLabelRoot
@onready var value_label: ScrambleLabel = $ValueLabelRoot/ValueLabel
@onready var corners_sprite: Sprite2D = $Corners
@onready var corners_animation_player: AnimationPlayer = $Corners/AnimationPlayer
@onready var hover_area: Area2D = $HoverArea
@onready var hover_collision_shape: CollisionShape2D = $HoverArea/CollisionShape2D
@onready var hover_details: MapSolverResultHoverDetails = $HoverDetails


func _ready() -> void:
	# Initialize initial state
	hide()
	modulate.a = 0.0
	hover_details.scale = Vector2.ONE * hover_details_visual_scale
	
	# Initialize the animation player for corners sprite
	_initialize_corners_animation_player()
	
	# Sets up handler function to listen to resized signal from the value label node in order to automatically recenter it's position.
	value_label.resized.connect(_on_value_label_resized)
	
	# Update value label if it was initialized before ready function
	if _map_solver_result_coord != null:
		_update_value_label()
	
	# Add triggers for hover area.
	hover_area.mouse_entered.connect(_on_hover_area_mouse_entered)
	hover_area.mouse_exited.connect(_on_hover_area_mouse_exited)


## Shows cursor either immediately if the [member cursor_animation_enabled] is disabled or initializes the animation for it.
func show_cursor() -> void:
	# Stop existing animation
	_kill_cursor_animation()
	
	# Show cursor
	show()
	
	# Set hover area to detect input events.
	if is_node_ready():
		hover_area.input_pickable = true
	
	# If animation is disabled, then simply set the desired state
	if not cursor_animation_enabled:
		modulate.a = 1.0
		return
	
	# Initialize cursor styles before animation
	modulate.a = 0.0
	
	# Initialize animation with animated opacity and size transition
	_cursor_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cursor_animation.tween_property(self, "modulate:a", 1.0, cursor_animation_show_duration)


## Hides cursor either immediately if the [member cursor_animation_enabled] is disabled or initializes the animation for it.
func hide_cursor() -> void:
	# Filter out processing if the cursor is already hidden
	if not visible:
		return
	
	# Hide hover details.
	_hide_hover_details(true)
	hover_area.input_pickable = false
	
	# Stop existing animation
	_kill_cursor_animation()
	
	# If animation is disabled, then simply set the desired state
	if not cursor_animation_enabled:
		_on_cursor_hide_animation_finished()
		return
	
	# Initialize animation with animated opacity transition
	_cursor_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_cursor_animation.tween_property(self, "modulate:a", 0.0, cursor_animation_hide_duration)
	
	# Prepare signal connection after animation ends to finalize hiding submenu
	if _cursor_animation != null and _cursor_animation.is_valid():
		_cursor_animation.finished.connect(_on_cursor_hide_animation_finished)


## After cursor hide animation finishes, sets it's state so that it wouldn't be visible and emits [signal cursor_hidden] signal, so that it's parent might take care of freeing this instance.
func _on_cursor_hide_animation_finished() -> void:
	# Hide cursor and set it's state
	hide()
	modulate.a = 0.0
	
	# Emit signal that the cursor has been hidden
	cursor_hidden.emit(self)


## Stops any cursor animation tween that might have been active and resets it's state.
func _kill_cursor_animation() -> void:
	if _cursor_animation != null and _cursor_animation.is_valid():
		_cursor_animation.kill()
	
	_cursor_animation = null


## Initialize result cursor with the map solver result coord that it's based on.
func update_data(map_solver_result_coord: MapSolverResultCoord, result_solve_stage: MapSolverResult.SolveStage, secret_room_display_name: String = "") -> void:
	# Update map solver result coord data
	_map_solver_result_coord = map_solver_result_coord
	_map_solver_result_solve_stage = result_solve_stage
	_hover_room_name = secret_room_display_name if not secret_room_display_name.is_empty() else hover_details_default_room_name
	
	# Update value label and ensure that hover details are hidden if the node is ready
	if is_node_ready():
		_update_value_label()
		_hide_hover_details(true)


## Updates value label text and visibilty based on the map solver result coord and solve stage member parameters.
func _update_value_label() -> void:
	# Prepare label text based on the solve stage and the map solver result coord
	var label_text: String = ""
	if _map_solver_result_solve_stage == MapSolverResult.SolveStage.CALCULATED_WEIGHTS:
		label_text = String.num(_map_solver_result_coord.calculated_weight, 2).trim_suffix(".0")
	elif _map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_SOLUTION:
		label_text = String.num(_map_solver_result_coord.probability * 100, 0) + "%"
	
	# Update value label text color
	var label_text_color := _map_solver_result_coord.text_color
	value_label.add_theme_color_override("font_color", label_text_color)
	
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


## Set value label text to provided [param value_text] value and adjusts the value label root scale to try and fit the text inside the value label restricted size.
func set_value_label_text(value_text: String, adjust_label_size: bool = true) -> void:
	value_label.change_text(value_text)
	
	if adjust_label_size:
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
	_on_value_label_resized()
	
	# Calculate scale factor for value label root node to fully fit the new text
	var available_size := value_label_area_size - Vector2.ONE * value_label_padding * 2.0
	var scale_factor: float = min(
		available_size.x / text_size.x,
		available_size.y / text_size.y,
		1.0
	)
	
	# Scale down the value label root node
	value_label_root.scale = Vector2.ONE * scale_factor


## Keeps the value label centered whenever its dimensions change.
func _on_value_label_resized() -> void:
	value_label.position = -value_label.size / 2.0 + value_label_visual_offset


## Handles the hover area mouse entered signal by initializing and showing the hover details scene instance.
func _on_hover_area_mouse_entered() -> void:
	# Filter out processing if the hover details aren't enabled or the scene isn't visible or there aren't any result coords assigned.
	if not hover_details_enabled or not visible or _map_solver_result_coord == null:
		return
	
	# Filter out processing if the current map solver stage is different then founding solutions.
	if _map_solver_result_solve_stage != MapSolverResult.SolveStage.FOUND_SOLUTION:
		return
	
	# Filter out processing if the mouse is currently over the other hud element that is blocking the interaction.
	if _mouse_is_over_blocking_hud():
		return
	
	# Set flag that hover details are active.
	_hover_details_active = true
	
	# Stop any existing animtion related to hover details.
	_kill_hover_details_tween()
	
	# Initialize hover details data.
	hover_details.prepare_details(_hover_room_name, _map_solver_result_coord.calculated_weight, _map_solver_result_coord.priority_group)
	
	# Align hover details size before calculating its position.
	_align_hover_details_size_to_pixel_grid()
	
	# Calculate and set the hover details position.
	var placement: Dictionary = _choose_hover_details_placement()
	_hover_details_final_position = placement["position"]
	hover_details.position = _hover_details_final_position
	
	# Initialize hover details display parameters and open animation.
	hover_details.modulate.a = 0.0
	hover_details.show()
	hover_details.animate_text()
	
	_hover_details_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_details_tween.tween_property(hover_details, "modulate:a", 1.0, hover_details_animation_duration)


## Handles the hover area mouse exited signal by hiding the hover details scene instance.
func _on_hover_area_mouse_exited() -> void:
	_hide_hover_details()


## Hides the hover details scene instance.
## Uses the provided [param immediate] flag to define whether the hide process should be instantenous or if the animation should be played for it.
func _hide_hover_details(immediate: bool = false) -> void:
	# Unset flag that hover details are active.
	_hover_details_active = false
	
	# Filter out processing if node wasn't already initialized.
	if not is_node_ready():
		return
	
	# Stops any existing hover details animation.
	_kill_hover_details_tween()
	
	# Initialize hover details display parameters if the immediate flag parameter was set or the hover details are currently not visible.
	if immediate or not hover_details.visible:
		hover_details.hide()
		hover_details.modulate.a = 0.0
		return
	
	# Initialize hover details close animation.
	_hover_details_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hover_details_tween.tween_property(hover_details, "modulate:a", 0.0, hover_details_animation_duration)
	
	# Queue hover details hide after the animation finishes.
	_hover_details_tween.finished.connect(func() -> void: if not _hover_details_active: hover_details.hide())


## Stops any existing animation set for the hover details.
func _kill_hover_details_tween() -> void:
	if _hover_details_tween != null and _hover_details_tween.is_valid():
		_hover_details_tween.kill()
	_hover_details_tween = null


## Checks if the mouse is currently over any hud element that might block local interaction with the hover details scene instance.
func _mouse_is_over_blocking_hud() -> bool:
	var node: Node = get_viewport().gui_get_hovered_control()
	while node != null:
		if node.is_in_group("blocks_map_result_tooltips"):
			return true
		node = node.get_parent()
	return false


## Returns a rectangle representing the hover area.
## If the hover rectangle shape isn't set it will use the value label area size to determien the rectangle shape.
func _get_hover_cursor_rect() -> Rect2:
	var rectangle: RectangleShape2D = hover_collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(-value_label_area_size * 0.5, value_label_area_size)
	
	var center: Vector2 = hover_area.position + hover_collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


## Returns a hover details local position that should be set for it according to the provided parameters.
## Uses provided [param cursor_rect] as a representation of the hover area rect to access its position and size to define base from which the result position is calculated.
## Uses provided [param tooltip_size] as a representation of the hover details rect to access it's size to ensure that hover details will be set next to and not on top of the cursor rect.
## Uses provided [param direction] to determine on which side of the cursor rect the hover details should be displayed on.
func _get_hover_details_local_position(cursor_rect: Rect2, tooltip_size: Vector2, direction: Vector2i) -> Vector2:
	# Calculate x and y parameters of the result vector based on the provided parameters.
	var x: float = cursor_rect.position.x + (cursor_rect.size.x - tooltip_size.x) * 0.5
	var y: float = cursor_rect.position.y + (cursor_rect.size.y - tooltip_size.y) * 0.5
	
	# Apply direction position offset based on the provided parameters.
	if direction.x < 0:
		x = cursor_rect.position.x - hover_details_gap - tooltip_size.x
	elif direction.x > 0:
		x = cursor_rect.end.x + hover_details_gap
	if direction.y < 0:
		y = cursor_rect.position.y - hover_details_gap - tooltip_size.y
	elif direction.y > 0:
		y = cursor_rect.end.y + hover_details_gap
	
	return Vector2(x, y)


## Transforms the provided [param local_rect] rectangle to the viewport global transform.
func _local_rect_to_viewport(local_rect: Rect2) -> Rect2:
	var t: Transform2D = get_global_transform_with_canvas()
	var p0: Vector2 = t * local_rect.position
	var p1: Vector2 = t * Vector2(local_rect.end.x, local_rect.position.y)
	var p2: Vector2 = t * local_rect.end
	var p3: Vector2 = t * Vector2(local_rect.position.x, local_rect.end.y)
	
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


## Aligns hover details size to mutliples of 4 to make it compatible with scaling it's contents.
## Rounds the current minimum size of the hover details to ensure that it's divisible by the multiplied step value and applies it.
func _align_hover_details_size_to_pixel_grid() -> void:
	# Clear the previously reserved minimum size for the hover details.
	hover_details.custom_minimum_size = Vector2.ZERO
	
	# Get the size required by the hover details contents.
	hover_details.reset_size()
	var required_size: Vector2 = hover_details.size
	
	# Apply mutlitples of 4 as the size possible values.
	const SIZE_STEP: float = 4.0
	var aligned_size: Vector2 = Vector2(ceilf(required_size.x / SIZE_STEP) * SIZE_STEP, ceilf(required_size.y / SIZE_STEP) * SIZE_STEP)
	
	# Apply the rounded size and update the layout.
	hover_details.custom_minimum_size = aligned_size
	hover_details.reset_size()


## Chooses and returns a dictionary containing the selected direction and position for it to use for the hover details scene instance placement.
func _choose_hover_details_placement() -> Dictionary:
	# Prepare cursor and viewport rect that will be used to define the available space for displaying the hover details.
	var cursor_rect: Rect2 = _get_hover_cursor_rect()
	var viewport_rect: Rect2 = get_viewport_rect().grow(-hover_details_viewport_margin)
	var cursor_screen_rect: Rect2 = _local_rect_to_viewport(cursor_rect)
	var tooltip_visual_size: Vector2 = hover_details.size * hover_details.scale
	
	# Prepare a list with directions offsets to be processed.
	var directions: Array[Vector2i] = HOVER_DIRECTIONS.duplicate()
	
	# Select the default direction that will be checked first depending on the hovert cursor position on viewport.
	var inward: Vector2i = Vector2i.ZERO
	if cursor_screen_rect.position.x < viewport_rect.position.x:
		inward.x = 1
	elif cursor_screen_rect.end.x > viewport_rect.end.x:
		inward.x = -1
	if cursor_screen_rect.position.y < viewport_rect.position.y:
		inward.y = 1
	elif cursor_screen_rect.end.y > viewport_rect.end.y:
		inward.y = -1
	
	# Move the default direction option to a list of directions beginning to be processed first.
	if inward != Vector2i.ZERO:
		directions.erase(inward)
		directions.push_front(inward)
	
	# Select best direction to use to fit the hover details.
	var best_fraction: float = -1.0
	var best_position: Vector2 = Vector2.ZERO
	var best_direction: Vector2i = Vector2i.ZERO
	for direction: Vector2i in directions:
		# Calculate visible fraction of the hover details in a given direction.
		var local_position: Vector2 = _get_hover_details_local_position(cursor_rect, tooltip_visual_size, direction)
		var screen_rect: Rect2 = _local_rect_to_viewport(Rect2(local_position, tooltip_visual_size))
		var screen_area: float = maxf(screen_rect.get_area(), 0.001)
		var visible_fraction: float = screen_rect.intersection(viewport_rect).get_area() / screen_area
		
		# Save the current direction as best option if the calculated visible fraction is highier then the previous one.
		if visible_fraction > best_fraction + 0.0001:
			best_fraction = visible_fraction
			best_position = local_position
			best_direction = direction
	
	# If there wouldn't be a single direction that would fit the hover detaills, move the best one into a viewport so that it would be visible.
	var chosen_screen_rect: Rect2 = _local_rect_to_viewport(Rect2(best_position, tooltip_visual_size))
	var screen_shift: Vector2 = Vector2.ZERO
	if chosen_screen_rect.position.x < viewport_rect.position.x:
		screen_shift.x = viewport_rect.position.x - chosen_screen_rect.position.x
	elif chosen_screen_rect.end.x > viewport_rect.end.x:
		screen_shift.x = viewport_rect.end.x - chosen_screen_rect.end.x
	if chosen_screen_rect.position.y < viewport_rect.position.y:
		screen_shift.y = viewport_rect.position.y - chosen_screen_rect.position.y
	elif chosen_screen_rect.end.y > viewport_rect.end.y:
		screen_shift.y = viewport_rect.end.y - chosen_screen_rect.end.y
	
	if screen_shift != Vector2.ZERO:
		var t: Transform2D = get_global_transform_with_canvas()
		best_position = t.affine_inverse() * (t * best_position + screen_shift)
	
	return {"position": best_position, "direction": best_direction}
