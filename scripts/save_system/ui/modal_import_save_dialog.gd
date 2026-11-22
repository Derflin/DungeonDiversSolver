class_name ModalImportSaveDialog
extends Control


signal file_requested
signal import_requested(slot: int)
signal cancelled


const AUTOMATIC_SLOT: int = -1
const TEXT_MUTED: Color = Color("b0b0b0")
const TEXT_ACCENT: Color = Color("e0c68d")
const TEXT_WARNING: Color = Color("e0ae76")


var _file_valid: bool = false
var _first_empty_slot: int = 1

var _slot_row_tween: Tween


@onready var choose_file_button: Button = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/SourceBodyMargin/SourceBodyContent/FileRow/ChooseFileButton
@onready var file_name_label: Label = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/SourceBodyMargin/SourceBodyContent/FileRow/FileNameLabel
@onready var save_info_row: HBoxContainer = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/SourceBodyMargin/SourceBodyContent/SaveInfoRow
@onready var save_name_label: Label = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/SourceBodyMargin/SourceBodyContent/SaveInfoRow/SaveNameLabel
@onready var file_message_label: Label = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/SourceBodyMargin/SourceBodyContent/FileMessageLabel
@onready var first_empty_radio: CheckBox = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/DestinationBodyMargin/DestinationBodyContent/DestinationOptions/FirstEmptyRadio
@onready var specific_slot_radio: CheckBox = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/DestinationBodyMargin/DestinationBodyContent/DestinationOptions/SpecificSlotRadio
@onready var specific_slot_row: HBoxContainer = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/DestinationBodyMargin/DestinationBodyContent/DestinationOptions/SpecificSlotRow
@onready var slot_number: SpinBox = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/DestinationBodyMargin/DestinationBodyContent/DestinationOptions/SpecificSlotRow/SlotNumber
@onready var slot_status_label: Label = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/DestinationBodyMargin/DestinationBodyContent/SlotStatusLabel
@onready var cancel_button: Button = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/Buttons/CancelButton
@onready var import_button: Button = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/Buttons/ImportButton


