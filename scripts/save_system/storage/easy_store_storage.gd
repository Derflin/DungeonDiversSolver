class_name EasyStoreStorage
extends RefCounted


const FIRST_SLOT: int = 1

const SAVE_DIRECTORY_NAME: String = "saves"
const SAVE_DIRECTORY: String = "user://saves"

const THUMBNAIL_DIRECTORY: String = "user://saves/thumbnails"

const SAVE_EXTENSION: String = ".sav"
const METADATA_EXTENSION: String = ".meta.json"
const THUMBNAIL_EXTENSION: String = ".webp"

const THUMBNAIL_MAX_SIZE := Vector2i(320, 180)

const GAME_STATE_SECTION: String = "game_state"


var _initialized: bool = false
var _save_version: int = 1

var _metadata_by_slot: Dictionary[int, SaveMetadata] = {}
var _pending_save_metadata: Dictionary[int, Dictionary] = {}


#region Initialization

## Initializes all EasyStore settings related to storage configs and this instance data parameters.
## Required to use before calling all the other functions from this class instance.
func initialize(save_version: int = 1) -> void:
	# Filter processing if the save storage was already initialized.
	if _initialized:
		return
	
	# Save passed parameters.
	_save_version = save_version
	
	# Create EasyStore config.
	var config := EasyStoreConfig.new()
	
	# Slots starting at 1.
	config.default_slot = FIRST_SLOT
	# Save version for migration/version handling.
	config.current_save_version = _save_version
	# Save files directory location.
	config.local.save_directory = SAVE_DIRECTORY_NAME
	# Save format serialization. Binary selected for compatibility with some Godot types like Vector2i.
	config.local.format = StoreEnums.SerializationFormat.BINARY
	# Save backups to keep at least one previous version.
	config.local.max_backups = 1
	
	# Initialize EasyStore config.
	EasyStore.initialize(config)
	
	# Add backend types to determine EasyStore save keeping method.
	EasyStore.add_backend(StoreEnums.BackendType.LOCAL)
	
	# Connect a custom signal handler for handling thumbnail and metadata save data.
	if not EasyStore.save_started.is_connected(_on_easy_store_save_started):
		EasyStore.save_started.connect(_on_easy_store_save_started)
	
	# Make sure that a thumbnail directory does exist.
	_ensure_thumbnail_directory()
	
	# Refresh slots manually to make sure that that they are loaded in correctly in our save storage.
	refresh_slots()
	
	# Mark save storage as initialized.
	_initialized = true

#endregion


#region Saving

## Save a provided [param game_state] along with it's [param custom_metadata] and [param thumbnail] image to the provided [param slot] number.
## Returns a bool value representing whether the save was successful or not.
func save_slot(slot: int, game_state: Dictionary, custom_metadata: Dictionary = {}, thumbnail: Image = null) -> bool:
	# Filter out processing if save storage wasn't initialized.
	if not _initialized:
		push_error("EasyStoreStorage: save_section() called before initialize().")
		return false
	
	# Filter out processing if provided slot number is invalid.
	if slot < FIRST_SLOT:
		push_error("EasyStoreStorage: invalid slot %d." % slot)
		return false
	
	# Prepare thumbnail path variable.
	var thumbnail_path := ""
	
	# Preserve existing thumbnail path.
	var existing_metadata := get_metadata(slot)
	if existing_metadata != null:
		thumbnail_path = existing_metadata.thumbnail_path
	
	# Save thumbnail and retrieve it's path if it was provided.
	if thumbnail != null:
		thumbnail_path = _write_thumbnail(slot, thumbnail)
		
		# Filter out processing if there was any issue with writing the thumbnail.
		if thumbnail_path.is_empty():
			push_error("EasyStoreStorage: failed to write thumbnail for slot %d." % slot)
			return false
	
	# Preserve save metadata to save it later once the EasyStore will finish saving the savedata to selected slot.
	_pending_save_metadata[slot] = {
		"custom": custom_metadata.duplicate(true),
		"thumbnail_path": thumbnail_path,
	}
	
	# Save the game data and check it's result.
	EasyStore.save(GAME_STATE_SECTION, game_state, slot)
	var result: Array = await _wait_for_save_completion(slot)
	var success: bool = result[1]
	if success:
		# Refresh slots manually to make sure that that they are loaded in correctly in our save storage.
		refresh_slots()
	
	return success


