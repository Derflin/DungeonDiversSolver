class_name ScrambleTextureRect
extends TextureRect


var _animation_id: int = 0


@export_group("Scramble", "scramble_")
## Enables/disables the scramble animation for the label.
@export var scramble_enabled: bool = true
## Overall duration in seconds of the scramble animation.
@export_range(0.0, 2.0, 0.01)
var scramble_duration: float = 0.35
## Interval in seconds between each scramble animation update.
@export_range(0.01, 0.2, 0.01)
var scramble_update_interval: float = 0.1
## Start time of scramble animation in animation progress percentage.
@export_range(0.0, 1.0, 0.01)
var scramble_start_time: float = 0.15
## Resolve time of scramble animation in animation progress percentage.
@export_range(0.0, 1.0, 0.01)
var scramble_resolve_time: float = 0.85
## List of textures that will be used for scrambling animation.
@export var scramble_textures: Array[Texture2D] = []


## Assign new texture to a texture rect texture along with providing scramble animation handling based on the set parameters.
func change_texture(new_texture: Texture2D, animate: bool = true) -> void:
	# Update current animation ID, which also causes previous animation to cancel
	_animation_id += 1
	var current_animation_id := _animation_id
	
	# Filter out processing if the new texture is the same as the one already set
	if new_texture == texture:
		return
	
	# If animation is disabled, then simply set the desired state
	if not animate or not scramble_enabled or scramble_duration <= 0.0:
		texture = new_texture
		return
	
	# Save the old texture
	var old_texture := texture
	
	# Start processing loop for animating the texture scramble
	var elapsed := 0.0
	while elapsed < scramble_duration:
		# Filter out processing if current animation was cancelled
		if current_animation_id != _animation_id:
			return
		
		# Calculate current progress percentage from the whole duration and how much time already passed
		var progress := elapsed / scramble_duration
		
		# Get current texture display based on the scramble progress
		if progress < scramble_start_time:
			texture = old_texture
			
		elif progress < scramble_resolve_time:
			texture = _get_random_texture(old_texture, new_texture)
			
		else:
			texture = new_texture
		
		# Wait for the next update interval
		await get_tree().create_timer(scramble_update_interval).timeout
		elapsed += scramble_update_interval
	
	# If the current animation wasn't cancelled, then assign final text as the new text that was passed
	if current_animation_id == _animation_id:
		texture = new_texture


## Changes internal animation id, causing existing animation to stop.
func cancel_animation() -> void:
	_animation_id += 1


## Immediately sets new texture and cancels all existing scramble animations for it.
func set_texture_immediate(new_texture: Texture2D) -> void:
	_animation_id += 1
	texture = new_texture


## Returns a random texture from the [member scramble_textures] parameter if it's not empty, otherwise it returns [param new_texture].
func _get_random_texture(old_texture: Texture2D, new_texture: Texture2D) -> Texture2D:
	# Return new_texture parameter if scramble_textures member is empty
	if scramble_textures.is_empty():
		return new_texture
	
	# Prepare available textures by filtering null textures and old/new textures
	var available_textures := scramble_textures.filter(
		func(candidate: Texture2D) -> bool:
			return candidate != null and candidate != old_texture and candidate != new_texture
	)
	
	# Return new_texture parameter if available_textures variable is empty
	if available_textures.is_empty():
		return new_texture
	
	# Return a random texture from the available_textures variable
	return available_textures.pick_random()
