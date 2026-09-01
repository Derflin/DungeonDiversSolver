extends Node2D


const MAP_CAMERA_INPUT_ALLOW_GROUP: StringName = &"allow_map_camera_input"


var grid_rect: Rect2 = Rect2(0, 0, 0, 0)
var _pan_candidate = false
var _is_panning = false
var _pan_start_screen_position = Vector2.ZERO
var _minimum_zoom: float
var _maximum_zoom: float


@onready var map_camera: Camera2D = $MapCamera


@export_group("Initial View")
@export_range(-100.0, 100.0, 1.0)
var fit_padding = 32.0
@export_range(0.01, 10.0, 0.01)
var minimum_zoom = 0.25
@export_range(0.01, 20.0, 0.01)
var maximum_zoom = 8.0

@export_group("Zoom Controls")
@export_range(1.01, 2.0, 0.01)
var zoom_factor = 1.25
@export var zoom_toward_mouse = true
@export_range(0.0, 200.0, 1.0)
var zoom_focus_margin = 20.0
@export_range(0.1, 1.0, 0.05)
var minimum_visible_fraction_per_axis := 0.5

@export_group("Camera Panning")
## Distance in screen pixels before a click becomes a drag.
@export_range(0.0, 20.0, 1.0)
var pan_drag_threshold = 4.0


func _ready() -> void:
	_minimum_zoom = minimum_zoom
	_maximum_zoom = maximum_zoom


func set_grid_rect(_grid_rect: Rect2) -> void:
	grid_rect = _grid_rect


func fit_map_to_view(instant: bool = false) -> void:
	_fit_map_to_view.call_deferred(instant)


func center_camera_at_position(center_position: Vector2) -> void:
	map_camera.set_camera_position(center_position)


func _fit_map_to_view(instant: bool = false) -> void:
	var map_rect = grid_rect
	
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		push_warning("Cannot fit a map with an empty size.")
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	var available_size = viewport_size - Vector2.ONE * fit_padding * 2.0
	
	available_size.x = maxf(available_size.x, 1.0)
	available_size.y = maxf(available_size.y, 1.0)
	
	# Both dimensions must fit, so use the smaller scale.
	var horizontal_zoom = available_size.x / map_rect.size.x
	var vertical_zoom = available_size.y / map_rect.size.y
	
	var fitted_zoom = minf(
		horizontal_zoom,
		vertical_zoom,
	)
	
	fitted_zoom = clampf(
		fitted_zoom,
		_minimum_zoom,
		_maximum_zoom,
	)
	
	minimum_zoom = fitted_zoom
	
	map_camera.set_camera_position(map_rect.get_center(), instant)
	map_camera.set_camera_zoom(fitted_zoom, instant)


func _unhandled_input(event: InputEvent) -> void:
	if map_camera == null:
		return
		
	if _handle_pan_input(event):
		return
	
	# Filter out rest of input events if they were performed over the another control node that don't allow them to pass through
	if not _check_if_input_events_allowed_to_pass():
		return
	
	if event.is_action_pressed("map_zoom_in"):
		_handle_zoom_input(event, zoom_factor)
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("map_zoom_out"):
		_handle_zoom_input(event, 1.0 / zoom_factor)
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("map_zoom_reset"):
		_fit_map_to_view()
		get_viewport().set_input_as_handled()


func _check_if_input_events_allowed_to_pass() -> bool:
	# Get current deepest hovered controled node
	var hovered_control := get_viewport().gui_get_hovered_control()
	
	# Return true if the current input event isn't hovered above any of the control nodes
	if hovered_control == null:
		return true
	
	# Check if the current node or any of it's parents are set inside the map camera input allow custom global group and return true if that's the case
	var node: Node = hovered_control
	while node != null:
		if node.is_in_group(MAP_CAMERA_INPUT_ALLOW_GROUP):
			return true
		
		node = node.get_parent()
	
	# Otherwise return false
	return false


func _handle_zoom_input(event: InputEvent, multiplier: float) -> void:
	var focus_position = (
		get_viewport().get_visible_rect().size / 2.0
	)
	
	if zoom_toward_mouse and event is InputEventMouse:
		focus_position = event.position
		
	_zoom_at_screen_position(
		map_camera.get_camera_zoom().x * multiplier,
		focus_position,
	)


func _zoom_at_screen_position(requested_zoom: float, screen_position: Vector2) -> void:
	var old_zoom = map_camera.get_camera_zoom().x
	
	var new_zoom = clampf(
		requested_zoom,
		minimum_zoom,
		maximum_zoom,
	)
	
	if is_equal_approx(old_zoom, new_zoom):
		return
		
	var zoom_target = _get_constrained_zoom_target(screen_position)
	
	var target_offset_from_camera = zoom_target - map_camera.get_camera_position()
	
	map_camera.set_camera_position(zoom_target - target_offset_from_camera * old_zoom / new_zoom)
	map_camera.set_camera_zoom(new_zoom)
	
	_clamp_camera_to_minimum_visibility()
	
	
