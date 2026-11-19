class_name MapCamera
extends Camera2D


const POSITION_COMPLETION_THRESHOLD_SCREEN: float = 0.1
const ZOOM_COMPLETION_THRESHOLD: float = 0.00005


@export_group("Smoothing Parameters", "smoothing_")
@export var smoothing_position_enabled: bool = true
@export_range(0.1, 30.0, 0.1) var smoothing_position_speed: float = 12.0
@export var smoothing_zoom_enabled: bool = true
@export_range(0.1, 30.0, 0.1) var smoothing_zoom_speed: float = 10.0


var target_position: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ONE

var _zoom_anchor_active: bool = false
var _zoom_anchor_world: Vector2 = Vector2.ZERO
var _zoom_anchor_screen: Vector2 = Vector2.ZERO
var _zoom_anchor_start_zoom: float = 1.0
var _zoom_anchor_start_offset: Vector2 = Vector2.ZERO
var _zoom_anchor_target_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Handle smoothing through this script instead of Camera2D's built-in smoothing.
	position_smoothing_enabled = false
	
	target_position = position
	target_zoom = zoom


func _process(delta: float) -> void:
	# Smoothly interpolate zoom toward the requested value.
	if smoothing_zoom_enabled:
		var zoom_weight := 1.0 - exp(-smoothing_zoom_speed * delta)
		var current_zoom := lerpf(zoom.x, target_zoom.x, zoom_weight)
		zoom = Vector2.ONE * current_zoom
	else:
		zoom = target_zoom
	
	# Complete almost-finished zooms.
	if absf(zoom.x - target_zoom.x) <= ZOOM_COMPLETION_THRESHOLD:
		zoom = target_zoom
	
	# During anchored zooming, derive the current camera position from the anchor.
	if _zoom_anchor_active:
		var viewport_center := get_viewport().get_visible_rect().get_center()
		var anchor_position := _zoom_anchor_world + (viewport_center - _zoom_anchor_screen) / zoom.x
		var zoom_distance := target_zoom.x - _zoom_anchor_start_zoom
		var zoom_progress := 1.0
		if not is_zero_approx(zoom_distance):
			zoom_progress = clampf((zoom.x - _zoom_anchor_start_zoom) / zoom_distance, 0.0, 1.0)
		
		position = anchor_position + _zoom_anchor_start_offset.lerp(_zoom_anchor_target_offset, zoom_progress)
		
		if zoom == target_zoom:
			position = target_position
			_zoom_anchor_active = false
		return
	
	# Preserve existing exponential smoothing for normal camera movement.
	if smoothing_position_enabled:
		var position_weight := 1.0 - exp(-smoothing_position_speed * delta)
		position = position.lerp(target_position, position_weight)
	else:
		position = target_position
	
	# Finish positional smoothing when it becomes smaller than a screen pixel fraction.
	if position.distance_to(target_position) * zoom.x <= POSITION_COMPLETION_THRESHOLD_SCREEN:
		position = target_position


## Returns the requested camera position, including any pending camera animation.
func get_camera_position() -> Vector2:
	return target_position


## Sets the camera position and exits any currently active anchored zoom animation.
func set_camera_position(new_position: Vector2, instant: bool = false) -> void:
	_zoom_anchor_active = false
	target_position = new_position
	if instant or not smoothing_position_enabled:
		position = target_position


## Returns the requested zoom, including any pending camera animation.
func get_camera_zoom() -> Vector2:
	return target_zoom


## Sets the camera zoom and exits any currently active anchored zoom animation.
func set_camera_zoom(new_zoom: float, instant: bool = false) -> void:
	_zoom_anchor_active = false
	target_zoom = Vector2.ONE * maxf(new_zoom, 0.00001)
	if instant or not smoothing_zoom_enabled:
		zoom = target_zoom


## Updates position and zoom as one request, useful for fitting and viewport resizing.
func set_camera_state(new_position: Vector2, new_zoom: float, instant: bool = false) -> void:
	set_camera_position(new_position, instant)
	set_camera_zoom(new_zoom, instant)


## Animates zoom around a world-space point while smoothly applying the final ma-boundary correction.
## The provided [param final_position] must already respect camera manager visibility constraints.
func set_camera_zoom_anchored(new_zoom: float, world_anchor: Vector2, screen_anchor: Vector2, final_position: Vector2) -> void:
	# Set the requested zoom.
	new_zoom = maxf(new_zoom, 0.00001)
	
	# Get viewport center.
	var viewport_center := get_viewport().get_visible_rect().get_center()
	
	# Preserve the currently rendered position even if a previous animation was in progress.
	var start_anchor_position := world_anchor + (viewport_center - screen_anchor) / zoom.x
	_zoom_anchor_start_offset = position - start_anchor_position
	
	# Calculate how far the final camera is allowed to move from the exact mouse anchor.
	var final_anchor_position := world_anchor + (viewport_center - screen_anchor) / new_zoom
	_zoom_anchor_target_offset = final_position - final_anchor_position
	
	# Keep track of parameters set while the function was called.
	_zoom_anchor_world = world_anchor
	_zoom_anchor_screen = screen_anchor
	_zoom_anchor_start_zoom = zoom.x
	target_position = final_position
	target_zoom = Vector2.ONE * new_zoom
	_zoom_anchor_active = smoothing_zoom_enabled and not is_equal_approx(zoom.x, new_zoom)
	
	# Apply the final constrained state immediately if zoom smoothing id disabled.
	if not _zoom_anchor_active:
		zoom = target_zoom
		position = target_position
