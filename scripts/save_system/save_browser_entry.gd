class_name SaveBrowserEntry
extends RefCounted


enum Source {
	USER_SAVE,
	EXAMPLE,
}

const DEFAULT_EXAMPLE_ORDER: int = 1000


var source: Source = Source.USER_SAVE
var entry_id: String = ""
var slot: int = -1
var example_id: String = ""
var example_order: int = DEFAULT_EXAMPLE_ORDER

var is_new_save_entry: bool = false
var exists: bool = false
var display_name: String = ""
var description: String = ""
var timestamp: int = 0
var thumbnail_path: String = ""
var game_metadata: Array[Dictionary] = []
var browser_hint: String = ""


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


## Creates and returns a SaveBrowserEntry instance representing a packaged read-only example save.
static func from_example_metadata(_example_id: String, metadata: SaveMetadata) -> SaveBrowserEntry:
	# Instantiate save browser entry.
	var entry := SaveBrowserEntry.new()
	
	# Initialize it with the provided metadata.
	entry.source = Source.EXAMPLE
	entry.example_id = _example_id
	entry.entry_id = "example:%s" % _example_id
	entry.slot = -1
	entry.exists = true
	entry.timestamp = 0
	var fallback_name := _example_id.replace("_", " ").capitalize()
	entry.display_name = str(metadata.custom.get("display_name", fallback_name))
	entry.description = str(metadata.custom.get("description", ""))
	entry.example_order = int(metadata.custom.get("example_order", DEFAULT_EXAMPLE_ORDER))
	
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
	entry.is_new_save_entry = false 
	entry.display_name = "Save %d" % _slot
	
	# Return prepared save browser entry.
	return entry


## Creates and returns a SaveBrowserEntry instance for the empty, unused [param _slot] number, which is marked as a placeholder for a new save entry to be created.
static func create_new_user_save_entry(_slot: int) -> SaveBrowserEntry:
	# Instantiate save browser entry.
	var entry := SaveBrowserEntry.new()
	
	# Initialize it with the provided metadata.
	entry.source = Source.USER_SAVE
	entry.slot = _slot
	entry.entry_id = "slot:%d" % _slot
	entry.exists = false
	entry.is_new_save_entry = true
	entry.display_name = "Save %d" % _slot
	
	# Return prepared save browser entry.
	return entry


## Checks if the save browser entry is sourced as an user save.
func is_user_save() -> bool:
	return source == Source.USER_SAVE


## Check if the save browser entry is sourced as an example save.
func is_example() -> bool:
	return source == Source.EXAMPLE


## Check if the save browser entry is a placeholder entry for a new save entry.
func is_new_save() -> bool:
	return is_new_save_entry


## Check if it would be allowed to delete the save browser entry based on it's parameters.
func can_delete() -> bool:
	return is_user_save() and exists


## Check if it would be allowed to overwrite the save browser entry based on it's parameters.
func can_overwrite() -> bool:
	return is_user_save() and exists
