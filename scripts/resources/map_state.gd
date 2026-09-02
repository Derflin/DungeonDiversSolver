class_name MapState
extends RefCounted


## Signal for communicating that a room instance inside a map state has been created along with it's [param room_coords] coordinates and the [param room_instance_data] itself.
signal room_created(room_coords: Vector2i, room_instance_data: RoomInstanceData)
## Signal for communicating that a room instance inside a map state has been deleted along with it's [param room_coords] coordinates.
signal room_deleted(room_coords: Vector2i)
## Signal for communicating that a room instance inside a map state has been updated along with it's [param room_coords] coordinates.
signal room_updated(room_coords: Vector2i)
## Signal for communicating that a map state has been changed.
signal map_state_changed()


var room_instances: Dictionary[Vector2i, RoomInstanceData] = {}


func _init() -> void:
	# Connect internal signal for updating map state
	map_state_changed.connect(_on_map_state_changed)
	
	# Connect game settings map_grid_size_parameter_changed signal
	GameSettings.map_grid_size_parameter_changed.connect(_on_game_settings_map_grid_size_parameter_changed)


## Checks if the room instance exists for the provided [param room_coords] coordinates.
func has_room_coords(room_coords: Vector2i) -> bool:
	return room_coords in room_instances and room_instances[room_coords] != null


## Returns a list of all room coords for which a room instance exists.
func get_all_room_coords() -> Array[Vector2i]:
	var all_room_coords: Array[Vector2i] = room_instances.keys()
	return all_room_coords


## Returns room instance for the provided [param room_coords] coordinates if it exists, otherwise returns [code]null[/code].
func get_room_instance(room_coords: Vector2i) -> RoomInstanceData:
	if not has_room_coords(room_coords):
		return null
	
	return room_instances[room_coords]


## Creates an empty default room instance for the provided [param room_coords] coordinates.
func create_and_save_empty_room(room_coords: Vector2i) -> void:
	var default_room_instance_data = RoomInstanceData.new()
	create_room(room_coords, default_room_instance_data)


## Create a room for the provided [param room_coords] coordinates using the provided [param room_instance_data].
## If [param replace] is [code]true[/code], then if the room already exists, it will first delete it and then create a new one, otherwise it will skip processing.
## If [param trigger_map_state_changed_signal] is [code]true[/code], then it will emit a [signal map_state_changed] signal.
func create_room(room_coords: Vector2i, room_instance_data: RoomInstanceData, replace: bool = false, trigger_map_state_changed_signal: bool = true) -> void:
	if has_room_coords(room_coords):
		if not replace:
			return
		
		delete_room(room_coords, false)
	
	room_instances[room_coords] = room_instance_data
	
	room_created.emit(room_coords, room_instance_data)
	if trigger_map_state_changed_signal:
		map_state_changed.emit()


## Delete an existing room for the provided [param room_coords] coordinates.
## If [param trigger_map_state_changed_signal] is [code]true[/code], then it will emit a [signal map_state_changed] signal.
func delete_room(room_coords: Vector2i, trigger_map_state_changed_signal: bool = true) -> void:
	if not has_room_coords(room_coords):
		return
	
	room_instances.erase(room_coords)
	
	room_deleted.emit(room_coords)
	if trigger_map_state_changed_signal:
		map_state_changed.emit()


## Updates an existing room for the provided [param room_coords] coordinates by modifying it's barricades configuration.
## Uses [param barricade_direction] and [param state] to determine, which barricade direction flag should be set and in which state.
func update_room_set_barricade(room_coords: Vector2i, barricade_direction: RoomInstanceData.BarricadeDirectionFlags, state: bool) -> void:
	var room_instance_data := get_room_instance(room_coords)
	if room_instances == null:
		return
	
	var changed: bool = false
	if state and not room_instance_data.has_barricade(barricade_direction):
		room_instance_data.enable_barricade(barricade_direction)
		changed = true
	elif not state and room_instance_data.has_barricade(barricade_direction):
		room_instance_data.disable_barricade(barricade_direction)
		changed = true
	
	if changed:
		room_updated.emit(room_coords)
		map_state_changed.emit()


