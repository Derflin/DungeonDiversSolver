extends Node


signal map_secrets_count_current_changed(kind: RoomSecretType.Kind, value: int)

@warning_ignore("unused_signal")
signal map_solver_submenu_opened()
@warning_ignore("unused_signal")
signal map_parameters_submenu_opened()

@warning_ignore("unused_signal")
signal map_solver_state_change_triggered(state: MapSolverState, secret_room_kind: RoomSecretType.Kind)
signal map_solver_state_changed()


enum MapSolverState {
	NONE,
	PLACEMENT_HINT,
	WEIGHT_HINT,
	SOLUTION_SHOW,
}


var map_state: MapState

var map_secrets_count_current: Dictionary[RoomSecretType.Kind, int]

var map_solver_state: MapSolverState = MapSolverState.NONE
var map_solver_secret_kind: RoomSecretType.Kind = RoomSecretType.Kind.NONE
var map_solver_result: MapSolverResult = null


func _ready() -> void:
	# Initialize map_state variable
	map_state = MapState.new()
	
	# Initialize map_secrets_count_max variable
	var secret_types_kinds = GameData.room_secret_types.get_all_kinds()
	for secret_type_kind in secret_types_kinds:
		map_secrets_count_current[secret_type_kind] = 0
	
	# Connect signals that might trigger change to the map solver result
	map_state.room_state_changed.connect(_on_map_state_room_state_changed)
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)
	GameSettings.map_secrets_count_max_changed.connect(_on_game_settings_map_secrets_count_max_changed)


func set_map_secrets_count_current(kind: RoomSecretType.Kind, value: int) -> void:
	if kind not in map_secrets_count_current or map_secrets_count_current[kind] != value:
		map_secrets_count_current[kind] = value
		map_secrets_count_current_changed.emit(kind, value)


## Returns a current value of the secret room type kind that is assigned to the currently enabled map solver state.
func get_map_solver_secret_kind() -> RoomSecretType.Kind:
	return map_solver_secret_kind


## Generates and returns map solver result based on the map solver state and current map state.
func _generate_map_solver_result() -> MapSolverResult:
	var result: MapSolverResult = null
	
	# Filter out processing and return default result if map solver is disabled
	if map_solver_state == MapSolverState.NONE or map_solver_secret_kind == RoomSecretType.Kind.NONE:
		return result
	
	# Generate new map solver result
	var map_solver := MapSolver.new()
	var only_hint_placement: bool = map_solver_state == MapSolverState.PLACEMENT_HINT
	var only_hint_placement_weights: bool = map_solver_state == MapSolverState.WEIGHT_HINT
	result = map_solver.find_secret_room_locations(map_solver_secret_kind, only_hint_placement, only_hint_placement_weights)
	
	return result


## Updates map solver result if the map solver is enabled. Meant to be used for updating map solver after any of the related signals that could affect would trigger.
func _update_map_solver_result_after_signal() -> void:
	# Filter out processing if the map solver is disabled
	if map_solver_state == MapSolverState.NONE:
		return
	
	# Update saved map solver result
	map_solver_result = _generate_map_solver_result()
	
	# Emit signal that map solver state has been changed
	map_solver_state_changed.emit()


## After map state change was triggered, update map solver result.
func _on_map_state_room_state_changed() -> void:
	_update_map_solver_result_after_signal()


## After game settings map grid size parameter change was triggered, update map solver result.
func _on_game_settings_map_grid_size_parameter_changed() -> void:
	_update_map_solver_result_after_signal()


## After game settings map secrets count max change was triggered, update map solver result if the current map solver secret kind is the same as the changed secret type kind.
func _on_game_settings_map_secrets_count_max_changed(kind: RoomSecretType.Kind, _value: int) -> void:
	# Filter out processing if the map solver secret type kind is different than the changed secret type kind
	if map_solver_secret_kind != kind:
		return
	_update_map_solver_result_after_signal()


## After map solver state change was triggered, save the new state, update the map solver result and emit signal that state has been changed.
func _on_map_solver_state_change_triggered(state: MapSolverState, secret_room_kind: RoomSecretType.Kind) -> void:
	# Reset map solver state if same map solver parameter were passed, otherwise save them as current ones
	if map_solver_state == state and map_solver_secret_kind == secret_room_kind:
		map_solver_state = MapSolverState.NONE
		map_solver_secret_kind = RoomSecretType.Kind.NONE
	else:
		map_solver_state = state
		map_solver_secret_kind = secret_room_kind
	
	# Update map solver result saved
	map_solver_result = _generate_map_solver_result()
	
	# Emit signal that map solver state has been changed
	map_solver_state_changed.emit()


#region Save Provider
# These functions expose this object's persistent state to the save system.

## Returns the unique key used to identify this Save Provider in save data.
func get_save_key() -> StringName:
	return &"game_state"


## Captures this Save Provider's current persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	return {
		map_state.get_save_key(): map_state.capture_save_data(),
		"map_secrets_count_current": map_secrets_count_current.duplicate(),
		"map_solver_state": map_solver_state,
		"map_solver_secret_kind": map_solver_secret_kind,
		"map_solver_result": null if map_solver_result == null else map_solver_result.capture_save_data(),
	}

## Restores this Save Provider's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	map_state.restore_save_data(data[map_state.get_save_key()])
	map_secrets_count_current = data["map_secrets_count_current"].duplicate()
	map_solver_state = data["map_solver_state"]
	map_solver_state = data["map_solver_secret_kind"]
	map_solver_result = null if data["map_solver_result"] == null else MapSolverResult.new().map_solver_result.restore_save_data(data["map_solver_result"])

#endregion
