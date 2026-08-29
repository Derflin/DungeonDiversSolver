class_name MapSolverDropdownOption
extends Button


signal selected(option_id: int)


var option_id: int = -1


func setup(id: int, label: String, texture: Texture2D = null, _is_disabled: bool = false) -> void:
	# Initialize scene parameters
	option_id = id
	text = label
	icon = texture
	disabled = _is_disabled


func _pressed() -> void:
	selected.emit(option_id)
