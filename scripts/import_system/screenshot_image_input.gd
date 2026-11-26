class_name ScreenshotImageInput
extends Node


signal image_file_selected(buffer: PackedByteArray, file_name: String)
signal file_error(message: String)
signal drop_hover_changed(is_hovering: bool)


const MAX_IMAGE_BYTES: int = 32 * 1024 * 1024


var _import_dialog: FileDialog
var _web_file_callback: Variant = null
var _request_pending: bool = false

var _web_drop_callback: Variant = null
var _web_drop_hover_callback: Variant = null
var _drop_enabled: bool = false


## Prepares the desktop file dialog and retains the browser file selection callback.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create a filesystem dialog for selecting screenshot files on desktop platforms.
	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.filters = PackedStringArray([
		"*.png ; PNG Images",
		"*.jpg, *.jpeg ; JPEG Images",
		"*.webp ; WebP Images",
	])
	_import_dialog.use_native_dialog = true
	add_child(_import_dialog)
	_import_dialog.file_selected.connect(_on_desktop_file_selected)
	_import_dialog.canceled.connect(_on_desktop_dialog_canceled)
	
	# Listen for native file drops on desktop platforms.
	get_window().files_dropped.connect(_on_desktop_files_dropped)
	
	# Keep the browser callback referenced for the lifetime of this node.
	if OS.has_feature("web"):
		_web_file_callback = JavaScriptBridge.create_callback(_on_web_file_selected)
		_web_drop_callback = JavaScriptBridge.create_callback(_on_web_file_dropped)
		_web_drop_hover_callback = JavaScriptBridge.create_callback(_on_web_drop_hover_changed)
		var browser_window := JavaScriptBridge.get_interface("window")
		browser_window.dd_solver_screenshot_file_callback = _web_file_callback
		browser_window.dd_solver_screenshot_drop_callback = _web_drop_callback
		browser_window.dd_solver_screenshot_drop_hover_callback = _web_drop_hover_callback


## Releases the browser callback reference when the input node leaves the scene tree.
func _exit_tree() -> void:
	if OS.has_feature("web"):
		_set_web_drop_enabled(false)
		JavaScriptBridge.eval("delete window.dd_solver_screenshot_file_callback;")
		JavaScriptBridge.eval("delete window.dd_solver_screenshot_drop_callback;")
		JavaScriptBridge.eval("delete window.dd_solver_screenshot_drop_hover_callback;")
		_web_file_callback = null
		_web_drop_callback = null
		_web_drop_hover_callback = null


## Opens the screenshot file picker on the current platform.
func request_image() -> void:
	# Reject overlapping file selection requests.
	if _request_pending:
		return
	
	_request_pending = true
	
	# Select files through a browser input in Web exports.
	if OS.has_feature("web"):
		_request_web_image()
		return
	
	# Select files through the desktop filesystem dialog.
	_import_dialog.popup_centered_clamped()


## Enables or disables drag-and-drop screenshot input.
func set_drop_enabled(enabled: bool) -> void:
	if _drop_enabled == enabled:
		return
	
	_drop_enabled = enabled
	drop_hover_changed.emit(false)
	
	if OS.has_feature("web"):
		_set_web_drop_enabled(_drop_enabled)


## Reads an image file from disk and emits its contents for screenshot decoding.
func _read_image_file_from_path(path: String) -> void:
	# Open the file and validate its encoded size before reading it.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		file_error.emit("Cannot open the selected screenshot file.")
		return
	
	var file_size: int = file.get_length()
	if file_size <= 0 or file_size > MAX_IMAGE_BYTES:
		file.close()
		file_error.emit("Screenshot file is empty or exceeds the 32 MiB limit.")
		return
	
	# Forward the screenshot bytes to the importer.
	var buffer: PackedByteArray = file.get_buffer(file_size)
	file.close()
	if buffer.size() != file_size:
		file_error.emit("Could not read the complete screenshot file.")
		return
	
	image_file_selected.emit(buffer, path.get_file())


#region Desktop File Selection

## Reads the selected desktop file and emits its binary contents.
func _on_desktop_file_selected(path: String) -> void:
	_request_pending = false
	_read_image_file_from_path(path)


## Clears the pending selection state when the desktop picker is dismissed.
func _on_desktop_dialog_canceled() -> void:
	_request_pending = false


## Reads a dropped image file when drag-and-drop import is active.
func _on_desktop_files_dropped(files: PackedStringArray) -> void:
	if not _drop_enabled or _request_pending:
		return
	if files.is_empty():
		return
	
	_request_pending = true
	drop_hover_changed.emit(false)
	
	# Use only the first dropped path for this importer.
	var path: String = files[0]
	_read_image_file_from_path(path)
	_request_pending = false

#endregion


#region Web File Selection

