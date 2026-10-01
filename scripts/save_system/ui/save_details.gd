class_name SaveDetails
extends PanelContainer


signal save_requested(entry: SaveBrowserEntry, display_name: String, description: String)
signal load_requested(entry: SaveBrowserEntry)
signal delete_requested(entry: SaveBrowserEntry)


@onready var source_label: Label = $MarginContainer/ContentsContainer/SourceLabel
@onready var name_edit: LineEdit = $MarginContainer/ContentsContainer/NameEdit
@onready var saved_label: Label = $MarginContainer/ContentsContainer/SavedLabel
@onready var thumbnail: TextureRect = $MarginContainer/ContentsContainer/Thumbnail
@onready var description_edit: LineEdit = $MarginContainer/ContentsContainer/DescriptionEdit
@onready var metadata_container: VBoxContainer = $MarginContainer/ContentsContainer/MetadataScrollContainer/MetadataContainer
@onready var delete_button: Button = $MarginContainer/ContentsContainer/Actions/DeleteButton
@onready var primary_button: Button = $MarginContainer/ContentsContainer/Actions/PrimaryButton


var _entry: SaveBrowserEntry = null
var _operation_mode: SaveUIEnums.OperationMode = SaveUIEnums.OperationMode.LOAD


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	
	clear_details()


## Show save details for the provided [param entry] and sets the provided [param operation_mode] for the save details.
## Provided [param pending_thumbnail] will be set as the thumbnail texture, if the entry doesn't already have an existing thumbnail assigned to itself.
func show_entry(entry: SaveBrowserEntry, operation_mode: SaveUIEnums.OperationMode, pending_thumbnail: Image = null) -> void:
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
	
	# Set name text depending on the provided save browser entry.
	name_edit.text = entry.display_name
	
	# Set description text depending on the provided save browser entry.
	description_edit.text = entry.description
	
	# Set saved label depending on the provided save browser entry.
	if entry.exists and entry.timestamp > 0:
		saved_label.text = "Last saved: %s" % SaveManager.format_timestamp(entry.timestamp)
	else:
		saved_label.text = ""
	
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
	source_label.text = message
	name_edit.text = ""
	saved_label.text = ""
	description_edit.text = ""
	thumbnail.texture = null
	_clear_metadata()
	
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
	primary_button.disabled = not enabled


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
	name_edit.editable = saving
	description_edit.editable = saving
	
	# Update delete button state.
	delete_button.visible = _entry.can_delete()
	
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


## Clears out existing nodes inside the metadata container.
func _clear_metadata() -> void:
	# Look through every existing child of the metadata container and remove them.
	for child: Node in metadata_container.get_children():
		metadata_container.remove_child(child)
		child.queue_free()
