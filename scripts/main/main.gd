class_name Main
extends Node


var _confirmation_pending: bool = false


@onready var map_display: MapDisplay = $World/MapRoot/MapDisplay
@onready var map_manager_control: MapManagerControl = $HudLayer/HudRoot/MapManagerControl

@onready var confirmation_dialog: ModalConfirmationDialog = $HudLayer/HudRoot/ModalConfirmationDialog

@onready var screenshot_image_input: ScreenshotImageInput = $Systems/ScreenshotImageInput
@onready var screenshot_importer: ScreenshotImporter = $Systems/ScreenshotImporter
@onready var screenshot_import_dialog: ScreenshotImportDialog = $HudLayer/HudRoot/ScreenshotImportDialog


func _ready() -> void:
	# Connect signal from map manager to handle reset map state requested signal.
	map_manager_control.map_manager_reset_map_state_requested.connect(_on_map_manager_control_reset_map_state_requested)
	
	# Connect signal from map manager to handle reset map settings requested signal.
	map_manager_control.map_manager_reset_map_settings_requested.connect(_on_map_manager_control_reset_map_settings_requested)
	
	# Connect the screenshot import request and the file selection results.
	map_manager_control.map_manager_import_screenshot_requested.connect(_on_map_manager_control_import_screenshot_requested)
	screenshot_image_input.image_file_selected.connect(_on_screenshot_image_file_selected)
	screenshot_image_input.file_error.connect(_on_screenshot_image_input_error)
	
	# Open the file picker when the screenshot import dialog requests a file.
	screenshot_import_dialog.select_screenshot_requested.connect(_on_screenshot_import_dialog_select_screenshot_requested)
	
	# Request clipboard image input when the import dialog receives a paste shortcut.
	screenshot_import_dialog.paste_screenshot_requested.connect(_on_screenshot_import_dialog_paste_screenshot_requested)
	
	# Update the screenshot import dialog while a file is dragged over the application.
	screenshot_image_input.drop_hover_changed.connect(_on_screenshot_image_input_drop_hover_changed)
	
	# Connect screenshot image preparation updates to the progress dialog.
	screenshot_importer.progress_changed.connect(screenshot_import_dialog.set_stage)
	screenshot_importer.screenshot_prepared.connect(_on_screenshot_prepared)
	screenshot_importer.import_failed.connect(_on_screenshot_import_failed)
	screenshot_importer.import_cancelled.connect(_on_screenshot_import_cancelled)
	
	# Connect dialog cancellation and closing actions.
	screenshot_import_dialog.cancel_requested.connect(screenshot_importer.request_cancel)
	screenshot_import_dialog.close_requested.connect(_on_screenshot_import_dialog_closed)


## Handles keyboard shortcuts for toggling fullscreen and returning to windowed mode.
func _unhandled_key_input(event: InputEvent) -> void:
	# Filter out repeated input and active confirmation dialogs.
	if event.is_echo() or _confirmation_pending or screenshot_import_dialog.visible:
		return
	
	# Disable fullscreen keyboard shortcuts in web builds.
	if OS.has_feature("web"):
		return
	
	var window := get_window()
	var is_fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	
	# Toggle fullscreen mode.
	if event.is_action_pressed("toggle_fullscreen"):
		window.mode = Window.MODE_WINDOWED if is_fullscreen else Window.MODE_FULLSCREEN
		return
	
	# Exit fullscreen mode when the cancel shortcut is pressed.
	if event.is_action_pressed("ui_cancel") and is_fullscreen:
		window.mode = Window.MODE_WINDOWED
		get_viewport().set_input_as_handled()


#region Screenshot Import

## Opens the screenshot picker when the map manager requests an import.
func _on_map_manager_control_import_screenshot_requested() -> void:
	# Prevent opening the picker while another modal or import task is active.
	if _confirmation_pending or screenshot_import_dialog.visible or screenshot_importer.is_import_in_progress():
		return
	if map_manager_control.save_manager_control.visible:
		return
	
	# Open the screenshot input dialog instead of the file picker.
	screenshot_import_dialog.show_input()
	
	# Accept dropped screenshot files while the input dialog is waiting for a selection.
	screenshot_image_input.set_drop_enabled(true)
	
	# Accept clipboard images while the screenshot selection view is active.
	screenshot_image_input.set_paste_enabled(true)


## Opens the platform-specific screenshot file picker from the dialog.
func _on_screenshot_import_dialog_select_screenshot_requested() -> void:
	# Ignore requests after the dialog has closed or while analysis is active.
	if not screenshot_import_dialog.visible or screenshot_importer.is_import_in_progress():
		return
	
	# Open the file picker directly from the selection button's press event.
	screenshot_image_input.request_image()


## Requests a screenshot image from the desktop clipboard.
func _on_screenshot_import_dialog_paste_screenshot_requested() -> void:
	# Ignore requests outside the screenshot selection view.
	if not screenshot_import_dialog.visible or screenshot_importer.is_import_in_progress():
		return
	
	screenshot_image_input.request_clipboard_image()


