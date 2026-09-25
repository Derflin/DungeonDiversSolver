class_name SaveBrowserEntry
extends RefCounted


enum Source {
	USER_SAVE,
	EXAMPLE,
}


var source: Source = Source.USER_SAVE
var entry_id: String = ""
var slot: int = -1
var example_id: String = ""

var exists: bool = false
var display_name: String = ""
var description: String = ""
var timestamp: int = 0
var thumbnail_path: String = ""
var game_metadata: Array[Dictionary] = []


## Creates and returns a SaveBrowserEntry instance with data collected from the provided [param metadata] stored for each existing saved slot.
static func from_user_metadata(metadata: SaveMetadata) -> SaveBrowserEntry:
	# Instantiate save browser entry.
	var entry := SaveBrowserEntry.new()
	
	# Initialize it with the provided metadata.
	entry.source = Source.USER_SAVE
	entry.slot = metadata.slot
	entry.entry_id = "slot:%d" % metadata.slot
	entry.exists = not metadata.is_empty
	entry.timestamp = metadata.timestamp
	entry.thumbnail_path = metadata.thumbnail_path
	entry.display_name = str(metadata.custom.get("display_name", "Save %d" % metadata.slot))
	entry.description = str(metadata.custom.get("description", ""))
	
	var saved_game_metadata: Variant = metadata.custom.get("game_metadata", [])
	if saved_game_metadata is Array:
		for item: Variant in saved_game_metadata:
			if item is Dictionary:
				entry.game_metadata.append(item.duplicate(true))
	
	# Return prepared save browser entry.
	return entry


## Creates and returns a SaveBrowserEntry instance for the empty, unused [param _slot] number.
static func create_empty_user_slot(_slot: int) -> SaveBrowserEntry:
	# Instantiate save browser entry.
	var entry := SaveBrowserEntry.new()
	
	# Initialize it with the provided metadata.
	entry.source = Source.USER_SAVE
	entry.slot = _slot
	entry.entry_id = "slot:%d" % _slot
	entry.exists = false
	entry.display_name = "Save %d" % _slot
	
	# Return prepared save browser entry.
	return entry


## Checks if the save browser entry is sourced as an user save.
func is_user_save() -> bool:
	return source == Source.USER_SAVE


## Check if the save browser entry is sourced as an example save.
func is_example() -> bool:
	return source == Source.EXAMPLE


## Check if it would be allowed to delete the save browser entry based on it's parameters.
func can_delete() -> bool:
	return is_user_save() and exists


## Check if it would be allowed to overwrite the save browser entry based on it's parameters.
func can_overwrite() -> bool:
	return is_user_save()
