class_name SaveSlotEntry
extends Button


signal entry_selected(entry: SaveBrowserEntry)


@onready var thumbnail: TextureRect = $MarginContainer/ContentsContainer/Thumbnail
@onready var slot_label: Label = $MarginContainer/ContentsContainer/InfoContainer/SlotLabel
@onready var name_label: Label = $MarginContainer/ContentsContainer/InfoContainer/NameLabel
@onready var saved_label: Label = $MarginContainer/ContentsContainer/InfoContainer/SavedLabel


var entry: SaveBrowserEntry = null


func _ready() -> void:
	pressed.connect(_on_pressed)


## Populates save slot entry instance with the provided [param new_entry] details.
## Provided [param operation_mode] is used to check the current operation mode and determine if
## the slot entry should be disabled or not if the [param new_entry] is for an empty save slot.
func setup(new_entry: SaveBrowserEntry, operation_mode: SaveUIEnums.OperationMode) -> void:
	# Save entry parameter in local instance field.
	entry = new_entry
	
	# Set default slot label text.
	slot_label.text = "Slot %d" % entry.slot
	
	# Set the slot entry nodes to an empty state if the provided save browser entry is not for an existing save.
	if not entry.exists:
		# Set the slot entry details for an empty save slot.
		thumbnail.texture = null
		name_label.text = "Empty"
		saved_label.text = ""
		disabled = operation_mode == SaveUIEnums.OperationMode.LOAD
		
		return
	
	# Set the slot entry details for not empty save slot.
	thumbnail.texture = SaveManager.get_thumbnail_texture(entry)
	name_label.text = entry.display_name
	saved_label.text = SaveManager.format_timestamp(entry.timestamp)
	disabled = false


## Sets slot entry button state without emitting it's default signals.
func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)


## Handle save slot entry button pressed signal to emit the [signal entry_selected] signal.
func _on_pressed() -> void:
	# Filter out processing if the save browser entry isn't assigned in the internal field.
	if entry == null:
		return
	
	# Propagate a new entry selected signal.
	entry_selected.emit(entry)
