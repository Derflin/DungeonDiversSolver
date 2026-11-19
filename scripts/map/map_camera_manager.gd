extends Node2D


const MAP_CAMERA_INPUT_ALLOW_GROUP: StringName = &"allow_map_camera_input"
const MAP_CAMERA_VIEW_OBSTACLES_GROUP: StringName = &"map_camera_view_obstacles"


@export_group("Initial View")
@export_range(0.0, 100.0, 1.0)
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


var grid_rect: Rect2 = Rect2(0, 0, 0, 0)
var _pan_candidate = false
var _is_panning = false
var _pan_start_screen_position = Vector2.ZERO
var _minimum_zoom: float
var _maximum_zoom: float


@onready var map_camera: MapCamera = $MapCamera


func _ready() -> void:
	_minimum_zoom = minimum_zoom
	_maximum_zoom = maximum_zoom


func set_grid_rect(_grid_rect: Rect2) -> void:
	grid_rect = _grid_rect


func fit_map_to_view(instant: bool = false) -> void:
	_fit_map_to_view.call_deferred(instant)


## Adjust camera position to be set and centered at the provided [param center_position] point.
func center_camera_at_position(center_position: Vector2) -> void:
	# Get the viewport area not covered by HUD blocking controls.
	var free_rect := _get_available_map_view_rect()
	if not free_rect.has_area():
		free_rect = get_viewport().get_visible_rect()
	
	# Get camera position centered around the center position adjusted to be centered around the free rect area.
	var camera_position := _get_position_for_safe_center(center_position, free_rect, map_camera.get_camera_zoom().x)
	
	# Adjust the camera position to be centered on the calculated position.
	map_camera.set_camera_position(camera_position)


## Adjusts camera zoom and position in order to fit the entire grid rectangle and display it's center in the available view rect center.
## Used the provided [param instant] flag to determine if changing the camera state should be instant or animated.
func _fit_map_to_view(instant: bool = false) -> void:
	# Get current map rect.
	var map_rect = grid_rect
	
	# Filter out processing if the map rect size is less then 0 in any axis.
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		push_warning("Cannot fit a map with an empty size.")
		return
	
	# Get the viewport area not covered by HUD blocking controls.
	var free_rect := _get_available_map_view_rect()
	if not free_rect.has_area():
		push_warning("MapCameraManager: No unobstructed viewport area remains after accounting for HUD blocking controls.")
		free_rect = get_viewport().get_visible_rect()
	
	# Apply the fit padding to the available area.
	var padding := maxf(fit_padding, 0.0)
	var available_size := free_rect.size - Vector2.ONE * padding * 2.0
	
	# Calculate the zoom required to fit both map dimensions.
	var fitted_zoom := minf(available_size.x / map_rect.size.x, available_size.y / map_rect.size.y)
	fitted_zoom = clampf(
		fitted_zoom,
		_minimum_zoom,
		_maximum_zoom,
	)
	
	# Preserve the calculated fitted zoom as the minimum zoom.
	minimum_zoom = fitted_zoom
	
	# Calculate the adjusted camera position according to the available free area.
	var centered_position := _get_position_for_safe_center(map_rect.get_center(), free_rect, fitted_zoom)
	
	# Update the camera zoom and position.
	map_camera.set_camera_zoom(fitted_zoom, instant)
	map_camera.set_camera_position(centered_position, instant)


