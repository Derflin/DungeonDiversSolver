class_name Main
extends Node


var _confirmation_pending: bool = false


@onready var map_display: MapDisplay = $World/MapRoot/MapDisplay
@onready var map_manager_control: MapManagerControl = $HudLayer/HudRoot/MapManagerControl

@onready var confirmation_dialog: ModalConfirmationDialog = $HudLayer/HudRoot/ModalConfirmationDialog


func _ready() -> void:
	# Connect signal from map manager to handle reset map state requested signal.
	map_manager_control.map_manager_reset_map_state_requested.connect(_on_map_manager_control_reset_map_state_requested)
	
	# Connect signal from map manager to handle reset map settings requested signal.
	map_manager_control.map_manager_reset_map_settings_requested.connect(_on_map_manager_control_reset_map_settings_requested)


## Toggles the application between windowed and fullscreen modes when the fullscreen shortcut is pressed.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		var window := get_window()
		if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_FULLSCREEN


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
