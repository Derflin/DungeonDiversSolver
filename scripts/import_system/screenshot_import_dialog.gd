class_name ScreenshotImportDialog
extends Control


signal cancel_requested()
signal close_requested()


var _processing: bool = false


@onready var stage_label: Label = $CenterContainer/PanelContainer/MarginContainer/Contents/StageLabel
@onready var progress_bar: ProgressBar = $CenterContainer/PanelContainer/MarginContainer/Contents/ProgressBar
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/Contents/MessageLabel
@onready var preview_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/Contents/PreviewContainer
@onready var preview_texture: TextureRect = $CenterContainer/PanelContainer/MarginContainer/Contents/PreviewContainer/PreviewTexture
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/Contents/CloseButton


## Connects the dialog controls and initializes the progress display.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_on_close_button_pressed)
	visible = false


## Displays the progress dialog for a newly selected screenshot.
func begin() -> void:
	_processing = true
	visible = true
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
	stage_label.text = "Screenshot ready"
	message_label.text = "%s — %d × %d pixels\nMap recognition is not implemented yet. The current map was not changed." % [file_name, image.get_width(), image.get_height()]
	progress_bar.indeterminate = false
	progress_bar.max_value = 1.0
	progress_bar.value = 1.0
	preview_texture.texture = ImageTexture.create_from_image(preview)
	preview_container.visible = true
	close_button.text = "Close"
	close_button.disabled = false


## Displays an error message and allows the user to close the dialog.
func show_error(message: String) -> void:
	_processing = false
	visible = true
	stage_label.text = "Screenshot could not be prepared"
	message_label.text = message
	progress_bar.indeterminate = false
	progress_bar.value = 0.0
	preview_container.visible = false
	close_button.text = "Close"
	close_button.disabled = false


## Displays the result of a cancelled preparation task.
func show_cancelled() -> void:
	_processing = false
	stage_label.text = "Screenshot preparation cancelled"
	message_label.text = "The current map was not changed."
	progress_bar.indeterminate = false
	progress_bar.value = 0.0
	preview_container.visible = false
	close_button.text = "Close"
	close_button.disabled = false


## Handles the cancel shortcut while the progress dialog is visible.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo() or not event.is_action_pressed("ui_cancel"):
		return
	
	get_viewport().set_input_as_handled()
	_on_close_button_pressed()


## Cancels active processing or closes the completed dialog.
func _on_close_button_pressed() -> void:
	if _processing:
		close_button.disabled = true
		close_button.text = "Cancelling..."
		cancel_requested.emit()
		return
	
	visible = false
	close_requested.emit()
