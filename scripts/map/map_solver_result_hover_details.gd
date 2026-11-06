class_name MapSolverResultHoverDetails
extends PanelContainer


var _room_name_text: String = ""
var _weight_text: String = ""
var _priority_text: String = ""


@onready var room_name_label: ScrambleLabel = $MarginContainer/VBoxContainer/RoomNameMargin/RoomNameLabel
@onready var weight_value_label: ScrambleLabel = $MarginContainer/VBoxContainer/WeightRow/WeightValue
@onready var priority_value_label: ScrambleLabel = $MarginContainer/VBoxContainer/PriorityRow/PriorityValue


func _ready() -> void:
	_ignore_control_mouse(self)
	hide()
	modulate.a = 0.0


## Prepares content without activating the text animation for it yet.
## Uses all provided parameters to save them inside the internal fields to keep track of their state and initializes related labels to an empty state for them.
func prepare_details(room_name: String, weight: float, priority_group: int) -> void:
	# Save provided parameters in the internal fields.
	_room_name_text = room_name
	_weight_text = String.num(weight, 2).trim_suffix(".0")
	_priority_text = str(priority_group) if priority_group > 0 else "-"
	
	# Prepare label sizes and their initial placeholder texts.
	_prepare_label_size(room_name_label, _room_name_text)
	_prepare_label_size(weight_value_label, _weight_text)
	_prepare_label_size(priority_value_label, _priority_text)
	
	# Adjust the root panel to its combined minimum size.
	reset_size()


## Prepares the provided [param label] node size by placing the provided [param target_text] string inside of it and reserving enough space for it.
## Also initializes empty initial state for the labels by assigning placeholder text inside of it of the size of the target text at the end of the function.
func _prepare_label_size(label: ScrambleLabel, target_text: String) -> void:
	# Clear the previously reserved minimum size for the label.
	label.custom_minimum_size = Vector2.ZERO
	
	# Temporarily set the final text to measure its required size and get it's combined minimum size.
	label.set_text_immediate(target_text)
	var required_size: Vector2 = label.get_combined_minimum_size()
	
	# Get the label's actual font and configured font size.
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	
	# Find the widest character that could appear during scrambling.
	var max_character_width: float = 0.0
	for index: int in range(label.scramble_characters.length()):
		var character: String = label.scramble_characters.substr(index, 1)
		var character_width: float = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		max_character_width = maxf(max_character_width, character_width)
	
	# Reserve enough width for the final text and scrambled characters.
	var required_width: float = maxf(required_size.x, max_character_width * float(target_text.length()))
	label.custom_minimum_size = Vector2(ceilf(required_width), ceilf(required_size.y))
	
	# Initialize the label with an empty placeholder containing the same number of characters as the target text.
	var temp_text: String = ""
	for i: int in range(target_text.length()):
		temp_text += " "
	label.set_text_immediate(temp_text)


# Sets the dynamic values labels to populate them using the data saved in internal fields to trigger the animation change for them.
func animate_text() -> void:
	room_name_label.change_text(_room_name_text)
	weight_value_label.change_text(_weight_text)
	priority_value_label.change_text(_priority_text)


func _ignore_control_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child: Node in node.get_children():
		_ignore_control_mouse(child)
