class_name PortableSaveService
extends RefCounted


const FORMAT_ID: String = "dungeon-divers-solver-save"
const FORMAT_VERSION: int = 1
const SAVE_EXTENSION: String = ".ddsave"
const MAX_ARCHIVE_BYTES: int = 16 * 1024 * 1024
const MAX_GAME_STATE_BYTES: int = 8 * 1024 * 1024
const MAX_THUMBNAIL_BYTES: int = 6 * 1024 * 1024
const MAX_MANIFEST_BYTES: int = 128 * 1024

const MANIFEST_ENTRY: String = "manifest.json"
const GAME_STATE_ENTRY: String = "game_state.bin"
const THUMBNAIL_ENTRY: String = "thumbnail.webp"

const TEMP_EXPORT_PATH: String = "user://portable_save_export.tmp"
const TEMP_IMPORT_PATH: String = "user://portable_save_import.tmp"


## Builds a portable archive containing the provided [param payload] save data and associated metadata.
## Returns a dictionary with success, buffer, and error fields.
static func encode(payload: Dictionary) -> Dictionary:
	# Validate the provided game state and metadata.
	var game_state: Variant = payload.get("game_state", null)
	if not game_state is Dictionary or game_state.is_empty():
		return _failure("Game state is missing or invalid.")
	
	var save_bytes := var_to_bytes(game_state)
	if save_bytes.is_empty() or save_bytes.size() > MAX_GAME_STATE_BYTES:
		return _failure("Game state exceeds the supported size.")
	
	# Prepare the portable save manifest.
	var manifest := {
		"format": FORMAT_ID,
		"format_version": FORMAT_VERSION,
		"save_version": int(payload.get("save_version", -1)),
		"display_name": str(payload.get("display_name", "")),
		"description": str(payload.get("description", "")),
		"game_metadata": payload.get("game_metadata", []),
		"has_thumbnail": false,
	}
	
	# Encode the thumbnail image when one is available.
	var thumbnail_bytes := PackedByteArray()
	var thumbnail: Variant = payload.get("thumbnail", null)
	if thumbnail is Image and not thumbnail.is_empty():
		thumbnail_bytes = thumbnail.save_webp_to_buffer()
		if thumbnail_bytes.is_empty() or thumbnail_bytes.size() > MAX_THUMBNAIL_BYTES:
			return _failure("Thumbnail cannot be included in the archive.")
		manifest["has_thumbnail"] = true
	
	var manifest_bytes := JSON.stringify(manifest).to_utf8_buffer()
	if manifest_bytes.size() > MAX_MANIFEST_BYTES:
		return _failure("Save metadata exceeds the supported size.")
	
	# Create the archive in a temporary user data file.
	var packer := ZIPPacker.new()
	if packer.open(TEMP_EXPORT_PATH) != OK:
		return _failure("Cannot create the temporary export archive.")
	
	var success := _write_entry(packer, MANIFEST_ENTRY, manifest_bytes)
	if success:
		success = _write_entry(packer, GAME_STATE_ENTRY, save_bytes)
	if success and not thumbnail_bytes.is_empty():
		success = _write_entry(packer, THUMBNAIL_ENTRY, thumbnail_bytes)
	packer.close()
	
	if not success:
		_remove_temp_file(TEMP_EXPORT_PATH)
		return _failure("Cannot write the portable save archive.")
	
	# Read the completed archive and remove the temporary file.
	var archive := FileAccess.get_file_as_bytes(TEMP_EXPORT_PATH)
	_remove_temp_file(TEMP_EXPORT_PATH)
	if archive.is_empty() or archive.size() > MAX_ARCHIVE_BYTES:
		return _failure("Portable save archive exceeds the supported size.")
	
	return {"success": true, "buffer": archive, "error": ""}


