extends Node


@warning_ignore("unused_signal")
signal map_secrets_count_current_changed(kind: RoomSecretType.Kind, value: int)
@warning_ignore("unused_signal")
signal map_solver_state_change_triggered(state: MapSolverState, secret_room_kind: RoomSecretType.Kind)
@warning_ignore("unused_signal")
signal map_solver_state_changed()

@warning_ignore("unused_signal")
signal map_solver_submenu_opened()
@warning_ignore("unused_signal")
signal map_parameters_submenu_opened()


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

var _is_restoring_save: bool = false
var _save_restore_signal_queue := SaveRestoreSignalQueue.new()


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
		_emit_state_signal(&"map_secrets_count_current_changed", [kind, value])


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
	# Filter out processing if the game state is currently restoring it's status from the save.
	if _is_restoring_save:
		return
	
	# Filter out processing if the map solver is disabled
	if map_solver_state == MapSolverState.NONE:
		return
	
	# Update saved map solver result
	map_solver_result = _generate_map_solver_result()
	
	# Emit signal that map solver state has been changed
	_emit_state_signal(&"map_solver_state_changed")


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
	_emit_state_signal(&"map_solver_state_changed")


#region Reset Map

## Resets game state to it's default empty state.
func reset_game_state_to_default() -> void:
	# Reset map solver status.
	map_solver_state = MapSolverState.NONE
	map_solver_secret_kind = RoomSecretType.Kind.NONE
	map_solver_result = null
	_emit_state_signal(&"map_solver_state_changed")
	
	# Reset map state.
	map_state.delete_all_rooms()

#endregion


#region Save Provider
# These functions expose this object's persistent state to the save system.

## Returns the unique key used to identify this Save Provider in save data.
func get_save_key() -> StringName:
	return &"game_state"


## Captures this Save Provider's current persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	var save_data_map_solver_result = null
	if map_solver_result != null:
		save_data_map_solver_result = map_solver_result.capture_save_data()
	
	return {
		map_state.get_save_key(): map_state.capture_save_data(),
		"map_secrets_count_current": map_secrets_count_current.duplicate(),
		"map_solver_state": map_solver_state,
		"map_solver_secret_kind": map_solver_secret_kind,
		"map_solver_result": save_data_map_solver_result,
	}

## Restores this Save Provider's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	# Restore map_state.
	map_state.restore_save_data(data[map_state.get_save_key()])
	
	# Restore map_secrets_count_current.
	var restored_current_counts: Dictionary = data["map_secrets_count_current"]
	map_secrets_count_current.clear()
	for kind: RoomSecretType.Kind in restored_current_counts:
		set_map_secrets_count_current(kind, restored_current_counts[kind])
	
	# Restore map_solver_state.
	map_solver_state = data["map_solver_state"]
	
	# Restore map_solver_secret_kind.
	map_solver_secret_kind = data["map_solver_secret_kind"]
	
	# Restore map_solver_result.
	if data["map_solver_result"] == null:
		map_solver_result = null
	else:
		map_solver_result = MapSolverResult.new()
		map_solver_result.restore_save_data(data["map_solver_result"])
	_emit_state_signal(&"map_solver_state_changed")


## Captures this Save Provider's current persistant state in form of summary metadata for save data.
func capture_save_metadata() -> Array[Dictionary]:
	var save_metadata: Array[Dictionary] = []
	
	var secret_count = 0
	for secret_type_kind in map_secrets_count_current:
		secret_count += map_secrets_count_current[secret_type_kind]
	save_metadata.append({
		"key": &"secret_count",
		"value": str(secret_count),
	})
	
	save_metadata.append_array(map_state.capture_save_metadata())
	
	return save_metadata


## Marks an internal flag that restoring data from save has started.
## It will cause all signals that affect the game state to be postponed after the flag would be unset.
func begin_save_restore() -> void:
	_is_restoring_save = true
	_save_restore_signal_queue.begin()


## Marks an internal flag that restoring data from save has finished.
## It will cause all signal that has been postponed during the save restore to be emitted.
func finish_save_restore() -> void:
	_is_restoring_save = false
	_save_restore_signal_queue.finish(self)


## Uses a provided [param signal_name] and it's provided [param arguments] to pass it to the signal queue.
## Signal queue will either emit them immediately if the save isn't being restored currently or it will queue them for later emit when the save will be finished restoring.
func _emit_state_signal(signal_name: StringName, arguments: Array = []) -> void:
	_save_restore_signal_queue.emit_or_defer(self, signal_name, arguments)

#endregion
