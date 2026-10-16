extends Node


signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
signal delete_completed(slot: int)
signal operation_failed(operation: StringName, slot: int, message: String)
signal user_saves_changed()


const SAVE_VERSION: int = 1
const FIRST_SLOT: int = 1


var _storage := EasyStoreStorage.new()
var _game_save_adapter: Node = null

var _user_entries_by_slot: Dictionary[int, SaveBrowserEntry] = {}

var _thumbnail_cache: Dictionary[String, Texture2D] = {}

var _is_busy: bool = false


func _ready() -> void:
	# Set process node to always be enabled.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialize save storage.
	_storage.initialize(SAVE_VERSION)
	
	# Update save entries.
	refresh_user_saves()


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

## Refresh save browser entries based on the saves metadata and returns a list of them as output.
func refresh_user_saves() -> Array[SaveBrowserEntry]:
	# Gather saves metadata from the save storage.
	var metadata_list: Array[SaveMetadata] = _storage.refresh_slots()
	
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


## Returns a list of existing save browser entries that were refreshed by the last refresh_user_saves() call.
func get_existing_user_saves() -> Array[SaveBrowserEntry]:
	var result: Array[SaveBrowserEntry] = []
	
	for entry: SaveBrowserEntry in _user_entries_by_slot.values():
		result.append(entry)
	
	return result


## Checks if save entry exist for the provided [param slot] number.
func has_user_save(slot: int) -> bool:
	return _user_entries_by_slot.has(slot)


## Returns a save entry for the provided [param slot] number if it exists, otherwise returns null.
func get_user_save(slot: int) -> SaveBrowserEntry:
	return _user_entries_by_slot.get(slot, null)


## Returns a save entry for the provided [param slot] number if it exists, otherwise it creates and returns an empty save entry for it.
func get_user_slot_entry(slot: int) -> SaveBrowserEntry:
	var existing := get_user_save(slot)
	
	if existing != null:
		return existing
	
	return SaveBrowserEntry.create_empty_user_slot(slot)


## Returns a first empty slot number that doesn't contain any existing user save.
func get_first_empty_user_slot() -> int:
	# Look through every slot starting from the first slot static value and incrementing it until it points to a slot that doesn't have any user save assigned to itself.
	var slot := FIRST_SLOT
	while _user_entries_by_slot.has(slot):
		slot += 1
	
	return slot


## Creates a new save browser entry for the first empty slot number that doesn't contain any existing user save.
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
	var success := await _storage.save_slot(slot, game_state, custom_metadata, thumbnail)
	
	# Remove thumbnail from cache and refresh user saves if the save was successful.
	if success:
		_thumbnail_cache.erase("slot:%d" % slot)
		refresh_user_saves()
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit singal that save was completed.
	save_completed.emit(slot, success)
	
	# Handle failed save operation if it wasn't successful.
	if not success:
		_emit_operation_error(&"save", slot, "The save operation failed.")
	
	return success

#endregion


#region Loading

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
		_emit_operation_error(&"load", slot, "The selected save does not exist.")
		return false
	
	# Mark save manager as busy.
	_is_busy = true
	
	# Try to load game state from the save slot. 
	var game_state: Dictionary = await _storage.load_slot(slot)
	
	# Check if load was successful.
	var success := not game_state.is_empty()
	
	# Restore loaded game state if it was loaded successfully.
	if success:
		_game_save_adapter.restore_game_state(game_state)
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit singal that load was completed.
	load_completed.emit(slot, success)
	
	# Handle failed load operation if it wasn't successful.
	if not success:
		_emit_operation_error(&"load", slot, "The selected save could not be loaded.")
	
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
	_storage.delete_slot(slot)
	_user_entries_by_slot.erase(slot)
	_thumbnail_cache.erase("slot:%d" % slot)
	
	# Unmark save manager as busy.
	_is_busy = false
	
	# Emit signals that saves have been changed and the slotted save was deleted.
	user_saves_changed.emit()
	delete_completed.emit(slot)
	
	return true

#endregion


#region Thumbnail Access

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
		var image := _storage.load_thumbnail(entry.slot)
		
		# Filter out processing if the prepared image is null or empty.
		if image == null or image.is_empty():
			return null
		
		# Create a texture from the image.
		var texture := ImageTexture.create_from_image(image)
		
		# Save created texture inside the thumbnail cache.
		_thumbnail_cache[entry.entry_id] = texture
		
		return texture
	
	return null

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
