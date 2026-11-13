class_name MapParameterEntry
extends HBoxContainer


## Emitted when the pointer enters the room help region.
signal help_preview_requested(entry: MapParameterEntry)
## Emitted when the room help region is actived by mouse selection or touch.
signal help_activation_requested(entry: MapParameterEntry, from_touch: bool)


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
## Outline style used while the pointer hovers over or previews room help.
@export var help_preview_style: StyleBoxFlat
## Outline style used while the associated room help is pinned.
@export var help_pinned_style: StyleBoxFlat
## Amount by which the visual outline extends beyond the help interaction region.
@export var help_highlight_padding: Vector2 = Vector2(2.0, 2.0)
## Space reserved between the help trigger region and the value editor.
@export var help_editor_gap: float = 3.0
## Maximum pointer movement still treated as a touch tap.
@export var help_touch_tap_max_movement: float = 12.0


var parameter_type: ParameterType = ParameterType.NONE
var secret_type_kind: RoomSecretType.Kind = RoomSecretType.Kind.NONE
var map_grid_size: Vector2i = Vector2i(0, 0)
var secret_type_value_current: int = 0
var secret_type_value_max: int = 0

# Visual state of the row while help is being previewed or selected.
var _help_row_hovered: bool = false
var _help_selected: bool = false
var _help_pinned: bool = false

# Prevents a touchscreen's emulated cursor from creating a hover-only preview.
var _allow_mouse_hover: bool = true

# Touch gesture currently being checked for activation of this entry.
var _touch_index: int = -1
var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_has_moved: bool = false

# Start of an emulated touch-to-mouse gesture delivered through the gui.
var _emulated_press_position: Vector2 = Vector2.ZERO
var _emulated_pressed: bool = false
var _emulated_moved: bool = false


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


## Returns the local area covering the icon, count, title and spaces between them.
func _get_help_region_rect() -> Rect2:
	var right_edge: float = maxf(0.0, entry_value_editor.position.x - help_editor_gap)
	return Rect2(Vector2.ZERO, Vector2(right_edge, size.y))


## Keeps the hover highlight and help preview synchronized with one input region.
func _process(_delta: float) -> void:
	# Non-secret entries and touch-only interaction don't create mouse previews.
	if not _has_help() or not _allow_mouse_hover:
		if _help_row_hovered:
			_help_row_hovered = false
			queue_redraw()
		return
	
	# Check if mouse hovers over the the entry hover area.
	var hovering: bool = contains_help_trigger_viewport_point(get_viewport().get_mouse_position())
	
	# Filter out processing if the entry mouse hover state is the same as the just checked one.
	if hovering == _help_row_hovered:
		return
	
	# Update row hover.
	_help_row_hovered = hovering
	queue_redraw()
	
	# Emit signal to request the help preview.
	if hovering:
		help_preview_requested.emit(self)


## Tracks physical mouse input and native touchscreen gestures separately.
func _input(event: InputEvent) -> void:
	# Filter out processing if the entry doesn't contain any help.
	if not _has_help():
		return
	
	# Handle native touchscreen press and release events.
	if event is InputEventScreenTouch:
		# Disable hover previews while interacting through touchscreen input.
		_allow_mouse_hover = false
		
		# Avoid processing the same touch through both native and emulated mouse events.
		if Input.emulate_mouse_from_touch:
			return
		
		# Register the start of a touch gesture within the interactive help region.
		if event.pressed and _touch_index == -1:
			if contains_help_trigger_viewport_point(event.position):
				_touch_index = event.index
				_touch_start_position = event.position
				_touch_has_moved = false
			
		# Evaluate the completed gesture when the tracked touch is released.
		elif not event.pressed and event.index == _touch_index:
			var is_tap: bool = not _touch_has_moved and event.position.distance_to(_touch_start_position) <= help_touch_tap_max_movement
			
			# Reset the active touch gesture before processing its activation.
			_touch_index = -1
			
			# Activate help only for taps released within the interactive region.
			if is_tap and contains_help_trigger_viewport_point(event.position):
				help_activation_requested.emit(self, true)
		
	# Track touch movement to prevent scrolling gestures from activating help.
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if event.position.distance_to(_touch_start_position) > help_touch_tap_max_movement:
			_touch_has_moved = true
		
	# Restore hover-based interaction when a physical mouse is used.
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_allow_mouse_hover = true


## Handles mouse selection and emulated touchscreen activation within the interactive help region.
func _gui_input(event: InputEvent) -> void:
	# Filter out processing if the entry doesn't contain any help.
	if not _has_help():
		return
	
	# Track pointer movement during an emulated touchscreen press to distinguish tapping from dragging.
	if event is InputEventMouseMotion and _emulated_pressed:
		var mouse_motion: InputEventMouseMotion = event
		if mouse_motion.position.distance_to(_emulated_press_position) > help_touch_tap_max_movement:
			_emulated_moved = true
		return
	
	# Filter out other input event types apart from mouse button events.
	if not event is InputEventMouseButton:
		return
	
	# Process only input events associated with the mapped selection action.
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.is_action_pressed(&"map_select") and not mouse_event.is_action_released(&"map_select"):
		return
	
	# Handle mouse button events emulated from touchscreen input.
	if mouse_event.device == InputEvent.DEVICE_ID_EMULATION:
		if mouse_event.pressed:
			# Store the initial press position and whether it occurred inside the help region.
			_emulated_pressed = _get_help_region_rect().has_point(mouse_event.position)
			_emulated_press_position = mouse_event.position
			_emulated_moved = false
		else:
			# Activate help only when a completed tap remains inside the help region.
			if _emulated_pressed and not _emulated_moved and _get_help_region_rect().has_point(mouse_event.position):
				help_activation_requested.emit(self, true)
			
			# Reset the gesture state after releasing the emulated mouse button.
			_emulated_pressed = false
		
		return
	
	# Activate help when a physical mouse selects the interactive help region.
	if mouse_event.pressed and _get_help_region_rect().has_point(mouse_event.position):
		help_activation_requested.emit(self, false)
		accept_event()


## Updates the active and pinned selection highlight for this entry.
func set_help_selected(selected: bool, pinned: bool = false) -> void:
	_help_selected = selected
	_help_pinned = pinned
	queue_redraw()


## Draws the configurable highlight around interactive secret-room rows.
func _draw() -> void:
	# Draw help feedback only for entries with renderable room help content.
	if not _has_help() or (not _help_selected and not _help_row_hovered):
		return
	
	# Select the exported border style for the current interaction state.
	var style: StyleBoxFlat = help_pinned_style if _help_pinned else help_preview_style
	if style == null:
		return
	
	# Expand the visible border without changing the input rectangle or entry layout.
	var border_rect: Rect2 = _get_help_region_rect()
	border_rect.position -= help_highlight_padding
	border_rect.size += help_highlight_padding * 2.0
	draw_style_box(style, border_rect)


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
	return contains_help_trigger_viewport_point(viewport_position)


## Checks whether the pointer is inside the visible, interactive help area.
func contains_help_trigger_viewport_point(viewport_position: Vector2) -> bool:
	# Filter out processing and return false if the current entry doesn't contain anything to be displayed in help or the scene isn't displayed.
	if not _has_help() or not is_visible_in_tree():
		return false
	
	# Reject coordinates outside the portion visible within thee drawer scroll viewport.
	if not _contains_visible_viewport_point(self, viewport_position):
		return false
	
	# Check whether viewport position lies inside the interactive help area.
	var local_position: Vector2 = make_canvas_position_local(viewport_position)
	return _get_help_region_rect().has_point(local_position)

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
