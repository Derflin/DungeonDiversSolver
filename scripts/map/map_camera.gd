extends Camera2D


@export_group("Smoothing Parameters", "smoothing_")
@export var smoothing_position_enabled: bool = true
@export_range(0.1, 30.0, 0.1)
var smoothing_position_speed: float = 12.0
@export var smoothing_zoom_enabled: bool = true
@export_range(0.1, 30.0, 0.1)
var smoothing_zoom_speed: float = 10.0


var target_position: Vector2:
	set(value):
		if not smoothing_position_enabled:
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
	if smoothing_position_enabled:
		var position_weight = 1.0 - exp(-smoothing_position_speed * delta)
		
		position = position.lerp(
			target_position,
			position_weight,
		)
	
	if smoothing_zoom_enabled:
		var zoom_weight = 1.0 - exp(-smoothing_zoom_speed * delta)
		
		var new_zoom = lerpf(
			zoom.x,
			target_zoom.x,
			zoom_weight,
		)
		
		zoom = Vector2.ONE * new_zoom


func get_camera_position() -> Vector2:
	if smoothing_position_enabled:
		return target_position
	
	return position


func set_camera_position(_position: Vector2, instant: bool = false) -> void:
	var aligned_position = _align_position_to_screen_pixels(_position, target_zoom)
	
	target_position = aligned_position
	if instant:
		position = aligned_position


func get_camera_zoom() -> Vector2:
	if smoothing_zoom_enabled:
		return target_zoom
	
	return zoom


func set_camera_zoom(_zoom: float, instant: bool = false) -> void:
	target_zoom = Vector2.ONE * _zoom
	target_position = _align_position_to_screen_pixels(target_position, target_zoom)
	if instant:
		zoom = Vector2.ONE * _zoom
		position = target_position


func _align_position_to_screen_pixels(world_position: Vector2, zoom_value: Vector2) -> Vector2:
	var viewport_center = get_viewport().get_visible_rect().size * 0.5
	
	var canvas_translation = viewport_center - world_position * zoom_value
	
	canvas_translation = canvas_translation.round()
	
	return (viewport_center - canvas_translation) / zoom_value
