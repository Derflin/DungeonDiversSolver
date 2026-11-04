class_name MapSolverResultHoverDetails
extends Control


var _room_name_text: String = ""
var _weight_text: String = ""
var _priority_text: String = ""


@onready var room_name_label: ScrambleLabel = $PanelContainer/MarginContainer/VBoxContainer/RoomNameLabel
@onready var weight_value_label: ScrambleLabel = $PanelContainer/MarginContainer/VBoxContainer/WeightRow/WeightValue
@onready var priority_value_label: ScrambleLabel = $PanelContainer/MarginContainer/VBoxContainer/PriorityRow/PriorityValue


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
	
	# Initializes empty state for the labels for the provided details in parameters.
	room_name_label.set_text_immediate("")
	weight_value_label.set_text_immediate("")
	priority_value_label.set_text_immediate("")


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
