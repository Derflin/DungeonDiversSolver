extends Node


signal user_save_completed(slot: int, success: bool)
signal user_load_completed(slot: int, success: bool)
signal user_delete_completed(slot: int)
signal user_saves_changed()

signal example_load_completed(example_id: String, success: bool)
signal example_saves_changed()

signal operation_failed(operation: StringName, slot: int, message: String)


const SAVE_VERSION: int = 1
const FIRST_SLOT: int = 1


var _user_save_storage := EasyStoreStorage.new()
var _example_save_storage := ExampleSaveStorage.new()
var _game_save_adapter: Node = null

var _user_entries_by_slot: Dictionary[int, SaveBrowserEntry] = {}
var _example_entries_by_id: Dictionary[String, SaveBrowserEntry] = {}

var _thumbnail_cache: Dictionary[String, Texture2D] = {}

var _is_busy: bool = false


func _ready() -> void:
	# Set process node to always be enabled.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialize user saves storage.
	_user_save_storage.initialize(SAVE_VERSION)
	
	# Initialize example saves storage.
	_example_save_storage.initialize(SAVE_VERSION)
	
	# Update user saves entries.
	refresh_user_saves()
	
	# Update example saves entries.
	refresh_example_saves()


#region Game Save Adapter

## Register [param adapter] node as the game save adapter.
func register_game_save_adapter(adapter: Node) -> void:
	assert(adapter != null)
	
	_game_save_adapter = adapter


## Unregister [param adapter] node from being the game save adapter if it's one currently.
func unregister_game_save_adapter(adapter: Node) -> void:
	if _game_save_adapter == adapter:
		_game_save_adapter = null

#endregion


#region Status

## Checks if the save manager is busy and processing something currently.
func is_busy() -> bool:
	return _is_busy

#endregion


#region User Save Queries

## Refreshes user save browser entries based on the user saves metadata and returns a list of them as output.
func refresh_user_saves() -> Array[SaveBrowserEntry]:
	# Gather saves metadata from the user save storage.
	var metadata_list: Array[SaveMetadata] = _user_save_storage.refresh_slots()
	
	# Clear currently saved user save browser entries.
	_user_entries_by_slot.clear()
	
	# Populate save browser entries from saves metadata list.
	for metadata: SaveMetadata in metadata_list:
		# Filter out processing the metadata if it's null or empty.
		if metadata == null or metadata.is_empty:
			continue
		
		# Filter out processing the metadata if it's slot number is invalid.
		if metadata.slot < FIRST_SLOT:
			continue
		
		# Prepare a new save browser entry based on the current metadata.
		var entry := SaveBrowserEntry.from_user_metadata(metadata)
		
		# Save prepared save browser entry.
		_user_entries_by_slot[entry.slot] = entry
	
	# Emit signal that save entries have been changed.
	user_saves_changed.emit()
	
	# Return a list of existing save browser entries.
	return get_existing_user_saves()


## Returns a list of existing user save browser entries that were refreshed by the last refresh_user_saves() call.
func get_existing_user_saves() -> Array[SaveBrowserEntry]:
	var result: Array[SaveBrowserEntry] = []
	
	for entry: SaveBrowserEntry in _user_entries_by_slot.values():
		result.append(entry)
	
	return result


## Checks if user save entry exist for the provided [param slot] number.
func has_user_save(slot: int) -> bool:
	return _user_entries_by_slot.has(slot)


## Returns a user save entry for the provided [param slot] number if it exists, otherwise returns null.
func get_user_save(slot: int) -> SaveBrowserEntry:
	return _user_entries_by_slot.get(slot, null)


## Returns a user save entry for the provided [param slot] number if it exists, otherwise it creates and returns an empty save entry for it.
func get_user_slot_entry(slot: int) -> SaveBrowserEntry:
	var existing := get_user_save(slot)
	
	if existing != null:
		return existing
	
	return SaveBrowserEntry.create_empty_user_slot(slot)


## Returns a first empty user slot number that doesn't contain any existing user save.
func get_first_empty_user_slot() -> int:
	# Look through every slot starting from the first slot static value and incrementing it until it points to a slot that doesn't have any user save assigned to itself.
	var slot := FIRST_SLOT
	while _user_entries_by_slot.has(slot):
		slot += 1
	
	return slot


## Creates a new user save browser entry for the first empty slot number that doesn't contain any existing user save.
func get_new_user_save_entry() -> SaveBrowserEntry:
	return SaveBrowserEntry.create_new_user_save_entry(get_first_empty_user_slot())