## Reads [param archive_bytes] and returns its validated game state, metadata and optional thumbnail.
## The [param expected_save_version] must match the save version declared in the archive.
static func decode(archive_bytes: PackedByteArray, expected_save_version: int) -> Dictionary:
	# Check the size of the selected file before opening it as an archive.
	if archive_bytes.is_empty() or archive_bytes.size() > MAX_ARCHIVE_BYTES:
		return _failure("Selected file is empty or too large.")
	
	# Write the selected bytes to a temporary file for ZIPReader.
	var temp := FileAccess.open(TEMP_IMPORT_PATH, FileAccess.WRITE)
	if temp == null:
		return _failure("Cannot prepare the selected save file.")
	temp.store_buffer(archive_bytes)
	temp.close()
	
	var reader := ZIPReader.new()
	if reader.open(TEMP_IMPORT_PATH) != OK:
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("Selected file is not a readable archive.")
	
	# Reject archives with missing or unexpected members.
	var members := reader.get_files()
	if not members.has(MANIFEST_ENTRY) or not members.has(GAME_STATE_ENTRY):
		reader.close()
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("Portable save archive is missing required files.")
	for member: String in members:
		if member != MANIFEST_ENTRY and member != GAME_STATE_ENTRY and member != THUMBNAIL_ENTRY:
			reader.close()
			_remove_temp_file(TEMP_IMPORT_PATH)
			return _failure("Portable save archive contains an unexpected file.")
	
	# Read the manifest and serialized game state.
	var manifest_bytes := reader.read_file(MANIFEST_ENTRY)
	var save_bytes := reader.read_file(GAME_STATE_ENTRY)
	if manifest_bytes.is_empty() or manifest_bytes.size() > MAX_MANIFEST_BYTES or save_bytes.is_empty() or save_bytes.size() > MAX_GAME_STATE_BYTES:
		reader.close()
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("Portable save contents are missing or exceed the supported size.")
	
	# Validate the manifest format and save version.
	var manifest_json := JSON.new()
	if manifest_json.parse(manifest_bytes.get_string_from_utf8()) != OK or not manifest_json.data is Dictionary:
		reader.close()
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("Portable save metadata is invalid.")
	var manifest: Dictionary = manifest_json.data
	if str(manifest.get("format", "")) != FORMAT_ID or int(manifest.get("format_version", -1)) != FORMAT_VERSION:
		reader.close()
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("Portable save format is not supported.")
	if int(manifest.get("save_version", -1)) != expected_save_version:
		reader.close()
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("This save uses an incompatible save version.")
	
	# Decode the game state without allowing serialized Object instances.
	var decoded: Variant = bytes_to_var(save_bytes)
	if not decoded is Dictionary or decoded.is_empty():
		reader.close()
		_remove_temp_file(TEMP_IMPORT_PATH)
		return _failure("Portable save game state is invalid.")
	
	# Decode the optional thumbnail and validate its size.
	var thumbnail: Image = null
	if bool(manifest.get("has_thumbnail", false)):
		if not reader.file_exists(THUMBNAIL_ENTRY):
			reader.close()
			_remove_temp_file(TEMP_IMPORT_PATH)
			return _failure("Portable save thumbnail is missing.")
		var image_bytes := reader.read_file(THUMBNAIL_ENTRY)
		if image_bytes.is_empty() or image_bytes.size() > MAX_THUMBNAIL_BYTES:
			reader.close()
			_remove_temp_file(TEMP_IMPORT_PATH)
			return _failure("Portable save thumbnail exceeds the supported size.")
		thumbnail = Image.new()
		if thumbnail.load_webp_from_buffer(image_bytes) != OK or thumbnail.get_width() > 4096 or thumbnail.get_height() > 4096:
			reader.close()
			_remove_temp_file(TEMP_IMPORT_PATH)
			return _failure("Portable save thumbnail could not be decoded.")
	
	reader.close()
	_remove_temp_file(TEMP_IMPORT_PATH)
	
	# Rebuild game metadata using dictionaries supported by the Save Manager.
	var game_metadata: Array[Dictionary] = []
	var raw_metadata: Variant = manifest.get("game_metadata", [])
	if raw_metadata is Array:
		for item: Variant in raw_metadata:
			if item is Dictionary:
				game_metadata.append(item.duplicate(true))
	
	var payload := {
		"game_state": decoded,
		"display_name": str(manifest.get("display_name", "")),
		"description": str(manifest.get("description", "")),
		"game_metadata": game_metadata,
		"thumbnail": thumbnail,
		"save_version": expected_save_version,
	}
	return {"success": true, "payload": payload, "error": ""}


## Writes [param data] into the named [param entry_name] member of [param packer].
static func _write_entry(packer: ZIPPacker, entry_name: String, data: PackedByteArray) -> bool:
	if packer.start_file(entry_name) != OK:
		return false
	var write_error := packer.write_file(data)
	var close_error := packer.close_file()
	return write_error == OK and close_error == OK


## Removes the temporary [param path] file if it exists.
static func _remove_temp_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Creates a failed result containing the provided [param message].
static func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message}
