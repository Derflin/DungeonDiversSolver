extends Node2D


const MAP_CAMERA_INPUT_ALLOW_GROUP: StringName = &"allow_map_camera_input"
const MAP_CAMERA_VIEW_OBSTACLES_GROUP: StringName = &"map_camera_view_obstacles"

enum CameraViewMode { FIT, CUSTOM }


@export_group("Initial View")
@export_range(0.0, 100.0, 1.0) var fit_padding = 32.0

@export_group("Relative Zoom Limits")
@export_range(1.0, 10.0, 0.05) var maximum_zoom_relative_to_fit: float = 3.0
## Target size of a single room cell at maximum zoom, in logical viewport pixels.
@export_range(32.0, 256.0, 4.0) var maximum_room_cell_screen_size: float = 60.0

@export_group("Zoom Controls")
@export_range(1.01, 2.0, 0.01) var zoom_factor = 1.25
@export var zoom_toward_mouse = true
@export_range(0.0, 200.0, 1.0) var zoom_focus_margin = 20.0
@export_range(0.1, 1.0, 0.05) var minimum_visible_fraction_per_axis := 0.5

@export_group("Camera Panning")
## Distance in screen pixels before a click becomes a drag.
@export_range(0.0, 20.0, 1.0) var pan_drag_threshold = 4.0


var grid_rect: Rect2 = Rect2(0, 0, 0, 0)
var _pan_candidate = false
var _is_panning = false
var _pan_start_screen_position = Vector2.ZERO

var _view_mode: CameraViewMode = CameraViewMode.FIT
var _fitted_zoom: float = 1.0
var _relative_zoom: float = 1.0

var _last_viewport_center: Vector2 = Vector2.ZERO
var _last_safe_rect: Rect2 = Rect2()
var _has_view_snapshot: bool = false
var _resize_pending: bool = false 


@onready var map_camera: MapCamera = $MapCamera


func _ready() -> void:
	# Recalculate camera framing when the logical viewport dimensions change.
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func set_grid_rect(_grid_rect: Rect2) -> void:
	grid_rect = _grid_rect


func fit_map_to_view(instant: bool = false) -> void:
	_fit_map_to_view.call_deferred(instant)


## Adjust camera position to be set and centered at the provided [param center_position] point.
## Centers the camera on a map point without resetting the user's current zoom ratio.
func center_camera_at_position(center_position: Vector2) -> void:
	# Get the viewport area not covered by HUD blocking controls.
	var free_rect := _get_available_map_view_rect()
	if not free_rect.has_area():
		free_rect = get_viewport().get_visible_rect()
	
	# Get camera position centered around the center position adjusted to be centered around the free rect area.
	var new_position := _get_position_for_safe_center(center_position, free_rect, map_camera.get_camera_zoom().x)
	
	# Set the camera view mode to custom to ensure that it's not set to fit mode.
	_view_mode = CameraViewMode.CUSTOM
	
	# Adjust the camera position to be centered on the calculated position.
	map_camera.set_camera_position(_get_clamped_camera_position(new_position, map_camera.get_camera_zoom().x))


## Adjusts camera zoom and position in order to fit the entire grid rectangle and display it's center in the available view rect center.
## Used the provided [param instant] flag to determine if changing the camera state should be instant or animated.
## Activates FIT mode so subsequent viewport resizing keeps the map fitted.
func _fit_map_to_view(instant: bool = false) -> void:
	# Filter out processing if the grid rect size is less then or equal 0 in any axis.
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		push_warning("Cannot fit a map with an empty size.")
		return
	
	# Get the viewport area not covered by HUD blocking controls.
	var free_rect := _get_available_map_view_rect()
	if not free_rect.has_area():
		push_warning("MapCameraManager: No unobstructed viewport area remains after accounting for HUD blocking controls.")
		free_rect = get_viewport().get_visible_rect()
	
	# Calculate the zoom required to fit both map dimensions.
	var new_fit_zoom := _calculate_fitted_zoom(free_rect)
	if new_fit_zoom <= 0.0:
		push_warning("MapCameraManager: Cannot fit map to an empty view area.")
		return
	
	# Save the current state for the fit view mode.
	_fitted_zoom = new_fit_zoom
	_relative_zoom = 1.0
	_view_mode = CameraViewMode.FIT
	
	# Calculate the adjusted camera position according to the available free area.
	var center_position := _get_position_for_safe_center(grid_rect.get_center(), free_rect, _fitted_zoom)
	
	# Update camera state including zoom and position.
	map_camera.set_camera_state(center_position, _fitted_zoom, instant)
	
	# Save the calculated available free area.
	_remember_view_geometry(free_rect)


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