## Returns current game metadata based on the current game state.
func capture_current_game_metadata() -> Array[Dictionary]:
	# Filter out processing if the game save adapter isn't registered.
	if _game_save_adapter == null:
		return []
	
	# Get game metadata from the game save adapter.
	var game_metadata: Array[Dictionary] = _game_save_adapter.capture_save_metadata()
	
	# Return a duplicate of the returned game metadata.
	return game_metadata.duplicate(true)

#endregion


#region Example Save Queries

## Refreshes example save browser entries based on the examples entries IDs and their metadata and returns a list of them as output.
func refresh_example_saves() -> Array[SaveBrowserEntry]:
	# Gather example saves idss from the example save storage.
	var example_ids: Array[String] = _example_save_storage.refresh_examples()
	
	# Clear currently saved example save browser entries along with their thumbnails.
	_example_entries_by_id.clear()
	_clear_example_thumbnail_cache()
	
	for example_id: String in example_ids:
		# Gather metadata for the example ID.
		var metadata := _example_save_storage.get_metadata(example_id)
		
		# Filter out processing the metadata if it's null or empty.
		if metadata == null or metadata.is_empty:
			continue
		
		# Prepare a new save browser entry based on the current metadata.
		var entry := SaveBrowserEntry.from_example_metadata(example_id, metadata)
		
		# Save prepared save browser entry.
		_example_entries_by_id[example_id] = entry
	
	# Emit signal that save entries have been changed.
	example_saves_changed.emit()
	
	# Return a list of example save browser entries.
	return get_example_saves()


## Returns a list of existing example save browser entries that were refreshed by the last refresh_example_saves() call.
## Return all example saves using their curated order.
func get_example_saves() -> Array[SaveBrowserEntry]:
	var result: Array[SaveBrowserEntry] = []
	
	for entry: SaveBrowserEntry in _example_entries_by_id.values():
		result.append(entry)
	
	result.sort_custom(_compare_example_save_entries)
	
	return result


## Returns whether the provided [param example_id] exists.
func has_example_save(example_id: String) -> bool:
	return _example_entries_by_id.has(example_id) 


## Returns a example save entry for the provided [param example_id] if it exists, otherwise returns null.
func get_example_save(example_id: String) -> SaveBrowserEntry:
	return _example_entries_by_id.get(example_id, null)


## Compares two provided example save browser entries, [param a] and [param b].
## First it compares them based on their example_order, then based on their display_name and finally based on the example_id.
func _compare_example_save_entries(a: SaveBrowserEntry, b: SaveBrowserEntry) -> bool:
	# Compare save entries based on the example_order field.
	if a.example_order != b.example_order:
		return a.example_order < b.example_order
	
	# Compare save entries based on their display names.
	var name_comparison := a.display_name.naturalnocasecmp_to(b.display_name)
	if name_comparison != 0:
		return name_comparison < 0
	
	# Compare save entries based on their example ids.
	return a.example_id.naturalnocasecmp_to(b.example_id) < 0

#endregion


#region Saving

## Tries to save the current game state into the provided [param slot] number along with the provided [param display_name], [param description] and [param thumbnail].
## Returns a bool indicating if the save operation was successful or not.
func save_user_save(slot: int, display_name: String, description: String, thumbnail: Image) -> bool:
	# Filter out processing if the save manager is currently busy processing something else.
	if _is_busy:
		return false
	
	# Filter out processing if the game save adapter isn't registered.
	if _game_save_adapter == null:
		_emit_operation_error(&"save", slot, "No GameSaveAdapter is registered.")
		return false
	
	# Filter out processing if the provided slot number is invalid.
	if slot < FIRST_SLOT:
		_emit_operation_error(&"save", slot, "Invalid save slot.")
		return false
	
	# Prepare normalized save slot name.
	var normalized_name := display_name.strip_edges()
	if normalized_name.is_empty():
		normalized_name = "Save %d" % slot
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Gather game state and metadata from the game save adapter.
	var game_state: Dictionary = _game_save_adapter.capture_game_state()
	var game_metadata: Array[Dictionary] = _game_save_adapter.capture_save_metadata()
	
	# Prepare custom metadata wrapper.
	var custom_metadata := {
		"display_name": normalized_name,
		"description": description,
		"game_metadata": game_metadata.duplicate(true),
	}
	
	# Try to save game state along with it's metadata and thumbnail into save slot. 
	var success := await _user_save_storage.save_slot(slot, game_state, custom_metadata, thumbnail)
	
	# Remove thumbnail from cache and refresh user saves if the save was successful.
	if success:
		_thumbnail_cache.erase("slot:%d" % slot)
		refresh_user_saves()
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit singal that save was completed.
	user_save_completed.emit(slot, success)
	
	# Handle failed save operation if it wasn't successful.
	if not success:
		_emit_operation_error(&"save", slot, "The save operation failed.")
	
	return success

