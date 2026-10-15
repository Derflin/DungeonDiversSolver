class_name SaveListEntry
extends Button


signal entry_selected(entry: SaveBrowserEntry)


@onready var thumbnail: TextureRect = $MarginContainer/ContentsContainer/Thumbnail
@onready var name_label: Label = $MarginContainer/ContentsContainer/InfoContainer/NameLabel
@onready var saved_label: Label = $MarginContainer/ContentsContainer/InfoContainer/SavedLabel
@onready var description_label: Label = $MarginContainer/ContentsContainer/InfoContainer/DescriptionLabel


var entry: SaveBrowserEntry = null


func _ready() -> void:
	pressed.connect(_on_pressed)


## Populates save list entry instance with the provided [param new_entry] details.
func setup(new_entry: SaveBrowserEntry) -> void:
	# Save entry parameter in local instance field.
	entry = new_entry
	
	# Set the list entry details for a save browser entry placeholder for creating new save. 
	if entry.is_new_save():
		thumbnail.texture = null
		name_label.text = "Create new save"
		saved_label.text = ""
		description_label.text = "Save to the first available slot."
		return
	
	# Set the list entry details.
	thumbnail.texture = SaveManager.get_thumbnail_texture(entry)
	name_label.text = entry.display_name
	saved_label.text = SaveManager.format_timestamp(entry.timestamp)
	description_label.text = _get_description_preview(entry.description)


## Sets list entry button state without emitting it's default signals.
func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)


## Returns a shortened version of the description string if it exceeds a set char limit of 90.
func _get_description_preview(description: String) -> String:
	var description_preview := description.strip_edges()
	
	if description_preview.length() <= 90:
		return description_preview
	
	return description_preview.left(87) + "..."


## Handle save list entry button pressed signal to emit the [signal entry_selected] signal.
func _on_pressed() -> void:
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if entry == null:
		return
	
	# Propagate a new entry selected signal.
	entry_selected.emit(entry)
