class_name SaveDetails
extends PanelContainer


signal save_requested(entry: SaveBrowserEntry, display_name: String, description: String)
signal load_requested(entry: SaveBrowserEntry)
signal delete_requested(entry: SaveBrowserEntry)


@onready var contents_container: VBoxContainer = $MarginContainer/ContentsContainer
@onready var source_label: Label = $MarginContainer/ContentsContainer/Header/SourceLabel
@onready var name_edit: LineEdit = $MarginContainer/ContentsContainer/NameField/NameEdit
@onready var name_badge_overlay: Control = $MarginContainer/ContentsContainer/NameField/BadgeOverlay
@onready var name_badge_unsaved: PanelContainer = $MarginContainer/ContentsContainer/NameField/BadgeOverlay/UnsavedBadge
@onready var name_badge_unsaved_label: Label = $MarginContainer/ContentsContainer/NameField/BadgeOverlay/UnsavedBadge/Label
@onready var thumbnail: TextureRect = $MarginContainer/ContentsContainer/ThumbnailFrame/Thumbnail
@onready var metadata_container: VBoxContainer = $MarginContainer/ContentsContainer/MetadataScrollContainer/MetadataContainer
@onready var description_edit: TextEdit = $MarginContainer/ContentsContainer/DescriptionField/DescriptionEdit
@onready var description_badge_overlay: Control = $MarginContainer/ContentsContainer/DescriptionField/BadgeOverlay
@onready var description_badge_unsaved: PanelContainer = $MarginContainer/ContentsContainer/DescriptionField/BadgeOverlay/UnsavedBadge
@onready var description_badge_unsaved_label: Label = $MarginContainer/ContentsContainer/DescriptionField/BadgeOverlay/UnsavedBadge/Label
@onready var saved_label: Label = $MarginContainer/ContentsContainer/Footer/SavedLabel
@onready var delete_button: Button = $MarginContainer/ContentsContainer/Footer/DeleteButton
@onready var primary_button: Button = $MarginContainer/ContentsContainer/Footer/PrimaryButton


@export_group("Transitions", "transition_")
@export_range(0.01, 0.50, 0.01)
var transition_fade_out_duration: float = 0.15
@export_range(0.01, 0.50, 0.01)
var transition_fade_in_duration: float = 0.18

@export_group("Badge Unsaved Changes", "badge_unsaved_")
@export var badge_unsaved_min_transition_duration: float = 0.04
@export var badge_unsaved_text_color: Color = Color("#1A1307")
@export var badge_unsaved_accent_color: Color = Color("#B58A3A")
@export_range(0.05, 0.40, 0.01)
var badge_unsaved_transition_duration: float = 0.18
@export_range(0.0, 8.0, 0.5)
var badge_unsaved_slide_distance: float = 3.0
@export_range(0.0, 10.0, 0.5)
var badge_unsaved_right_inset: float = 2.0


var _entry: SaveBrowserEntry = null
var _operation_mode: SaveUIEnums.OperationMode = SaveUIEnums.OperationMode.LOAD
var _interaction_enabled: bool = true

var _updating_fields: bool = false
var _name_original: String = ""
var _name_dirty: bool = false
var _name_unsaved_tween: Tween = null
var _name_normal_style: StyleBoxFlat
var _name_focus_style: StyleBoxFlat
var _name_read_only_style: StyleBoxFlat
var _name_clean_normal_border: Color
var _name_clean_focus_border: Color
var _name_clean_read_only_border: Color
var _name_badge_visible_position: Vector2
var _description_original: String = ""
var _description_dirty: bool = false
var _description_unsaved_tween: Tween = null
var _description_normal_style: StyleBoxFlat
var _description_focus_style: StyleBoxFlat
var _description_read_only_style: StyleBoxFlat
var _description_clean_normal_border: Color
var _description_clean_focus_border: Color
var _description_clean_read_only_border: Color
var _description_badge_visible_position: Vector2

var _content_transition_tween: Tween = null