## Handle easy store save started signal that is emitted after EasyStore finishes creating/initializng a new save data.
## Modyfies already created save metadata for the provided [param slot] number in order to include in it pending custom ssave metadata along with it's thumbnail.
func _on_easy_store_save_started(slot: int) -> void:
	# Filter out processing if the save metadata isn't saved in the pending metadata dictionary.
	if not _pending_save_metadata.has(slot):
		return
	
	# Get save metadata.
	var metadata: SaveMetadata = EasyStore.get_save_metadata(slot)
	 
	# Filter out processing if the save metadata doesn't exist.
	if metadata == null:
		push_error("EasyStoreStorage: EasyStore did not provide metadata for slot %d." % slot)
		_pending_save_metadata.erase(slot)
		return
	
	# Get pending custom save metadata.
	var pending_metadata: Dictionary = _pending_save_metadata[slot]
	
	# Save pending custom save metadata into save metadata.
	metadata.custom = pending_metadata["custom"].duplicate(true)
	metadata.thumbnail_path = pending_metadata["thumbnail_path"]
	metadata.game_version = str(ProjectSettings.get_setting("application/config/version", ""))
	metadata.save_version = _save_version
	
	# Clear pending custom save metadata.
	_pending_save_metadata.erase(slot)


## Handles waiting for the save completed signal for the provided [param slot] number.
func _wait_for_save_completion(slot: int) -> Array:
	# Wait for signal that save was completed.
	while true:
		var result: Array = await EasyStore.save_completed
		
		var completed_slot: int = result[0]
		
		if completed_slot == slot:
			return result
	
	return [slot, false]

#endregion


#region Loading

## Load a save connected to the provided [param slot] number.
## Returns a dictionary containing all the loaded data from the save file.
func load_slot(slot: int) -> Dictionary:
	# Filter out processing if save storage wasn't initialized.
	if not _initialized:
		push_error("EasyStoreStorage: load_slot() called before initialize().")
		return {}
	
	# Filter out processing if provided slot number is invalid.
	if slot < FIRST_SLOT:
		push_error("EasyStoreStorage: invalid slot %d." % slot)
		return {}
	
	# Load in all existing save slots.
	# Uses load_all function instead of load function to ensure that most recent data will be used for this.
	EasyStore.load_all(slot)
	
	# Wait for the load to complete.
	while true:
		var result: Array = await EasyStore.load_completed
		
		# Check if load completed signal was triggered for our awaited save slot.
		var completed_slot: int = result[0]
		if completed_slot != slot:
			continue
		
		# Gather data about load result.
		var sections_data: Dictionary = result[1]
		var success: bool = result[2]
		if not success:
			return {}
		
		# Filter out processing if the loaded data doesn't have a game state section in it.
		if not sections_data.has(GAME_STATE_SECTION):
			push_error("EasyStoreStorage: slot %d does not containt the \"%s\" section." % [slot, GAME_STATE_SECTION])
			return {}
		
		# Get game state section from the loaded data.
		var game_state: Variant = sections_data[GAME_STATE_SECTION]
		
		# Filter out processing if the game state section is not a valid dicitonary.
		if not game_state is Dictionary:
			push_error("EasyStoreStorage: the \"%s\" section in slot %d is not a Dictionary.")
			return {}
		
		# Refresh slots manually to make sure that that they are loaded in correctly in our save storage.
		refresh_slots()
		
		return game_state.duplicate(true)
	
	return {}

#endregion


#region Deleting

## Delete a save connected to the provided [param slot] number including the save file, thumbnail and it's metadata file.
func delete_slot(slot: int) -> void:
	# Filter out processing if save storage wasn't initialized.
	if not _initialized:
		push_error("EasyStoreStorage: delete_slot() called before initialize().")
		return
	
	# Filter out processing if provided slot number is invalid.
	if slot < FIRST_SLOT:
		push_error("EasyStoreStorage: invalid slot %d." % slot)
		return
	
	# Delete selected slot and it's thumbnail and locally stored metadata.
	EasyStore.delete_slot(slot)
	_delete_thumbnail(slot)
	_metadata_by_slot.erase(slot)

