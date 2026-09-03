class_name MapSolverResultCursor
extends Node2D


const CORNERS_ANIMATION_NAME := &"default"


@onready var value_label: ScrambleLabel = $ValueLabel
@onready var corners_sprite: Sprite2D = $Corners
@onready var corners_animation_player: AnimationPlayer = $Corners/AnimationPlayer


@export_group("Value Label", "value_label_")
## Used as maximum value that might be assigned to font size while trying to fit value label text into it's restricted size.
@export var value_label_font_size_max: int = 16
## Used as minimum value that might be assigned to font size while trying to fit value label text into it's restricted size.
@export var value_label_font_size_min: int = 4


func _ready() -> void:
	_initialize_corners_animation_player()


## Initializes corners sprite animation player with correct animation and it's state.
func _initialize_corners_animation_player() -> void:
	corners_animation_player.play(CORNERS_ANIMATION_NAME)
	
	var animation_length := corners_animation_player.current_animation_length
	var global_time := Time.get_ticks_msec() / 1000.0
	var animation_time := fmod(global_time, animation_length)
	
	corners_animation_player.seek(animation_time, true)


## Set value label text to provided [param value_text] value and adjusts the font size to try and fit the text inside the value label restricted size.
func set_value_text(value_text: String) -> void:
	value_label.change_text(value_text)
	
	_fit_value_label_text(value_text)


## Adjust the font size of the value label, so that it would fit into it's restricted size.
## Uses [member value_label_font_size_min] and [member value_label_font_size_max] exported class parameters as range of tested font sizes, where it will try to set the biggest possible font size that would fit.
func _fit_value_label_text(value_text: String) -> void:
	# Get value label theme font
	var font := value_label.get_theme_font("font")
	
	# Try to find the highiest possible font size from the range, that would fit inside value label restricted size
	for font_size in range(value_label_font_size_max, value_label_font_size_min - 1, -1):
		var text_size := font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		
		# If text with a given font_size fits, then assign it
		if text_size.x <= value_label.size.x and text_size.y <= value_label.size.y:
			value_label.add_theme_font_size_override("font_size", font_size)
			return
	
	# If none of the font sizes in range would fit, then set the smallest one as default result
	value_label.add_theme_font_size_override("font_size", value_label_font_size_min)
