class_name PortableSaveFileIO
extends Node


signal import_file_selected(buffer: PackedByteArray, file_name: String)
signal file_error(message: String)


var _import_dialog: FileDialog
var _export_dialog: FileDialog
var _export_buffer: PackedByteArray = PackedByteArray()
var _web_file_callback: Variant = null


## Creates desktop file dialogs and connects their file selection signals.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Prepare the desktop import file dialog.
	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.filters = PackedStringArray(["*.ddsave ; Dungeon Divers Save"])
	_import_dialog.use_native_dialog = true
	add_child(_import_dialog)
	_import_dialog.file_selected.connect(_on_desktop_import_selected)
	
	# Prepare the desktop export file dialog.
	_export_dialog = FileDialog.new()
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.filters = PackedStringArray(["*.ddsave ; Dungeon Divers Save"])
	_export_dialog.use_native_dialog = true
	add_child(_export_dialog)
	_export_dialog.file_selected.connect(_on_desktop_export_selected)


## Opens a file picker and emits the selected portable save bytes.
func request_import() -> void:
	# Use the browser file picker for Web exports.
	if OS.has_feature("web"):
		_request_web_import()
		return
	
	# Open the desktop filesystem picker.
	_import_dialog.popup_centered_clamped()


## Exports [param buffer] using the provided [param suggested_name] file name.
## On desktop, the user selects the destination path before the bytes are written.
func request_export(buffer: PackedByteArray, suggested_name: String) -> void:
	if buffer.is_empty():
		file_error.emit("There is no portable save data to export.")
		return
	
	# Trigger the browser download from the active user interaction.
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(buffer, suggested_name, "application/octet-stream")
		return
	
	# Store the archive until the desktop destination is selected.
	_export_buffer = buffer
	_export_dialog.current_file = suggested_name
	_export_dialog.popup_centered_clamped()


## Reads the desktop file selected at [param path] and emits its contents.
func _on_desktop_import_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		file_error.emit("Cannot open the selected save file.")
		return
	
	if file.get_length() <= 0 or file.get_length() > PortableSaveService.MAX_ARCHIVE_BYTES:
		file_error.emit("Selected save file is empty or too large.")
		return
	
	import_file_selected.emit(file.get_buffer(file.get_length()), path.get_file())


## Writes the prepared export data to the selected [param path].
func _on_desktop_export_selected(path: String) -> void:
	if not path.to_lower().ends_with(PortableSaveService.SAVE_EXTENSION):
		path += PortableSaveService.SAVE_EXTENSION
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		file_error.emit("Cannot create the selected export file.")
		return
	
	file.store_buffer(_export_buffer)
	file.close()
	_export_buffer = PackedByteArray()


## Opens a browser file picker and forwards the selected file buffer to Godot.
func _request_web_import() -> void:
	# Keep the JavaScript callback alive for the asynchronous file selection.
	_web_file_callback = JavaScriptBridge.create_callback(_on_web_file_selected)
	var browser_window := JavaScriptBridge.get_interface("window")
	browser_window.dd_portable_save_file_callback = _web_file_callback
	
	# Create a temporary browser input element to request one portable save file.
	JavaScriptBridge.eval("""
		(function () {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.ddsave';
			input.addEventListener('change', async () => {
				const file = input.files && input.files[0];
				if (!file) return;
				if (file.size > 16 * 1024 * 1024) {
					window.dd_portable_save_file_callback(new Uint8Array());
					return;
				}
				try {
					const bytes = new Uint8Array(await file.arrayBuffer());
					window.dd_portable_save_file_callback(bytes, file.name);
				} catch (error) {
					window.dd_portable_save_file_callback(new Uint8Array());
				}
			});
			input.click();
		})();
	""")


## Converts the JavaScript [param args] buffer into a Godot byte array.
func _on_web_file_selected(args: Array) -> void:
	if args.is_empty() or not JavaScriptBridge.is_js_buffer(args[0]):
		file_error.emit("Browser did not return a valid file.")
		return
	
	var data := JavaScriptBridge.js_buffer_to_packed_byte_array(args[0])
	if data.is_empty():
		file_error.emit("Selected save file could not be read.")
		return
	
	import_file_selected.emit(data, str(args[1]) if args.size() > 1 else "Imported Save.ddsave")
