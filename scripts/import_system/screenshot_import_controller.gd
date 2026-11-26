class_name ScreenshotImportController
extends Node


@onready var screenshot_image_input: ScreenshotImageInput = $"../ScreenshotImageInput"
@onready var screenshot_importer: ScreenshotImporter = $"../ScreenshotImporter"
@onready var screenshot_import_dialog: ScreenshotImportDialog = $"../../HudLayer/HudRoot/ScreenshotImportDialog"


#region Initialization

## Connects screenshot input, processing, and dialog events.
func _ready() -> void:
	# Forward screenshot selection and input errors to the import workflow.
	screenshot_image_input.image_file_selected.connect(_on_image_file_selected)
	screenshot_image_input.file_error.connect(_on_image_input_error)
	screenshot_image_input.drop_hover_changed.connect(_on_drop_hover_changed)
	
	# Forward analysis progress and completion to the import dialog.
	screenshot_importer.progress_changed.connect(screenshot_import_dialog.set_stage)
	screenshot_importer.screenshot_prepared.connect(_on_screenshot_prepared)
	screenshot_importer.import_failed.connect(_on_import_failed)
	screenshot_importer.import_cancelled.connect(_on_import_cancelled)
	
	# Route dialog actions to their corresponding input or processing operations.
	screenshot_import_dialog.select_screenshot_requested.connect(_on_select_screenshot_requested)
	screenshot_import_dialog.paste_screenshot_requested.connect(_on_paste_screenshot_requested)
	screenshot_import_dialog.cancel_requested.connect(screenshot_importer.request_cancel)
	screenshot_import_dialog.close_requested.connect(_on_dialog_closed)

#endregion


#region Dialog Lifecycle

## Opens the screenshot selection dialog when the import workflow is idle.
func open_dialog() -> void:
	if screenshot_import_dialog.visible or screenshot_importer.is_import_in_progress():
		return
	
	# Prepare the selection view and activate its supported input methods.
	screenshot_import_dialog.show_input()
	_set_input_active(true)


## Returns whether the screenshot import dialog is visible.
func is_dialog_open() -> bool:
	return screenshot_import_dialog.visible


## Updates drag-and-drop and clipboard availability for the selection view.
func _set_input_active(active: bool) -> void:
	screenshot_image_input.set_drop_enabled(active)
	screenshot_image_input.set_paste_enabled(active)


## Disables screenshot input when the dialog has been dismissed.
func _on_dialog_closed() -> void:
	_set_input_active(false)

#endregion


#region Screenshot Input

## Opens the platform-specific screenshot file picker from the selection view.
func _on_select_screenshot_requested() -> void:
	if not screenshot_import_dialog.is_waiting_for_input():
		return
	
	screenshot_image_input.request_image()


## Requests the image pixels currently available from the desktop clipboard.
func _on_paste_screenshot_requested() -> void:
	if not screenshot_import_dialog.is_waiting_for_input():
		return
	
	screenshot_image_input.request_clipboard_image()


## Starts screenshot preparation after input supplies image data.
func _on_image_file_selected(buffer: PackedByteArray, file_name: String) -> void:
	if not screenshot_import_dialog.is_waiting_for_input() or screenshot_importer.is_import_in_progress():
		return
	
	# Disable additional input before reporting processing progress.
	_set_input_active(false)
	screenshot_import_dialog.begin()
	await screenshot_importer.prepare_screenshot(buffer, file_name)


## Displays an input error and allows another screenshot selection.
func _on_image_input_error(message: String) -> void:
	if not screenshot_import_dialog.is_waiting_for_input():
		return
	
	screenshot_import_dialog.show_error(message)
	_set_input_active(true)


## Updates drop-target feedback while the selection dialog is active.
func _on_drop_hover_changed(is_hovering: bool) -> void:
	if screenshot_import_dialog.is_waiting_for_input():
		screenshot_import_dialog.set_drop_hovered(is_hovering)

#endregion


#region Preparation Results

## Displays the decoded screenshot preview after successful preparation.
func _on_screenshot_prepared(image: Image, preview: Image, file_name: String) -> void:
	if screenshot_import_dialog.visible:
		screenshot_import_dialog.show_prepared(image, preview, file_name)


## Displays a screenshot preparation error and restores input availability.
func _on_import_failed(message: String) -> void:
	if not screenshot_import_dialog.visible:
		return
	
	screenshot_import_dialog.show_error(message)
	_set_input_active(true)


## Restores screenshot selection after preparation is cancelled.
func _on_import_cancelled() -> void:
	if not screenshot_import_dialog.visible:
		return
	
	screenshot_import_dialog.show_cancelled()
	_set_input_active(true)

#endregion
