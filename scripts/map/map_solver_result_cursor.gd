class_name MapSolverResultCursor
extends Node2D


## Signal for communicating that the result cursor has been fully hidden, so that the parent container could optionally manage it's state. 
## Sent along with the [param result_cursor] reference to itself. 
signal cursor_hidden(result_cursor: MapSolverResultCursor)


const CORNERS_ANIMATION_NAME := &"default"

const BLOCKS_MAP_RESULT_TOOLTIPS_GROUP_NAME := &"blocks_map_result_tooltips"

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

@export_group("Value Label Transition", "value_label_transition_")
## Enables the fade transition when switching the cursor's displayed value label.
@export var value_label_transition_enabled: bool = true
## Total duration of fading out old content and fading in new content.
@export_range(0.0, 1.0, 0.01)
var value_label_transition_duration: float = 0.2

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
@export_range(0.0, 16.0, 0.5)
var hover_details_hud_margin: float = 2.0
@export var hover_details_animation_duration: float = 0.16
@export var hover_details_visual_scale: float = 0.5
@export_group("Hover Connector", "hover_details_connector_")
@export var hover_details_connector_enabled: bool = true
@export var hover_details_connector_start_overlap: float = 0.0
@export var hover_details_connector_end_overlap: float = 1.0

@export_group("Placement Explanation", "placement_explanation_")
@export var placement_explanation_enabled: bool = true
@export var placement_explanation_animation_duration: float = 0.16

@export_group("Candidate Hover Highlight", "candidate_hover_")
## Enables the translucent room highlight while hovering a result cursor.
@export var candidate_hover_enabled: bool = true
## Color drawn over the entire candidate room upon hover.
@export var candidate_hover_color: Color = Color(0.30, 0.60, 0.95, 0.35)
## Enables the fade transition when showing or hiding the blue candidate room highlight.
@export var candidate_hover_transition_enabled: bool = true
## Duration of the candidate room highlight fade transition.
@export var candidate_hover_transition_duration: float = 0.16

@export_group("Hover Information Indicator", "hover_info_indicator_")
## Enables the persistent information availability icon on result cursors.
@export var hover_info_indicator_enabled: bool = true
## Diameter of the circular indicator background in local pixels.
@export_range(2.0, 20.0, 0.5) var hover_info_indicator_diameter: float = 4.0
## Minimum space between the indicator's outer border and the edges of the result cursor.
@export_range(0.0, 4.0, 0.5) var hover_info_indicator_corner_inset: float = 0.0
## Free space between the circular background edge and the icon texture.
@export_range(0.0, 5.0, 0.5) var hover_info_indicator_icon_padding: float = 0.5
## Background color when hovering the result cursor can show additional details.
@export var hover_info_indicator_available_background: Color = Color(0.85, 0.72, 0.46, 1.0)
## Background color when no additional hover information is available.
@export var hover_info_indicator_unavailable_background: Color = Color(0.36, 0.35, 0.35, 0.95)
## Tint applied to the indicator icon texture when hover information exists.
@export var hover_info_indicator_available_icon_color: Color = Color(0.16, 0.14, 0.12, 1.0)
## Tint applied to the indicator icon texture when hover information is unavailable.
@export var hover_info_indicator_unavailable_icon_color: Color = Color(0.72, 0.70, 0.68, 1.0)

@export_subgroup("Transition", "hover_info_indicator_transition_")
## Enables the hover information indicator transtion when its availability changes or when the result curosr's displayed value is updated.
@export var hover_info_indicator_transition_enabled: bool = true
## Duration of the complete indicator fade-out and fade-in transition.
@export_range(0.0, 1.0, 0.01) var hover_info_indicator_transition_duration: float = 0.2
## Lowest opacity reached when briefly dimming the indicator during a value label scramble animation.
@export_range(0.0, 1.0, 0.05) var hover_info_indicator_transition_dim_opacity: float = 0.4

@export_subgroup("Outline", "hover_info_indicator_outline_")
## Thickness of the circular outline surrounding the information indicator.
@export_range(0.0, 3.0, 0.25) var hover_info_indicator_outline_width: float = 1.0
## Color used for the circular outline surrounding the information indicator.
@export var hover_info_indicator_outline_color: Color = Color(0.15, 0.13, 0.12, 1.0)

@export_subgroup("Unavailable Slash", "hover_info_indicator_unavailable_slash_")
## Width of the diagonal slash displayed over unavailable information icons.
@export_range(0.5, 3.0, 0.25) var hover_info_indicator_unavailable_slash_width: float = 1.0
## Color used for the diagonal slash displayed over unavailable information icons.
@export var hover_info_indicator_unavailable_slash_color: Color = Color(0.16, 0.15, 0.15, 1.0)
## Length of the diagonal slash relative to the indicator's background radius.
@export_range(0.25, 1.5, 0.05) var hover_info_indicator_unavailable_slash_length_factor: float = 0.75


var _cursor_animation: Tween

var _candidate_hover_tween: Tween = null
var _candidate_hover_active: bool = false

var _value_display_tween: Tween
var _value_label_scale_tween: Tween
var _value_label_adjust_size_during_scramble: bool = true
var _value_label_scramble_started_in_call: bool = false

var _hover_info_indicator_tween: Tween = null
var _hover_info_indicator_available: bool = false
var _hover_info_indicator_state_initialized: bool = false

var _map_solver_result_coord: MapSolverResultCoord = null
var _map_solver_result_solve_stage: MapSolverResult.SolveStage

var _show_zero_weight_check: bool = false

var _hover_details_tween: Tween
var _hover_details_active: bool = false
var _hover_details_final_position: Vector2 = Vector2.ZERO
var _hover_room_name: String = "Secret Room"

var _placement_explanation_tween: Tween
var _placement_explanation_active: bool = false
var _placement_explanation_grid_space: GridSpace = null

var _cursor_hiding: bool = false


@onready var candidate_hover_highlight: Polygon2D = $CandidateHoverHighlight
@onready var corners_sprite: Sprite2D = $Corners
@onready var corners_animation_player: AnimationPlayer = $Corners/AnimationPlayer
@onready var value_display_root: Node2D = $ValueDisplayRoot
@onready var value_label_root: Node2D = $ValueDisplayRoot/ValueLabelRoot
@onready var value_label: ScrambleLabel = $ValueDisplayRoot/ValueLabelRoot/ValueLabel
@onready var value_check_mark: Sprite2D = $ValueDisplayRoot/ValueCheckMark
@onready var hover_info_indicator: Node2D = $HoverInfoIndicator
@onready var hover_info_indicator_outline: Polygon2D = $HoverInfoIndicator/CircleOutline
@onready var hover_info_indicator_background: Polygon2D = $HoverInfoIndicator/CircleBackground
@onready var hover_info_indicator_icon: Sprite2D = $HoverInfoIndicator/Icon
@onready var hover_info_indicator_unavailable_slash: Line2D = $HoverInfoIndicator/UnavailableSlash
@onready var hover_area: Area2D = $HoverArea
@onready var hover_collision_shape: CollisionShape2D = $HoverArea/CollisionShape2D
@onready var hover_connector: Line2D = $HoverConnector
@onready var hover_details: MapSolverResultHoverDetails = $HoverDetails
@onready var placement_explanation: MapSolverResultPlacementExplanation = $PlacementExplanation