## Checks the nodes assigned inside the MAP_CAMERA_VIEW_OBSTACLES_GROUP group and reduces the viewport rects over their rects.
## Returns the remaining rectangle as a space available where the map view might be placed without overlapping the view obstacles.
func _get_available_map_view_rect() -> Rect2:
	# Prepare variables for available map view obstacles and prepare a list of boundaries for them.
	var viewport_rect := get_viewport().get_visible_rect()
	var obstacles: Array[Rect2] = []
	var x_boundaries: Array[float] = [viewport_rect.position.x, viewport_rect.end.x]
	
	# Collect all nodes elements assigned to the view obstacle group.
	for node in get_tree().get_nodes_in_group(MAP_CAMERA_VIEW_OBSTACLES_GROUP):
		# Filter out processing if the node isn't a control node.
		if not node is Control:
			continue
		var hud_control := node as Control
		
		# Filter out processing if the node viewport is different then the current viewport.
		if hud_control.get_viewport() != get_viewport():
			continue
		
		# Filter out processing if the node is hidden.
		if not hud_control.is_visible_in_tree():
			continue
		
		# Filter out processing if the node size is lest or equal 0 in any axis.
		if hud_control.size.x <= 0.0 or hud_control.size.y <= 0.0:
			continue
		
		# Convert nodes bounds to vieport coordinates.
		var transform_to_viewport := hud_control.get_global_transform_with_canvas()
		var corners: Array[Vector2] = [
			transform_to_viewport * Vector2.ZERO,
			transform_to_viewport * Vector2(hud_control.size.x, 0.0),
			transform_to_viewport * hud_control.size,
			transform_to_viewport * Vector2(0.0, hud_control.size.y),
		]
		var top_left := corners[0]
		var bottom_right := corners[0]
		for corner in corners:
			top_left = top_left.min(corner)
			bottom_right = bottom_right.max(corner)
		
		var occupied_rect := Rect2(top_left, bottom_right - top_left)
		
		# Check how much of the occupied area is in viewport and filter out processing if the occupied rect is completely outside of it.
		occupied_rect = occupied_rect.intersection(viewport_rect)
		if not occupied_rect.has_area():
			continue
		
		obstacles.append(occupied_rect)
		x_boundaries.append(occupied_rect.position.x)
		x_boundaries.append(occupied_rect.end.x)
		
	# Return an entire viewport rectangle if there aren't any view obstacles.
	if obstacles.is_empty():
		return viewport_rect
	
	# Calculate the remaining space after excluding the obstacles rects from the viewport rect.
	x_boundaries.sort()
	var best_rect := Rect2()
	var preferred_center := viewport_rect.get_center()
	for left_index in range(x_boundaries.size() - 1):
		var left_x := x_boundaries[left_index]
		for right_index in range(left_index + 1, x_boundaries.size()):
			var right_x := x_boundaries[right_index]
			
			# Filter out processing the x coord pairs if they aren't valid.
			if right_x <= left_x:
				continue
			
			# Find obstacles intersecting the current horizontal span.
			var blocked_vertical_bands: Array[Vector2] = []
			for obstacle in obstacles:
				if obstacle.position.x < right_x and obstacle.end.x > left_x:
					blocked_vertical_bands.append(Vector2(obstacle.position.y, obstacle.end.y))
			
			blocked_vertical_bands.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			
			# Evaluate available vertical gaps.
			var next_free_y := viewport_rect.position.y
			for blocked_band in blocked_vertical_bands:
				if blocked_band.x > next_free_y:
					var upper_gap := Rect2(left_x, next_free_y, right_x - left_x, blocked_band.x - next_free_y)
					best_rect = _choose_better_free_rect(best_rect, upper_gap, preferred_center)
				
				next_free_y = maxf(next_free_y, blocked_band.y)
				
				if next_free_y >= viewport_rect.end.y:
					break
			
			# Check the remaining gap below the obstacles.
			if next_free_y < viewport_rect.end.y:
				var lower_gap := Rect2(left_x, next_free_y, right_x - left_x, viewport_rect.end.y - next_free_y)
				best_rect = _choose_better_free_rect(best_rect, lower_gap, preferred_center)
	
	return best_rect


## Compares which of the provided [param current] and [param candidate] rects is better in terms of space.
## Returns a rect that either has bigger area or if it's equal then the one that is closer to the provided [param preferred_center] point.
func _choose_better_free_rect(current: Rect2, candidate: Rect2, preferred_center: Vector2) -> Rect2:
	# Return the candidate rect if it has a bigger area then the current rect.
	if candidate.get_area() > current.get_area() and not is_equal_approx(candidate.get_area(), current.get_area()):
		return candidate
	
	# Return the candidate rect if it has approximetely the same area as current rect and it's closer to the preferred center.
	if is_equal_approx(candidate.get_area(), current.get_area()):
		if candidate.get_center().distance_squared_to(preferred_center) < current.get_center().distance_squared_to(preferred_center):
			return candidate
	
	# Otherwise return current
	return current


