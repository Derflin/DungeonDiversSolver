class_name MapParameterEntry
extends HBoxContainer


enum ParameterType {
	NONE = -1,
	MAP_GRID_SIZE = 10,
	SECRET_TYPE_COUNT_MAX = 20,
}


var parameter_type: ParameterType = ParameterType.NONE
var secret_type_kind: RoomSecretType.Kind = RoomSecretType.Kind.NONE
var map_grid_size: Vector2i = Vector2i(0, 0)
var secret_type_value_current: int = 0
var secret_type_value_max: int = 0


@onready var entry_icon := $IconContainer/Icon
@onready var entry_count_label := $CountLabel
@onready var entry_description_label := $DescriptionLabel
@onready var entry_value_editor := $ValueEditor


@export_group("Label Parameters", "label_")
@export var label_default_color := Color.WHITE
@export var label_valid_color := Color.LIME_GREEN
@export var label_invalid_color := Color.RED


func initialize_map_grid_size() -> void:
	# Initialize parameters
	parameter_type = ParameterType.MAP_GRID_SIZE
	
	# Get initial state of variables that will be managed by this parameter entry scene
	_get_map_grid_size()
	
	# Connect signals related to the parameter that will be managed by this parameter entry scene
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)
	
	# Set initialized data into display nodes
	display_icon()
	refresh_display_texts()


func initialize_secret_type_count_max(_secret_type_kind: RoomSecretType.Kind) -> void:
	# Initialize parameters
	parameter_type = ParameterType.SECRET_TYPE_COUNT_MAX
	secret_type_kind = _secret_type_kind
	
	# Get initial state of variables that will be managed by this parameter entry scene
	_get_secret_type_count_current()
	_get_secret_type_count_max()
	
	# Connect signals related to the parameter that will be managed by this parameter entry scene
	GameState.map_secrets_count_current_changed.connect(_on_game_state_map_secrets_count_current_changed)
	GameSettings.map_secrets_count_max_changed.connect(_on_game_settings_map_secrets_count_max_changed)
	
	# Set initialized data into display nodes
	display_icon()
	refresh_display_texts()


func _get_map_grid_size() -> void:
	# Check if appropriate parameter entry type
	if parameter_type != ParameterType.MAP_GRID_SIZE:
		return
	
	# Gather map_grid_size from the game settings
	map_grid_size = GameSettings.map_grid_size


func _get_secret_type_count_current() -> void:
	# Check if appropriate parameter entry type
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Gather secret_type_value_current from the game state
	secret_type_value_current = GameState.map_secrets_count_current[secret_type_kind]


func _get_secret_type_count_max() -> void:
	# Check if appropriate parameter entry type
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Gather secret_type_value_max from the game settings
	secret_type_value_max = GameSettings.map_secrets_count_max[secret_type_kind]


func display_icon() -> void:
	# Prepare and assign icon texture depending on the parameter entry type
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		entry_icon.texture = GameSettings.map_grid_size_icon
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		entry_icon.texture = GameData.room_secret_types.get_type(secret_type_kind).get_static_texture()


func refresh_display_texts() -> void:
	_update_count_label()
	_update_description_label()
	_update_value_editor()


func _update_count_label() -> void:
	# Prepare and assign label parameters depending on the parameter entry type
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		var label_text := "%dx%d" % [map_grid_size.x, map_grid_size.y]
		var label_color := label_default_color
		
		entry_count_label.text = label_text
		entry_count_label.label_settings.font_color = label_color
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		var label_text := "%d/%d" % [secret_type_value_current, secret_type_value_max]
		var label_color := label_default_color
		label_color = label_invalid_color if secret_type_value_current > secret_type_value_max else label_color
		label_color = label_valid_color if secret_type_value_max != 0 and secret_type_value_current == secret_type_value_max else label_color
		
		entry_count_label.text = label_text
		entry_count_label.label_settings.font_color = label_color


func _update_description_label() -> void:
	# Prepare and assign label parameters depending on the parameter entry type
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		var label_text := "Grid Size"
		var label_color := label_default_color
		
		entry_description_label.text = label_text
		entry_description_label.label_settings.font_color = label_color
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		var label_text := ""
		label_text += GameData.room_secret_types.get_type(secret_type_kind).display_name
		var label_color := label_default_color
		
		entry_description_label.text = label_text
		entry_description_label.label_settings.font_color = label_color


func _update_value_editor() -> void:
	# Prepare and assign spinbox value editor parameters depending on the parameter entry type
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		entry_value_editor.value = map_grid_size.x
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		entry_value_editor.value = secret_type_value_max


func _on_game_settings_map_grid_size_parameter_changed() -> void:
	# Check if appropriate parameter entry type
	if parameter_type != ParameterType.MAP_GRID_SIZE:
		return
	
	# Assign value
	map_grid_size = GameSettings.map_grid_size
	
	# Set collected data into display nodes
	refresh_display_texts()


func _on_game_state_map_secrets_count_current_changed(kind: RoomSecretType.Kind, value: int) -> void:
	# Check if appropriate parameter entry type
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Check if appropriate signal kind parameter type
	if kind != secret_type_kind:
		return
	
	# Assign value
	secret_type_value_current = value
	
	# Set collected data into display nodes
	refresh_display_texts()


func _on_game_settings_map_secrets_count_max_changed(kind: RoomSecretType.Kind, value: int) -> void:
	# Check if appropriate parameter entry type
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Check if appropriate signal kind parameter type
	if kind != secret_type_kind:
		return
	
	# Assign value
	secret_type_value_max = value
	
	# Set collected data into display nodes
	refresh_display_texts()


func _on_value_editor_value_changed(value: float) -> void:
	# Gather value from spinbox value editor and save it game_settings
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		GameSettings.set_map_grid_size(entry_value_editor.value)
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		GameSettings.set_map_secrets_count_max(secret_type_kind, entry_value_editor.value)
	
	# Manually release focus from the spinbox editor fields
	entry_value_editor.release_focus()
	entry_value_editor.get_line_edit().release_focus()