## Updates an existing room for the provided [param room_coords] coordinates by modifying it's connections configuration.
## Uses [param connection_direction] and [param state] to determine, which connection direction flag should be set and in which state.
func update_room_set_connection(room_coords: Vector2i, connection_direction: RoomInstanceData.ConnectionDirectionFlags, state: bool) -> void:
	var room_instance_data := get_room_instance(room_coords)
	if room_instances == null:
		return
	
	var changed: bool = false
	if state and not room_instance_data.has_connection(connection_direction):
		room_instance_data.enable_connection(connection_direction)
		changed = true
	elif not state and room_instance_data.has_connection(connection_direction):
		room_instance_data.disable_connection(connection_direction)
		changed = true
	
	if changed:
		room_updated.emit(room_coords)
		map_state_changed.emit()


## Updates an existing room for the provided [param room_coords] coordinates by modifying it's special type configuration.
## Uses [param special_room_kind] and [param state] to determine, which room special type should be set and in which state.
func update_room_set_special_type(room_coords: Vector2i, special_room_kind: RoomSpecialType.Kind, state: bool) -> void:
	var room_instance_data := get_room_instance(room_coords)
	if room_instances == null:
		return
	
	var changed: bool = false
	changed = room_instance_data.set_special_type(RoomSpecialType.Kind.NONE if not state else special_room_kind)
	
	if changed:
		room_updated.emit(room_coords)
		map_state_changed.emit()


## Updates an existing room for the provided [param room_coords] coordinates by modifying it's secret type configuration.
## Uses [param secret_room_kind] and [param state] to determine, which room secret type should be set and in which state.
func update_room_set_secret_type(room_coords: Vector2i, secret_room_kind: RoomSecretType.Kind, state: bool) -> void:
	var room_instance_data := get_room_instance(room_coords)
	if room_instances == null:
		return
	
	var changed: bool = false
	changed = room_instance_data.set_secret_type(RoomSecretType.Kind.NONE if not state else secret_room_kind)
	
	if changed:
		room_updated.emit(room_coords)
		map_state_changed.emit()


## Updates the game state by updating it's members, which currently include current map secrets counts.  
func _update_game_state() -> void:
	# Count instances of all secret room types currently set in any of the existing rooms in map
	var secret_count: Dictionary[RoomSecretType.Kind, int] = {}
	for room_coords in room_instances:
		var room_instance_data: RoomInstanceData = room_instances[room_coords]
		var room_secret_type_kind = room_instance_data.get_secret_type_kind()
		if room_secret_type_kind != null and room_secret_type_kind != RoomSecretType.Kind.NONE:
			if room_secret_type_kind in secret_count:
				secret_count[room_secret_type_kind] += 1
			else:
				secret_count[room_secret_type_kind] = 1
	
	# Save counted room secret types inside game state and for all other room secret types that didn't occur while counting, set them to 0
	var all_secret_type_kinds = GameData.room_secret_types.get_all_kinds()
	for room_secret_type_kind in all_secret_type_kinds:
		if room_secret_type_kind in secret_count:
			GameState.set_map_secrets_count_current(room_secret_type_kind, secret_count[room_secret_type_kind])
		else:
			GameState.set_map_secrets_count_current(room_secret_type_kind, 0)


func _on_map_state_changed() -> void:
	_update_game_state()


## After detecting [signal GameSettings.map_grid_size_parameter_changed] signal, check if grid size change didn't cause some rooms to be out of grid, if yes then delete them.
func _on_game_settings_map_grid_size_parameter_changed(_map_grid_size: Vector2i) -> void:
	# Check which rooms would be placed out of the current grid
	var room_coords_deletion_queue: Array[Vector2i] = []
	for room_coords in room_instances:
		if room_coords.x >= _map_grid_size.x or room_coords.y >= _map_grid_size.y:
			room_coords_deletion_queue.append(room_coords)
	
	# Delete any room that would be placed outside the map grid and don't propage it's map_state_changed signal
	for room_coords in room_coords_deletion_queue:
		delete_room(room_coords, false)
	
	# If any of the room was set to be deleted, then emit the map_state_changed signal
	if room_coords_deletion_queue.size() > 0:
		map_state_changed.emit()