#endregion


#region Slot Discovery

## Rebuilds the browser metadata index directly from EasyStore's lightweight .meta.json sidecar files. 
## This is the temporary workaround for EasyStore 1.0.0's public list_slots() implementation that doesn't fully load in all the existing files. 
## Call this whenever the save browser is opened/refreshed so that externally added, removed or edited saves are detected.
func refresh_slots() -> Array[SaveMetadata]:
	# Prepare a variable for storing the discovered save metadata.
	var discovered: Dictionary[int, SaveMetadata] = {}
	
	# Open save metadata directory.
	var directory := DirAccess.open(SAVE_DIRECTORY)
	
	# Filter out processing and clear locally stored metadata if the save metadata directory doesn't exist.
	if directory == null:
		_metadata_by_slot.clear()
		return []
	
	# Discover all save metadata existing in the directory.
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			var metadata := _read_metadata_file(file_name)
			
			if metadata != null:
				discovered[metadata.slot] = metadata
		
		file_name = directory.get_next()
	directory.list_dir_end()
	
	# Save discovered metadata.
	_metadata_by_slot = discovered
	
	# Return a result from calling the function responsible from listing out the save slots.
	return list_slots()


## Returns metadata currently loaded by the most recent refresh_slots() call.
func list_slots() -> Array[SaveMetadata]:
	var result: Array[SaveMetadata] = []
	
	# Look through and append each metadata as a result.
	for metadata: SaveMetadata in _metadata_by_slot.values():
		result.append(metadata)
	
	# Sort results by the slot number.
	result.sort_custom(func(a: SaveMetadata, b: SaveMetadata) -> bool: return a.slot < b.slot)
	
	return result


## Checks if the metadata currently loaded by the most recent refresh_slots() call contains a given [param slot] number. 
func has_slot(slot: int) -> bool:
	return _metadata_by_slot.has(slot)


## Returns metadata currently loaded by the most recent refresh_slots() call if it contains a given [param slot] number.
func get_metadata(slot: int) -> SaveMetadata:
	return _metadata_by_slot.get(slot, null)


## Tries to read the metadata file using the provided [param file_name] and returns parsed SaveMetadata.
## Returns null if any issues occur while trying to read the metadata file.
func _read_metadata_file(file_name: String) -> SaveMetadata:
	# Filter out processing if the provided file_name doesn't start with the "slot_" prefix.
	if not file_name.begins_with("slot_"):
		return null
	
	# Filter out processing if the provided file_name doesn't end with the format extension suffix.
	if not file_name.ends_with(METADATA_EXTENSION):
		return null
	
	# Prepare slot text name.
	var slot_text := file_name.trim_prefix("slot_").trim_suffix(METADATA_EXTENSION)
	
	# Filter out processing if the slot text name isn't for a valid integer.
	if not slot_text.is_valid_int():
		return null
	
	# Get slot number.
	var slot := int(slot_text)
	
	# Filter out processing if slot number is invalid.
	if slot < FIRST_SLOT:
		return null
	
	# Filter out processing if the save file is missing for the slot number.
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		push_warning("EasyStoreStorage: metadata exists for slot %d but the save file is missing." % slot)
		return null
	
	# Open metadata file
	var metadata_path := SAVE_DIRECTORY.path_join(file_name)
	var file := FileAccess.open(metadata_path, FileAccess.READ)
	
	# Filter out processing if the metadata file couldn't be opened.
	if file == null:
		push_warning("EasyStoreStorage: could not open metadata file for slot %d." % slot)
		return null
	
	# Try to load in the metadata file using JSON parser.
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	
	# Filter out processing if the parser encountered any issues during parsing metadata file.
	if error != OK:
		push_warning("EasyStoreStorage: invalid metadata JSON for slot %d." % slot)
		return null
	if not json.data is Dictionary:
		push_warning("EasyStoreStorage: metadata for slot %d is not a Dictionary." % slot)
		return null
	
	# Create a new save metadata and load it in with the loaded metadata from file.
	var metadata := SaveMetadata.new()
	metadata.from_dict(json.data)
	
	# Filter out processing if the filename slot and the metadata slot don't match.
	if metadata.slot != slot:
		push_warning("EasyStoreStorage: metadata slot mismatch in %s." % file_name)
		return null
	
	# Return nothing if the created metadata is empty.
	if metadata.is_empty:
		return null
	
	return metadata

