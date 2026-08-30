class_name ScrambleLabel
extends Label


var _animation_id: int = 0


@export_group("Scramble", "scramble_")
## Enables/disables the scramble animation for the label.
@export var scramble_enabled: bool = true
## Overall duration in seconds of the scramble animation.
@export_range(0.0, 2.0, 0.01)
var scramble_duration: float = 0.35
## Interval in seconds between each scramble animation update.
@export_range(0.01, 0.2, 0.01)
var scramble_update_interval: float = 0.03
## List of characters that will be used for displaying random characters during a scramble animation.
@export var scramble_characters: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?#$%"
## Causes scramble animation to not scramble through unchanged empty space characters if they keep the same index and character. If [member scramble_unchanged_chars] enabled, then this parameter doesn't affect anything.
@export var scramble_preserve_spaces: bool = true
## Causes scramble animation to not scramble through unchanged characters if they keep the same index and character.
@export var scramble_unchanged_chars: bool = false


## Assign new text to a label text along with providing scramble animation handling based on the set parameters.
func change_text(new_text: String, animate: bool = true) -> void:
	# Update current animation ID, which also causes previous animation to cancel
	_animation_id += 1
	var current_animation_id := _animation_id
	
	# Filter out processing if the new text is the same as the one already set
	if new_text == text:
		return
	
	# If animation is disabled, then simply set the desired state
	if not animate or not scramble_enabled or scramble_duration <= 0.0:
		text = new_text
		return
	
	# Save the old text and calculate max lengths based on it and the new text
	var old_text := text
	var max_length: int = max(old_text.length(), new_text.length())
	
	# Generate overall percentage times when the scramble should start and when it should resolve for each given character in the new text
	var scramble_start_times: Array[float] = []
	var resolve_times: Array[float] = []
	scramble_start_times.resize(max_length)
	resolve_times.resize(max_length)
	for i in range(max_length):
		if i >= old_text.length():
			scramble_start_times[i] = randf_range(0.20, 0.45)
		else:
			scramble_start_times[i] = randf_range(0.05, 0.30)
		
		resolve_times[i] = randf_range(0.55, 0.95)
	
	# Start processing loop for animating the character scramble
	var elapsed := 0.0
	while elapsed < scramble_duration:
		# Filter out processing if current animation was cancelled
		if current_animation_id != _animation_id:
			return
		
		# Calculate current progress percentage from the whole duration and how much time already passed
		var progress := elapsed / scramble_duration
		
		# Prepare currently displayed text based on the scramble animation state
		var displayed_text := ""
		for i in range(max_length):
			# Get old and new character in a given index
			var old_character := _get_character_or_empty(old_text, i)
			var new_character := _get_character_or_empty(new_text, i)
			
			# If scramble unchanged chars is disabled and both the characters are the same, then simply don't animate scramble for them
			if not scramble_unchanged_chars and old_character == new_character:
				displayed_text += new_character
				continue
			
			# Get current character display based on the scramble progress
			if progress < scramble_start_times[i]:
				displayed_text += old_character
				
			elif progress < resolve_times[i]:
				# If scramble preserve spaces is enabled and both the characters are the same empty space char, then simply use it instead of generating random character for them
				if scramble_preserve_spaces and old_character == " " and new_character == " ":
					displayed_text += " "
				else:
					displayed_text += _get_random_character()
				
			else:
				displayed_text += new_character
		
		# Assign prepared display text to the label text parameter
		text = displayed_text
		
		# Wait for the next update interval
		await get_tree().create_timer(scramble_update_interval).timeout
		elapsed += scramble_update_interval
	
	# If the current animation wasn't cancelled, then assign final text as the new text that was passed
	if current_animation_id == _animation_id:
		text = new_text


## Changes internal animation id, causing existing animation to stop.
func cancel_animation() -> void:
	_animation_id += 1


## Immediately sets new text and cancels all existing scramble animations for it.
func set_text_immediate(new_text: String) -> void:
	_animation_id += 1
	text = new_text


## Returns a random character from the [member scramble_characters] parameter if it's not empty, otherwise it returns empty space char.
func _get_random_character() -> String:
	if scramble_characters.is_empty():
		return " "
	
	var index := randi_range(0, scramble_characters.length() - 1)
	
	return scramble_characters.substr(index, 1)


## Returns a character from a given value under a given index if it exists, otherwise returns an empty char.
func _get_character_or_empty(value: String, index: int) -> String:
	if index >= value.length() or index < 0:
		return ""
	
	return value.substr(index, 1)
