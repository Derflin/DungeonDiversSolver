class_name Main
extends Node


var _confirmation_pending: bool = false


@onready var map_display: MapDisplay = $World/MapRoot/MapDisplay
@onready var map_manager_control: MapManagerControl = $HudLayer/HudRoot/MapManagerControl

@onready var confirmation_dialog: ModalConfirmationDialog = $HudLayer/HudRoot/ModalConfirmationDialog


func _ready() -> void:
	# Connect signal from map manager to handle reset map triggered signal.
	map_manager_control.map_manager_reset_map_triggered.connect(_on_map_manager_control_reset_map_triggered)


## Handles opening up the confirmation dialog for the map reset and then if confirmed also handles map reset process.
## After confirmation calls appropriate function from the GameState autoloaded scene to trigger the map reset.
func _on_map_manager_control_reset_map_triggered() -> void:
	# Show user the confirmation dialog and await his response.
	var confirmed := await _request_confirmation(
		"Reset Map",
		"Do you want to reset the current map to a default empty state?",
		"Reset",
		"Cancel",
		true
	)
	
	# Filter out processing if the user didn't confirm the overwrite save operation.
	if not confirmed:
		return
	
	# Clear the map display room editor menu if it's opened.
	map_display.hide_map_room_editor_menu()
	
	# Reset game state.
	GameState.reset_game_state_to_default()


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