## Connects the dialog controls and initializes the destination selection.
func _ready() -> void:
	# Connect file selection, destination and dialog action signals.
	choose_file_button.pressed.connect(func() -> void: file_requested.emit())
	first_empty_radio.toggled.connect(_on_destination_mode_toggled)
	specific_slot_radio.toggled.connect(_on_destination_mode_toggled)
	slot_number.value_changed.connect(_on_slot_number_changed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	import_button.pressed.connect(_on_import_pressed)
	
	# Hide the modal until an import operation is requested.
	visible = false
	_refresh_destination()


## Opens the import dialog with [param first_empty_slot] as the default destination.
func open_dialog(first_empty_slot: int) -> void:
	# Reset the selected file and destination settings.
	_first_empty_slot = maxi(1, first_empty_slot)
	_file_valid = false
	file_name_label.text = "No file selected"
	file_message_label.text = "Select a portable save file."
	file_message_label.add_theme_color_override("font_color", TEXT_MUTED)
	file_message_label.visible = true
	file_name_label.add_theme_color_override("font_color", TEXT_MUTED)
	file_name_label.tooltip_text = ""
	save_info_row.visible = false
	save_name_label.text = ""
	save_name_label.tooltip_text = ""
	first_empty_radio.set_pressed_no_signal(true)
	specific_slot_radio.set_pressed_no_signal(false)
	slot_number.value = float(_first_empty_slot)
	
	# Display the modal and update its destination controls.
	_refresh_destination()
	visible = true
	choose_file_button.grab_focus()


## Displays information about the selected [param file_name] and its [param display_name].
func set_selected_file(file_name: String, display_name: String) -> void:
	# Display the archive filename with its full value available as a tooltip.
	_file_valid = true
	file_name_label.text = file_name.get_file()
	file_name_label.tooltip_text = file_name.get_file()
	file_name_label.add_theme_color_override("font_color", TEXT_ACCENT)
	
	# Show the decoded save name separately from file errors.
	save_name_label.text = display_name
	save_name_label.tooltip_text = display_name
	save_info_row.visible = true
	file_message_label.visible = false
	
	_refresh_destination()


## Displays the provided [param message] and disables importing the current file.
func show_file_error(message: String) -> void:
	_file_valid = false
	file_name_label.text = "No valid file selected"
	file_name_label.tooltip_text = ""
	file_name_label.add_theme_color_override("font_color", TEXT_MUTED)
	
	# Hide metadata from a previously validated file.
	save_info_row.visible = false
	save_name_label.text = ""
	
	file_message_label.text = message
	file_message_label.add_theme_color_override("font_color", TEXT_WARNING)
	file_message_label.visible = true
	_refresh_destination()


## Hides the dialog and clears its file selection state.
func close_dialog() -> void:
	visible = false
	_file_valid = false


## Returns the selected destination slot or AUTOMATIC_SLOT for the first free slot.
func get_destination_slot() -> int:
	if first_empty_radio.button_pressed:
		return AUTOMATIC_SLOT
	return maxi(1, int(slot_number.value))


## Updates the destination controls when a [param pressed] radio option changes.
func _on_destination_mode_toggled(pressed: bool) -> void:
	if pressed:
		_refresh_destination()


## Updates the destination information when the slot number [param _value] changes.
func _on_slot_number_changed(_value: float) -> void:
	_refresh_destination()


## Updates the available destination options and the import action state.
func _refresh_destination() -> void:
	if not is_node_ready():
		return
	
	# Update slot number selection field.
	var use_specific_slot := specific_slot_radio.button_pressed
	var selected_slot := int(slot_number.value) if use_specific_slot else _first_empty_slot
	_update_specific_slot_row(use_specific_slot)
	
	# Describe whether importing to the selected slot replaces saved data.
	if SaveManager.has_user_save(selected_slot):
		var occupied_entry := SaveManager.get_user_save(selected_slot)
		slot_status_label.text = "Slot %d: %s (replacement requires confirmation)." % [selected_slot, occupied_entry.display_name]
		slot_status_label.add_theme_color_override("font_color", TEXT_WARNING)
	else:
		slot_status_label.text = "Slot %d is empty." % selected_slot
		slot_status_label.add_theme_color_override("font_color", TEXT_MUTED)
	
	import_button.disabled = not _file_valid


## Updates the availability and appearance of the specific slot controls.
func _update_specific_slot_row(enabled: bool) -> void:
	# Keep the row visible to preserve the dialog layout.
	specific_slot_row.visible = true
	
	# Disable direct editing and interaction while the option is inactive.
	slot_number.editable = enabled
	slot_number.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	slot_number.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	
	# Disable indirect editing and interaction while the option is inactive through built-in line edit.
	var line_edit := slot_number.get_line_edit()
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	line_edit.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	line_edit.mouse_default_cursor_shape = Control.CURSOR_IBEAM if enabled else Control.CURSOR_ARROW
	if not enabled and line_edit.has_focus():
		line_edit.release_focus()
	
	# Stop any previous appearance transition.
	if _slot_row_tween and _slot_row_tween.is_running():
		_slot_row_tween.kill()
	_slot_row_tween = null
	
	# Prepare target opacity for the slot row.
	var target_alpha := 1.0 if enabled else 0.4
	
	# Avoid animating the initial layout while the modal is hidden.
	if not is_visible_in_tree():
		specific_slot_row.modulate.a = target_alpha
		return
	
	# Smoothly fade between active and inactive appearance.
	_slot_row_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_slot_row_tween.tween_property(specific_slot_row, "modulate:a", target_alpha, 0.15)


## Emits the selected import destination when the archive is valid.
func _on_import_pressed() -> void:
	if _file_valid:
		import_requested.emit(get_destination_slot())


## Closes the dialog and emits its cancellation signal.
func _on_cancel_pressed() -> void:
	close_dialog()
	cancelled.emit()