#endregion


#region User Loading

## Tries to load the game state from the provided [param slot] number and restore it.
## Returns a bool indicating if the load operation was successful or not.
func load_user_save(slot: int) -> bool:
	# Filter out processing if the save manager is currently busy processing something else.
	if _is_busy:
		return false
	
	# Filter out processing if the game save adapter isn't registered.
	if _game_save_adapter == null:
		_emit_operation_error(&"load", slot, "No GameSaveAdapter is registered.")
		return false
	
	# Filter out processing if the save for the provided slot number doesn't exist.
	if not has_user_save(slot):
		_emit_operation_error(&"load", slot, "The selected user save does not exist.")
		return false
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Try to load game state from the save slot. 
	var game_state: Dictionary = await _user_save_storage.load_slot(slot)
	
	# Check if load was successful.
	var success := not game_state.is_empty()
	
	# Restore loaded game state if it was loaded successfully.
	if success:
		_game_save_adapter.restore_game_state(game_state)
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit singal that load was completed.
	user_load_completed.emit(slot, success)
	
	# Handle failed load operation if it wasn't successful.
	if not success:
		_emit_operation_error(&"load", slot, "The selected user save could not be loaded.")
	
	return success

#endregion


#region Example Loading

## Tries to load the game state using the provided [param example_id] in order to find the example save and restore it.
## Returns a bool indicating if the load operation was successful or not.
func load_example_save(example_id: String) -> bool:
	# Filter out processing if the save manager is currently busy processing something else.
	if _is_busy:
		return false
	
	# Filter out processing if the game save adapter isn't registered.
	if _game_save_adapter == null:
		_emit_operation_error(&"load_example", -1, "No GameSaveAdapter is registered.")
		return false
	
	# Filter out processing if the save for the provided example id doesn't exist.
	if not has_example_save(example_id):
		_emit_operation_error(&"load", -1, "The selected example save does not exist.")
		return false
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Try to load game state from the example save. 
	var game_state: Dictionary = _example_save_storage.load_example(example_id)
	
	# Check if load was successful.
	var success := not game_state.is_empty()
	
	# Restore loaded game state if it was loaded successfully.
	if success:
		_game_save_adapter.restore_game_state(game_state)
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit singal that load was completed.
	example_load_completed.emit(example_id, success)
	
	# Handle failed load operation if it wasn't successful.
	if not success:
		_emit_operation_error(&"load_example", -1, "The selected example save could not be loaded.")
	
	return success

#endregion


#region Portable Save Transfer

## Returns the saved game data and metadata for the provided [param entry] without restoring the game state.
func prepare_portable_export(entry: SaveBrowserEntry) -> Dictionary:
	# Validate the requested entry and current storage operation state.
	if _is_busy or entry == null or not entry.exists or entry.is_new_save():
		return {}
	if entry.is_user_save() and not has_user_save(entry.slot):
		return {}
	if entry.is_example() and not has_example_save(entry.example_id):
		return {}
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Load the save contents without applying them to the current game.
	var game_state: Dictionary = {}
	if entry.is_user_save():
		game_state = await _user_save_storage.load_slot(entry.slot)
	elif entry.is_example():
		game_state = _example_save_storage.load_example(entry.example_id)
	
	# Unmark save manager as busy and filter out further processing if the loaded game state is empty.
	if game_state.is_empty():
		_is_busy = false
		return {}
	
	# Gather the optional thumbnail for the selected save.
	var thumbnail: Image = null
	var texture := get_thumbnail_texture(entry)
	if texture != null:
		thumbnail = texture.get_image()
	
	# Prepare a result dictionary with parsed game data for export.
	var payload := {
		"game_state": game_state,
		"display_name": entry.display_name,
		"description": entry.description,
		"game_metadata": entry.game_metadata.duplicate(true),
		"thumbnail": thumbnail,
		"save_version": SAVE_VERSION,
	}
	
	# Unmark save manager as busy.
	_is_busy = false
	
	return payload


