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


var map_secrets_count_current: Dictionary[RoomSecretType.Kind, int]
var map_solver_state: MapSolverState = MapSolverState.NONE
var map_solver_secret_kind: RoomSecretType.Kind = RoomSecretType.Kind.NONE


func _ready() -> void:
	# Initialize map_secrets_count_max variable
	var secret_types_kinds = GameData.room_secret_types.get_all_kinds()
	for secret_type_kind in secret_types_kinds:
		map_secrets_count_current[secret_type_kind] = 0


func set_map_secrets_count_current(kind: RoomSecretType.Kind, value: int) -> void:
	if kind not in map_secrets_count_current or map_secrets_count_current[kind] != value:
		map_secrets_count_current[kind] = value
		map_secrets_count_current_changed.emit(kind, value)


func _on_map_solver_state_change_triggered(state: MapSolverState, secret_room_kind: RoomSecretType.Kind) -> void:
	# Reset map solver state if same map solver parameter were passed, otherwise save them as current ones
	if map_solver_state == state and map_solver_secret_kind == secret_room_kind:
		map_solver_state = MapSolverState.NONE
		map_solver_secret_kind = RoomSecretType.Kind.NONE
	else:
		map_solver_state = state
		map_solver_secret_kind = secret_room_kind
	
	# Emit signal that map solver state has been changed
	map_solver_state_changed.emit()
