extends Camera2D


@export_group("Smoothing Parameters", "smoothing_")
@export var smoothing_position_enabled: bool = true
@export_range(0.1, 30.0, 0.1)
var smoothing_position_speed: float = 12.0
@export var smoothing_zoom_enabled: bool = true
@export_range(0.1, 30.0, 0.1)
var smoothing_zoom_speed: float = 10.0


var _zoom_anchor_active: bool = false
var _zoom_anchor_world: Vector2 = Vector2.ZERO
var _zoom_anchor_screen: Vector2 = Vector2.ZERO


var target_position: Vector2:
	set(value):
		if not smoothing_position_enabled and not _zoom_anchor_active:
			position = value
		target_position = value
		
var target_zoom: Vector2:
	set(value):
		if not smoothing_zoom_enabled:
			zoom = value
		target_zoom = value


func _ready() -> void:
	position_smoothing_enabled = false
	
	target_position = position
	target_zoom = zoom


func _process(delta: float) -> void:
	# Smoothly interpolate the camera zoom.
	if smoothing_zoom_enabled:
		var zoom_weight := 1.0 - exp(-smoothing_zoom_speed * delta)
		var new_zoom := lerpf(zoom.x, target_zoom.x, zoom_weight)
		zoom = Vector2.ONE * new_zoom
	
	# Calculate position from the current zoom during anchored zooming.
	if _zoom_anchor_active:
		# Calculate position.
		var viewport_center := get_viewport().get_visible_rect().get_center()
		position = _zoom_anchor_world + (viewport_center - _zoom_anchor_screen) / zoom.x
		
		# Finish the animation once sufficiently close to the end.
		if absf(zoom.x - target_zoom.x) < 0.0001:
			zoom = target_zoom
			position = target_position
			_zoom_anchor_active = false
		
	# Otherwise preserve normal camera position smoothing.
	elif smoothing_position_enabled:
		var position_weight := 1.0 - exp(-smoothing_position_speed * delta)
		position = position.lerp(target_position, position_weight)


func get_camera_position() -> Vector2:
	if smoothing_position_enabled or _zoom_anchor_active:
		return target_position
	
	return position


func set_camera_position(_position: Vector2, instant: bool = false) -> void:
	_zoom_anchor_active = false
	
	var aligned_position = _align_position_to_screen_pixels(_position, target_zoom)
	
	target_position = aligned_position
	if instant:
		position = aligned_position


func get_camera_zoom() -> Vector2:
	if smoothing_zoom_enabled:
		return target_zoom
	
	return zoom


func set_camera_zoom(_zoom: float, instant: bool = false) -> void:
	_zoom_anchor_active = false
	
	target_zoom = Vector2.ONE * _zoom
	target_position = _align_position_to_screen_pixels(target_position, target_zoom)
	if instant:
		zoom = Vector2.ONE * _zoom
		position = target_position


func set_camera_zoom_anchored(new_zoom: float, world_anchor: Vector2, screen_anchor: Vector2) -> void:
	# Remember the point that should stay fixed during zooming.
	_zoom_anchor_world = world_anchor
	_zoom_anchor_screen = screen_anchor
	_zoom_anchor_active = smoothing_zoom_enabled
	
	# Set the requested zoom.
	target_zoom = Vector2.ONE * new_zoom
	
	# Calculate the final camera position for that zoom.
	var viewport_center := get_viewport().get_visible_rect().get_center()
	var final_position := world_anchor + (viewport_center - screen_anchor) / new_zoom
	
	# Preserve the existing pixel alignment behaviour.
	target_position = _align_position_to_screen_pixels(final_position, target_zoom)
	
	# Apply changes immediately if zoom smoothing is disabled.
	if not smoothing_zoom_enabled:
		zoom = target_zoom
		position = target_position


func _align_position_to_screen_pixels(world_position: Vector2, zoom_value: Vector2) -> Vector2:
	var viewport_center = get_viewport().get_visible_rect().size * 0.5
	
	var canvas_translation = viewport_center - world_position * zoom_value
	
	canvas_translation = canvas_translation.round()
	
	return (viewport_center - canvas_translation) / zoom_value