#endregion


#region Thumbnails

## Returns a thumbnail path string based on the provided [param slot] number.
func get_thumbnail_path(slot: int) -> String:
	var metadata := get_metadata(slot)
	
	if metadata == null:
		return ""
	
	return metadata.thumbnail_path


## Tries to load in the thumbnail for the provided [param slot] number.
## Returns null if any issues would occur while trying to read the thumbnail file.
func load_thumbnail(slot: int) -> Image:
	# Prepare file path.
	var path := get_thumbnail_path(slot)
	
	# Filter out processing if the prepared file path is empty.
	if path.is_empty():
		return null
	
	# Filter out processing if the file for a given file path doesn't exist.
	if not FileAccess.file_exists(path):
		return null
	
	# Load in image from file.
	var image := Image.load_from_file(path)
	
	# Filter out processing if the loaded image is null or empty.
	if image == null or image.is_empty():
		return null
	
	return image


## Tries to save the [param source_image] for a given [param slot] number as it's thumbnail.
## If successful, returns file path to the thumbnail file.
## Otherwise it returns empty string.
func _write_thumbnail(slot: int, source_image: Image) -> String:
	# Filter out processing if the provided source image is null or empty.
	if source_image == null or source_image.is_empty():
		return ""
	
	# Make sure that a thumbnail directory does exist.
	_ensure_thumbnail_directory()
	
	# Make an independent copy because resize() mutates the Image.
	var image := Image.create_from_data(
		source_image.get_width(),
		source_image.get_height(),
		source_image.has_mipmaps(),
		source_image.get_format(),
		source_image.get_data(),
	)
	
	# Prepare a new target size for the image to fit the thumbnail target size.
	var source_size := Vector2(image.get_width(), image.get_height())
	var scale_x := float(THUMBNAIL_MAX_SIZE.x) / source_size.x
	var scale_y := float(THUMBNAIL_MAX_SIZE.y) / source_size.y
	var scale_factor: float = min(min(scale_x, scale_y), 1.0)
	var target_size := Vector2i(
		max(1, roundi(source_size.x * scale_factor)),
		max(1, roundi(source_size.y * scale_factor)),
	)
	
	# Resize image to fit the thumbnail target size.
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	
	# Get thumbnail file path and save it.
	var path := _get_thumbnail_path(slot)
	var error := image.save_webp(path, true, 0.85)
	
	# Filter out processsing if during saving the thumbnail any issues occurred.
	if error != OK:
		return ""
	
	return path


## Deletes a thumbnail file for a given [param slot] number if it exists.
func _delete_thumbnail(slot: int) -> void:
	# Get thumbnail file path.
	var path := _get_thumbnail_path(slot)
	
	# Filter out processing if the file doesn't exist.
	if not FileAccess.file_exists(path):
		return
	
	# Delete thumbnail file.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Ensures that the thumbnail directory does exist, if not then it creates it along with all the recursive necessary directories.
func _ensure_thumbnail_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THUMBNAIL_DIRECTORY))

#endregion


#region Paths

## Returns a save file path string for the provided [param slot] number.
func _get_save_path(slot: int) -> String:
	return SAVE_DIRECTORY.path_join("slot_%d%s" % [slot, SAVE_EXTENSION])


## Returns a thumbnail file path string for the provided [param slot] number.
func _get_thumbnail_path(slot: int) -> String:
	return THUMBNAIL_DIRECTORY.path_join("slot_%d%s" % [slot, THUMBNAIL_EXTENSION])

#endregion