## Adjusts and returns the provided [param world_position] point by adding to it an offset between viewport visible rect center and provided [param safe_rect] rect center.
## Additionaly adjusts the calculated offset by dividing with the provided [param camera_zoom].
func _get_position_for_safe_center(world_position: Vector2, safe_rect: Rect2, camera_zoom: float) -> Vector2:
	var viewport_center := get_viewport().get_visible_rect().get_center()
	return world_position + (viewport_center - safe_rect.get_center()) / camera_zoom


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
	var focus_position := get_viewport().get_visible_rect().get_center()
	
	var usable_rect := _get_available_map_view_rect()
	if usable_rect.has_area():
		focus_position = usable_rect.get_center()
	
	if zoom_toward_mouse and event is InputEventMouse:
		focus_position = event.position
		
	_zoom_at_screen_position(
		map_camera.get_camera_zoom().x * multiplier,
		focus_position,
	)


func _zoom_at_screen_position(requested_zoom: float, screen_position: Vector2) -> void:
	# Retrieve the currently requested zoom and apply existing zoom restrictions.
	var old_zoom := map_camera.get_camera_zoom().x
	var new_zoom := clampf(requested_zoom, minimum_zoom, maximum_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return
	
	# Calculate the world-space point and its current on-screen position.
	var zoom_target := _get_constrained_zoom_target(screen_position)
	var anchor_screen: Vector2 = get_global_transform_with_canvas() * zoom_target
	
	# Calculate the exact anchor destination at the final zoom.
	var viewport_center := get_viewport().get_visible_rect().get_center()
	var requested_position := zoom_target + (viewport_center - anchor_screen) / new_zoom
	
	# Clamp the destination before starting the animation.
	var constrained_position := _get_clamped_camera_position(requested_position, new_zoom)
	map_camera.set_camera_zoom_anchored(new_zoom, zoom_target, anchor_screen, constrained_position)


func _clamp_camera_to_minimum_visibility() -> void:
	# Keep panning within the same map visibility restrictions as zooming.
	var requested_position := map_camera.get_camera_position()
	var constrained_position := _get_clamped_camera_position(requested_position, map_camera.get_camera_zoom().x)
	if requested_position.distance_squared_to(constrained_position) > 0.0000001:
		map_camera.set_camera_position(constrained_position)


## Restricts a requested camera position without changing the current camera animation.
## This helper can be used by normal panning and mouse-anchored zooming.
func _get_clamped_camera_position(requested_position: Vector2, requested_zoom: float) -> Vector2:
	# Get map rectangle and return the requested_position if it's size is zero.
	var map_rect := grid_rect
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return requested_position
	
	# Get the viewport area not covered by HUD blocking controls.
	var usable_rect := _get_available_map_view_rect()
	if not usable_rect.has_area():
		usable_rect = get_viewport().get_visible_rect()
	
	# Convert the unobstructed view area to world units at the requested zoom.
	var camera_zoom := maxf(requested_zoom, 0.00001)
	var visible_world_size := usable_rect.size / camera_zoom
	var viewport_center := get_viewport().get_visible_rect().get_center()
	var safe_center_offset := (usable_rect.get_center() - viewport_center) / camera_zoom
	var safe_center_world := requested_position + safe_center_offset
	
	# Apply the same minimum visbility fraction on both axes.
	safe_center_world.x = _clamp_axis_for_overlap(
		safe_center_world.x,
		map_rect.position.x,
		map_rect.end.x,
		visible_world_size.x,
		minimum_visible_fraction_per_axis,
	)
	safe_center_world.y = _clamp_axis_for_overlap(
		safe_center_world.y,
		map_rect.position.y,
		map_rect.end.y,
		visible_world_size.y,
		minimum_visible_fraction_per_axis,
	)
	
	return safe_center_world - safe_center_offset


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
