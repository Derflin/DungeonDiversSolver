class_name RoomSecretHelpAnimationRect
extends TextureRect


## Maximum number of frames advanced during a single processing tick.
const MAX_FRAMES_PER_TICK: int = 64


# Resource and named animation currently assigned to this control.
var _frames: SpriteFrames
var _animation_name: StringName = &"default"

# Playback position and time accumulated within the current frame.
var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _playing: bool = false

# Largest frame dimensions, used to reserve a stable illustration area.
var _natural_size: Vector2 = Vector2.ONE


#region Initialization

## Configures the image to preserve frame proportions without affecting its minimum size.
func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_process(false)

#endregion


#region Animation Configuration

## Assigns a SpriteFrames clip and restarts playback from its first frame.
func configure(frames: SpriteFrames, animation_name: StringName = &"default") -> void:
	# Stop processing while the old animation state is replaced.
	set_process(false)
	_playing = false
	_frames = frames
	_animation_name = animation_name
	_frame_index = 0
	_frame_elapsed = 0.0
	_natural_size = Vector2.ONE
	texture = null
	
	# Reject resources that cannot provide a first frame.
	if _frames == null or not _frames.has_animation(_animation_name):
		return
	if _frames.get_frame_count(_animation_name) == 0:
		return
	
	# Determine the largest frame size so playback cannot resize the panel.
	_natural_size = _calculate_natural_size()
	texture = _frames.get_frame_texture(_animation_name, 0)
	
	# A single frame clip or an animation with zero fps remains a static preview.
	_playing = (
		_frames.get_frame_count(_animation_name) > 1
		and _frames.get_animation_speed(_animation_name) > 0.0
	)
	set_process(_playing)


## Returns the maximum frame dimensions for measuring the illustrated content.
func get_natural_size() -> Vector2:
	return _natural_size


## Measures the largest texture dimensions in the selected SpriteFrames animation.
func _calculate_natural_size() -> Vector2:
	var largest_size: Vector2 = Vector2.ZERO
	
	for index: int in range(_frames.get_frame_count(_animation_name)):
		var frame_texture: Texture2D = _frames.get_frame_texture(_animation_name, index)
		if frame_texture == null:
			continue
		
		var frame_size: Vector2 = frame_texture.get_size()
		largest_size.x = maxf(largest_size.x, frame_size.x)
		largest_size.y = maxf(largest_size.y, frame_size.y)
	
	return Vector2(maxf(1.0, largest_size.x), maxf(1.0, largest_size.y))

#endregion


#region Animation Playback

## Advances playback using each frame's configured duration and animation fps.
func _process(delta: float) -> void:
	# Preserve the current frame while the panel or one of its ancestors is hidden.
	if not _playing or not is_visible_in_tree():
		return
	
	# Keep track of elapsed time.
	_frame_elapsed += delta
	
	# Advance multiple frames after a slow tick without allowing an endless loop.
	var frames_advanced: int = 0
	while _playing and frames_advanced < MAX_FRAMES_PER_TICK:
		var frame_seconds: float = _get_current_frame_seconds()
		if _frame_elapsed < frame_seconds:
			break
		
		_frame_elapsed -= frame_seconds
		_advance_frame()
		frames_advanced += 1
	
	# Discard excessive accumulated time after a large applciation stall.
	if frames_advanced == MAX_FRAMES_PER_TICK:
		_frame_elapsed = 0.0


## Returns the current frame duration in seconds, including relative frame timing.
func _get_current_frame_seconds() -> float:
	var animation_fps: float = _frames.get_animation_speed(_animation_name)
	var relative_duration: float = _frames.get_frame_duration(_animation_name, _frame_index)
	
	return maxf(0.001, relative_duration / maxf(0.001, animation_fps))


## Displays the next frame or completes playback when a non-looping clip ends.
func _advance_frame() -> void:
	var frame_count: int = _frames.get_frame_count(_animation_name)
	
	# Restart a looping clip or retain the last frame of a non-looping clip.
	if _frame_index + 1 >= frame_count:
		if _frames.get_animation_loop(_animation_name):
			_frame_index = 0
		else:
			_playing = false
			set_process(false)
			return
	else:
		_frame_index += 1
	
	# Change only the displayed frame, the reserved control dimensions stay fixed.
	texture = _frames.get_frame_texture(_animation_name, _frame_index)

#endregion
