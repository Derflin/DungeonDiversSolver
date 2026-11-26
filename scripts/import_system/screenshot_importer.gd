class_name ScreenshotImporter
extends Node


signal progress_changed(stage: String, completed: int, total: int, indeterminate: bool)
signal screenshot_prepared(source_image: Image, preview_image: Image, file_name: String)
signal import_failed(message: String)
signal import_cancelled()


const MAX_IMAGE_BYTES: int = 32 * 1024 * 1024
const MAX_IMAGE_PIXELS: int = 32 * 1000 * 1000
const PREVIEW_MAX_SIDE: int = 640


var source_image: Image = null
var preview_image: Image = null
var _is_processing: bool = false
var _cancel_requested: bool = false


#region Preparation Lifecycle

## Returns whether a screenshot import operation is currently active.
func is_import_in_progress() -> bool:
	return _is_processing


## Requests cancellation at the next available processing checkpoint.
func request_cancel() -> void:
	if _is_processing:
		_cancel_requested = true


## Decodes a screenshot and prepares an image sample for subsequent analysis.
func prepare_screenshot(buffer: PackedByteArray, file_name: String) -> void:
	# Prevent concurrent analysis tasks from modifying the cached screenshot.
	if _is_processing:
		return
	
	_is_processing = true
	_cancel_requested = false
	source_image = null
	preview_image = null
	
	# Validate the encoded file before attempting to decode it.
	progress_changed.emit("Validating screenshot file", 0, 0, true)
	await get_tree().process_frame
	if _finish_if_cancelled():
		return
	if buffer.is_empty() or buffer.size() > MAX_IMAGE_BYTES:
		_fail("Screenshot file is empty or exceeds the 32 MiB limit.")
		return
	
	# Decode the file using its content signature.
	var image_format: String = _detect_image_format(buffer)
	if image_format.is_empty():
		_fail("Unsupported screenshot format. Select a PNG, JPEG, or WebP image.")
		return
	
	progress_changed.emit("Decoding screenshot", 0, 0, true)
	await get_tree().process_frame
	if _finish_if_cancelled():
		return
	
	var image := Image.new()
	var decode_error: Error = FAILED
	match image_format:
		"png":
			decode_error = image.load_png_from_buffer(buffer)
		"jpeg":
			decode_error = image.load_jpg_from_buffer(buffer)
		"webp":
			decode_error = image.load_webp_from_buffer(buffer)
	
	if _finish_if_cancelled():
		return
	if decode_error != OK or image.is_empty():
		_fail("The selected screenshot could not be decoded.")
		return
	
	# Validate the decoded image dimensions before allocating a preview.
	var image_size: Vector2i = image.get_size()
	if image_size.x <= 0 or image_size.y <= 0 or image_size.x * image_size.y > MAX_IMAGE_PIXELS:
		_fail("Screenshot dimensions exceed the supported 32-megapixel limit.")
		return
	
	# Prepare a smaller image for preview and future low-resolution analysis.
	progress_changed.emit("Preparing screenshot preview", 0, 0, true)
	await get_tree().process_frame
	if _finish_if_cancelled():
		return
	
	var sample: Image = image.duplicate() as Image
	var max_side: int = maxi(image_size.x, image_size.y)
	if max_side > PREVIEW_MAX_SIDE:
		var scale_factor: float = float(PREVIEW_MAX_SIDE) / float(max_side)
		var sample_size := Vector2i(
			maxi(1, roundi(float(image_size.x) * scale_factor)),
			maxi(1, roundi(float(image_size.y) * scale_factor)),
		)
		sample.resize(sample_size.x, sample_size.y, Image.INTERPOLATE_BILINEAR)
	
	if _finish_if_cancelled():
		return
	
	# Retain decoded images for the next analysis stage and report success.
	source_image = image
	preview_image = sample
	_is_processing = false
	progress_changed.emit("Screenshot ready", 1, 1, false)
	screenshot_prepared.emit(source_image, preview_image, file_name)

#endregion


#region Image Format Detection

## Identifies supported screenshot formats using the encoded file signature.
func _detect_image_format(buffer: PackedByteArray) -> String:
	# Detect PNG from its eight-byte header.
	if buffer.size() >= 8:
		if buffer[0] == 0x89 and buffer[1] == 0x50 and buffer[2] == 0x4E and buffer[3] == 0x47 and buffer[4] == 0x0D and buffer[5] == 0x0A and buffer[6] == 0x1A and buffer[7] == 0x0A:
			return "png"
	
	# Detect JPEG from its start-of-image marker.
	if buffer.size() >= 3:
		if buffer[0] == 0xFF and buffer[1] == 0xD8 and buffer[2] == 0xFF:
			return "jpeg"
	
	# Detect WebP from its RIFF container markers.
	if buffer.size() >= 12:
		if buffer.slice(0, 4).get_string_from_ascii() == "RIFF" and buffer.slice(8, 12).get_string_from_ascii() == "WEBP":
			return "webp"
	
	return ""

#endregion


#region Processing Completion

## Completes the current task when cancellation has been requested.
func _finish_if_cancelled() -> bool:
	if not _cancel_requested:
		return false
	
	_is_processing = false
	_cancel_requested = false
	import_cancelled.emit()
	return true


## Ends the current task and reports the provided error message.
func _fail(message: String) -> void:
	_is_processing = false
	_cancel_requested = false
	import_failed.emit(message)

#endregion
