class_name ExampleSaveStorage
extends RefCounted


const EXAMPLES_DIRECTORY: String = "res://data/save_system/example_saves"
const SAVE_FILE_NAME: String = "save.sav"
const METADATA_FILE_NAME: String = "metadata.json"
const THUMBNAIL_FILE_NAME: String = "thumbnail.webp"
const GAME_STATE_SECTION: String = "game_state"


var _initialized: bool = false
var _save_version: int = 1

var _metadata_by_id: Dictionary[String, SaveMetadata] = {}
var _save_path_by_id: Dictionary[String, String] = {}
var _thumbnail_path_by_id: Dictionary[String, String] = {}


#region Initialization

## Initializes the built-in example save storage.
## Uses provided [param save_version] value to store it internally and later discern between different save versions. 
func initialize(save_version: int = 1) -> void:
	if _initialized:
		return
	
	_save_version = save_version
	_initialized = true

#endregion


#region Example Discovery

## Refreshes all examples found inside the packaged examples directory.
## Returns the discovered example IDs.
func refresh_examples() -> Array[String]:
	# Filter out processing if save storage wasn't initialized.
	if not _initialized:
		push_error("ExampleSaveStorage: refresh_examples() called before initialize().")
		return []
	
	# Clear existing found examples data.
	_metadata_by_id.clear()
	_save_path_by_id.clear()
	_thumbnail_path_by_id.clear()
	
	# Open examples directory.
	var directory := DirAccess.open(EXAMPLES_DIRECTORY)
	
	# Return empty list if the opened directory wasn't valid.
	if directory == null:
		return []
	
	# Check each existing directory in the examples directory and check if it contains the example save.
	directory.list_dir_begin()
	var item_name := directory.get_next()
	while not item_name.is_empty():
		if directory.current_is_dir() and not item_name.begins_with("."):
			_discover_example(item_name)
		
		item_name = directory.get_next()
	directory.list_dir_end()
	
	return list_example_ids()


## Discovers and validates one example directory for the provided [param example_id] example directory.
func _discover_example(example_id: String) -> void:
	# Filter out processing if the provided example ID is empty.
	if example_id.is_empty():
		return
	
	# Prepare variables for checking and discovering the example save files.
	var example_directory := EXAMPLES_DIRECTORY.path_join(example_id)
	var save_path := example_directory.path_join(SAVE_FILE_NAME)
	var metadata_path := example_directory.path_join(METADATA_FILE_NAME)
	var thumbnail_path := example_directory.path_join(THUMBNAIL_FILE_NAME)
	
	# Validate if the example directory contains the save file.
	if not FileAccess.file_exists(save_path):
		push_warning("ExampleSaveStorage: example \"%s\" is missing %s." % [example_id, SAVE_FILE_NAME])
		return
	
	# Validate if the example directory contains the metadata file.
	if not FileAccess.file_exists(metadata_path):
		push_warning("ExampleSaveStorage: example \"%s\" is missing %s." % [example_id, METADATA_FILE_NAME])
		return
	
	# Validate if the example directory contains the thumbnail file.
	if not FileAccess.file_exists(thumbnail_path):
		push_warning("ExampleSaveStorage: example \"%s\" is missing %s." % [example_id, THUMBNAIL_FILE_NAME])
		return
	
	# Read metadata file contents.
	var metadata := _read_metadata_file(example_id, metadata_path)
	
	# Filter out processing if the metadata is invalid or empty.
	if metadata == null:
		return
	
	if metadata.is_empty:
		push_warning("ExampleSaveStorage: example \"%s\" metadata describes an empty save." % example_id)
		return
	
	# Validate if the example save uses the same save version as the current one.
	if metadata.save_version != _save_version:
		push_warning("ExampleSaveStorage: example \"%s\" uses save version %d, but version %d is required." % [example_id, metadata.save_version, _save_version])
		return
	
	# Check if thumbnail exists.
	var thumbnail_exists: bool = false
	if ResourceLoader.exists(thumbnail_path, "Texture2D"):
		thumbnail_exists = true
	else:
		push_warning("ExampleSaveStorage: example \"%s\" does not have a valid thumbnail." % example_id)
	
	# Save example save details to the internal fields.
	_save_path_by_id[example_id] = save_path
	_metadata_by_id[example_id] = metadata
	_thumbnail_path_by_id[example_id] = thumbnail_path if thumbnail_exists else ""