## Imports the provided [param payload] as a user save in the specified [param slot].
## Returns whether EasyStore completed the save operation successfully.
func import_portable_user_save(slot: int, payload: Dictionary) -> bool:
	# Validate the destination and incoming save data.
	if _is_busy or slot < FIRST_SLOT:
		return false
	if int(payload.get("save_version", -1)) != SAVE_VERSION:
		return false
	var game_state: Variant = payload.get("game_state", null)
	if not game_state is Dictionary or game_state.is_empty():
		return false
	
	# Prepare user save metadata from the portable file.
	var display_name := str(payload.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = "Save %d" % slot
	var metadata := {
		"display_name": display_name,
		"description": str(payload.get("description", "")),
		"game_metadata": payload.get("game_metadata", []),
	}
	var thumbnail: Image = payload.get("thumbnail", null)
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Write the imported save into the selected user slot.
	var success := await _user_save_storage.save_slot(slot, game_state, metadata, thumbnail, false)
	if success:
		_thumbnail_cache.erase("slot:%d" % slot)
		refresh_user_saves()
	
	# Unmark save manager as busy.
	_is_busy = false
	
	if not success:
		_emit_operation_error(&"import", slot, "The portable save could not be imported.")
	return success

#endregion


#region Deleting

## Tries to delete the saved game state for the provided [param slot] number along with all of it's related data.
## Returns a bool indicating if the delete operation was successful or not.
func delete_user_save(slot: int) -> bool:
	# Filter out processing if the save manager is currently busy processing something else.
	if _is_busy:
		return false
	
	# Filter out processing if the save for the provided slot number doesn't exist.
	if not has_user_save(slot):
		return false
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Delete save slot from the save storage and all the related data to it from the current instance.
	_user_save_storage.delete_slot(slot)
	_user_entries_by_slot.erase(slot)
	_thumbnail_cache.erase("slot:%d" % slot)
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit signals that saves have been changed and the slotted save was deleted.
	user_saves_changed.emit()
	user_delete_completed.emit(slot)
	
	return true

#endregion


#region Thumbnail Access

# Prepares and returns a thumbnail image using the same processing that is used for stored save thumbnails.
func prepare_thumbnail(source_image: Image) -> Image:
	return _user_save_storage.prepare_thumbnail(source_image)


# Returns a texture of the thumbnail for the provided save browser entry if it exists, otherwise it returns null.
func get_thumbnail_texture(entry: SaveBrowserEntry) -> Texture2D:
	# Filter out processing if the provided save entry is empty.
	if entry == null:
		return null
	
	# Filter out processing if the entry doesn't exist or wasn't properly initialized.
	if not entry.exists:
		return null
	
	# Return thumbnail cache if it was already loaded in earlier and it's still saved in it.
	if _thumbnail_cache.has(entry.entry_id):
		return _thumbnail_cache[entry.entry_id]
	
	# Process save entry if it's user save.
	if entry.is_user_save():
		# Load thumbnail through the save storage.
		var image := _user_save_storage.load_thumbnail(entry.slot)
		
		# Filter out processing if the prepared image is null or empty.
		if image == null or image.is_empty():
			return null
		
		# Create a texture from the image.
		var texture := ImageTexture.create_from_image(image)
		
		# Save created texture inside the thumbnail cache.
		_thumbnail_cache[entry.entry_id] = texture
		
		return texture
	
	# Process save entry if it's example save.
	if entry.is_example():
		# Load thumbnail through the save storage.
		var texture := _example_save_storage.load_thumbnail(entry.example_id)
		
		# Filter out processing if the prepared texture is null.
		if texture == null:
			return null
		
		# Save created texture inside the thumbnail cache.
		_thumbnail_cache[entry.entry_id] = texture
		
		return texture
	
	return null


## Clears example saves thumbnail cache entries.
func _clear_example_thumbnail_cache() -> void:
	var cache_keys := _thumbnail_cache.keys()
	for key: String in cache_keys:
		if key.begins_with("example:"):
			_thumbnail_cache.erase(key)

#endregion


#region Formatting

## Returns a localized datetime string from the provided [param timestamp].
## Returns empty string if timestamp is invalid.
func format_timestamp(timestamp: int) -> String:
	# Filter out processing and return an empty string if timestamp isn't valid.
	if timestamp <= 0:
		return ""
	
	# Get current system local time zone.
	var timezone := Time.get_time_zone_from_system()
	
	# Convert timestamp to local time zone.
	var local_timestamp := timestamp + int(timezone.get("bias", 0)) * 60
	
	# Format the local timestamp into datetime string.
	return Time.get_datetime_string_from_unix_time(local_timestamp, true)

#endregion


#region Errors

## Handles operation errors by pushing error system messages and emitting the operation failed signal.
func _emit_operation_error(operation: StringName, slot: int, message: String) -> void:
	push_error("SaveManager: %s" % message)
	operation_failed.emit(operation, slot, message)

#endregion