## Updates the screenshot import dialog while a file is dragged over the application.
func _on_screenshot_image_input_drop_hover_changed(is_hovering: bool) -> void:
	if not screenshot_import_dialog.visible:
		return
	
	screenshot_import_dialog.set_drop_hovered(is_hovering)


## Starts screenshot preparation after a file has been selected.
func _on_screenshot_image_file_selected(buffer: PackedByteArray, file_name: String) -> void:
	# Ignore delayed file picker results when the input dialog is no longer active.
	if not screenshot_import_dialog.visible or screenshot_importer.is_import_in_progress():
		return
	
	# Stop accepting dropped files once a concrete screenshot is being prepared.
	screenshot_image_input.set_drop_enabled(false)
	
	# Stop accepting clipboard images while an image is being prepared.
	screenshot_image_input.set_paste_enabled(false)
	
	# Show activity feedback before beginning image decoding.
	screenshot_import_dialog.begin()
	await screenshot_importer.prepare_screenshot(buffer, file_name)


## Displays a file-selection error without changing the active map.
func _on_screenshot_image_input_error(message: String) -> void:
	# Ignore errors received after the dialog closes or while processing another image.
	if not screenshot_import_dialog.visible or screenshot_importer.is_import_in_progress():
		return
	
	# Keep screenshot selection available after a failed input attempt.
	screenshot_import_dialog.show_error(message)
	screenshot_image_input.set_drop_enabled(true)
	screenshot_image_input.set_paste_enabled(true)


## Displays the prepared screenshot and its source dimensions.
func _on_screenshot_prepared(image: Image, preview: Image, file_name: String) -> void:
	screenshot_import_dialog.show_prepared(image, preview, file_name)


## Displays an import error and restores screenshot selection.
func _on_screenshot_import_failed(message: String) -> void:
	# Ignore late completion events after the dialog has closed.
	if not screenshot_import_dialog.visible:
		return
	
	# Return to the selection view after screenshot preparation fails.
	screenshot_import_dialog.show_error(message)
	screenshot_image_input.set_drop_enabled(true)
	screenshot_image_input.set_paste_enabled(true)


## Restores screenshot selection after a preparation task is cancelled.
func _on_screenshot_import_cancelled() -> void:
	# Ignore late cancellation events after the dialog has closed.
	if not screenshot_import_dialog.visible:
		return
	
	# Make the available input methods active again.
	screenshot_import_dialog.show_cancelled()
	screenshot_image_input.set_drop_enabled(true)
	screenshot_image_input.set_paste_enabled(true)


## Disables screenshot input when the import dialog closes.
func _on_screenshot_import_dialog_closed() -> void:
	# Stop receiving dropped files and clipboard images outside the dialog.
	screenshot_image_input.set_drop_enabled(false)
	screenshot_image_input.set_paste_enabled(false)

#endregion


## Handles opening up the confirmation dialog for the map state reset and then if confirmed also handles map state reset process.
## After confirmation calls appropriate function from the GameState autoloaded scene to trigger the map state reset.
func _on_map_manager_control_reset_map_state_requested() -> void:
	# Show user the confirmation dialog and await his response.
	var confirmed := await _request_confirmation(
		"Reset Map",
		"Do you want to reset the current map to a default empty state?",
		"Reset",
		"Cancel",
		true
	)
	
	# Filter out processing if the user didn't confirm the reset operation.
	if not confirmed:
		return
	
	# Clear the map display room editor menu if it's opened.
	map_display.hide_map_room_editor_menu()
	
	# Reset game map state.
	GameState.reset_map_state_to_default()


## Handles opening up the confirmation dialog for the map settings reset and then if confirmed also handles map settings reset process.
## After confirmation calls appropriate function from the GameSettings autoloaded scene to trigger the map settings reset.
func _on_map_manager_control_reset_map_settings_requested() -> void:
	# Show user the confirmation dialog and await his response.
	var confirmed := await _request_confirmation(
		"Reset Settings",
		"Do you want to reset the current settings to a default empty state?",
		"Reset",
		"Cancel",
		true
	)
	
	# Filter out processing if the user didn't confirm the reset operation.
	if not confirmed:
		return
	
	# Reset game map settings.
	GameSettings.reset_map_settings_to_default()


#region Confirmation

## Checks if there aren't any other pending confirmation dialogs and creates a new one if that's case.
## All provided parameters are used as call parameters for requesting confirmation dialog.
func _request_confirmation(title: String, message: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel", focus_cancel: bool = false) -> bool:
	# Filter out processing if there is already an existing confirmation pending.
	if _confirmation_pending:
		return false
	
	# Mark confirmation as currently pending.
	_confirmation_pending = true
	
	# Show user the confirmation dialog and await his response.
	var confirmed := await confirmation_dialog.request_confirmation(
		title,
		message,
		confirm_text,
		cancel_text,
		focus_cancel,
	)
	
	# Mark confirmation as no longer pending.
	_confirmation_pending = false
	
	return confirmed

#endregion
