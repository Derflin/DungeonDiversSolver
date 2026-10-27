class_name SaveListEntry
extends Button


signal entry_selected(entry: SaveBrowserEntry)


@onready var thumbnail: TextureRect = $MarginContainer/ContentsContainer/Thumbnail
@onready var name_label: Label = $MarginContainer/ContentsContainer/MarginContainer/InfoContainer/NameLabel
@onready var saved_label: Label = $MarginContainer/ContentsContainer/MarginContainer/InfoContainer/SavedLabel
@onready var description_label: Label = $MarginContainer/ContentsContainer/MarginContainer/InfoContainer/DescriptionLabel


var entry: SaveBrowserEntry = null


func _ready() -> void:
	pressed.connect(_on_pressed)


## Populates save list entry instance with the provided [param new_entry] details.
func setup(new_entry: SaveBrowserEntry) -> void:
	# Save entry parameter in local instance field.
	entry = new_entry
	
	# Set the list entry details for a save browser entry placeholder for creating new save. 
	if entry.is_new_save():
		thumbnail.visible = false
		thumbnail.texture = null
		name_label.text = "Create new save"
		saved_label.text = "-"
		description_label.text = entry.browser_hint
		return
	
	# Set the list entry details.
	thumbnail.visible = true
	thumbnail.texture = SaveManager.get_thumbnail_texture(entry)
	name_label.text = entry.display_name
	if entry.is_example():
		saved_label.text = "Example"
	else:
		saved_label.text = SaveManager.format_timestamp(entry.timestamp)
		if saved_label.text.is_empty():
			saved_label.text = "-"
	description_label.text = _get_single_line_preview(entry.description)
	if description_label.text.strip_edges().is_empty():
		description_label.text = "-"


## Prepares and returns a single line preview based on the provided [param _text] string.
## For multiline strings it replaces the new line special character with "|" character to mark where the new lines were placed and to keep it consistent.
## Removes the empty lines and replaces white spaces that would set together in groups (more than one) leaving only one white space, in order to shorten the preview. 
func _get_single_line_preview(_text: String) -> String:
	# Normalize new line and carriage return characters to only use the new line.
	var normalized := _text.replace("\r\n", "\n").replace("\r", "\n")
	
	# Split normalized text based on the new line character.
	var lines := normalized.split("\n", false)
	
	# Prepare cleaned lines skipping empty ones.
	var cleaned_lines: Array[String] = []
	for line: String in lines:
		var cleaned_line := line.strip_edges()
		if not cleaned_line.is_empty():
			cleaned_lines.append(cleaned_line)
	
	# Return single line preview of the text where each new line character is replaced with "|" char.
	return " | ".join(cleaned_lines)


## Sets list entry button state without emitting it's default signals.
func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)


## Handle save list entry button pressed signal to emit the [signal entry_selected] signal.
func _on_pressed() -> void:
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if entry == null:
		return
	
	# Propagate a new entry selected signal.
	entry_selected.emit(entry)
