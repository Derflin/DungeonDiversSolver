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
	
	# Connect screenshot image preparation updates to the progress dialog.
	screenshot_importer.progress_changed.connect(screenshot_import_dialog.set_stage)
	screenshot_importer.screenshot_prepared.connect(_on_screenshot_prepared)
	screenshot_importer.import_failed.connect(screenshot_import_dialog.show_error)
	screenshot_importer.import_cancelled.connect(screenshot_import_dialog.show_cancelled)
	screenshot_import_dialog.cancel_requested.connect(screenshot_importer.request_cancel)


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
	
	# Open the platform-specific file picker from the button interaction.
	screenshot_image_input.request_image()


## Starts screenshot preparation after a file has been selected.
func _on_screenshot_image_file_selected(buffer: PackedByteArray, file_name: String) -> void:
	# Show activity feedback before beginning image decoding.
	screenshot_import_dialog.begin()
	await screenshot_importer.prepare_screenshot(buffer, file_name)


## Displays a file-selection error without changing the active map.
func _on_screenshot_image_input_error(message: String) -> void:
	screenshot_import_dialog.show_error(message)


## Displays the prepared screenshot and its source dimensions.
func _on_screenshot_prepared(image: Image, preview: Image, file_name: String) -> void:
	screenshot_import_dialog.show_prepared(image, preview, file_name)

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