#region Result Cursor Lifecycle and State

func _ready() -> void:
	# Initialize initial state
	hide()
	modulate.a = 0.0
	
	# Initialize value display state.
	value_display_root.modulate.a = 1.0
	value_label_root.hide()
	value_label_root.modulate.a = 1.0
	value_check_mark.hide()
	value_check_mark.modulate.a = 1.0
	
	# Initialize hover details initial state.
	hover_details.scale = Vector2.ONE * hover_details_visual_scale
	hover_connector.hide()
	hover_connector.modulate.a = 0.0
	
	# Initialize placement explanation initial state.
	placement_explanation.hide()
	placement_explanation.modulate.a = 0.0
	
	# Initialize candidate hover highlight and hover information icon.
	candidate_hover_highlight.hide()
	candidate_hover_highlight.modulate.a = 0.0
	_initialize_hover_info_indicator()
	hover_info_indicator.modulate.a = 1.0
	
	# Initialize the animation player for corners sprite
	_initialize_corners_animation_player()
	
	# Sets up handler function to listen to resized signal from the value label node in order to automatically recenter it's position.
	value_label.resized.connect(_on_value_label_resized)
	
	# Sets up handler function to listen to scramble started and finished signals from the value label node to handle text scale animation transition.
	value_label.scramble_started.connect(_on_value_label_scramble_started)
	value_label.scramble_finished.connect(_on_value_label_scramble_finished)
	
	# Update value label if it was initialized before ready function
	if _map_solver_result_coord != null:
		_update_value_display()
	
	# Refresh placement explanation.
	_refresh_placement_explanation()
	
	# Refresh candidate hover geometry and icon status after the explanation renderer has received its data.
	_refresh_cursor_hover_visuals()


## Continuously checks whether hover details, placement explanation and candidate hover highlight should be displayed and handles changes to their visibility state. 
func _process(_delta: float) -> void:
	# Check if hover details are valid to be shown and show/hide them accordingly based on it and their current active status.
	var hover_valid: bool = _is_hover_details_display_valid()
	if hover_valid and not _hover_details_active:
		_show_hover_details()
	elif not hover_valid and _hover_details_active:
		_hide_hover_details()
	
	# Check if placement explanation is valid to be shown and show/hide it accordingly based on it and it's current active status.
	var explanation_valid: bool = _is_placement_explanation_display_valid()
	if explanation_valid and not _placement_explanation_active:
		_show_placement_explanation()
	elif not explanation_valid and _placement_explanation_active:
		_hide_placement_explanation()
	
	# Check if candidate hover highlight is valid to be shown and show/hide it accordingly based on it and it's current active status.
	var candidate_hover_valid: bool = (
		candidate_hover_enabled
		and _is_cursor_hover_stage()
		and _is_result_cursor_hover_valid()
	)
	if candidate_hover_valid and not _candidate_hover_active:
		_show_candidate_hover_highlight()
	elif not candidate_hover_valid and _candidate_hover_active:
		_hide_candidate_hover_highlight()


## Shows cursor either immediately if the [member cursor_animation_enabled] is disabled or initializes the animation for it.
func show_cursor() -> void:
	# Allow hover visuals again when this cursor is displayed.
	_cursor_hiding = false
	
	# Stop existing animation
	_kill_cursor_animation()
	
	# Show cursor
	show()
	
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
	
	# Disable hover detection for the remainder of the hide animation.
	_cursor_hiding = true
	_hide_candidate_hover_highlight(true)
	
	# Stop the hover information indicator transition when removing the cursor.
	_kill_hover_info_indicator_tween()
	hover_info_indicator.modulate.a = 1.0
	
	# Hide hover details.
	_hide_hover_details(true)
	
	# Hide placement explanation.
	_hide_placement_explanation(true)
	
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

#endregion


#region Result Data and Solver Stages

## Initialize result cursor with the map solver result coord that it's based on.
func update_data(map_solver_result_coord: MapSolverResultCoord, result_solve_stage: MapSolverResult.SolveStage, grid_space_reference: GridSpace, secret_room_display_name: String = "", show_zero_weight_check: bool = false) -> void:
	# Store previous display state before updating the result.
	var had_previous_result: bool = _map_solver_result_coord != null
	var previous_stage: MapSolverResult.SolveStage = _map_solver_result_solve_stage
	var previous_check: bool = _show_zero_weight_check
	
	# Update map solver result coord data.
	_map_solver_result_coord = map_solver_result_coord
	_map_solver_result_solve_stage = result_solve_stage
	_hover_room_name = secret_room_display_name if not secret_room_display_name.is_empty() else hover_details_default_room_name
	
	# Store grid space reference for placement explanation.
	_placement_explanation_grid_space = grid_space_reference
	
	# Update check mark display state.
	_show_zero_weight_check = show_zero_weight_check
	
	# Update value label and ensure that hover details are hidden if the node is ready.
	if is_node_ready():
		# Animate only when the stage or displayed indicator changed.
		var animate_transition: bool = had_previous_result and (previous_stage != _map_solver_result_solve_stage or previous_check != _show_zero_weight_check)
		
		# Update value display.
		_update_value_display(animate_transition)
		
		# Make sure that hover details are hidden by default.
		_hide_hover_details(true)
		
		# Make sure that placement explanation is hidden by default.
		_hide_placement_explanation(true)
		
		# Refresh the placement explanation data for the updated result coordinate.
		_refresh_placement_explanation()
		
		# Refresh candidate hover highlight and hover information indicator.
		_refresh_cursor_hover_visuals(animate_transition)


## Updates the placement explanation renderer using this cursor's current result data.
func _refresh_placement_explanation() -> void:
	# Clear stale geometry when no result or gird reference is available.
	if _map_solver_result_coord == null or _placement_explanation_grid_space == null:
		placement_explanation.clear_data()
		return
	
	# Initialize placement explanation scene display.
	placement_explanation.configure(
		_map_solver_result_coord.coords,
		_map_solver_result_coord.placement_explanations,
		_placement_explanation_grid_space,
		value_label.get_theme_font("font"),
	)


## Returns whether the current map solver stage can display placement explanation geometry when the corresponding result cursor is hovered.
func _is_placement_explanation_stage() -> bool:
	return(
		_map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_VALID_PLACEMENTS
		or _map_solver_result_solve_stage == MapSolverResult.SolveStage.CALCULATED_WEIGHTS
	)


## Returns whether the current map solver stage supports hovering result cursors.
func _is_cursor_hover_stage() -> bool:
	return (
		_is_placement_explanation_stage()
		or _map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_SOLUTION
	)

#endregion


#region Hover Information Indicator

