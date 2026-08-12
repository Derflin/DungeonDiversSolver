extends Node2D


#TODO: look through debugger warnings and check if any of them could be easily removed
#TODO: look through defined functions and check if any of them could be renamed to internal (_ at the begginging of the function names)
#TODO: add readme file and mark TODOs in it
#TODO: add comments
#TODO: add asserts if everything needed is assigned on the start (mostly in case of export variables that need to be populated for everything to work correctly)
#TODO: add room_cell_preview for testing out different textures/animations
#TODO: add map validation based on some rules (rules defined in cataloge or something, displayed on screen to show which failed and which succeeded)
#TODO: add option to save/load current map into a file
#TODO: add option to set map parameters like map size, types of secret rooms, their count and their order
#TODO: implement scripts for checking, hinting and solving each secret room type based on the current map
#TODO: add overlay hud menu for triggering hinting and solving each secret room type for the current map
#TODO: add option to load in map state from game screenshot (most likey would need to analyze the image and assume that the whole map is visible on it)


var _pan_candidate = false
var _is_panning = false
var _pan_start_screen_position = Vector2.ZERO


@onready var grid_space: Node2D = $GridSpace
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
	var instant = true
	fit_map_to_view.call_deferred(instant)


func fit_map_to_view(instant: bool = false) -> void:
	var map_rect = grid_space.get_map_rect()
	
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
		minimum_zoom,
		maximum_zoom,
	)
	
	minimum_zoom = fitted_zoom
	
	map_camera.set_camera_position(map_rect.get_center(), instant)
	map_camera.set_camera_zoom(fitted_zoom, instant)


func _unhandled_input(event: InputEvent) -> void:
	if map_camera == null:
		return
		
	if _handle_pan_input(event):
		return
		
	if event.is_action_pressed("map_zoom_in"):
		_handle_zoom_input(event, zoom_factor)
		get_viewport().set_input_as_handled()
		
	elif event.is_action_pressed("map_zoom_out"):
		_handle_zoom_input(event, 1.0 / zoom_factor)
		get_viewport().set_input_as_handled()
		
	elif event.is_action_pressed("map_zoom_reset"):
		fit_map_to_view()
		get_viewport().set_input_as_handled()


func _handle_zoom_input(event: InputEvent, multiplier: float) -> void:
	var focus_position = (
		get_viewport().get_visible_rect().size / 2.0
	)
	
	if zoom_toward_mouse and event is InputEventMouse:
		focus_position = event.position
		
	zoom_at_screen_position(
		map_camera.get_camera_zoom().x * multiplier,
		focus_position,
	)


func zoom_at_screen_position(requested_zoom: float, screen_position: Vector2) -> void:
	var old_zoom = map_camera.get_camera_zoom().x
	
	var new_zoom = clampf(
		requested_zoom,
		minimum_zoom,
		maximum_zoom,
	)
	
	if is_equal_approx(old_zoom, new_zoom):
		return
		
	var zoom_target = get_constrained_zoom_target(screen_position)
	
	var target_offset_from_camera = zoom_target - map_camera.get_camera_position()
	
	map_camera.set_camera_position(zoom_target - target_offset_from_camera * old_zoom / new_zoom)
	map_camera.set_camera_zoom(new_zoom)
	
	clamp_camera_to_minimum_visibility()
	
	
func clamp_camera_to_minimum_visibility() -> void:
	var map_rect = grid_space.get_map_rect()
	
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
	
	new_position.x = clamp_axis_for_overlap(
		new_position.x,
		map_rect.position.x,
		map_rect.end.x,
		visible_world_size.x,
		minimum_visible_fraction_per_axis,
	)
	
	new_position.y = clamp_axis_for_overlap(
		new_position.y,
		map_rect.position.y,
		map_rect.end.y,
		visible_world_size.y,
		minimum_visible_fraction_per_axis
	)
	
	map_camera.set_camera_position(new_position)
	
	
func clamp_axis_for_overlap(requested_position: float, map_minimum: float, map_maximum: float, visible_length: float, required_fraction: float) -> float:
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


func get_constrained_zoom_target(screen_position: Vector2) -> Vector2:
	var map_rect = grid_space.get_map_rect()
	var cursor_map_position = make_canvas_position_local(screen_position)
	
	var map_vicinity = map_rect.grow(zoom_focus_margin)
	
	if map_vicinity.has_point(cursor_map_position):
		return cursor_map_position
		
	return project_point_to_rect_edge(
		cursor_map_position,
		map_rect,
	)
	
	
func project_point_to_rect_edge(point: Vector2, rect: Rect2) -> Vector2:
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
		
		clamp_camera_to_minimum_visibility()
		
		get_viewport().set_input_as_handled()
		return true
		
	return false	


func _on_grid_space_grid_space_parameters_changed() -> void:
	fit_map_to_view.call_deferred()


func _on_grid_space_selected_room_changed(room_coords: Vector2i, room_center_position: Vector2) -> void:
	map_camera.set_camera_position(room_center_position)