## Returns the maximum zoom based on the relative zoom limit and on the maximum room cell screen size to ensure proper visibility.
func _get_maximum_camera_zoom() -> float:
	# Calculate maximum zoom limit based on the fitted zoom and the set relative zoom limit.
	var relative_limit: float = _fitted_zoom * maximum_zoom_relative_to_fit
	
	# Calculate maximum zoom limit based on the room cell size and set expected maximum room cell screen size.
	var room_size := GameSettings.map_grid_room_size
	var largest_room_side: float = maxf(1.0, maxf(float(room_size.x), float(room_size.y)))
	var room_size_limit: float = maximum_room_cell_screen_size / largest_room_side
	
	# Retur a maximum zoom limit that would require a bigger zoom based on the calculated limits.
	return maxf(relative_limit, room_size_limit)


## Requests a mouse-anchored zoom when possible, and a smoothly constrained zoom near map limits.
func _zoom_at_screen_position(requested_zoom: float, screen_position: Vector2) -> void:
	# Filter out processing if the last saved fitted zoom is invalid. 
	if _fitted_zoom <= 0.0:
		return
	
	# Retrieve the currently requested zoom and apply existing zoom restrictions.
	var old_zoom := map_camera.get_camera_zoom().x
	var new_zoom := clampf(requested_zoom, _fitted_zoom, _get_maximum_camera_zoom())
	if is_equal_approx(old_zoom, new_zoom):
		return
	
	## Treat reaching the minimum zoom as an intentional return to the fitted view.
	## Don't try to keep the a distant mouse anchor while showing the entire map.
	#if is_equal_approx(new_zoom, _fitted_zoom):
	#	_fit_map_to_view(false)
	#	return
	
	# Resolve the current world point that should remain under the cursor.
	var zoom_target: Vector2 = _get_constrained_zoom_target(screen_position)
	var anchor_screen: Vector2 = get_global_transform_with_canvas() * zoom_target
	var viewport_center: Vector2 = get_viewport().get_visible_rect().get_center()
	
	# Calculate the exact anchor destination and its boundary-constrained alternative.
	var requested_position: Vector2 = zoom_target + (viewport_center - anchor_screen) / new_zoom
	var constrained_position: Vector2 = _get_clamped_camera_position(requested_position, new_zoom)
	
	# Update view state using the final requested relative zoom.
	_view_mode = CameraViewMode.CUSTOM
	_relative_zoom = new_zoom / _fitted_zoom
	
	# Animate the final state normally if the anchor would move the map beyond its limits.
	var correction_screen_distance: float = requested_position.distance_to(constrained_position) * new_zoom
	if correction_screen_distance > 0.25:
		map_camera.set_camera_state(constrained_position, new_zoom)
		return
	
	# Keep exact mouse anchoring when the requested destination is unrestricted.
	map_camera.set_camera_zoom_anchored(new_zoom, zoom_target, anchor_screen, constrained_position)


## Restricts the camera target position to keep the usable viewing area's center within the map boundaries.
func _clamp_camera_to_map_bounds() -> void:
	# Keep panning within the same map visibility restrictions as zooming.
	var requested_position := map_camera.get_camera_position()
	var constrained_position := _get_clamped_camera_position(requested_position, map_camera.get_camera_zoom().x)
	
	# Update the camera position only if the requested position exceeds the limits.
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
	var viewport_center := get_viewport().get_visible_rect().get_center()
	var safe_center_offset := (usable_rect.get_center() - viewport_center) / camera_zoom
	
	# Determine which world-space position appears at the center of the usable area.
	var requested_safe_center := requested_position + safe_center_offset
	
	# Restrict the usable area's center to remain inside the map boundaries.
	var clamped_safe_center := Vector2(
		clampf(requested_safe_center.x, map_rect.position.x, grid_rect.end.x),
		clampf(requested_safe_center.y, map_rect.position.y, grid_rect.end.y),
	)
	
	return clamped_safe_center - safe_center_offset


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
			
		var camera_movement := (event as InputEventMouseMotion).relative / map_camera.get_camera_zoom().x
		
		# Set the camera view mode to custom to ensure that it's not set to fit mode.
		_view_mode = CameraViewMode.CUSTOM
		
		# Subtraction makes the map follow the mouse:
		# drag right -> map appers to move right.
		var requested_position := map_camera.get_camera_position() - camera_movement
		var constrained_position := _get_clamped_camera_position(requested_position, map_camera.get_camera_zoom().x)
		map_camera.set_camera_position(constrained_position)
		
		get_viewport().set_input_as_handled()
		return true
		
	return false	