func _ready() -> void:
	# Initialize visuals for the editable fields that have the unsaved badge assigned to them.
	_initialize_unsaved_visuals()
	
	# Connect signals for handling the events after the buttons are pressed.
	primary_button.pressed.connect(_on_primary_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	
	# Connect signals for detecting text changed signal for the editable fields that might affect other elements.
	name_edit.text_changed.connect(_on_name_changed)
	description_edit.text_changed.connect(_on_description_changed)
	
	# Connect signals for the unused badge overlays to resize and change their positions after resize signal was detected.
	name_badge_overlay.resized.connect(_on_unsaved_badge_layout_changed)
	description_badge_overlay.resized.connect(_on_unsaved_badge_layout_changed)
	
	# Update layouts for the editable fields that have unsaved badge assigned to them.
	call_deferred("_initialize_unsaved_badge_layout")
	
	clear_details()


## Handles user input in order to detect pointer inputs that might require losing focus from the focussable elements in the scene.
func _input(event: InputEvent) -> void:
	# Filter out processing if the current scene isn't visible.
	if not is_visible_in_tree():
		return
	
	# Get focus owner and filter out processing if the focus owner isn't one of the focussable elements managed by this scene.
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != name_edit and focus_owner != description_edit:
		return
	
	# Get current pointer position based on the used pointer and on which actions should be used for further releasing the focus.
	var pointer_position: Vector2
	# Handle mouse as current pointer device.
	if event is InputEventMouseButton:
		# Filter out processing if the mouse event doesn't have pressed flag set.
		if not event.pressed:
			return
		
		# Filter out processing if the mouse event is related in any way to the mouse wheel actions.
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		
		pointer_position = event.position
		
	# Handle touch as current pointer device.
	elif event is InputEventScreenTouch:
		# Filter out processing if the screen touch even doesn't have pressed flag set.
		if not event.pressed:
			return
		
		pointer_position = event.position
		
	# Filter out any other event types.
	else:
		return
	
	# Filter out processing if the input event was performed inside the currently focussed element.
	if focus_owner.get_global_rect().has_point(pointer_position):
		return
	
	# Release focus from the currently focussed element.
	focus_owner.release_focus()


## Show save details for the provided [param entry] and sets the provided [param operation_mode] for the save details.
## Provided [param pending_thumbnail] will be set as the thumbnail texture, if the entry doesn't already have an existing thumbnail assigned to itself.
## Provided [param preserve_edits] flag will determine if the save details should preserve the existing edited interactible save fields if the save entry didn't change.
func show_entry(entry: SaveBrowserEntry, operation_mode: SaveUIEnums.OperationMode, pending_thumbnail: Image = null, preserve_edits: bool = false) -> void:
	# Check if the provided entry is for the same save as the last one that was provided.
	var same_entry: bool = _entry != null and entry != null and _entry.entry_id == entry.entry_id
	
	# Cache user interactible save fields that could have been edited by the user.
	var edited_name: String = name_edit.text
	var edited_description: String = description_edit.text
	
	# Save parameters in local instance fields.
	_entry = entry
	_operation_mode = operation_mode
	
	# Filter out processing if the provided save browser entry is null.
	if entry == null:
		clear_details()
		return
	
	# Set source label depending on the provided save browser entry.
	if entry.is_example():
		source_label.text = "Example"
	elif entry.exists:
		source_label.text = "Slot %d" % entry.slot
	else:
		source_label.text = "Slot %d - Empty" % entry.slot
	
	# Set the updating fields flag.
	_updating_fields = true
	
	# Check if previous entry edits should be preserved and set name text and description text depending on it and the provided save browser entry.
	var keep_edits: bool = preserve_edits and same_entry and operation_mode == SaveUIEnums.OperationMode.SAVE
	if keep_edits:
		name_edit.text = edited_name
		description_edit.text = edited_description
	else:
		# Save initial state of the name and description fields.
		_name_original = entry.display_name
		_description_original = entry.description
		
		name_edit.text = entry.display_name
		description_edit.text = entry.description
	
	# Unset the updating fields flag.
	_updating_fields = false
	
	# Initialize clean state for the name and description fields if new values were inside of it.
	if not keep_edits:
		_set_name_dirty(false, false)
		_set_description_dirty(false, false)
	
	# Set saved label depending on the provided save browser entry.
	if entry.exists and entry.timestamp > 0:
		saved_label.text = SaveManager.format_timestamp(entry.timestamp)
	else:
		saved_label.text = "-"
	
	# Set thumbnail texture depending on the provided save browser entry and the provided pending thumbnail.
	if entry.exists:
		thumbnail.texture = SaveManager.get_thumbnail_texture(entry)
	elif pending_thumbnail != null:
		thumbnail.texture = ImageTexture.create_from_image(pending_thumbnail)
	else:
		thumbnail.texture = null
	
	# Populate metadata details.
	_populate_metadata(entry.game_metadata)
	
	# Update available interactions including the actions buttons and editable fields.
	_update_interactions()


## Clears currently assigned save browser entry and resets save details state.
func clear_details(message: String = "No save selected.") -> void:
	# Clear save entry saved in the local instance field.
	_entry = null
	
	# Reset state of the display nodes.
	source_label.text = "-"
	name_edit.text = ""
	name_edit.placeholder_text = message
	saved_label.text = "-"
	description_edit.text = ""
	description_edit.placeholder_text = "No description"
	thumbnail.texture = null
	_clear_metadata()
	_add_metadata_message("Select a save to view game details.")
	
	# Reset editable fields status along with their dirty statuses.
	_name_original = ""
	_description_original = ""
	_updating_fields = true
	name_edit.text = ""
	description_edit.text = ""
	_updating_fields = false
	_set_name_dirty(false, false)
	_set_description_dirty(false, false)
	
	# Disable editable fields
	name_edit.editable = false
	description_edit.editable = false
	
	# Hide actions buttons.
	delete_button.visible = false
	primary_button.visible = false


## Updates state for interactions elements including action buttons and editable fields.
## Sets the editable fields editable state based on the provided [param enabled] state and the saved save browser entry and operation mode.
## Sets the actions buttons state based on the provided [param enabled] state.
func set_interaction_enabled(enabled: bool) -> void:
	# Save interaction status.
	_interaction_enabled = enabled
	
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if _entry == null:
		return
	
	# Check if the editable fields should be enabled.
	var editing_allowed: bool = enabled and _operation_mode == SaveUIEnums.OperationMode.SAVE and _entry.is_user_save()
	
	# Set editable fields editable state.
	name_edit.editable = editing_allowed
	description_edit.editable = editing_allowed
	
	# Set actions buttons disabled state.
	delete_button.disabled = not enabled
	_update_primary_button_state()


## Updates available actions buttons and editable fields depending on the saved save browser entry.
func _update_interactions() -> void:
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if _entry == null:
		return
	
	# Set the editable fields and delete button as disabled but leave the primary button enabled if the saved entry is an example.
	if _entry.is_example():
		name_edit.editable = false
		description_edit.editable = false
		delete_button.visible = false
		primary_button.visible = true
		primary_button.text = "Load"
		return
	
	# Check if saving operation mode is active.
	var saving: bool = _operation_mode == SaveUIEnums.OperationMode.SAVE
	
	# Update editable fields editable state.
	name_edit.editable = saving and _interaction_enabled
	description_edit.editable = saving and _interaction_enabled
	
	# Update delete button state.
	delete_button.visible = _entry.can_delete()
	delete_button.text = "Delete"
	
	# Update primary button state.
	if saving:
		primary_button.visible = true
		if _entry.exists:
			primary_button.text = "Overwrite"
		else:
			primary_button.text = "Save Here"
	else:
		primary_button.visible = _entry.exists
		primary_button.text = "Load"
	_update_primary_button_state()


## Handles text changed signal for the connected line edit node by updating the interaction state of the primary button.
## Also checks if the dirty status for the name field has changed.
func _on_name_changed(_new_text: String) -> void:
	# Update primary button interaction state.
	_update_primary_button_state()
	
	# Filter out processing if the updating fields flag is set.
	if _updating_fields:
		return
	
	# Check current dirty status for the name field and sets it in accordingly.
	var dirty := name_edit.text.strip_edges() != _name_original.strip_edges()
	_set_name_dirty(dirty)


## Handles text changed signal for the connected text edit node by checking if the dirty status for the description field has changed.
func _on_description_changed() -> void:
	# Filter out processing if the updating fields flag is set.
	if _updating_fields:
		return
	
	# Check current dirty status for the description field and sets it in accordingly.
	var dirty := description_edit.text.strip_edges() != _description_original.strip_edges()
	_set_description_dirty(dirty)


## Updates the interaction state of the primary button based on it's vibility state along with the interaction tracked status and save browser entry details. 
func _update_primary_button_state() -> void:
	# Filter out processing if the primary button isn't visible.
	if not primary_button.visible:
		return
	
	# Disable the primary button and filter out further processing if the interactions are disabled by the internal field tracking the interaction status.
	if not _interaction_enabled:
		primary_button.disabled = true
		return
	
	# Update the primary disabled state according to the save details name edit if the current save browser entry is not empty and the operation mode is set to save.
	if _entry != null and _entry.is_user_save() and _operation_mode == SaveUIEnums.OperationMode.SAVE:
		primary_button.disabled = name_edit.text.strip_edges().is_empty()
		return
	
	# Otherwise if all the other conditions weren't met, then enable the primary button.
	primary_button.disabled = false


## Handles primary button pressed signal to correctly interpret how it should be handled and propagated.
func _on_primary_pressed() -> void:
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if _entry == null:
		return
	
	# Button should be processed as load button if the saved save browser entry is an example.
	if _entry.is_example():
		load_requested.emit(_entry)
		return
	
	# Handle the signal propagation based on the save details operation mode.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		save_requested.emit(_entry, name_edit.text.strip_edges(), description_edit.text.strip_edges())
	else:
		load_requested.emit(_entry)


## Handles delete button pressed signal to correctly interpret how it should be handled and propagated.
func _on_delete_pressed() -> void:
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if _entry == null:
		return
	
	# Filter out processing if entry can't be deleted.
	if not _entry.can_delete():
		return
	
	# Handle the signal propagation.
	delete_requested.emit(_entry)


## Populates metadata container with metadata entries from the provided [param metadata] list with metadata details saved in dictionaries.
func _populate_metadata(metadata: Array[Dictionary]) -> void:
	# Clear out existing elements in metadata container.
	_clear_metadata()
	
	# Add default empty metadata message if the provided metadata is empty.
	if metadata.is_empty():
		_add_metadata_message("No additional game details.")
		return
	
	# Populate metadata container with new contents based on the provided metadata.
	for item: Dictionary in metadata:
		# Prepare new row entry.
		var row := HBoxContainer.new()
		
		# Prepare new key and value labels.
		var key_label := Label.new()
		var value_label := Label.new()
		
		# Set key and value labels texts based on the item metadata.
		key_label.text = str(item.get("key", "")).capitalize()
		value_label.text = str(item.get("value", ""))
		
		# Set key and value labels config parameters.
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		# Add key and value labels as children of the new entry.
		row.add_child(key_label)
		row.add_child(value_label)
		
		# Add new entry as a child of the metadata container.
		metadata_container.add_child(row)


## Adds label node to the metadata container including the provided text [param message] parameter.
func _add_metadata_message(message: String) -> void:
	# Create new label for the provided message.
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Add the created label to the metadata container node. 
	metadata_container.add_child(label)


## Clears out existing nodes inside the metadata container.
func _clear_metadata() -> void:
	# Look through every existing child of the metadata container and remove them.
	for child: Node in metadata_container.get_children():
		metadata_container.remove_child(child)
		child.queue_free()


## Duplicates, assigns overrides in the node and returns a source style from the provided [param control] node set under the provided [param style_name].
func _duplicate_field_style(control: Control, style_name: StringName) -> StyleBoxFlat:
	# Get source style using style name from the control node.
	var source_style := control.get_theme_stylebox(style_name)
	assert(source_style is StyleBoxFlat, "SaveDetails: Expected %s style to be StyleBoxFlat." % style_name)
	
	# Prepare duplicate of the source style.
	var style_copy := source_style.duplicate() as StyleBoxFlat
	
	# Assign current style copy as the overriden style in the control node.
	control.add_theme_stylebox_override(style_name, style_copy)
	
	return style_copy


## Initializes local copies of the initial visual state of the fields that can be modified by the user and that are related to the unsaved badges.
## Copies are made to later be able to go back to what was set before any possible changes to the styles.
## This also results in local changes not affecting all existing related nodes when changing specific styles.
func _initialize_unsaved_visuals() -> void:
	# Create private StyleBox copies for NameEdit.
	_name_normal_style = _duplicate_field_style(name_edit, &"normal")
	_name_focus_style = _duplicate_field_style(name_edit, &"focus")
	_name_read_only_style = _duplicate_field_style(name_edit, &"read_only")
	
	# Save NameEdit's clean border colors.
	_name_clean_normal_border = _name_normal_style.border_color
	_name_clean_focus_border = _name_focus_style.border_color
	_name_clean_read_only_border = _name_read_only_style.border_color
	
	# Create private StyleBox copies for DescriptionEdit.
	_description_normal_style = _duplicate_field_style(description_edit, &"normal")
	_description_focus_style = _duplicate_field_style(description_edit, &"focus")
	_description_read_only_style = _duplicate_field_style(description_edit, &"read_only")
	
	# Save DescriptionEdit's clean border colors.
	_description_clean_normal_border = _description_normal_style.border_color
	_description_clean_focus_border = _description_focus_style.border_color
	_description_clean_read_only_border = _description_read_only_style.border_color
	
	# Configure badges.
	_configure_unsaved_badge(name_badge_unsaved, name_badge_unsaved_label)
	_configure_unsaved_badge(description_badge_unsaved, description_badge_unsaved_label)
	
	# Initialize clean state for the name and description fields.
	_set_name_dirty(false, false)
	_set_description_dirty(false, false)


## Creates, initializes and assigns style for the provided unsaved [param badge].
## Initializes label styles for the provided [param label] that is located inside the badge itself. 
func _configure_unsaved_badge(badge: PanelContainer, label: Label) -> void:
	# Create and initialize badge style.
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = badge_unsaved_accent_color
	badge_style.corner_radius_top_left = 2
	badge_style.corner_radius_top_right = 2
	#badge_style.corner_radius_bottom_left = 2
	#badge_style.corner_radius_bottom_right = 2
	badge_style.content_margin_left = 5.0
	badge_style.content_margin_right = 5.0
	badge_style.content_margin_top = 1.0
	badge_style.content_margin_bottom = 1.0
	
	# Assign created badge style.
	badge.add_theme_stylebox_override(&"panel", badge_style)
	
	# Initialize label styles.
	label.add_theme_color_override(&"font_color", badge_unsaved_text_color)
	#label.add_theme_font_size_override(&"font_size", 10)


## Checks current provided unsaved [param badge] state using it and the provided [param dirty] flag and initializes transition animation to the target state.
## All the remaining provided parameters are used for applying the animation to their styles.
func _animate_unsaved_visual(
	badge: PanelContainer, 
	normal_style: StyleBoxFlat,
	focus_style: StyleBoxFlat,
	read_only_style: StyleBoxFlat,
	clean_normal_border: Color,
	clean_focus_border: Color,
	clean_read_only_border: Color,
	visible_position: Vector2,
	dirty: bool,
) -> Tween:
	# Calculate target state and remaining state based on the opacity state.
	var target_alpha := 1.0 if dirty else 0.0
	var remaining_distance: float = abs(badge.modulate.a - target_alpha)
	
	# Apply visual state immediately and filter out further processing if the calculated distance is almost or just done.
	if remaining_distance <= 0.001:
		_apply_unsaved_visual_immediate(
			badge, 
			normal_style, 
			focus_style, 
			read_only_style, 
			clean_normal_border, 
			clean_focus_border,
			clean_read_only_border,
			visible_position,
			dirty,
		)
		return null
	
	# Calculate animation parameters.
	var duration: float = max(badge_unsaved_min_transition_duration, badge_unsaved_transition_duration * remaining_distance)
	var target_normal_border := badge_unsaved_accent_color if dirty else clean_normal_border
	var target_focus_border := badge_unsaved_accent_color.lightened(0.18) if dirty else clean_focus_border
	var target_read_only_border := badge_unsaved_accent_color.darkened(0.25) if dirty else clean_read_only_border
	var target_position := visible_position if dirty else visible_position + Vector2(0.0, badge_unsaved_slide_distance)
	
	# Create tween for the animation.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Animate styles.
	tween.tween_property(badge, "modulate:a", target_alpha, duration)
	tween.tween_property(badge, "position", target_position, duration)
	tween.tween_property(normal_style, "border_color", target_normal_border, duration)
	tween.tween_property(focus_style, "border_color", target_focus_border, duration)
	tween.tween_property(read_only_style, "border_color", target_read_only_border, duration)
	
	return tween


## Checks current provided unsaved [param badge] state using it and the provided [param dirty] flag and immediately sets appropriate styles to set the target state.
## All the remaining provided parameters are used for applying the target state to their styles.
func _apply_unsaved_visual_immediate(
	badge: PanelContainer, 
	normal_style: StyleBoxFlat,
	focus_style: StyleBoxFlat,
	read_only_style: StyleBoxFlat,
	clean_normal_border: Color,
	clean_focus_border: Color,
	clean_read_only_border: Color,
	visible_position: Vector2,
	dirty: bool,
) -> void:
	# Set the badge opacity styles.
	var target_alpha := 1.0 if dirty else 0.0
	var badge_modulate := badge.modulate
	badge_modulate.a = target_alpha
	badge.modulate = badge_modulate
	
	# Set the target state based on the provided dirty flag.
	if dirty:
		# Set the badge to be visible.
		badge.position = visible_position
		normal_style.border_color = badge_unsaved_accent_color
		focus_style.border_color = badge_unsaved_accent_color.lightened(0.18)
		read_only_style.border_color = badge_unsaved_accent_color.darkened(0.25)
	else:
		# Set the badge to be hidden.
		badge.position = visible_position + Vector2(0.0, badge_unsaved_slide_distance)
		normal_style.border_color = clean_normal_border
		focus_style.border_color = clean_focus_border
		read_only_style.border_color = clean_read_only_border


## Initializes name field state according to the provided [param dirty] flag and [param animate] flag.
## Provided [param dirty] flag is used to check if the field isn't already initialized according to this flag, in which case it skips further processing.
## Provided [param animate] flag is used to define whether the field state should be changed immediately or over time animated.
func _set_name_dirty(dirty: bool, animate: bool = true) -> void:
	# Filter out further processing if the animate flag is set and current dirty status matches the provided flag status.
	if animate and _name_dirty == dirty:
		return
	
	# Set dirty flag status.
	_name_dirty = dirty
	
	# Kill existing animation if it does exist.
	if _name_unsaved_tween != null and _name_unsaved_tween.is_valid():
		_name_unsaved_tween.kill()
	_name_unsaved_tween = null
	
	# Initialize field state.
	if animate:
		_name_unsaved_tween = _animate_unsaved_visual(
			name_badge_unsaved,
			_name_normal_style,
			_name_focus_style,
			_name_read_only_style,
			_name_clean_normal_border,
			_name_clean_focus_border,
			_name_clean_read_only_border,
			_name_badge_visible_position,
			dirty,
		)
	else:
		_apply_unsaved_visual_immediate(
			name_badge_unsaved,
			_name_normal_style,
			_name_focus_style,
			_name_read_only_style,
			_name_clean_normal_border,
			_name_clean_focus_border,
			_name_clean_read_only_border,
			_name_badge_visible_position,
			dirty,
		)


## Initializes description field state according to the provided [param dirty] flag and [param animate] flag.
## Provided [param dirty] flag is used to check if the field isn't already initialized according to this flag, in which case it skips further processing.
## Provided [param animate] flag is used to define whether the field state should be changed immediately or over time animated.
func _set_description_dirty(dirty: bool, animate: bool = true) -> void:
	# Filter out further processing if the animate flag is set and current dirty status matches the provided flag status.
	if animate and _description_dirty == dirty:
		return
	
	# Set dirty flag status.
	_description_dirty = dirty
	
	# Kill existing animation if it does exist.
	if _description_unsaved_tween != null and _description_unsaved_tween.is_valid():
		_description_unsaved_tween.kill()
	_description_unsaved_tween = null
	
	# Initialize field state.
	if animate:
		_description_unsaved_tween = _animate_unsaved_visual(
			description_badge_unsaved,
			_description_normal_style,
			_description_focus_style,
			_description_read_only_style,
			_description_clean_normal_border,
			_description_clean_focus_border,
			_description_clean_read_only_border,
			_description_badge_visible_position,
			dirty,
		)
	else:
		_apply_unsaved_visual_immediate(
			description_badge_unsaved,
			_description_normal_style,
			_description_focus_style,
			_description_read_only_style,
			_description_clean_normal_border,
			_description_clean_focus_border,
			_description_clean_read_only_border,
			_description_badge_visible_position,
			dirty,
		)


## Updates position for the editable fields that have the unsaved badge attached to them.
func _update_unsaved_badge_layouts() -> void:
	_name_badge_visible_position = _position_unsaved_badge(name_badge_overlay, name_badge_unsaved)
	_description_badge_visible_position = _position_unsaved_badge(description_badge_overlay, description_badge_unsaved)


## Positions provided [param badge] node in order to display on top of the provided [param overlay] node to the right side of it.
## Returns calculated position for the badge.
func _position_unsaved_badge(overlay: Control, badge: PanelContainer) -> Vector2:
	# Get badge minimum size and set it as actual badge size.
	var badge_size := badge.get_combined_minimum_size()
	badge.size = badge_size
	
	# Calculate visible position where the badge should be displayed along with the current visibility progress.
	var visible_position := Vector2(overlay.size.x - badge_size.x - badge_unsaved_right_inset, -badge_size.y)
	var visibility_progress := clampf(badge.modulate.a, 0.0, 1.0)
	
	# Set the badge position to the upper right corner of the overlay.
	badge.position = visible_position + Vector2(0.0, badge_unsaved_slide_distance * (1.0 - visibility_progress))
	
	return visible_position


## Handles detected signals that might affect the unsaved badge layouts and calls the function to update them accordingly.
func _on_unsaved_badge_layout_changed() -> void:
	call_deferred("_update_unsaved_badge_layouts")


## Updates layouts related to the editable fields that have the unsaved badge assigned to them.
## Updates badge layout to have correct positions and initializes clean states for them.
func _initialize_unsaved_badge_layout() -> void:
	# Update layouts.
	_update_unsaved_badge_layouts()
	
	# Initialize clean state for the name and description fields.
	_set_name_dirty(false, false)
	_set_description_dirty(false, false)


## Returns a bool value indicating if any of the editable fields have some unsaved changes in them.
func has_unsaved_changes() -> bool:
	return _name_dirty or _description_dirty


#region Contents Transitions

## Fades out currently displayed save details contents. 
func fade_contents_out() -> void:
	await _fade_contents_to(0.0, transition_fade_out_duration)


## Fades in currently displayed save details contents.
func fade_contents_in() -> void:
	await _fade_contents_to(1.0, transition_fade_in_duration)


## Resets save details contents to their normal fully visible state.
func reset_content_transition() -> void:
	# Kill existing animation if it does exist.
	if _content_transition_tween != null and _content_transition_tween.is_valid():
		_content_transition_tween.kill()
	_content_transition_tween = null
	
	# Reset opacity setting to fully visible.
	var content_modulate := contents_container.modulate
	content_modulate.a = 1.0
	contents_container.modulate = content_modulate


## Fades save details contents to the provided target opacity.
func _fade_contents_to(target_alpha: float, duration: float) -> void:
	# Kill existing animation if it does exist.
	if _content_transition_tween != null and _content_transition_tween.is_valid():
		_content_transition_tween.kill()
	_content_transition_tween = null
	
	# Filter out processing if contents already use the target opacity.
	if is_equal_approx(contents_container.modulate.a, target_alpha):
		return
	
	# Create tween for the animation.
	_content_transition_tween = create_tween()
	_content_transition_tween.set_trans(Tween.TRANS_QUAD)
	_content_transition_tween.set_ease(Tween.EASE_OUT)
	
	# Animate styles.
	_content_transition_tween.tween_property(contents_container, "modulate:a", target_alpha, duration)
	
	# Wait until transition finishes.
	await _content_transition_tween.finished
	
	# Remove assigned transition after it has finished.
	_content_transition_tween = null

#endregion
