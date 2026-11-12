class_name MapParameterEntry
extends HBoxContainer


## Emitted when the pointer enters a secret room's icon or title.
signal help_preview_requested(entry: MapParameterEntry)
## Emitted when the icon or title is clicked or tapped.
signal help_activation_requested(entry: MapParameterEntry)


enum ParameterType {
	NONE = -1,
	MAP_GRID_SIZE = 10,
	SECRET_TYPE_COUNT_MAX = 20,
}


@export_group("Label Parameters", "label_")
@export var label_default_color := Color.WHITE
@export var label_valid_color := Color.LIME_GREEN
@export var label_invalid_color := Color.RED

@export_group("Help Highlight", "help_")
## Border color displayed while the pointer is over a room with available help.
@export var help_hover_border_color: Color = Color(0.72, 0.64, 0.50, 0.8)
## Border color displayed while the room's help description is pinned.
@export var help_pinned_border_color: Color = Color(0.98, 0.81, 0.45, 1.0)
## Width of the outline drawn around interactive secret room entries.
@export_range(0.0, 8.0, 0.5) var help_border_width: float = 1.0


var parameter_type: ParameterType = ParameterType.NONE
var secret_type_kind: RoomSecretType.Kind = RoomSecretType.Kind.NONE
var map_grid_size: Vector2i = Vector2i(0, 0)
var secret_type_value_current: int = 0
var secret_type_value_max: int = 0

# Visual state of the row while help is being previewed or selected.
var _help_row_hovered: bool = false
var _help_selected: bool = false
var _help_pinned: bool = false


@onready var entry_icon_container: Control = $IconContainer
@onready var entry_icon := $IconContainer/Icon
@onready var entry_count_label := $CountLabel
@onready var entry_description_label := $DescriptionLabel
@onready var entry_value_editor := $ValueEditor


#region Initialization

func _ready() -> void:
	# Allow the icon and title to receive input without intercepting the value editor.
	mouse_filter = Control.MOUSE_FILTER_PASS
	entry_icon_container.mouse_filter = Control.MOUSE_FILTER_PASS
	entry_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_count_label.mouse_filter = Control.MOUSE_FILTER_PASS
	entry_description_label.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Trigger the help panel only from the room icon and description label.
	entry_icon_container.mouse_entered.connect(_on_help_trigger_entered)
	entry_description_label.mouse_entered.connect(_on_help_trigger_entered)
	entry_icon_container.gui_input.connect(_on_help_trigger_gui_input)
	entry_description_label.gui_input.connect(_on_help_trigger_gui_input)
	
	# Keep a visual highlight while the pointer remains anywhere over the row.
	mouse_entered.connect(_on_help_row_entered)
	mouse_exited.connect(_on_help_row_exited)


func initialize_map_grid_size() -> void:
	# Initialize parameters.
	parameter_type = ParameterType.MAP_GRID_SIZE
	
	# Get initial state of variables that will be managed by this parameter entry scene.
	_get_map_grid_size()
	
	# Connect signals related to the parameter that will be managed by this parameter entry scene.
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)
	
	# Set initialized data into display nodes.
	display_icon()
	refresh_display_texts()


func initialize_secret_type_count_max(_secret_type_kind: RoomSecretType.Kind) -> void:
	# Initialize parameters.
	parameter_type = ParameterType.SECRET_TYPE_COUNT_MAX
	secret_type_kind = _secret_type_kind
	
	# Get initial state of variables that will be managed by this parameter entry scene.
	_get_secret_type_count_current()
	_get_secret_type_count_max()
	
	# Connect signals related to the parameter that will be managed by this parameter entry scene.
	GameState.map_secrets_count_current_changed.connect(_on_game_state_map_secrets_count_current_changed)
	GameSettings.map_secrets_count_max_changed.connect(_on_game_settings_map_secrets_count_max_changed)
	
	# Set initialized data into display nodes.
	display_icon()
	refresh_display_texts()

#endregion


#region Help Interaction

## Returns whether this entry represents a secret room with displayable help.
func _has_help() -> bool:
	# Filter out processing if the parameter type isn't for a secret type or the assigned secret type is none.
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == RoomSecretType.Kind.NONE:
		return false
	
	# Delegate help content validation to the owning room resource.
	var room: RoomSecretType = GameData.room_secret_types.get_type(secret_type_kind)
	return room != null and room.has_help_content()


## Requests a temporary preview when the pointer enters the room icon or title.
func _on_help_trigger_entered() -> void:
	# Emit help preview requested signal if there is any help content for the current entry.
	if _has_help():
		help_preview_requested.emit(self)


## Handles click and touch activation of the room help panel.
func _on_help_trigger_gui_input(event: InputEvent) -> void:
	# Filter out processing if there isn't any help content for the current entry.
	if not _has_help():
		return
	
	# Primary mouse presses activate or toggle the current room's description.
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			help_activation_requested.emit(self)
			
	# Direct touch presses activate help when a synthetic mouse event is not used.
	elif event is InputEventScreenTouch:
		# Avoid double activation when godot synthesizes a mouse event from a touch.
		if event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION and not Input.emulate_mouse_from_touch:
			help_activation_requested.emit(self)


## Updates the row's temporary pointer-hover highlight.
func _on_help_row_entered() -> void:
	_help_row_hovered = true
	queue_redraw()


## Removes the temporary highlight after the pointer leaves the row.
func _on_help_row_exited() -> void:
	_help_row_hovered = false
	queue_redraw()


## Updates the active and pinned selection highlight for this entry.
func set_help_selected(selected: bool, pinned: bool = false) -> void:
	_help_selected = selected
	_help_pinned = pinned
	queue_redraw()