func _clamp_camera_to_minimum_visibility() -> void:
	var map_rect = grid_rect
	
	if map_rect.size.x <= 0:
		return
		
	if map_rect.size.y <= 0:
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	
	var map_camera_zoom = map_camera.get_camera_zoom()
	var visible_world_size = Vector2(
		viewport_size.x / map_camera_zoom.x,
		viewport_size.y / map_camera_zoom.y,
	)
	
	var new_position = map_camera.get_camera_position()
	
	new_position.x = _clamp_axis_for_overlap(
		new_position.x,
		map_rect.position.x,
		map_rect.end.x,
		visible_world_size.x,
		minimum_visible_fraction_per_axis,
	)
	
	new_position.y = _clamp_axis_for_overlap(
		new_position.y,
		map_rect.position.y,
		map_rect.end.y,
		visible_world_size.y,
		minimum_visible_fraction_per_axis
	)
	
	map_camera.set_camera_position(new_position)
	
	
func _clamp_axis_for_overlap(requested_position: float, map_minimum: float, map_maximum: float, visible_length: float, required_fraction: float) -> float:
	var map_length = map_maximum - map_minimum
	
	var required_overlap = visible_length * clampf(required_fraction, 0.0, 1.0)
	
	# The map is too small to satisfy the requested overlap.
	# Centering it is the least surprising fallback.
	if map_length < required_overlap:
		return (map_minimum + map_maximum) / 2.0
		
	var half_visible_length = visible_length / 2.0
	
	var minimum_camera_position = map_minimum + required_overlap - half_visible_length
	var maximum_camera_position = map_maximum - required_overlap + half_visible_length
	
	if minimum_camera_position > maximum_camera_position:
		return (map_minimum + map_maximum) / 2.0
		
	return clampf(
		requested_position,
		minimum_camera_position,
		maximum_camera_position,
	)


func _get_constrained_zoom_target(screen_position: Vector2) -> Vector2:
	var map_rect = grid_rect
	var cursor_map_position = make_canvas_position_local(screen_position)
	
	var map_vicinity = map_rect.grow(zoom_focus_margin)
	
	if map_vicinity.has_point(cursor_map_position):
		return cursor_map_position
		
	return _project_point_to_rect_edge(
		cursor_map_position,
		map_rect,
	)
	
	
func _project_point_to_rect_edge(point: Vector2, rect: Rect2) -> Vector2:
	var center = rect.get_center()
	var direction = point - center
	
	if direction.length_squared() < 0.000001:
		return center
		
	var half_size = rect.size / 2.0
	
	var horizontal_scale = INF
	var vertical_scale = INF
	
	if not is_zero_approx(direction.x):
		horizontal_scale = half_size.x / absf(direction.x)
		
	if not is_zero_approx(direction.y):
		vertical_scale = half_size.y / absf(direction.y)
		
	var intersection_scale = minf(horizontal_scale, vertical_scale)
	
	return center + direction * intersection_scale
	
	
func _handle_pan_input(event: InputEvent) -> bool:
	# Begin a possible drag.
	if event.is_action_pressed("map_pan"):
		if not event is InputEventMouse:
			return false
			
		_pan_candidate = true
		_is_panning = false
		_pan_start_screen_position = event.position
		
		# Do not consume the initial press yet, since it may still be a click.
		return false
		
	# End the drag.
	if event.is_action_released("map_pan"):
		var was_panning = _is_panning
		
		_pan_candidate = false
		_is_panning = false
		
		if was_panning:
			get_viewport().set_input_as_handled()
			
		return was_panning
		
	# Move the camera while dragging.
	if event is InputEventMouseMotion and _pan_candidate:
		# Safety check in case a release event was missed, for example after losing window focus.
		if not Input.is_action_pressed("map_pan"):
			_pan_candidate = false
			_is_panning = false
			return false
			
		if not _is_panning:
			var distance_from_start = event.position.distance_to(_pan_start_screen_position)
			
			if distance_from_start < pan_drag_threshold:
				return false
				
			_is_panning = true
			
		var camera_movement = event.relative / map_camera.get_camera_zoom().x
		
		# Subtraction makes the map follow the mouse:
		# drag right -> map appers to move right.
		map_camera.set_camera_position(map_camera.get_camera_position() - camera_movement)
		
		_clamp_camera_to_minimum_visibility()
		
		get_viewport().set_input_as_handled()
		return true
		
	return false	
