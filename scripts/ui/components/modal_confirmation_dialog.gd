class_name ModalConfirmationDialog
extends Control


signal decision_made(confirmed: bool)


@onready var title_label: Label = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/TitleLabel
@onready var message_label: Label = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/MessageLabel
@onready var cancel_button: Button = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/Buttons/CancelButton
@onready var confirm_button: Button = $CenterContainer/DialogPanel/MarginContainer/ContentsContainer/Buttons/ConfirmButton


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


## Cancels the active confirmation dialog when the cancel shortcut is pressed.
func _unhandled_key_input(event: InputEvent) -> void:
	# Filter out processing if the dialog isn't visible.
	if not is_visible_in_tree():
		return
	
	# Filter out unrelated or repeated keyboard input.
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	
	# Consume the shortcut before cancelling the dialog.
	get_viewport().set_input_as_handled()
	_on_cancel_pressed()


## Populates modal confirmation dialog, shows it, waits for a response from it and then hides it.
## By default the confirm button will be focussed on, but [param focus_cancel] flag can be set to set focus to the cancel button.
## Returns a bool value representing the confirmation response.
func request_confirmation(title: String, message: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel", focus_cancel: bool = false) -> bool:
	# Populate modal confirmation dialog.
	title_label.text = title
	message_label.text = message
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	
	# Show the modal.
	visible = true
	
	# Set confirmation button as focussed.
	if focus_cancel:
		cancel_button.grab_focus()
	else:
		confirm_button.grab_focus()
	
	# Wait for a signal containing a response from the modal. 
	var confirmed: bool = await decision_made
	
	# Hide the modal.
	visible = false
	
	return confirmed


func _on_confirm_pressed() -> void:
	decision_made.emit(true)


func _on_cancel_pressed() -> void:
	decision_made.emit(false)
