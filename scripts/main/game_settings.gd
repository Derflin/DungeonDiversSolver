extends Node


@warning_ignore("unused_signal")
signal map_secrets_count_max_changed(kind: RoomSecretType.Kind, value: int)
@warning_ignore("unused_signal")
signal map_grid_size_parameter_changed()
@warning_ignore("unused_signal")
signal map_grid_room_size_parameter_changed()


var map_secrets_count_max: Dictionary[RoomSecretType.Kind, int]

var _is_restoring_save: bool = false
var _save_restore_signal_queue := SaveRestoreSignalQueue.new()


@export_group("Map Grid Parameters", "map_grid_")
@export var map_grid_size: Vector2i = Vector2i(17, 17):
	set(value):
		map_grid_size = value
		
		_emit_state_signal(&"map_grid_size_parameter_changed")
@export var map_grid_size_icon: Texture2D

@export var map_grid_room_size: Vector2i = Vector2i(15, 15):
	set(value): 
		map_grid_room_size = value
		
		_emit_state_signal(&"map_grid_room_size_parameter_changed")


func _ready() -> void:
	# Initialize map_secrets_count_max variable
	var secret_types_kinds = GameData.room_secret_types.get_all_kinds()
	for secret_type_kind in secret_types_kinds:
		map_secrets_count_max[secret_type_kind] = 0


func set_map_secrets_count_max(kind: RoomSecretType.Kind, value: int) -> void:
	if kind not in map_secrets_count_max or map_secrets_count_max[kind] != value:
		map_secrets_count_max[kind] = value
		_emit_state_signal(&"map_secrets_count_max_changed", [kind, value])


func set_map_grid_size(size: int) -> void:
	map_grid_size = Vector2i(size, size)


#region Reset Game Settings

## Resets game state to it's default empty state.
func reset_game_settings_to_default() -> void:
	# Reset map secrets max counts.
	for secret_kind: RoomSecretType.Kind in map_secrets_count_max.keys():
		set_map_secrets_count_max(secret_kind, 0)
	
	# Rest map size.
	map_grid_size = Vector2i(17, 17)

#endregion


#region Save Provider
# These functions expose this object's persistent state to the save system.

## Returns the unique key used to identify this Save Provider in save data.
func get_save_key() -> StringName:
	return &"game_settings"


## Captures this Save Provider's current persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	return {
		"map_secrets_count_max": map_secrets_count_max.duplicate(),
		"map_grid_size": map_grid_size,
		"map_grid_room_size": map_grid_room_size,
	}

## Restores this Save Provider's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	# Restore map_secrets_count_max.
	var restored_secret_counts: Dictionary = data["map_secrets_count_max"]
	map_secrets_count_max.clear()
	for kind: RoomSecretType.Kind in restored_secret_counts:
		set_map_secrets_count_max(kind, restored_secret_counts[kind])
	
	# Restore map_grid_size.
	map_grid_size = data["map_grid_size"]
	
	# Restore map_grid_room_size.
	map_grid_room_size = data["map_grid_room_size"]


## Captures this Save Provider's current persistant state in form of summary metadata for save data.
func capture_save_metadata() -> Array[Dictionary]:
	var save_metadata: Array[Dictionary] = [
		{
			"key": &"map_size",
			"value": "%d x %d" % [map_grid_size.x, map_grid_size.y],
		},
	]
	
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