## Creates a filled circular polygon of the provided [param radius] around the hover information indicator's local origin.
func _make_hover_info_indicator_circle(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var vertex_count: int = 16
	
	for vertex_index: int in range(vertex_count):
		var angle: float = TAU * float(vertex_index) / float(vertex_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	return points


## Initializes the hover information indicator circles, slash and icon.
func _initialize_hover_info_indicator() -> void:
	# Draw the dark outline slightly larger than the colored circular background.
	var radius: float = hover_info_indicator_diameter * 0.5
	
	hover_info_indicator_outline.polygon = _make_hover_info_indicator_circle(radius + hover_info_indicator_outline_width)
	hover_info_indicator_outline.color = hover_info_indicator_outline_color
	hover_info_indicator_background.polygon = _make_hover_info_indicator_circle(radius)
	
	# Prepare the diagonal line displayed across an unavailable information icon.
	var slash_extent: float = radius * hover_info_indicator_unavailable_slash_length_factor
	hover_info_indicator_unavailable_slash.points = PackedVector2Array([
		Vector2(-slash_extent, -slash_extent),
		Vector2(slash_extent, slash_extent),
	])
	hover_info_indicator_unavailable_slash.width = hover_info_indicator_unavailable_slash_width
	hover_info_indicator_unavailable_slash.default_color = hover_info_indicator_unavailable_slash_color
	
	# Fit the chosen texture inside the circle without assuming its source image resolution.
	if hover_info_indicator_icon.texture != null:
		var texture_size: Vector2 = hover_info_indicator_icon.texture.get_size()
		var available_icon_size: float = maxf(1.0, hover_info_indicator_diameter - hover_info_indicator_icon_padding * 2.0)
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var icon_scale: float = minf(available_icon_size / texture_size.x, available_icon_size / texture_size.y)
			hover_info_indicator_icon.scale = Vector2.ONE * icon_scale
	
	# Initialize hover info indicator visible status.
	hover_info_indicator.hide()


## Applies the hover information indicator's appearance based on whether additional hover information is [param available] for the current result.
## Updates its background, icon tint and unavailable slash immediately.
func _apply_hover_info_indicator_state(available: bool) -> void:
	# Assign the appropriate circular background color.
	hover_info_indicator_background.color = (
		hover_info_indicator_available_background
		if available
		else hover_info_indicator_unavailable_background
	)
	
	# Assign the appropriate icon tint.
	hover_info_indicator_icon.modulate = (
		hover_info_indicator_available_icon_color
		if available
		else hover_info_indicator_unavailable_icon_color
	)
	
	# Display the unavailable slash only when no information exists.
	hover_info_indicator_unavailable_slash.visible = not available


## Updates the hover information indicator's availability state.
## When the availability changes or [param animate_change] is enabled, fade out the previous appearance before applying the new one.
## The first initialization always applies its appearance immediately.
func _set_hover_info_indicator_state(available: bool, animate_change: bool = false) -> void:
	# Determine whether the indicator already had an assigned state.
	var had_previous_state: bool = _hover_info_indicator_state_initialized
	
	# Check whether the availability actually changed.
	var availability_changed: bool = had_previous_state and _hover_info_indicator_available != available
	
	# Store the current state for future updates.
	_hover_info_indicator_available = available
	_hover_info_indicator_state_initialized = true
	
	# Preserve any running animation when no visual update is required.
	if had_previous_state and not availability_changed and not animate_change:
		return
	
	# Stop any existing indicator transition.
	_kill_hover_info_indicator_tween()
	
	# Apply the appearance immediately when transitions are disabled, during initialization, or when the cursor is not visible.
	if (
		not had_previous_state
		or not hover_info_indicator_transition_enabled
		or hover_info_indicator_transition_duration <= 0.0
		or not is_visible_in_tree()
		or _cursor_hiding
	):
		_apply_hover_info_indicator_state(available)
		hover_info_indicator.modulate.a = 1.0
		return
	
	# Prepare the duration of each half of the transition.
	var half_duration: float = hover_info_indicator_transition_duration * 0.5
	
	# Initialize a sequential fade-out and fade-in transition.
	_hover_info_indicator_tween = create_tween()
	
	# Fade out the previous indicator appearance.
	_hover_info_indicator_tween.tween_property(
		hover_info_indicator,
		"modulate:a",
		0.0,
		half_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Replace the indicator appearance while it's invisible.
	_hover_info_indicator_tween.tween_callback(
		func() -> void: _apply_hover_info_indicator_state(available)
	)
	
	# Fade in the updated indicator appearance.
	_hover_info_indicator_tween.tween_property(
		hover_info_indicator,
		"modulate:a",
		1.0,
		half_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Briefly dims the hover information indicator when the displayed result value is being updated by the value label.
func _pulse_hover_info_indicator() -> void:
	# Filter out processing if transitions are disabled or the indicator hasn't received its initial display state yet.
	if (
		not hover_info_indicator_transition_enabled
		or hover_info_indicator_transition_duration <= 0.0
		or not _hover_info_indicator_state_initialized
		or not hover_info_indicator.visible
		or not is_visible_in_tree()
		or _cursor_hiding
	):
		return
	
	# Don't interrupt an indicator transition already in progress.
	if _hover_info_indicator_tween != null and _hover_info_indicator_tween.is_running():
		return
	
	# Prepare the duration of each half of the dimming animation.
	var half_duration: float = hover_info_indicator_transition_duration * 0.5
	
	# Initialize a sequential dim and restore transition.
	_hover_info_indicator_tween = create_tween()
	
	# Dim the indicator while the result value is changing.
	_hover_info_indicator_tween.tween_property(
		hover_info_indicator,
		"modulate:a",
		hover_info_indicator_transition_dim_opacity,
		half_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Restore its original opacity.
	_hover_info_indicator_tween.tween_property(
		hover_info_indicator,
		"modulate:a",
		1.0,
		half_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Stops any existing animation assigned to the hover information indicator.
func _kill_hover_info_indicator_tween() -> void:
	if _hover_info_indicator_tween != null and _hover_info_indicator_tween.is_valid():
		_hover_info_indicator_tween.kill()
	_hover_info_indicator_tween = null

#endregion


#region Hover Visual Geometry and State

## Updates the candidate hover highlight polygon and the state, position and appearance of the hover information indicator.
## When [param animate_indicator] is enabled, animates the hover info indicator alongside the result cursor's existing value display transition.
func _refresh_cursor_hover_visuals(animate_indicator: bool = false) -> void:
	# Immediately reset the candidate hover transition before updating its geometry or switching to a different result coordinate.
	_hide_candidate_hover_highlight(true)
	
	# Clear previous visuals when the cursor doesn't have valid room data.
	if _map_solver_result_coord == null or _placement_explanation_grid_space == null:
		candidate_hover_highlight.polygon = PackedVector2Array()
		hover_info_indicator.hide()
		return
	
	# Fetch the full candidate room rectangle in grid space coordinates.
	var grid_rect: Rect2 = _placement_explanation_grid_space.get_room_rect(_map_solver_result_coord.coords)
	var grid_corners: PackedVector2Array = PackedVector2Array([
		grid_rect.position,
		Vector2(grid_rect.end.x, grid_rect.position.y),
		grid_rect.end,
		Vector2(grid_rect.position.x, grid_rect.end.y),
	])
	
	# Convert the corners to this cursor's local coordinate system.
	var cursor_corners: PackedVector2Array = PackedVector2Array()
	for grid_corner: Vector2 in grid_corners:
		cursor_corners.append(to_local(_placement_explanation_grid_space.to_global(grid_corner)))
	
	# Prepare the candidate hover highlight overlay.
	candidate_hover_highlight.polygon = cursor_corners
	candidate_hover_highlight.color = candidate_hover_color
	
	# Show the indicator if it should be active.
	var indicator_visible: bool = (
		hover_info_indicator_enabled
		and _is_cursor_hover_stage()
		and hover_info_indicator_icon.texture != null
		and (
			_map_solver_result_solve_stage != MapSolverResult.SolveStage.FOUND_SOLUTION
			or hover_details_enabled
		)
	)
	hover_info_indicator.visible = indicator_visible
	if not indicator_visible:
		# Reset the indicator transition when its display is disabled.
		_kill_hover_info_indicator_tween()
		hover_info_indicator.modulate.a = 1.0
		_hover_info_indicator_state_initialized = false
		return
	
	# Prepare the result cursor bounds.
	var cursor_rect: Rect2 = _get_hover_cursor_rect()
	
	# Calculate the full radius of the indicator.
	var indicator_outer_radius: float = hover_info_indicator_diameter * 0.5 + hover_info_indicator_outline_width + hover_info_indicator_corner_inset
	
	# Position the indicator in the top-right corner of the result cursor.
	hover_info_indicator.position = Vector2(
		cursor_rect.end.x - indicator_outer_radius,
		cursor_rect.position.y + indicator_outer_radius,
	)

	# Determine whether hovering reveals additional information.
	var has_hover_information: bool = (
		_map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_SOLUTION
		or (
			_is_placement_explanation_stage()
			and placement_explanation_enabled
			and placement_explanation.has_visuals()
		)
	)
	
	# Updates the hover information indicator's active or unavailable state.
	_set_hover_info_indicator_state(has_hover_information, animate_indicator)

#endregion


#region Value Display and Label Animations

## Updates value display and visibilty based on the map solver result coord and solve stage member parameters.
## Handles the initialization of transition animation for the changes that would be applied to the value display.
## Provided [param animate_transition] flag defines if the changes should be applied through aniamtion or immediately.
func _update_value_display(animate_transition: bool = false) -> void:
	# Check whether the green checkmark should be displayed.
	var show_check: bool = (
		(
			_map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_VALID_PLACEMENTS
		)
		or
		(
			_map_solver_result_solve_stage == MapSolverResult.SolveStage.CALCULATED_WEIGHTS
			and _show_zero_weight_check
		)
	)
	
	# Prepare label text based on the solve stage and the map solver result coord.
	var label_text: String = ""
	if _map_solver_result_solve_stage == MapSolverResult.SolveStage.CALCULATED_WEIGHTS:
		if not show_check:
			label_text = String.num(_map_solver_result_coord.calculated_weight, 2).trim_suffix(".0")
	elif _map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_SOLUTION:
		label_text = String.num(_map_solver_result_coord.probability * 100, 0) + "%"
	
	# Prepare value label text color.
	var label_text_color := _map_solver_result_coord.text_color if _map_solver_result_coord != null else Color.WHITE
	
	# Detect whether the old and new states containt visible content.
	var has_old_content: bool = value_label_root.visible or value_check_mark.visible
	var has_new_content: bool = show_check or not label_text.is_empty()
	
	# Stop any existing display transition.
	_kill_value_display_tween()
	
	# Apply the result immediately if the transition is disabled or the cursor isn't currently visible.
	if not animate_transition or not value_label_transition_enabled or value_label_transition_duration <= 0.0 or not is_visible_in_tree():
		_apply_value_display(show_check, label_text, label_text_color)
		value_display_root.modulate.a = 1.0
		return
	
	# Create a sequential fade-out / fade-in transition.
	var half_duration: float = value_label_transition_duration * 0.5
	
	# Animate fade in if nothing was displayed previously.
	if not has_old_content:
		_apply_value_display(show_check, label_text, label_text_color)
		
		if has_new_content:
			value_display_root.modulate.a = 0.0
			
			_value_display_tween = create_tween()
			_value_display_tween.tween_property(value_display_root, "modulate:a", 1.0, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			value_display_root.modulate.a = 1.0
		
		return
	
	# Prepare a sequential fade-out / fade-in animation.
	_value_display_tween = create_tween()
	
	# Fade out the old content while it is still visible.
	_value_display_tween.tween_property(value_display_root, "modulate:a", 0.0, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Replace the content only after it has become transparent.
	_value_display_tween.tween_callback(func() -> void: _apply_value_display(show_check, label_text, label_text_color))
	
	# Fade in the new content.
	if has_new_content:
		_value_display_tween.tween_property(value_display_root, "modulate:a", 1.0, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# Reset opacity for the next update while no content is visible.
		_value_display_tween.tween_callback(func() -> void: value_display_root.modulate.a = 1.0)


## Stops any existing animation set for the value display.
func _kill_value_display_tween() -> void:
	if _value_display_tween != null and _value_display_tween.is_valid():
		_value_display_tween.kill()
	_value_display_tween = null


## Applies provided value display parameters to the value displays and sets which of them should be displayed currently.
func _apply_value_display(show_check: bool, label_text: String, label_color: Color) -> void:
	# Check whether we were previously displaying the checkmark.
	var was_showing_check: bool = value_check_mark.visible
	
	# Hide both display nodes before updating their contents.
	value_label_root.hide()
	value_check_mark.hide()
	
	# Reset display opacity.
	value_label_root.modulate.a = 1.0
	value_check_mark.modulate.a = 1.0
	
	# Display the checkmark instead of the value label.
	if show_check:
		# Stop any existing value label node scale animation.
		_kill_value_label_scale_tween()
		
		# Cancel value label scramble animation and restore the label's final text.
		value_label.cancel_animation()
		
		# Restore the correct scale for the retained text.
		_fit_value_label_text(value_label.text)
		
		# Display the check mark.
		value_check_mark.show()
		return
	
	# Clear the label when there is no text to display.
	if label_text.is_empty():
		# Stop any existing value label node scale animation.
		_kill_value_label_scale_tween()
		
		# Clear the displayed text.
		value_label.set_text_immediate("")
		
		# Reset scale for the next first appearence of the value label.
		value_label_root.scale = Vector2.ONE
		return
	
	# Check whether the currently assigned label color differs from the new color.
	var label_color_changed: bool = not value_label.get_theme_color("font_color").is_equal_approx(label_color)
	
	# Update label color.
	value_label.add_theme_color_override("font_color", label_color)
	
	# Display the value label root.
	value_label.show()
	value_label_root.show()
	
	# Update label text.
	set_value_label_text(label_text, true, was_showing_check or label_color_changed)


## Initializes corners sprite animation player with correct animation and it's state.
func _initialize_corners_animation_player() -> void:
	corners_animation_player.play(CORNERS_ANIMATION_NAME)
	
	var animation_length := corners_animation_player.current_animation_length
	var global_time := Time.get_ticks_msec() / 1000.0
	var animation_time := fmod(global_time, animation_length)
	
	corners_animation_player.seek(animation_time, true)


## Set value label text to provided [param value_text] value and adjusts the value label root scale to try and fit the text inside the value label restricted size.
func set_value_label_text(value_text: String, adjust_label_size: bool = true, force_scramble: bool = false) -> void:
	# Store whether fitting is enabled for this text change.
	_value_label_adjust_size_during_scramble = adjust_label_size
	
	# Reset the flag indicating if the value label node has started scramble.
	_value_label_scramble_started_in_call = false
	
	# Ensure that value label uses the base font size.
	value_label.add_theme_font_size_override("font_size", value_label_base_font_size)
	
	# Set the provided value text string in value label node.
	value_label.change_text(value_text, true, force_scramble)
	
	# Fit value label text scale if it's set immediately, otherwise this will be taken care by handling the value label signal.
	if adjust_label_size and not _value_label_scramble_started_in_call:
		var scale_tween_active: bool = _value_label_scale_tween != null and _value_label_scale_tween.is_valid() and _value_label_scale_tween.is_running()
		if not scale_tween_active:
			_fit_value_label_text(value_text)


## Calculates and returns a scale that would need to be applied to the value label in order to fit the provided [param value_text] string.
func _calculate_value_label_scale(value_text: String) -> float:
	# Return default scale if the value text is empty.
	if value_text.is_empty():
		return 1.0
	
	# Get value label theme font.
	var font := value_label.get_theme_font("font")
	
	# Calculate text size.
	var text_width := font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, value_label_base_font_size).x
	var text_height := font.get_height(value_label_base_font_size)
	var text_size := Vector2(text_width, text_height)
	
	# Return default scale if the value text size would be none.
	if text_size.x <= 0.0 or text_size.y <= 0.0:
		return 1.0
	
	# Calculate the available display area.
	var available_size := value_label_area_size - Vector2.ONE * float(value_label_padding) * 2.0
	available_size.x = maxf(available_size.x, 1.0)
	available_size.y = maxf(available_size.y, 1.0)
	
	# Calculate and return the scale required to fit the text.
	return minf(available_size.x / text_size.x, minf(available_size.y / text_size.y, 1.0))


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
	
	# Scale down the value label root node
	value_label_root.scale = Vector2.ONE * _calculate_value_label_scale(value_text)


## Handles emitted scramble started signal from value label node to handle the local scale adjustment for the value label root node.
## Also initializes the brief dim for the hover information indicator.
func _on_value_label_scramble_started(old_text: String, new_text: String, duration: float) -> void:
	# Set flag that value label scramble started.
	_value_label_scramble_started_in_call = true
	
	# Briefly dim the hover information indicator when the displayed value begins scrambling.
	# Skip this when the value display already has its own transition.
	if _value_display_tween == null or not _value_display_tween.is_running():
		_pulse_hover_info_indicator()
	
	# Filter out processing if the flag for value label size adjusting during scramble is not set.
	if not _value_label_adjust_size_during_scramble:
		return
	
	# Stop any existing value label scale transition.
	_kill_value_label_scale_tween()
	
	# Calculate the scale required by the new text.
	var target_scale: float = _calculate_value_label_scale(new_text)
	
	# Set the scale immediately if this is first appearence of the scrambled text and it didn't had any text assigned before.
	if old_text.is_empty():
		value_label_root.scale = Vector2.ONE * target_scale
		return
	
	# Filter out processing if the scale doesn't need to change.
	if is_equal_approx(value_label_root.scale.x, target_scale):
		return
	
	# Start a continuous transition from the current scale.
	_value_label_scale_tween = create_tween()
	_value_label_scale_tween.tween_property(value_label_root, "scale", Vector2.ONE * target_scale, duration).set_trans(Tween.TRANS_LINEAR)


## Handles emitted scramble finished signal from value label node to handle finishing the remaining scale adjustment transition for the value label root node.
func _on_value_label_scramble_finished(final_text: String) -> void:
	# Filter out processing if the flag for value label size adjusting during scramble is not set.
	if not _value_label_adjust_size_during_scramble:
		return
	
	# Stop any existing value label scale transition.
	_kill_value_label_scale_tween()
	
	# Ensure the final text text has its exact required size and scale set up correctly.
	_fit_value_label_text(final_text)


## Stops any existing animation set for the value label related to the scale transitions.
func _kill_value_label_scale_tween() -> void:
	if _value_label_scale_tween != null and _value_label_scale_tween.is_valid():
		_value_label_scale_tween.kill()
	_value_label_scale_tween = null


## Keeps the value label centered whenever its dimensions change.
func _on_value_label_resized() -> void:
	value_label.position = -value_label.size / 2.0 + value_label_visual_offset

#endregion


#region Hover Details Transitions

## Shows the hover details scene instance.
func _show_hover_details() -> void:
	# Filter out processing if the hover details aren't valid to be shown.
	if not _is_hover_details_display_valid():
		return
	
	# Set flag that hover details are active.
	_hover_details_active = true
	
	# Stop any existing animation related to hover details.
	_kill_hover_details_tween()
	
	# Initialize hover details data.
	hover_details.prepare_details(_hover_room_name, _map_solver_result_coord.calculated_weight, _map_solver_result_coord.priority_group)
	
	# Align hover details size before calculating its position.
	_align_hover_details_size_to_pixel_grid()
	
	# Calculate and set the hover details position.
	var placement: Dictionary = _choose_hover_details_placement()
	_hover_details_final_position = placement["position"]
	hover_details.position = _hover_details_final_position
	
	# Prepare and display the connector if it's enabled.
	if hover_details_connector_enabled:
		_update_hover_connector()
		if hover_connector.get_point_count() == 2:
			hover_connector.modulate.a = 0.0
			hover_connector.show()
		else:
			hover_connector.hide()
	else:
		hover_connector.hide()
	
	# Initialize hover details display parameters and open animation.
	hover_details.modulate.a = 0.0
	hover_details.show()
	hover_details.animate_text()
	
	_hover_details_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_details_tween.tween_property(hover_details, "modulate:a", 1.0, hover_details_animation_duration)
	
	if hover_connector.visible:
		_hover_details_tween.tween_property(hover_connector, "modulate:a", 1.0, hover_details_animation_duration)


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
		hover_connector.hide()
		hover_connector.modulate.a = 0.0
		return
	
	# Initialize hover details close animation.
	_hover_details_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hover_details_tween.tween_property(hover_details, "modulate:a", 0.0, hover_details_animation_duration)
	
	if hover_connector.visible:
		_hover_details_tween.tween_property(hover_connector, "modulate:a", 0.0, hover_details_animation_duration)
	
	# Queue hover details hide after the animation finishes.
	_hover_details_tween.finished.connect(_on_hover_details_hide_finished)


## Handles hover details hide animation finished signal by setting it's hidden state.
func _on_hover_details_hide_finished() -> void:
	# Filter out processing if the hover details are supposed to be displayed currently.
	if _hover_details_active:
		return
	
	# Set hover details display parameters to the hidden state.
	hover_details.hide()
	hover_connector.hide()
	hover_connector.modulate.a = 0.0


## Stops any existing animation set for the hover details.
func _kill_hover_details_tween() -> void:
	if _hover_details_tween != null and _hover_details_tween.is_valid():
		_hover_details_tween.kill()
	_hover_details_tween = null

#endregion


#region Placement Explanation Transitions

## Shows the placement explanation scene instance.
func _show_placement_explanation() -> void:
	# Filter out processing if the placement explanation isn't valid to be shown.
	if not _is_placement_explanation_display_valid():
		return
	
	# Set flag that placement explanation is active.
	_placement_explanation_active = true
	
	# Stop any existing animation related to placement explanation.
	_kill_placement_explanation_tween()
	
	# Initialize placement explanation display parameters and open animation.
	placement_explanation.show()
	
	_placement_explanation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_placement_explanation_tween.tween_property(placement_explanation, "modulate:a", 1.0, placement_explanation_animation_duration)


## Hides the placement explanation scene instance.
## Uses the provided [param immediate] flag to define whether the hide process should be instantenous or if the animation should be played for it.
func _hide_placement_explanation(immediate: bool = false) -> void:
	# Unset flag that placement explanation is active.
	_placement_explanation_active = false
	
	# Filter out processing if node wasn't already initialized.
	if not is_node_ready():
		return
	
	# Stops any existing placement explanation animation.
	_kill_placement_explanation_tween()
	
	# Initialize placement explanation display parameters if the immediate flag parameter was set or the placement explanation is currently not visible.
	if immediate or not placement_explanation.visible:
		placement_explanation.hide()
		placement_explanation.modulate.a = 0.0
		return
	
	# Initialize placement explanation close animation.
	_placement_explanation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_placement_explanation_tween.tween_property(placement_explanation, "modulate:a", 0.0, placement_explanation_animation_duration)
	
	# Queue placement explanation hide after the animation finishes.
	_placement_explanation_tween.tween_callback(func() -> void: if not _placement_explanation_active: placement_explanation.hide())


## Stops any existing animation set for the placement explanation.
func _kill_placement_explanation_tween() -> void:
	if _placement_explanation_tween != null and _placement_explanation_tween.is_valid():
		_placement_explanation_tween.kill()
	_placement_explanation_tween = null

#endregion


#region Candidate Hover Highlight Transitions

## Shows the candidate hover highlight node.
func _show_candidate_hover_highlight() -> void:
	# Filter out processing if the candidate highlight is already active.
	if _candidate_hover_active:
		return
	
	# Set flag indicating that the candidate highlight is active.
	_candidate_hover_active = true
	
	# Stop any existing candidate highlight animation.
	_kill_candidate_hover_tween()
	
	# Initialize the starting opacity if the highlight was hidden.
	if not candidate_hover_highlight.visible:
		candidate_hover_highlight.modulate.a = 0.0
	
	# Make sure the candidate highlight is visible before animating it.
	candidate_hover_highlight.show()
	
	# Immediately apply candidate hover highlight state if transition for it is disabled.
	if not candidate_hover_transition_enabled or candidate_hover_transition_duration <= 0.0:
		candidate_hover_highlight.modulate.a = 1.0
		return
	
	# Initialize the candidate highlight fade-in transition.
	_candidate_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_candidate_hover_tween.tween_property(candidate_hover_highlight, "modulate:a", 1.0, candidate_hover_transition_duration)


## Hides the candidate hover highlight node.
func _hide_candidate_hover_highlight(immediate: bool = false) -> void:
	# Unset the candidate highlight active state.
	_candidate_hover_active = false
	
	# Filter out processing if the node hasn't been initialized yet.
	if not is_node_ready():
		return
	
	# Stop any currently running candidate highlight transition.
	_kill_candidate_hover_tween()
	
	# Immediately hide the highlight if requested, if transitions are disabled, or if hte highlight is already hidden.
	if immediate or not candidate_hover_transition_enabled or candidate_hover_transition_duration <= 0.0 or not candidate_hover_highlight.visible:
		candidate_hover_highlight.hide()
		candidate_hover_highlight.modulate.a = 0.0
		return
	
	# Initialize the candidate highlight fade-out transition.
	_candidate_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_candidate_hover_tween.tween_property(candidate_hover_highlight, "modulate:a", 0.0, candidate_hover_transition_duration)
	
	# Hide the highlight after its fade-out transition finishes.
	_candidate_hover_tween.finished.connect(_on_candidate_hover_highlight_hide_finished)


## Finalizes the candidate highlight hide transition by hiding its node.
func _on_candidate_hover_highlight_hide_finished() -> void:
	# Filter out processing if the highlight become active again.
	if _candidate_hover_active:
		return
	
	# Apply the final hidden state.
	candidate_hover_highlight.hide()
	candidate_hover_highlight.modulate.a = 0.0


## Stops any existing animation set for the candidate hover highlight.
func _kill_candidate_hover_tween() -> void:
	if _candidate_hover_tween != null and _candidate_hover_tween.is_valid():
		_candidate_hover_tween.kill()
	_candidate_hover_tween = null

#endregion


#region Hover Eligibility and Connector Geometry

## Checks if the mouse is currently over any hud element that might block local interaction with the hover details scene instance.
func _mouse_is_over_blocking_hud() -> bool:
	var node: Node = get_viewport().gui_get_hovered_control()
	while node != null:
		if node.is_in_group(BLOCKS_MAP_RESULT_TOOLTIPS_GROUP_NAME):
			return true
		node = node.get_parent()
	return false


## Checks and returns a bool value indicating whether the mouse is currently over the result cursor hover area and isn't interacting with a blocking HUD element.
## Returns false if the result cursor isn't visible.
func _is_result_cursor_hover_valid() -> bool:
	# Check whether the result cursor is currently visible and if the map solver result coords aren't empty.
	if _cursor_hiding or not is_visible_in_tree() or _map_solver_result_coord == null:
		return false
	
	# Check whether the mouse is physically inside the hover rectangle.
	if not _get_hover_cursor_rect().has_point(get_local_mouse_position()):
		return false
	
	# Check whether a blocking HUD element is under the mouse.
	if _mouse_is_over_blocking_hud():
		return false
	
	return true


## Checks and returns bool value indicating whether the hover details display is valid.
## This is checked based on if the hover details are enabled and if map solver result solve stage is appropriate to this and if the mouse is currently hovered over the result cursor hover area.
func _is_hover_details_display_valid() -> bool:
	return (
		hover_details_enabled 
		and _map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_SOLUTION 
		and _is_result_cursor_hover_valid()
	)


## Checks and returns bool value indicating whether the placement explanation display is valid.
## This is checked based on if the placement explanation is enabled and if map solver result solve stage is appropriate to this and if the mouse is currently hovered over the result cursor hover area and if there is anything to be displayed.
func _is_placement_explanation_display_valid() -> bool:
	return (
		placement_explanation_enabled
		and (_map_solver_result_solve_stage == MapSolverResult.SolveStage.FOUND_VALID_PLACEMENTS 
			or _map_solver_result_solve_stage == MapSolverResult.SolveStage.CALCULATED_WEIGHTS
		)
		and _is_result_cursor_hover_valid()
		and placement_explanation.has_visuals()
	)


## Returns a rectangle representing the hover area.
## If the hover rectangle shape isn't set it will use the value label area size to determien the rectangle shape.
func _get_hover_cursor_rect() -> Rect2:
	var rectangle: RectangleShape2D = hover_collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(-value_label_area_size * 0.5, value_label_area_size)
	
	var center: Vector2 = hover_area.position + hover_collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


## Calculates and returns the closest border point located between the provided [param rect] center and the provided [param target] point. 
func _get_rect_border_point(rect: Rect2, target: Vector2) -> Vector2:
	# Calculate direction from rectangle center to the target.
	var center: Vector2 = rect.get_center()
	var direction: Vector2 = target - center
	
	# Return center if the target is set at the rectangle center.
	if direction.is_zero_approx():
		return center
	
	# Calculate scaling factor needed to reach the rectangle border.
	var half_size: Vector2 = rect.size * 0.5
	var factor: float = maxf(absf(direction.x) / maxf(half_size.x, 0.001), absf(direction.y) / maxf(half_size.y, 0.001))
	
	# Return intersection between the direction and rectangle border.
	return center + direction / factor


## Update hover connector points by finding the result cursor and hover details rects and finding the intersection points between a line from theirs centers and borders.
func _update_hover_connector() -> void:
	# Get result cursor rectangle.
	var cursor_rect: Rect2 = _get_hover_cursor_rect()
	
	# Get hover details rectangle in result cursor local coordinates.
	var tooltip_rect: Rect2 = Rect2(hover_details.position, hover_details.size * hover_details.scale)
	
	# Remove existing connector points and filter out processing if the both the cursor and hover details rectangles overlap.
	if cursor_rect.intersects(tooltip_rect):
		hover_connector.clear_points()
		return
	
	# Calculate rectangles centers.
	var cursor_center: Vector2 = cursor_rect.get_center()
	var tooltip_center: Vector2 = tooltip_rect.get_center()
	
	# Find points where the line meets the rectangle borders.
	var start_point: Vector2 = _get_rect_border_point(cursor_rect, tooltip_center)
	var end_point: Vector2 = _get_rect_border_point(tooltip_rect, cursor_center)
	
	# Extend the connector start and end points slightly by the set start and end overlap parameters values.
	var connector_direction: Vector2 = end_point - start_point
	if hover_details_connector_start_overlap != 0.0 and not connector_direction.is_zero_approx():
		start_point += -1 * connector_direction.normalized() * hover_details_connector_start_overlap
	if hover_details_connector_end_overlap != 0.0 and not connector_direction.is_zero_approx():
		end_point += connector_direction.normalized() * hover_details_connector_end_overlap
	
	# Update hover connector points.
	hover_connector.points = PackedVector2Array([start_point, end_point])

#endregion


#region Hover Details Layout and HUD Avoidance

## Returns a hover details local position that should be set for it according to the provided parameters.
## Uses provided [param cursor_rect] as a representation of the hover area rect to access its position and size to define base from which the result position is calculated.
## Uses provided [param tooltip_size] as a representation of the hover details rect to access it's size to ensure that hover details will be set next to and not on top of the cursor rect.
## Uses provided [param direction] to determine on which side of the cursor rect the hover details should be displayed on.
func _get_hover_details_local_position(cursor_rect: Rect2, tooltip_size: Vector2, direction: Vector2i) -> Vector2:
	# Calculate x and y parameters of the result vector based on the provided parameters.
	var x: float = cursor_rect.position.x + (cursor_rect.size.x - tooltip_size.x) * 0.5
	var y: float = cursor_rect.position.y + (cursor_rect.size.y - tooltip_size.y) * 0.5
	
	# Apply direction position offset based on the provided parameters.
	var scaled_hover_details_gap: float = hover_details_gap / 2 if direction.x != 0 and direction.y != 0 else hover_details_gap
	if direction.x < 0:
		x = cursor_rect.position.x - scaled_hover_details_gap - tooltip_size.x
	elif direction.x > 0:
		x = cursor_rect.end.x + scaled_hover_details_gap
	if direction.y < 0:
		y = cursor_rect.position.y - scaled_hover_details_gap - tooltip_size.y
	elif direction.y > 0:
		y = cursor_rect.end.y + scaled_hover_details_gap
	
	return Vector2(x, y)


## Transforms the provided [param local_rect] rectangle to the provided [param item] canvas viewport global transform.
func _canvas_rect_to_viewport(item: CanvasItem, local_rect: Rect2) -> Rect2:
	var t: Transform2D = item.get_global_transform_with_canvas()
	var p0: Vector2 = t * local_rect.position
	var p1: Vector2 = t * Vector2(local_rect.end.x, local_rect.position.y)
	var p2: Vector2 = t * local_rect.end
	var p3: Vector2 = t * Vector2(local_rect.position.x, local_rect.end.y)
	
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


## Transforms the provided [param local_rect] rectangle to the viewport global transform.
func _local_rect_to_viewport(local_rect: Rect2) -> Rect2:
	return _canvas_rect_to_viewport(self, local_rect)


## Gets all the rects for the blocking hud nodes that might block the hover details display.
## Checks all the nodes assigned to the BLOCKS_MAP_RESULT_TOOLTIPS_GROUP_NAME group, removes any that are duplicated or for the hidden canvas layers.
## Remaining nodes are then processed to look through their children and get any mouse blocking interfaces and return their blocking rects.
func _get_blocking_hud_rects() -> Array[Rect2]:
	var hud_rects: Array[Rect2] = []
	
	# Check every node assigned to the blocking group to check for their blocking rects.
	for root: Node in get_tree().get_nodes_in_group(BLOCKS_MAP_RESULT_TOOLTIPS_GROUP_NAME):
		# Ignore node elements belonging to another viewport.
		if root.get_viewport() != get_viewport():
			continue
		
		# Skip nested group members and hidden canvas layers.
		var ancestor: Node = root.get_parent()
		var skip_root: bool = false
		while ancestor != null:
			# Skip processing the ancestor if it's also in the same group.
			if ancestor.is_in_group(BLOCKS_MAP_RESULT_TOOLTIPS_GROUP_NAME):
				skip_root = true
				break
			
			# Skip processing the ancestor if it's a hidden canvas layer.
			if ancestor is CanvasLayer and not (ancestor as CanvasLayer).visible:
				skip_root = true
				break
			
			# Get next parent node.
			ancestor = ancestor.get_parent()
		
		# Skip processing the root if it was filtered at any point.
		if skip_root:
			continue
		
		# Get the blocking hud rects for the root node and append them to the hud rects result.
		_append_blocking_hud_rects(root, hud_rects)
	
	return hud_rects


## Checks the provided [param node] to check if it's a control node stopping mouse inputs and if yes, then it appends it's area rect to the provided [param hud_rects] list.
## Otherwise it runs the function recursively through it's every child node to search for blocking huds rects.
func _append_blocking_hud_rects(node: Node, hud_rects: Array[Rect2]) -> void:
	# Ignore other viewports and hidden canvas layers.
	if node.get_viewport() != get_viewport():
		return
	
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	
	# Ignore invisible branches.
	if node is CanvasItem:
		var item: CanvasItem = node as CanvasItem
		if not item.is_visible_in_tree():
			return
	
	# Save node bounds rect and stop traversing this particular branch if the control node blocks mouse input.
	if node is Control:
		var control: Control = node as Control

		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			var screen_rect: Rect2 = _canvas_rect_to_viewport(control, Rect2(Vector2.ZERO, control.size))
			if screen_rect.has_area():
				hud_rects.append(screen_rect.grow(hover_details_hud_margin))
	
	# Continue searching for the blocking hud rects through every child branch.
	for child: Node in node.get_children():
		_append_blocking_hud_rects(child, hud_rects)


## Returns overlap area calculated from overlapping provided [param tooltip_rect] rectangle with provided [param hud_rects] list of rectangles.
func _get_hud_overlap_area(tooltip_rect: Rect2, hud_rects: Array[Rect2]) -> float:
	var clipped_rects: Array[Rect2] = []
	var x_edges: Array[float] = []
	
	# Calculates intersections of the hud rects with the tooltip rect.
	for hud_rect: Rect2 in hud_rects:
		var overlap: Rect2 = tooltip_rect.intersection(hud_rect)
		if overlap.has_area():
			clipped_rects.append(overlap)
			x_edges.append(overlap.position.x)
			x_edges.append(overlap.end.x)
	
	# Return 0 if nothing overlaps the tooltip.
	if clipped_rects.is_empty():
		return 0.0
	
	# Divide the combined area into vertical strips.
	x_edges.sort()
	var total_area: float = 0.0
	for i: int in range(x_edges.size() - 1):
		var x_left: float = x_edges[i]
		var x_right: float = x_edges[i + 1]
		
		# Skip processing if the x coords pairs aren't compatible.
		if x_right <= x_left:
			continue
		
		# Collect Y intervals intersecting this strip.
		var y_intervals: Array[Vector2] = []
		for rect: Rect2 in clipped_rects:
			if rect.position.x < x_right and rect.end.x > x_left:
				y_intervals.append(Vector2(rect.position.y, rect.end.y))
		
		y_intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		
		if y_intervals.is_empty():
			continue
		
		# Merge overlapping Y intervals and accumulate area.
		var y_start: float = y_intervals[0].x
		var y_end: float = y_intervals[0].y
		for j: int in range(1, y_intervals.size()):
			var interval: Vector2 = y_intervals[j]
			if interval.x > y_end:
				total_area += (x_right - x_left) * (y_end - y_start)
				y_start = interval.x
				y_end = interval.y
			else:
				y_end = maxf(y_end, interval.y)
		
		total_area += (x_right - x_left) * (y_end - y_start)
	
	return total_area


## Adjust provided [param local_position] to match the viewport by calculating the shift between the provided [param screen_rect] and [param viewport_rect] rectangles and adjusting it.
func _adjust_hover_position_to_viewport(local_position: Vector2, screen_rect: Rect2, viewport_rect: Rect2) -> Vector2:
	var screen_shift: Vector2 = Vector2.ZERO
	
	# Adjust horizontal position.
	if screen_rect.size.x > viewport_rect.size.x:
		screen_shift.x = viewport_rect.get_center().x - screen_rect.get_center().x
	elif screen_rect.position.x < viewport_rect.position.x:
		screen_shift.x = viewport_rect.position.x - screen_rect.position.x
	elif screen_rect.end.x > viewport_rect.end.x:
		screen_shift.x = viewport_rect.end.x - screen_rect.end.x
	
	# Adjust vertical position.
	if screen_rect.size.y > viewport_rect.size.y:
		screen_shift.y = viewport_rect.get_center().y - screen_rect.get_center().y
	elif screen_rect.position.y < viewport_rect.position.y:
		screen_shift.y = viewport_rect.position.y - screen_rect.position.y
	elif screen_rect.end.y > viewport_rect.end.y:
		screen_shift.y = viewport_rect.end.y - screen_rect.end.y
	
	# Return local position if screen shift is none.
	if screen_shift.is_zero_approx():
		return local_position
	
	# Convert the viewport-space adjustment back to local coordinates.
	var t: Transform2D = get_global_transform_with_canvas()
	
	return t.affine_inverse() * (t * local_position + screen_shift)


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
	
	# Collect visible blocking hud rectangles.
	var hud_rects: Array[Rect2] = _get_blocking_hud_rects()
	
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
	var best_fits: bool = false
	var best_fraction: float = -1.0
	var best_hud_overlap: float = INF
	var best_position: Vector2 = Vector2.ZERO
	var best_direction: Vector2i = Vector2i.ZERO
	for direction: Vector2i in directions:
		# Calculate original candidate position.
		var local_position: Vector2 = _get_hover_details_local_position(cursor_rect, tooltip_visual_size, direction)
		var screen_rect: Rect2 = _local_rect_to_viewport(Rect2(local_position, tooltip_visual_size))
		
		# Check whether the entire tooltip fits inside the viewport.
		var fits: bool = viewport_rect.encloses(screen_rect)
		
		# Calculate viewport visibility before any correction.
		var visible_fraction: float = screen_rect.intersection(viewport_rect).get_area() / maxf(screen_rect.get_area(), 0.001)
		
		# Calculate the final position used for evaluating hud overlap.
		var evaluated_position: Vector2 = local_position
		if not fits:
			evaluated_position = _adjust_hover_position_to_viewport(local_position, screen_rect, viewport_rect)
		
		# Measure hud overlap at the corrected position.
		var evaluated_rect: Rect2 = _local_rect_to_viewport(Rect2(evaluated_position, tooltip_visual_size))
		var hud_overlap: float = _get_hud_overlap_area(evaluated_rect, hud_rects)

		# Determine whether this candidate is better than the previously selected one.
		var choose: bool = false
		if fits and not best_fits:
			choose = true
		elif fits == best_fits:
			if not fits and visible_fraction > best_fraction + 0.0001:
				choose = true
				
			elif fits or absf(visible_fraction - best_fraction) <= 0.0001:
				if hud_overlap < best_hud_overlap - 0.01:
					choose = true
		
		# Save the selected candidate.
		if choose:
			best_fits = fits
			best_fraction = visible_fraction
			best_hud_overlap = hud_overlap
			best_position = evaluated_position
			best_direction = direction
	
	return {"position": best_position, "direction": best_direction}

#endregion
