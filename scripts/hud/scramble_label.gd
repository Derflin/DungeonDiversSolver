class_name ScrambleLabel
extends Label


var _animation_id: int = 0


@export_group("Scramble", "scramble_")
@export var scramble_enabled: bool = true
@export_range(0.0, 2.0, 0.01)
var scramble_duration: float = 0.35
@export_range(0.01, 0.2, 0.01)
var scramble_update_interval: float = 0.03
@export var scramble_characters: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?#$%"
@export var scramble_preserve_spaces: bool = true
@export var scramble_unchanged_chars: bool = false
@export var scramble_omitted_characters: String = "-"
@export var scramble_after_before_omitted_characters: String = " "


func change_text(new_text: String, animate: bool = true) -> void:
	_animation_id += 1
	var current_animation_id := _animation_id
	
	if new_text == text:
		return
	
	if not animate or not scramble_enabled or scramble_duration <= 0.0:
		text = new_text
		return
	
	var old_text := text
	var max_length: int = max(old_text.length(), new_text.length())
	
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
	
	var elapsed := 0.0
	
	while elapsed < scramble_duration:
		if current_animation_id != _animation_id:
			return
		
		var progress := elapsed / scramble_duration
		var displayed_text := ""
		
		for i in range(max_length):
			var old_character := _get_character_or_space(old_text, i)
			var new_character := _get_character_or_space(new_text, i)
			
			if (new_character in scramble_omitted_characters) or (not scramble_unchanged_chars and old_character == new_character):
				displayed_text += new_character
				continue
			
			var character_not_random_flag: bool = false
			if new_character in scramble_after_before_omitted_characters and (
				(i > 0 and _get_character_or_space(new_text, i - 1) in scramble_omitted_characters) 
				or (i < new_text.length() - 1 and _get_character_or_space(new_text, i + 1) in scramble_omitted_characters)
			):
				character_not_random_flag = true
			
			if progress < scramble_start_times[i]:
				displayed_text += old_character
			
			elif progress < resolve_times[i]:
				if scramble_preserve_spaces and old_character == " " and new_character == " ":
					displayed_text += " "
				elif character_not_random_flag:
					displayed_text += new_character
				else:
					displayed_text += _get_random_character()
				
			else:
				displayed_text += new_character
		
		text = displayed_text
		
		await get_tree().create_timer(scramble_update_interval).timeout
		
		elapsed += scramble_update_interval
	
	if current_animation_id == _animation_id:
		text = new_text


func cancel_animation() -> void:
	_animation_id += 1


func set_text_immediate(new_text: String) -> void:
	_animation_id += 1
	text = new_text


func _get_random_character() -> String:
	if scramble_characters.is_empty():
		return " "
	
	var index := randi_range(0, scramble_characters.length() - 1)
	
	return scramble_characters.substr(index, 1)


func _get_character_or_space(value: String, index: int) -> String:
	if index >= value.length():
		return " "
	
	return value.substr(index, 1)
