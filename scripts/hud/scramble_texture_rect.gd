class_name ScrambleTextureRect
extends TextureRect


var _animation_id: int = 0
var _shader_material: ShaderMaterial


@export_group("Scramble", "scramble_")
## Enables/disables the scramble animation for the texture rect.
@export var scramble_enabled: bool = true
## Overall duration in seconds of the scramble animation.
@export_range(0.0, 2.0, 0.01)
var scramble_duration: float = 0.35
## Interval in seconds between each scramble animation update.
@export_range(0.01, 0.2, 0.01)
var scramble_update_interval: float = 0.05
## Start time of scramble animation in animation progress percentage.
@export_range(0.0, 1.0, 0.01)
var scramble_start_time: float = 0.15
## Resolve time of scramble animation in animation progress percentage.
@export_range(0.0, 1.0, 0.01)
var scramble_resolve_time: float = 0.85
## List of textures that will be used for scrambling animation.
@export var scramble_textures: Array[Texture2D] = []

@export_group("Scramble Opacity", "scramble_opacity_")
## Enables/disables the opacity during scramble animation for the texture rect.
@export var scramble_opacity_enabled: bool = true
## Opacity minimum value for selecting a random opacity for a scrambled texture during scramble animation.
@export_range(0.0, 1.0, 0.01)
var scramble_opacity_min_value: float = 0.4
## Opacity maximum value for selecting a random opacity for a scrambled texture during scramble animation.
@export_range(0.0, 1.0, 0.01)
var scramble_opacity_max_value: float = 0.6

@export_group("Scramble Noise", "scramble_noise_")
## Enables/disables procedural noise over the scrambled texture.
@export var scramble_noise_enabled: bool = true
## Minimum amount of the icon covered by the noise.
@export_range(0.0, 1.0, 0.01)
var scramble_noise_min_amount: float = 0.25
## Maximum amount of the icon covered by the noise.
@export_range(0.0, 1.0, 0.01)
var scramble_noise_max_amount: float = 0.75
## Size of individual noise blocks in texture pixels.
@export_range(1.0, 8.0, 1.0)
var scramble_noise_block_size: float = 4.0
## Color used for generated noise pixels.
@export var scramble_noise_color: Color = Color.BLACK


func _ready() -> void:
	# Initialize shader material used for scramble noise
	_initialize_shader_material()


## Initializes shader material used for scramble noise overlay on the texture by assigning it from the CavnasItem node material property and assigning it scramble noise parameters.
func _initialize_shader_material() -> void:
	# Filter out processing if the scramble noise is disabled
	if not scramble_noise_enabled:
		return
	
	# Get and assign shader material from default material parameter from the CanvasItem node
	_shader_material = material as ShaderMaterial
	if _shader_material == null:
		return
	
	# Assign scramble noise parameters to the shader material
	_shader_material.set_shader_parameter("block_size", scramble_noise_block_size)
	_shader_material.set_shader_parameter("noise_color", scramble_noise_color)
	_reset_noise()


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
		
		# Get current texture display based on the scramble progress and the scramble opacity parameters
		if progress < scramble_start_time:
			texture = old_texture
			
		elif progress < scramble_resolve_time:
			texture = _get_random_texture(old_texture, new_texture)
			
		else:
			texture = new_texture
		
		# Calculate current scramble opacity for the label based on the scramble opacity parameters
		if scramble_opacity_enabled:
			if progress < scramble_start_time:
				modulate.a = 1.0
			elif progress < scramble_resolve_time:
				modulate.a = randf_range(scramble_opacity_min_value, scramble_opacity_max_value)
			else:
				modulate.a = 1.0
		
		# Update procedural noise overlay
		_update_noise(progress)
		
		# Wait for the next update interval
		await get_tree().create_timer(scramble_update_interval).timeout
		elapsed += scramble_update_interval
	
	# If the current animation wasn't cancelled, then assign final text as the new text that was passed and reset opacity to base value
	if current_animation_id == _animation_id:
		texture = new_texture
		
		# Reset opacity
		if scramble_opacity_enabled:
			modulate.a = 1.0
		
		# Reset procedural noise overlay
		_reset_noise()


## Changes internal animation id, causing existing animation to stop.
func cancel_animation() -> void:
	_animation_id += 1
	
	# Reset opacity
	if scramble_opacity_enabled:
		modulate.a = 1.0
	
	# Reset procedural noise overlay
	_reset_noise()


## Immediately sets new texture and cancels all existing scramble animations for it.
func set_texture_immediate(new_texture: Texture2D) -> void:
	_animation_id += 1
	texture = new_texture
	
	# Reset opacity
	if scramble_opacity_enabled:
		modulate.a = 1.0
	
	# Reset procedural noise overlay
	_reset_noise()


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


## Updates scramble noise shader material based on the progress percantage of the scramble animation.
func _update_noise(progress: float) -> void:
	# Filter out processing if the scramble noise is disabled or if the shader material isn't assigned
	if not scramble_noise_enabled or _shader_material == null:
		return
	
	# Calculate noise amount based on the progress percentage and the scramble animation parameters
	var noise_amount := 0.0
	if progress >= scramble_start_time and progress < scramble_resolve_time:
		var scramble_progress := inverse_lerp(scramble_start_time, scramble_resolve_time, progress)
		noise_amount = lerpf(scramble_noise_max_amount, scramble_noise_min_amount, scramble_progress)
	
	# Assign calculated scramble noise variables to the shader material
	_shader_material.set_shader_parameter("noise_amount", noise_amount)
	# Every animation update gets a different procedural noise pattern.
	_shader_material.set_shader_parameter("noise_seed", randf_range(0.0, 10000.0))


## Updates scramble noise shader material by resetting it's noise state parameters to default values.
func _reset_noise() -> void:
	# Filter out processing if the scramble noise is disabled or if the shader material isn't assigned
	if not scramble_noise_enabled or _shader_material == null:
		return
	
	# Reset shader material parameters related to the scramble noise
	_shader_material.set_shader_parameter("noise_amount", 0.0)
	_shader_material.set_shader_parameter("noise_seed", 0.0)