## Opens the browser file picker and forwards its bytes through the JavaScript callback.
func _request_web_image() -> void:
	JavaScriptBridge.eval("""
		(function () {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/png,image/jpeg,image/webp';
			input.style.display = 'none';
			document.body.appendChild(input);
			let finished = false;
			const send = (bytes, name, status) => {
				if (finished) return;
				finished = true;
				input.remove();
				window.dd_solver_screenshot_file_callback(bytes, name, status);
			};
			input.addEventListener('cancel', () => {
				send(new Uint8Array(), '', 'cancelled');
			});
			input.addEventListener('change', async () => {
				const file = input.files && input.files[0];
				if (!file) {
					send(new Uint8Array(), '', 'cancelled');
					return;
				}
				if (file.size === 0 || file.size > 32 * 1024 * 1024) {
					send(new Uint8Array(), file.name, 'invalid_size');
					return;
				}
				try {
					const bytes = new Uint8Array(await file.arrayBuffer());
					send(bytes, file.name, 'ok');
				} catch (error) {
					send(new Uint8Array(), file.name, 'read_error');
				}
			});
			input.click();
		})();
	""")


## Installs or removes browser drag-and-drop listeners for screenshot import.
func _set_web_drop_enabled(enabled: bool) -> void:
	JavaScriptBridge.eval("""
		(function (enabled) {
			if (window.ddSolverScreenshotDropCleanup) {
				window.ddSolverScreenshotDropCleanup();
				window.ddSolverScreenshotDropCleanup = null;
			}
			if (!enabled) {
				return;
			}
			const onDragOver = function (event) {
				event.preventDefault();
				if (event.dataTransfer) {
					event.dataTransfer.dropEffect = 'copy';
				}
				window.dd_solver_screenshot_drop_hover_callback(true);
			};
			const onDragLeave = function (event) {
				event.preventDefault();
				window.dd_solver_screenshot_drop_hover_callback(false);
			};
			const onDrop = async function (event) {
				event.preventDefault();
				window.dd_solver_screenshot_drop_hover_callback(false);
				const file = event.dataTransfer && event.dataTransfer.files && event.dataTransfer.files[0];
				if (!file) {
					window.dd_solver_screenshot_drop_callback(new Uint8Array(), '', 'cancelled');
					return;
				}
				if (file.size === 0 || file.size > 32 * 1024 * 1024) {
					window.dd_solver_screenshot_drop_callback(new Uint8Array(), file.name, 'invalid_size');
					return;
				}
				try {
					const bytes = new Uint8Array(await file.arrayBuffer());
					window.dd_solver_screenshot_drop_callback(bytes, file.name, 'ok');
				} catch (error) {
					window.dd_solver_screenshot_drop_callback(new Uint8Array(), file.name, 'read_error');
				}
			};
			window.addEventListener('dragover', onDragOver);
			window.addEventListener('dragleave', onDragLeave);
			window.addEventListener('drop', onDrop);
			window.ddSolverScreenshotDropCleanup = function () {
				window.removeEventListener('dragover', onDragOver);
				window.removeEventListener('dragleave', onDragLeave);
				window.removeEventListener('drop', onDrop);
			};
		})(%s);
	""" % ["true" if enabled else "false"])


## Converts browser-supplied image bytes into a Godot packed byte array.
func _on_web_file_selected(args: Array) -> void:
	_request_pending = false
	
	# Ignore file picker cancellation without reporting an import error.
	var status: String = str(args[2]) if args.size() > 2 else "read_error"
	if status == "cancelled":
		return
	if status == "invalid_size":
		file_error.emit("Screenshot file is empty or exceeds the 32 MiB limit.")
		return
	if status != "ok" or args.is_empty() or not JavaScriptBridge.is_js_buffer(args[0]):
		file_error.emit("Browser could not read the selected screenshot file.")
		return
	
	# Forward the selected file to the importer.
	var buffer: PackedByteArray = JavaScriptBridge.js_buffer_to_packed_byte_array(args[0])
	if buffer.is_empty() or buffer.size() > MAX_IMAGE_BYTES:
		file_error.emit("Screenshot file is empty or exceeds the 32 MiB limit.")
		return
	
	var file_name: String = str(args[1]) if args.size() > 1 else "Screenshot"
	image_file_selected.emit(buffer, file_name)


## Converts browser drag-and-drop image bytes into a Godot packed byte array.
func _on_web_file_dropped(args: Array) -> void:
	# Ignore dropped files while input is inactive or a file picker is pending.
	if not _drop_enabled or _request_pending:
		return
	
	# Ignore incomplete or cancelled drag operations.
	var status: String = str(args[2]) if args.size() > 2 else "read_error"
	if status == "cancelled":
		return
	if status == "invalid_size":
		file_error.emit("Screenshot file is empty or exceeds the 32 MiB limit.")
		return
	if status != "ok" or args.is_empty() or not JavaScriptBridge.is_js_buffer(args[0]):
		file_error.emit("Browser could not read the dropped screenshot file.")
		return
	
	var buffer: PackedByteArray = JavaScriptBridge.js_buffer_to_packed_byte_array(args[0])
	if buffer.is_empty() or buffer.size() > MAX_IMAGE_BYTES:
		file_error.emit("Screenshot file is empty or exceeds the 32 MiB limit.")
		return
	
	var file_name: String = str(args[1]) if args.size() > 1 else "Screenshot"
	image_file_selected.emit(buffer, file_name)


## Updates the dialog feedback while a file is dragged across the browser window.
func _on_web_drop_hover_changed(args: Array) -> void:
	if not _drop_enabled:
		return
	
	var is_hovering: bool = bool(args[0]) if not args.is_empty() else false
	drop_hover_changed.emit(is_hovering)

#endregion