## Draws the configurable highlight around interactive secret-room rows.
func _draw() -> void:
	# Filter out processing if there isn't any help content for the current entry.
	if not _has_help():
		return
	
	# Filter out processing if entry isn't selected or hovered.
	if not _help_selected and not _help_row_hovered:
		return
	
	# A pinned selection uses a distinct outline from temporary hover feedback.
	var border_color: Color = help_pinned_border_color if _help_pinned else help_hover_border_color
	
	# Draw a highlight rectangle.
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, help_border_width)


## Checks whether a viewport position remains inside a control after clipping.
func _contains_visible_viewport_point(target: Control, viewport_position: Vector2) -> bool:
	# Filter out processing if the target node isn't valid or it's not visible.
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return false
	
	# Begin with the control's visible rectangle in the shared HUD canvas.
	var visible_rect: Rect2 = target.get_global_rect()
	var ancestor: Node = target.get_parent()
	
	# Controls clipped by an ancestor cannot receive input outside that area.
	while ancestor != null:
		if ancestor is Control:
			var parent_control: Control = ancestor
			if parent_control.clip_contents:
				visible_rect = visible_rect.intersection(parent_control.get_global_rect())
				if not visible_rect.has_area():
					return false
		ancestor = ancestor.get_parent()
	
	return visible_rect.has_point(viewport_position)


## Checks whether the pointer is inside the visible part of this row.
func contains_row_viewport_point(viewport_position: Vector2) -> bool:
	return _contains_visible_viewport_point(self, viewport_position)


## Checks whether the pointer is inside the visible room icon or title.
func contains_help_trigger_viewport_point(viewport_position: Vector2) -> bool:
	# Filter out processing and return false if the current entry doesn't contain anything to be displayed in help.
	if not _has_help():
		return false
	
	# Count labels and vlaue editors don't activate the description panel.
	for trigger: Control in [entry_icon_container, entry_description_label]:
		if _contains_visible_viewport_point(trigger, viewport_position):
			return true
	
	# Otherwise return false.
	return false

#endregion


#region Parameter Data

func _get_map_grid_size() -> void:
	# Check if appropriate parameter entry type.
	if parameter_type != ParameterType.MAP_GRID_SIZE:
		return
	
	# Gather map_grid_size from the game settings.
	map_grid_size = GameSettings.map_grid_size


func _get_secret_type_count_current() -> void:
	# Check if appropriate parameter entry type.
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Gather secret_type_value_current from the game state.
	secret_type_value_current = GameState.map_secrets_count_current[secret_type_kind]


func _get_secret_type_count_max() -> void:
	# Check if appropriate parameter entry type.
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Gather secret_type_value_max from the game settings.
	secret_type_value_max = GameSettings.map_secrets_count_max[secret_type_kind]

#endregion


#region Parameter Display

func display_icon() -> void:
	# Prepare and assign icon texture depending on the parameter entry type.
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		entry_icon.texture = GameSettings.map_grid_size_icon
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		entry_icon.texture = GameData.room_secret_types.get_type(secret_type_kind).get_static_texture()


func refresh_display_texts() -> void:
	_update_count_label()
	_update_description_label()
	_update_value_editor()


func _update_count_label() -> void:
	# Prepare and assign label parameters depending on the parameter entry type.
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
	# Prepare and assign label parameters depending on the parameter entry type.
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
	# Prepare and assign spinbox value editor parameters depending on the parameter entry type.
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		entry_value_editor.value = map_grid_size.x
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		entry_value_editor.value = secret_type_value_max

#endregion


#region Parameter Change Signals

func _on_game_settings_map_grid_size_parameter_changed() -> void:
	# Check if appropriate parameter entry type.
	if parameter_type != ParameterType.MAP_GRID_SIZE:
		return
	
	# Assign value.
	map_grid_size = GameSettings.map_grid_size
	
	# Set collected data into display nodes.
	refresh_display_texts()


func _on_game_state_map_secrets_count_current_changed(kind: RoomSecretType.Kind, value: int) -> void:
	# Check if appropriate parameter entry type.
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Check if appropriate signal kind parameter type.
	if kind != secret_type_kind:
		return
	
	# Assign value.
	secret_type_value_current = value
	
	# Set collected data into display nodes.
	refresh_display_texts()


func _on_game_settings_map_secrets_count_max_changed(kind: RoomSecretType.Kind, value: int) -> void:
	# Check if appropriate parameter entry type.
	if parameter_type != ParameterType.SECRET_TYPE_COUNT_MAX or secret_type_kind == null or secret_type_kind == RoomSecretType.Kind.NONE:
		return
	
	# Check if appropriate signal kind parameter type.
	if kind != secret_type_kind:
		return
	
	# Assign value.
	secret_type_value_max = value
	
	# Set collected data into display nodes.
	refresh_display_texts()


func _on_value_editor_value_changed(value: float) -> void:
	# Gather value from spinbox value editor and save it game_settings.
	if parameter_type == ParameterType.MAP_GRID_SIZE:
		GameSettings.set_map_grid_size(entry_value_editor.value)
	
	elif parameter_type == ParameterType.SECRET_TYPE_COUNT_MAX and secret_type_kind != null and secret_type_kind != RoomSecretType.Kind.NONE:
		GameSettings.set_map_secrets_count_max(secret_type_kind, entry_value_editor.value)
	
	# Manually release focus from the spinbox editor fields.
	entry_value_editor.release_focus()
	entry_value_editor.get_line_edit().release_focus()

#endregion