## Reads an EasyStore metadata sidecar for the provided [param example_id] direcotry under the provided [param path] and returns it if it does exist.
func _read_metadata_file(example_id: String, path: String) -> SaveMetadata:
	# Open metadata file for reading.
	var file := FileAccess.open(path, FileAccess.READ)
	
	# Filter out processing if the file is invalid or empty.
	if file == null:
		push_warning("ExampleSaveStorage: could not open metadata for example \"%s\"." % example_id)
		return null
	
	# Read metadata file contents and try to parse it as JSON.
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_warning("ExampleSaveStorage: invalid metadata JSON for example \"%s\"." % example_id)
		return null
	
	# Validate if json data is dictionary.
	if not json.data is Dictionary:
		push_warning("ExampleSaveStorage: metadat for example \"%s\" is not a Dictionary." % example_id)
		return null
	
	# Prepare save metadata.
	var metadata := SaveMetadata.new()
	metadata.from_dict(json.data)
	
	return metadata


## Returns all discovered example IDs.
func list_example_ids() -> Array[String]:
	var result: Array[String] = []
	
	for example_id: String in _metadata_by_id.keys():
		result.append(example_id)
	result.sort()
	
	return result


## Checks whether the provided [param example_id] exists and returns a bool value indicating a result.
func has_example(example_id: String) -> bool:
	return _metadata_by_id.has(example_id)


## Returns the metadata for the provided [param example_id].
func get_metadata(example_id: String) -> SaveMetadata:
	return _metadata_by_id.get(example_id, null)


## Returns the packaged thumbnail path for the provided [param example_id].
func get_thumbnail_path(example_id: String) -> String:
	return _thumbnail_path_by_id.get(example_id, "")

#endregion


#region Loading

## Loads and returns the game_state section from a packaged example save using the provided [param example_id].
func load_example(example_id: String) -> Dictionary:
	# Filter out processing if save storage wasn't initialized.
	if not _initialized:
		push_error("ExampleSaveStorage: load_example() called before initialize().")
		return {}
	
	# Filter out processing if the example doesn't exist.
	if not has_example(example_id):
		push_error("ExampleSaveStorage: example \"%s\" does not exist." % example_id)
		return {}
	
	# Get save path.
	var save_path: String = _save_path_by_id.get(example_id, "")
	
	# Filter out processing if the save file doesn't exist under the discovered save path.
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		push_error("ExampleSaveStorage: save file for example \"%s\" is missing." % example_id)
		return {}
	
	# Open save file for reading.
	var file := FileAccess.open(save_path, FileAccess.READ)
	
	# Filter out processing if the file is invalid or empty.
	if file == null:
		push_error("ExampleSaveStorageL could not open example \"%s\"." % example_id)
		return {}
	
	# Read file contents.
	var raw := file.get_buffer(file.get_length())
	
	# Filter out processing if the file contents are empty.
	if raw.is_empty():
		push_error("ExampleSaveStorage: example \"%s\" contains no save data." % example_id)
		return {}
	
	# Try to decode the file contents into godot objects.
	var decoded: Variant = bytes_to_var(raw)
	
	# Filter out processing if the decoded data isn't dictionary.
	if not decoded is Dictionary:
		push_error("ExampleSaveStorage: example \"%s\" is not a valid EasyStore binary save." % example_id)
		return {}
	
	# Import decoded objects details into savefile.
	var save_file := SaveFile.new()
	save_file.from_dict(decoded)
	
	# Filter out processing if the save file version is different than the currently used one.
	if save_file.version != _save_version:
		push_error("ExampleSaveStorage: example \"%s\" uses save version %d, but version %d is required." % [example_id, save_file.version, _save_version])
		return {}
	
	# Filter out processing if the save file doesn't contain game state section details.
	if not save_file.has_section(GAME_STATE_SECTION):
		push_error("ExampleSaveStorage: example \"%s\" does not contain the \"%s\" section." % [example_id, GAME_STATE_SECTION])
		return {}
	
	# Get game state section from the save file.
	var game_state: Dictionary = save_file.get_section(GAME_STATE_SECTION)
	
	return game_state.duplicate(true)

#endregion


#region Thumbnails

## Loads the packaged thumbnail for the provided [param example_id] as an imported godot texture2d and returns it if it exists.
func load_thumbnail(example_id: String) -> Texture2D:
	# Get path for the thumbnail.
	var path := get_thumbnail_path(example_id)
	
	# Filter out processing if the path for the file is empty.
	if path.is_empty():
		return null
	
	# Load file under the path as texture2d.
	var resource := ResourceLoader.load(path, "Texture2D")
	
	# Return loaded resource if it was properly loaded as texture2d.
	if resource is Texture2D:
		return resource
	
	# Otherwise return empty result.
	return null

#endregion
