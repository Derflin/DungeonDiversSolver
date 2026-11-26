class_name ScreenshotImportDialog
extends Control


signal cancel_requested()
signal close_requested()
signal select_screenshot_requested()
signal paste_screenshot_requested()


var _processing: bool = false
var _drop_hovered: bool = false


@onready var input_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/Contents/InputContainer
@onready var select_screenshot_button: Button = $CenterContainer/PanelContainer/MarginContainer/Contents/InputContainer/SelectScreenshotButton
@onready var drop_target_title_label: Label = $CenterContainer/PanelContainer/MarginContainer/Contents/InputContainer/DropTargetPanel/DropTargetMargin/DropTargetContents/DropTargetTitleLabel
@onready var stage_label: Label = $CenterContainer/PanelContainer/MarginContainer/Contents/StageLabel
@onready var progress_bar: ProgressBar = $CenterContainer/PanelContainer/MarginContainer/Contents/ProgressBar
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/Contents/MessageLabel
@onready var preview_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/Contents/PreviewContainer
@onready var preview_texture: TextureRect = $CenterContainer/PanelContainer/MarginContainer/Contents/PreviewContainer/PreviewTexture
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/Contents/CloseButton


#region Initialization

## Connects the dialog controls and initializes the progress display.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect the screenshot selection and dialog dismissal controls.
	select_screenshot_button.pressed.connect(_on_select_screenshot_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	visible = false

#endregion


#region Dialog Views

## Displays the screenshot selection controls and resets the previous result.
func show_input() -> void:
	_processing = false
	visible = true
	
	# Show selection controls without presenting processing or result details.
	input_container.visible = true
	stage_label.visible = false
	progress_bar.visible = false
	message_label.visible = false
	preview_container.visible = false
	preview_texture.texture = null
	
	# Reset the drop-target visuals whenever the selection view is shown.
	_drop_hovered = false
	_update_drop_target_state()
	
	# Restore the dialog dismissal control and focus the primary action.
	close_button.text = "Close"
	close_button.disabled = false
	select_screenshot_button.grab_focus()


## Returns whether the dialog is accepting new screenshot input.
func is_waiting_for_input() -> bool:
	return is_visible_in_tree() and input_container.visible and not _processing


## Displays the progress dialog for a newly selected screenshot.
func begin() -> void:
	_processing = true
	visible = true
	
	# Replace screenshot selection controls with processing feedback.
	input_container.visible = false
	stage_label.visible = true
	progress_bar.visible = true
	message_label.visible = true
	
	# Clear the drop-target feedback while processing is active.
	_drop_hovered = false
	_update_drop_target_state()
	
	stage_label.text = "Preparing screenshot"
	message_label.text = "Reading the selected image."
	progress_bar.indeterminate = true
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	preview_container.visible = false
	preview_texture.texture = null
	close_button.text = "Cancel"
	close_button.disabled = false


## Updates the current processing stage and its measured progress.
func set_stage(stage: String, completed: int, total: int, indeterminate: bool) -> void:
	if not _processing:
		return
	
	stage_label.text = stage
	progress_bar.indeterminate = indeterminate or total <= 0
	if not progress_bar.indeterminate:
		progress_bar.min_value = 0.0
		progress_bar.max_value = float(maxi(1, total))
		progress_bar.value = float(clampi(completed, 0, total))


## Displays the decoded screenshot preview without modifying the active map.
func show_prepared(image: Image, preview: Image, file_name: String) -> void:
	_processing = false
	
	# Display the completed result instead of the screenshot selection view.
	input_container.visible = false
	stage_label.visible = true
	progress_bar.visible = true
	message_label.visible = true
	
	# Reset the drop-target feedback after processing finishes.
	_drop_hovered = false
	_update_drop_target_state()
	
	stage_label.text = "Screenshot ready"
	message_label.text = "%s — %d × %d pixels\nMap recognition is not implemented yet. The current map was not changed." % [file_name, image.get_width(), image.get_height()]
	progress_bar.indeterminate = false
	progress_bar.max_value = 1.0
	progress_bar.value = 1.0
	preview_texture.texture = ImageTexture.create_from_image(preview)
	preview_container.visible = true
	close_button.text = "Close"
	close_button.disabled = false


## Displays an error and keeps screenshot selection available for another attempt.
func show_error(message: String) -> void:
	_show_selection_message("Screenshot could not be prepared", message)


## Displays the result of a cancelled screenshot preparation task.
func show_cancelled() -> void:
	_show_selection_message("Screenshot preparation cancelled", "The current map was not changed.")


## Displays a message with the screenshot selection controls available.
func _show_selection_message(title: String, message: String) -> void:
	_processing = false
	visible = true
	
	# Restore the selection controls and hide any stale preview or progress bar.
	input_container.visible = true
	stage_label.visible = true
	progress_bar.visible = false
	message_label.visible = true
	preview_container.visible = false
	preview_texture.texture = null
	
	# Reset the drop target and present the result message.
	_drop_hovered = false
	_update_drop_target_state()
	stage_label.text = title
	message_label.text = message
	progress_bar.indeterminate = false
	progress_bar.value = 0.0
	close_button.text = "Close"
	close_button.disabled = false

#endregion


#region Input Events

## Handles the cancel shortcut while the progress dialog is visible.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo() or not event.is_action_pressed("ui_cancel"):
		return
	
	get_viewport().set_input_as_handled()
	_on_close_button_pressed()


## Requests clipboard image input when the selection view receives a paste shortcut.
func _input(event: InputEvent) -> void:
	# Browser clipboard input is handled through the page's paste event.
	if OS.has_feature("web"):
		return
	
	if not is_visible_in_tree() or not input_container.visible or _processing:
		return
	if not (event is InputEventKey):
		return
	
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	
	# Recognize the platform paste shortcut without affecting other key presses.
	var paste_modifier_pressed: bool = key_event.ctrl_pressed or key_event.meta_pressed
	var paste_key_pressed: bool = key_event.keycode == KEY_V or key_event.physical_keycode == KEY_V
	if not paste_modifier_pressed or not paste_key_pressed:
		return
	
	get_viewport().set_input_as_handled()
	paste_screenshot_requested.emit()


## Cancels active processing or closes the completed dialog.
func _on_close_button_pressed() -> void:
	if close_button.disabled:
		return
	
	if _processing:
		close_button.disabled = true
		close_button.text = "Cancelling..."
		cancel_requested.emit()
		return
	
	visible = false
	close_requested.emit()


## Requests a screenshot file selection when the dialog is idle.
func _on_select_screenshot_button_pressed() -> void:
	# Accept selection only while the dialog is waiting for screenshot input.
	if not is_waiting_for_input():
		return
	
	select_screenshot_requested.emit()

#endregion


#region Drop Target Feedback

## Updates the drop-target appearance while a file is dragged over the dialog.
func set_drop_hovered(is_hovered: bool) -> void:
	if _drop_hovered == is_hovered:
		return
	
	_drop_hovered = is_hovered
	_update_drop_target_state()


## Refreshes the drop-target text according to its current hover state.
func _update_drop_target_state() -> void:
	if _drop_hovered:
		drop_target_title_label.text = "Release to import the screenshot"
	else:
		drop_target_title_label.text = "Drag and drop a screenshot here"

#endregion