## Returns the zoom that fits the whole map into the available viewport rectangle.
func _calculate_fitted_zoom(free_rect: Rect2) -> float:
	# Filter out processing and return 0 if the grid rect size is less then or equal 0 in any axis.
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return 0.0
	
	# Calculate available area from the provided free rect and padding parameters.
	var padding := maxf(fit_padding, 0.0)
	var available_size := free_rect.size - Vector2.ONE * padding * 2.0
	
	# Filter out processing and return 0 if the calculated available area size is less then or equal 0 in any axis.
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return 0.0
	
	return minf(available_size.x / grid_rect.size.x, available_size.y / grid_rect.size.y)


## Saves the geometry associated with the camera's previous requested view.
func _remember_view_geometry(free_rect: Rect2) -> void:
	_last_viewport_center = get_viewport().get_visible_rect().get_center()
	_last_safe_rect = free_rect
	_has_view_snapshot = true


## Schedules a single resize update instead of starting an animation for each resize event.
func _on_viewport_size_changed() -> void:
	# Filter out processing if there is already pending resize.
	if _resize_pending:
		return
	
	# Set the resize pending flag.
	_resize_pending = true
	
	# Queue viewport resize.
	_apply_viewport_resize.call_deferred()


## Applies a responsive fit or preserves the custom view after HUD layout has updated.
func _apply_viewport_resize() -> void:
	# Wait for layout to update before measuring the unobstructed map area.
	await get_tree().process_frame
	
	# Unset the resize pending flag.
	_resize_pending = false
	
	# Filter out processing if the grid rect size is less then or equal 0 in any axis.
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return
	
	# Get the viewport area not covered by HUD blocking controls.
	var free_rect := _get_available_map_view_rect()
	if not free_rect.has_area():
		free_rect = get_viewport().get_visible_rect()
	
	# Calculate the zoom required to fit both map dimensions.
	var new_fit_zoom := _calculate_fitted_zoom(free_rect)
	if new_fit_zoom <= 0.0:
		return
	
	# Use the normal fitted view function call if no previous view was established.
	if not _has_view_snapshot:
		_fit_map_to_view(true)
		return
	
	# Get the current zoom and camera focus position.
	var old_zoom := maxf(map_camera.get_camera_zoom().x, 0.00001)
	var old_focus_world := map_camera.get_camera_position() + (_last_safe_rect.get_center() - _last_viewport_center) / old_zoom
	
	# Save the calculated fit zoom for the fit view mode.
	_fitted_zoom = new_fit_zoom
	
	# Calculate the new camera zoom and position based on the current view mode.
	var new_zoom: float
	var new_position: Vector2
	match _view_mode:
		CameraViewMode.FIT:
			_relative_zoom = 1.0
			new_zoom = _fitted_zoom
			new_position = _get_position_for_safe_center(grid_rect.get_center(), free_rect, new_zoom)
			
		CameraViewMode.CUSTOM:
			var maximum_relative_zoom: float = _get_maximum_camera_zoom() / _fitted_zoom
			_relative_zoom = clampf(_relative_zoom, 1.0, maximum_relative_zoom)
			new_zoom = _fitted_zoom * _relative_zoom
			new_position = _get_position_for_safe_center(old_focus_world, free_rect, new_zoom)
			new_position = _get_clamped_camera_position(new_position, new_zoom)
			
		_:
			return
	
	# Update camera state including zoom and position.
	map_camera.set_camera_state(new_position, new_zoom, true)
	
	# Save the calculated available free area.
	_remember_view_geometry(free_rect)
