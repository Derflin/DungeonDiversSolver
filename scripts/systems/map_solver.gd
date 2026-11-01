class_name MapSolver
extends RefCounted


enum Direction {
	NONE,
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const DIRECTION_TO_OPPOSITE_DIRECTION: Dictionary[Direction, Direction] = {
	Direction.UP: Direction.DOWN,
	Direction.DOWN: Direction.UP,
	Direction.LEFT: Direction.RIGHT,
	Direction.RIGHT: Direction.LEFT,
}

const DIRECTION_TO_COORDS_OFFSET: Dictionary[Direction, Vector2i] = {
	Direction.UP: Vector2i(0, -1),
	Direction.DOWN: Vector2i(0, 1),
	Direction.LEFT: Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
}

const DIRECTION_TO_BARRICADE_CURRENT_ROOM_DIRECTION_FLAGS: Dictionary[Direction, RoomInstanceData.BarricadeDirectionFlags] = {
	Direction.UP: RoomInstanceData.BarricadeDirectionFlags.UP,
	Direction.DOWN: RoomInstanceData.BarricadeDirectionFlags.DOWN,
	Direction.LEFT: RoomInstanceData.BarricadeDirectionFlags.LEFT,
	Direction.RIGHT: RoomInstanceData.BarricadeDirectionFlags.RIGHT,
}

const DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS: Dictionary[Direction, RoomInstanceData.BarricadeDirectionFlags] = {
	Direction.UP: RoomInstanceData.BarricadeDirectionFlags.DOWN,
	Direction.DOWN: RoomInstanceData.BarricadeDirectionFlags.UP,
	Direction.LEFT: RoomInstanceData.BarricadeDirectionFlags.RIGHT,
	Direction.RIGHT: RoomInstanceData.BarricadeDirectionFlags.LEFT,
}


var text_color_code_gradient: Gradient = Gradient.new()


var _map_state: MapState
var _map_state_all_room_coords: Array[Vector2i]


func _init() -> void:
	# Prepare map state copy
	_map_state = GameState.map_state.copy()
	_map_state_all_room_coords = _map_state.get_all_room_coords()
	
	# Initialize color text color code gradient
	text_color_code_gradient.set_offsets(PackedFloat32Array([0.0, 0.5, 1.0]))
	text_color_code_gradient.set_colors(PackedColorArray([Color.RED, Color.YELLOW, Color.LIME_GREEN]))


func find_secret_room_locations(
	secret_room_kind: RoomSecretType.Kind,
	only_hint_placement: bool = false,
	only_hint_placement_weights: bool = false,
) -> MapSolverResult:
	# Prepare return output value
	var result = MapSolverResult.new()
	result.clear_status_message()
	
	# Check if GameData has specified secret room kind
	if not GameData.room_secret_types.has_type(secret_room_kind):
		result.append_status_message("Missing selected secret room type kind inside resources in GameData")
		return result
	
	# Get current secret room kind current and max count and check how many of them need to be solved
	var secret_room_count_current: int = GameState.map_secrets_count_current.get(secret_room_kind, 0)
	var secret_room_count_max: int = GameSettings.map_secrets_count_max.get(secret_room_kind, 0)
	var secret_room_generate_count := secret_room_count_max - secret_room_count_current
	if secret_room_count_max - secret_room_count_current <= 0:
		result.append_status_message("All secret rooms already placed")
		return result
	
	# Gather secret room type data
	var secret_room_type = GameData.room_secret_types.get_type(secret_room_kind)
	var secret_room_placement_config: SecretPlacementConfig = secret_room_type.placement_config
	
	# Check if secret room type data has any placement configuration assigned
	if secret_room_placement_config == null:
		result.append_status_message("Secret room kind missing placement configuration")
		return result
	
	# Find valid placements and return them if the only_hint_placement flag is true
	_find_valid_placements(result, secret_room_placement_config)
	if only_hint_placement:
		result.append_status_message("Found %d valid placements" % [result.get_result_coords().size()])
		return result
	
	# Calculate weights for valid placements and return them if the only_hint_placement_weights flag is true
	_calculate_weights(result, secret_room_placement_config)
	if only_hint_placement_weights:
		# Color code the weight results and save text colors for each valid placement
		result.assign_color_code(text_color_code_gradient, secret_room_placement_config.weight_count_type, true, false)
		
		result.append_status_message("Calculated weights for %d valid placements" % [result.get_result_coords().size()])
		return result
	
	# Find and mark final solutions
	_find_solutions(result, secret_room_placement_config, secret_room_generate_count)
	
	# Color code the solution results and save text colors for each found placement
	result.assign_color_code(text_color_code_gradient, secret_room_placement_config.weight_count_type, false, true)
	
	result.append_status_message("Found %d valid and most probable placements" % [result.get_result_coords().size()])
	return result


func _find_valid_placements(result: MapSolverResult, placement_config: SecretPlacementConfig) -> void:
	# Initialize stage state
	result.stage = MapSolverResult.SolveStage.FOUND_VALID_PLACEMENTS
	
	# Check every coordinate position
	for column in GameSettings.map_grid_size.x:
		for row in GameSettings.map_grid_size.y:
			# Filter out room coords where the room already exists
			var room_coords := Vector2i(column, row)
			if _map_state.has_room_coords(room_coords):
				continue
			
			# Filter out room coords where the specified distance from other rooms isn't kept
			if not _check_if_room_coords_distance_from_nearest_room(room_coords, placement_config.room_distance):
				continue
			
			# Filter out room coords that don't keep the neighbours min and max counts
			var neighbours_count := _get_neighbours_count(room_coords)
			if neighbours_count > placement_config.room_neighbours_max or neighbours_count < placement_config.room_neighbours_min:
				continue
			
			# Filter out room coords that don't keep the neighbours restrictions
			if neighbours_count == 0 and (placement_config.neighbour_require_barricade or placement_config.neighbour_require_secret or placement_config.neighbour_require_special):
				continue
			if not _check_if_room_coords_abide_neighbours_restrictions(room_coords, placement_config):
				continue
			
			# Filter out room coords that have neighbours that wouldn't allow the placement of a room next to them because it would break their room placement restrictions.
			if not _check_if_room_coords_placement_abide_existing_rooms_placement_restrictions(room_coords):
				continue
			
			# Filter out room coords that have neighbours that wouldn't allow the placement of a secret room next to them.
			if not _check_if_neighbours_allow_secret_placement(room_coords):
				continue
			
			# Save coords inside the result
			result.assign_coord_to_result(room_coords)
			
	# Filter out room coords that don't keep the optional restrictions set in placement config inside the assigned placement types
	for placement_type in placement_config.placement_types:
		_filter_results_placement_type_placement_restrictions(result, placement_type)


func _check_if_room_coords_distance_from_nearest_room(room_coords: Vector2i, room_expected_distance: int) -> bool:
	var rooms_at_expected_distance_counter := 0
	var non_secret_room_at_expected_distance_counter := 0
	
	# Check every possible room coords in distance range
	for column_offset in range(-room_expected_distance, room_expected_distance + 1):
		for row_offset in range(-room_expected_distance, room_expected_distance + 1):
			var coords_distance_from_center = abs(column_offset) + abs(row_offset)
			
			# Filter out coords that are located out of range
			if coords_distance_from_center > room_expected_distance or coords_distance_from_center == 0:
				continue
			
			# Filter out coords that are outside of the grid
			var current_coords := Vector2i(room_coords.x + column_offset, room_coords.y + row_offset)
			if not _check_if_room_coords_inside_grid(current_coords):
				continue
			
			# Check if room exists for the given coords and if yes, then either count it if it's at the expected range or return false if it's not, since then range is smaller than expected 
			if _map_state.has_room_coords(current_coords):
				if coords_distance_from_center < room_expected_distance:
					return false
				else:
					# Count the room instance.
					rooms_at_expected_distance_counter += 1
					
					# Count the non secret room instance if the checked room isn't for a secret room.
					var current_coords_room_instance := _map_state.get_room_instance(current_coords) 
					if not current_coords_room_instance.has_secret_type():
						non_secret_room_at_expected_distance_counter += 1
	
	# Check if there were any rooms at the expected range
	if rooms_at_expected_distance_counter == 0:
		return false
	
	# Check if there is at least one room that isn't a secret room at the expected range
	if non_secret_room_at_expected_distance_counter == 0:
		return false
	
	return true


func _check_if_room_coords_inside_grid(room_coords: Vector2i) -> bool:
	# Check if the given room coords are set inside the defined grid size
	if room_coords.x >= 0 and room_coords.x < GameSettings.map_grid_size.x and room_coords.y >= 0 and room_coords.y < GameSettings.map_grid_size.y:
		return true
	return false


func _get_neighbours_count(room_coords: Vector2i, include_secret_rooms: bool = false) -> int:
	var result = 0
	
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction
		if current_dir == Direction.NONE:
			continue
		
		# Check if neighbour does exist in a given direction and count it in if it does
		var neighbour_coords = room_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if not _map_state.has_room_coords(neighbour_coords):
			continue
		
		# Check if neighbour is a secret room
		var neighbour_room_instance := _map_state.get_room_instance(neighbour_coords)
		var neighbour_is_secret_room := neighbour_room_instance.has_secret_type()
		
		# Count the neighbour if it's not a secret room or if it's a secret room and the include secret rooms flag is set
		if not neighbour_is_secret_room or (neighbour_is_secret_room and include_secret_rooms):
			result += 1
	
	return result


func _check_if_room_coords_abide_neighbours_restrictions(room_coords: Vector2i, placement_config: SecretPlacementConfig) -> bool:
	# Gather data room coords neighbours about the barricade relation to the current room and if they are any special/secret rooms among them
	var barricade_count := 0
	var special_count := 0
	var secret_count := 0
	
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction
		if current_dir == Direction.NONE:
			continue
		
		# Filter out the coords if neighbour doesn't exist for it
		var neighbour_coords := room_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		var room_instance := _map_state.get_room_instance(neighbour_coords)
		if room_instance == null:
			continue
		
		# Check if neighbour does fulfill the relation requirements and if yes, then count it in
		if room_instance.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[current_dir]):
			barricade_count += 1
		if room_instance.get_special_type_kind() != RoomSpecialType.Kind.NONE:
			special_count += 1
		if room_instance.get_secret_type_kind() != RoomSecretType.Kind.NONE:
			secret_count += 1
	
	# Check placement config neighbours restrictions
	if barricade_count > 0 and not placement_config.neighbour_allow_barricade:
		return false
	if barricade_count == 0 and placement_config.neighbour_require_barricade:
		return false
	if special_count > 0 and not placement_config.neighbour_allow_special:
		return false
	if special_count == 0 and placement_config.neighbour_require_special:
		return false
	if secret_count > 0 and not placement_config.neighbour_allow_secret:
		return false
	if secret_count == 0 and placement_config.neighbour_require_secret:
		return false
	
	return true


## Checks if placing the secret room on the provided [param room_coords] would abide with existing rooms placement restrictions.
## Returns a bool value indicating the result of the check.
func _check_if_room_coords_placement_abide_existing_rooms_placement_restrictions(room_coords: Vector2i) -> bool:
	# Check all existing room coordinates.
	for existing_room_coords: Vector2i in _map_state_all_room_coords:
		var room_instance := _map_state.get_room_instance(existing_room_coords)
		
		# Filter out the room if it isn't a secret room, since only them have custom placement configs that affect this.
		if not room_instance.has_secret_type():
			continue
		
		# Get placement config.
		var secret_type_kind := room_instance.get_secret_type_kind()
		var secret_type := GameData.room_secret_types.get_type(secret_type_kind)
		var placement_config := secret_type.placement_config
		
		# Calculate distance between the rooms.
		var coords_offset: Vector2i = abs(room_coords - existing_room_coords)
		var distance: int = coords_offset.x + coords_offset.y
		
		# Check if placing the room in the provided room_coords would break the distance restriction with the currently checked room.
		if distance < placement_config.room_distance:
			return false
	
	return true


## Checks if neighbours of the provided [param room_coords] for the empty grid space would allow secret room placement next to them.
## Returns a bool value indicating the result of the check.
func _check_if_neighbours_allow_secret_placement(room_coords: Vector2i) -> bool:
	# Check each direction for neighbours
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction
		if current_dir == Direction.NONE:
			continue
		
		# Filter out the coords if neighbour doesn't exist for it
		var neighbour_coords := room_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		var room_instance := _map_state.get_room_instance(neighbour_coords)
		if room_instance == null:
			continue
		
		# Filter out the neighbour if it isn't a secret room, since only them have custom placement configs that affect this
		if not room_instance.has_secret_type():
			continue
		
		# Get neighbour placement config
		var neighbour_secret_type_kind := room_instance.get_secret_type_kind()
		var neighbour_secret_type := GameData.room_secret_types.get_type(neighbour_secret_type_kind)
		var neighbour_placement_config := neighbour_secret_type.placement_config
		
		# Check if placement config allow secret as it's neighbours
		if not neighbour_placement_config.neighbour_allow_secret:
			return false
	
	return true


func _filter_results_placement_type_placement_restrictions(result: MapSolverResult, placement_type: SecretPlacementType) -> void:
	# Check if placement type should validate placement restrictions, and if yes then prepare initial data needed for filtering
	var prepared_placement_type_data: Dictionary[String, Variant] = {}
	if placement_type is SecretPlacementTypeIntersection:
		# Prepare a list of intersected base rooms coords
		var intersect_group_coords_1 := _find_room_types_coords(placement_type.intersect_room_type_1)
		var intersect_group_coords_2 := _find_room_types_coords(placement_type.intersect_room_type_2)
		
		# Save the data inside the outputted data
		prepared_placement_type_data = {
			"intersect_group_coords_1": intersect_group_coords_1,
			"intersect_group_coords_2": intersect_group_coords_2,
		}
		
	elif placement_type is SecretPlacementTypeLoop:
		# Prepare a dict with coords as key and values represeting each separated room group
		var room_connections_groups := _find_group_room_connections()
		
		# Save the data inside the outputted data
		prepared_placement_type_data = {
			"room_connections_groups": room_connections_groups,
		}
		
	elif placement_type is SecretPlacementTypePath:
		# Prepare a list of starter base rooms coords
		var start_room_group_coords := _find_room_types_coords(placement_type.start_room)
		
		# Prepare a dict with coords as key and values represeting each separated room group
		var room_connections_groups := _find_group_room_connections()
		
		# Save the data inside the outputted data
		prepared_placement_type_data = {
			"start_room_group_coords": start_room_group_coords,
			"room_connections_groups": room_connections_groups,
		}
		
	else:
		# Ignore every other placement type that wasn't specified until now
		return
	
	# Validate placement types for each coords saved in the result
	var filtered_coords: Array[Vector2i] = []
	var result_coords_all := result.get_result_coords()
	for cur_coords in result_coords_all:
		var cur_coords_valid := false
		
		# Validate placement
		if placement_type is SecretPlacementTypeIntersection:
			cur_coords_valid = _filter_results_placement_type_placement_restrictions_intersection(prepared_placement_type_data, cur_coords)
			
		elif placement_type is SecretPlacementTypeLoop:
			cur_coords_valid = _filter_results_placement_type_placement_restrictions_loop(prepared_placement_type_data, cur_coords)
			
		elif placement_type is SecretPlacementTypePath:
			cur_coords_valid = _filter_results_placement_type_placement_restrictions_path(prepared_placement_type_data, cur_coords)
		
		if not cur_coords_valid:
			filtered_coords.append(cur_coords)
	
	# Remove all the coords that were marked as filtered
	for filtered_coord in filtered_coords:
		result.unassign_coord_from_result(filtered_coord)


func _filter_results_placement_type_placement_restrictions_intersection(prepared_placement_type_data: Dictionary[String, Variant], cur_coords: Vector2i) -> bool:
	# Check if the current room coordinates align with X and Y axis for any set of points between the first and second intersect groups
	for intersect_1_coords in prepared_placement_type_data["intersect_group_coords_1"]:
		for intersect_2_coords in prepared_placement_type_data["intersect_group_coords_2"]:
			# Calculate the intersection rectangle boundaries
			var min_x: int = mini(intersect_1_coords.x, intersect_2_coords.x)
			var max_x: int = maxi(intersect_1_coords.x, intersect_2_coords.x)
			var min_y: int = mini(intersect_1_coords.y, intersect_2_coords.y)
			var max_y: int = maxi(intersect_1_coords.y, intersect_2_coords.y)
			
			# Check if coords are on one of the vertical edges
			var on_vertical_edge: bool = (
				(cur_coords.x == min_x or cur_coords.x == max_x)
				and cur_coords.y >= min_y
				and cur_coords.y <= max_y
			)
			
			# Check if coords are on one of the horizontal edges
			var on_horizontal_edge: bool = (
				(cur_coords.y == min_y or cur_coords.y == max_y)
				and cur_coords.x >= min_x
				and cur_coords.x <= max_x
			)
			
			if on_vertical_edge or on_horizontal_edge:
				return true
	
	return false


func _filter_results_placement_type_placement_restrictions_loop(prepared_placement_type_data: Dictionary[String, Variant], cur_coords: Vector2i) -> bool:
	var cur_coords_valid: bool = false
	
	# Check if there are at least 2 negihbours to the current room that have the same group other than -1
	var neighbours_groups_count: Dictionary[int, int] = {}
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction
		if current_dir == Direction.NONE:
			continue
		
		# Calculate count of groups based on the neighbours
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords in prepared_placement_type_data["room_connections_groups"]:
			# Check if the room doesn't have a blockade in the direction of the current coords, if yes then skip counting it
			var neighbour_room_instance_data := _map_state.get_room_instance(neighbour_coords)
			if neighbour_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[current_dir]):
				continue
			
			# Add group instance to the count
			var neighbour_group_id = prepared_placement_type_data["room_connections_groups"][neighbour_coords]
			if neighbour_group_id in neighbours_groups_count:
				neighbours_groups_count[neighbour_group_id] += 1
			else:
				neighbours_groups_count[neighbour_group_id] = 1
	
	# Check if any of the neighbours group count is highier than 1, ignoring group id -1
	for group_id in neighbours_groups_count:
		if group_id != -1 and neighbours_groups_count[group_id] >= 2:
			cur_coords_valid = true
			break
	
	return cur_coords_valid


func _filter_results_placement_type_placement_restrictions_path(prepared_placement_type_data: Dictionary[String, Variant], cur_coords: Vector2i) -> bool:
	var cur_coords_valid: bool = false
	
	# Check what groups are assigned to each neighbour of the current coords
	var neighbours_groups: Array[int] = []
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction
		if current_dir == Direction.NONE:
			continue
		
		# Save each neighbour group
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords in prepared_placement_type_data["room_connections_groups"]:
			var neighbour_group_id = prepared_placement_type_data["room_connections_groups"][neighbour_coords]
			if neighbour_group_id not in neighbours_groups:
				neighbours_groups.append(neighbour_group_id)
	
	# Check if any starting rooms have the same group as any of the neighbour rooms checked
	for start_room_coords in prepared_placement_type_data["start_room_group_coords"]:
		if start_room_coords in prepared_placement_type_data["room_connections_groups"] and prepared_placement_type_data["room_connections_groups"][start_room_coords] in neighbours_groups:
			cur_coords_valid = true
			break
	
	return cur_coords_valid


func _find_room_types_coords(room_type: RoomType) -> Array[Vector2i]:
	var found_coords: Array[Vector2i] = []
	
	# Check each room if they have a specific room type assigned to themselfes
	for room_coords in _map_state_all_room_coords:
		var room_instance_data := _map_state.get_room_instance(room_coords)
		if room_instance_data.has_specified_room_type(room_type):
			found_coords.append(room_coords)
	
	return found_coords


func _find_group_room_connections() -> Dictionary[Vector2i, int]:
	var coords_to_group_id: Dictionary[Vector2i, int] = {}
	
	# Assign connection groups to each room in the grid
	var group_id: int = 0
	for room_coords in _map_state_all_room_coords:
		# Check if the room wasn't already assigned to other group
		if room_coords in coords_to_group_id:
			continue
		
		# Assign group to a current room and then recusively assign the same group to it's neighbours that are connected to it
		_assign_neighbour_group_room_connection(coords_to_group_id, group_id, room_coords, Direction.NONE)
		
		# Increase the group ID
		group_id += 1
	
	return coords_to_group_id


func _assign_neighbour_group_room_connection(coords_to_group_id: Dictionary[Vector2i, int], group_id: int, cur_room_coords: Vector2i, last_room_dir: Direction) -> void:
	# Filter processing room coords that are already grouped
	if cur_room_coords in coords_to_group_id:
		return
	
	# Assign unassinged group room id if the room is a secret room and stop recursive processing
	var cur_room_instance_data := _map_state.get_room_instance(cur_room_coords)
	if cur_room_instance_data.get_secret_type_kind() != RoomSecretType.Kind.NONE:
		coords_to_group_id[cur_room_coords] = -1
		return
	
	# Check if room doesn't have blockades in the last room direction, if yes then skip processing it further
	if last_room_dir != Direction.NONE and cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[last_room_dir]):
		return
	
	# Assign group id to current room coords
	coords_to_group_id[cur_room_coords] = group_id
	
	# Recursively propagate assigning groups to neighbouring compatible rooms
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction and the last made direction
		if current_dir == Direction.NONE or (last_room_dir != Direction.NONE and current_dir == DIRECTION_TO_OPPOSITE_DIRECTION[last_room_dir]):
			continue
		
		# Filter out the coords if neighbour doesn't exist for it
		var neighbour_coords := cur_room_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if not _map_state.has_room_coords(neighbour_coords):
			continue
		
		# Check if current room has any barricades in the direction of this neighbour room
		if not cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CURRENT_ROOM_DIRECTION_FLAGS[current_dir]):
			_assign_neighbour_group_room_connection(coords_to_group_id, group_id, neighbour_coords, current_dir)


func _calculate_weights(result: MapSolverResult, placement_config: SecretPlacementConfig) -> void:
	# Initialize stage state
	result.stage = MapSolverResult.SolveStage.CALCULATED_WEIGHTS
	
	# Initialize result coords weights
	result.initialize_result_coords_weights()
	
	# Calculate coords weights based on the placement config placement types
	for placement_type in placement_config.placement_types:
		_calculate_weight_placement_type(result, placement_type)


func _calculate_weight_placement_type(result: MapSolverResult, placement_type: SecretPlacementType) -> void:
	var result_coords_all := result.get_result_coords()
	
	# Calculate coords weights based on the placement type
	if placement_type is SecretPlacementTypeCorridor:
		# Calculate weights for each coords saved in the result
		for cur_coords in result_coords_all:
			var cur_coords_weight := _calculate_weights_placement_type_corridor(placement_type, cur_coords)
			result.assign_weight_to_result_coords(cur_coords, cur_coords_weight)
		
	elif placement_type is SecretPlacementTypeDistance:
		# Find all the related room types
		var related_room_types_coords: Array[Vector2i] = []
		for room_type in placement_type.related_room_types:
			var room_type_coords := _find_room_types_coords(room_type)
			for cur_coords in room_type_coords:
				if cur_coords not in related_room_types_coords:
					related_room_types_coords.append(cur_coords)
		
		# Calculate weights for each coords saved in the result
		for cur_coords in result_coords_all:
			var cur_coords_weight := _calculate_weights_placement_type_distance(placement_type, related_room_types_coords, cur_coords)
			result.assign_weight_to_result_coords(cur_coords, cur_coords_weight)
		
	elif placement_type is SecretPlacementTypeIntersection:
		# Calculate weights for each coords saved in the result
		for cur_coords in result_coords_all:
			var cur_coords_weight := _calculate_weights_placement_type_intersection()
			result.assign_weight_to_result_coords(cur_coords, cur_coords_weight)
		
	elif placement_type is SecretPlacementTypeLoop:
		# Prepare a dict with coords as key and values represeting each separated room group
		var room_connections_groups := _find_group_room_connections()
	
		# Calculate weights for each coords saved in the result
		for cur_coords in result_coords_all:
			var cur_coords_weight := _calculate_weights_placement_type_loop(placement_type, cur_coords, room_connections_groups)
			result.assign_weight_to_result_coords(cur_coords, cur_coords_weight)
		
	elif placement_type is SecretPlacementTypeNeighbour:
		# Calculate weights for each coords saved in the result
		for cur_coords in result_coords_all:
			var cur_coords_weight := _calculate_weights_placement_type_neighbour(placement_type, cur_coords)
			result.assign_weight_to_result_coords(cur_coords, cur_coords_weight)
		
	elif placement_type is SecretPlacementTypePath:
		# Find all the start room types
		var start_room_types_coords: Array[Vector2i] = []
		var room_type_coords := _find_room_types_coords(placement_type.start_room)
		for cur_coords in room_type_coords:
			if cur_coords not in start_room_types_coords:
				start_room_types_coords.append(cur_coords)
		
		# Calculate weights for each coords saved in the result
		for cur_coords in result_coords_all:
			var cur_coords_weight := _calculate_weights_placement_type_path(placement_type, cur_coords, start_room_types_coords)
			result.assign_weight_to_result_coords(cur_coords, cur_coords_weight)


func _calculate_weights_placement_type_corridor(placement_type: SecretPlacementType, cur_room_coords: Vector2i, last_dir: Direction = Direction.NONE, length: int = 0) -> float:
	# Prepare array for calculated weights
	var calculated_weights: Array[float] = []
	
	# If last dir wasn't defined earlier, then call the function recursively for each neighbour
	if last_dir == Direction.NONE:
		for current_dir: Direction in Direction.values():
			# For each direction apart from the default NONE direction
			if current_dir == Direction.NONE:
				continue
			
			# Filter out the coords if neighbour doesn't exist for it
			var neighbour_coords := cur_room_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
			if not _map_state.has_room_coords(neighbour_coords):
				continue
			
			# Filter out the coords if neighbour is a secret room and they aren't allowed in the placement type
			var room_instance_data := _map_state.get_room_instance(neighbour_coords)
			if not placement_type.allow_secret_rooms_in_corridor and room_instance_data.has_secret_type():
				continue
			
			# Calculate corridor length
			var cur_dir_weight := _calculate_weights_placement_type_corridor(placement_type, neighbour_coords, current_dir, length + 1)
			if cur_dir_weight > 0:
				calculated_weights.append(cur_dir_weight)
		
	else:
		# If the current room doesn't exist, then return current corridor length - 1 as result (excluding current room)
		var room_instance_data := _map_state.get_room_instance(cur_room_coords)
		if room_instance_data == null:
			return length - 1
		
		# Check if the barricades aren't set in the direction where the last room was located, if yes, then return length - 1 (excluding current room)
		if room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[last_dir]):
			return length - 1
		
		# Check if the room instance data is for the secret room and if they are not allowed in placement type, if yes, then return length - 1 (excluding current room)
		if not placement_type.allow_secret_rooms_in_corridor and room_instance_data.has_secret_type():
			return length - 1
		
		# Check if the current room has a barricade in the same direction made as the last room, if yes then return length (including current room)
		if room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CURRENT_ROOM_DIRECTION_FLAGS[last_dir]):
			return length
		
		# Call this function recursively to calculate weight and return it's return value
		return _calculate_weights_placement_type_corridor(
			placement_type,
			cur_room_coords + DIRECTION_TO_COORDS_OFFSET[last_dir],
			last_dir,
			length + 1,
		)
	
	# Aggregate calculated weights according to the placement type config
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


func _calculate_weights_placement_type_distance(placement_type: SecretPlacementType, related_room_types_coords: Array[Vector2i], cur_coords: Vector2i) -> float:
	# Prepare array for calculated weights
	var calculated_weights: Array[float] = []
	
	#NOTE: Against what the game description may sound like, it appears that this formula is incorrect, since it uses room centers, while the game calculates the distances using the room farthest corners.
	## Calculate absolute distance from each related room types coords to the current room coords
	#for related_room_type_coords in related_room_types_coords:
	#	calculated_weights.append(cur_coords.distance_to(related_room_type_coords))
	
	# Calculate the grid distance from each related room type to the current room coordinates using the room center + 1 to account for the calculations taking into account farthest corners of the room rather than their centers.
	for related_room_type_coords: Vector2i in related_room_types_coords:
		var delta: Vector2i = cur_coords - related_room_type_coords
		var distance_x: float = float(absi(delta.x) + 1)
		var distance_y: float = float(absi(delta.y) + 1)
		var distance: float = sqrt(distance_x * distance_x + distance_y * distance_y)
		calculated_weights.append(distance)
	
	# Aggregate calculated weights according to the placement type config
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


func _calculate_weights_placement_type_intersection() -> float:
	# Return 1, since the intersection doesn't need any weights calculated
	# Only marked and defined, so that it would not be assigned as omitted or unintentional in the future
	return 1


func _calculate_weights_placement_type_loop(placement_type: SecretPlacementType, cur_coords: Vector2i, room_connections_groups: Dictionary[Vector2i, int]) -> float:
	# Prepare array for calculated weights
	var calculated_weights: Array[float] = []
	
	# Prepare a dictionary where for each distinct room group, it will have a list of all the neighbouring rooms coords
	var neighbours_groups_coords: Dictionary[int, Variant] = {}
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction
		if current_dir == Direction.NONE:
			continue
		
		# Prepare a list of neighbour coords divided into each separate groups
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords in room_connections_groups:
			# Check if the room doesn't have a blockade in the direction of the current coords, if yes then skip counting it
			var neighbour_room_instance_data := _map_state.get_room_instance(neighbour_coords)
			if neighbour_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[current_dir]):
				continue
			
			# Assign neighbour coords to correct group
			var neighbour_group_id = room_connections_groups[neighbour_coords]
			if neighbour_group_id in neighbours_groups_coords:
				neighbours_groups_coords[neighbour_group_id].append(neighbour_coords)
			else:
				var group_coords: Array[Vector2i] = [neighbour_coords]
				neighbours_groups_coords[neighbour_group_id] = group_coords
	
	# Calculate weights for each neighbours room groups that have at least 2 coords assigned to them (excluding group id -1)
	for group_id in neighbours_groups_coords:
		if group_id == -1:
			continue
		
		var group_coords: Array[Vector2i] = neighbours_groups_coords[group_id]
		if group_coords.size() < 2:
			continue
		
		# Get direction from current room to all neighbour room in the group
		var neighbouring_coords_last_dir: Dictionary[Vector2i, Direction]
		for cur_neighbour_coords in group_coords:
			var neighbour_offset = cur_neighbour_coords - cur_coords
			for offset_dir in DIRECTION_TO_COORDS_OFFSET:
				if DIRECTION_TO_COORDS_OFFSET[offset_dir] == neighbour_offset:
					neighbouring_coords_last_dir[cur_neighbour_coords] = offset_dir
					break
		
		# Calculate max path lengths from each neighbour coords to the current coords
		for cur_neighbour_coords in neighbouring_coords_last_dir.keys():
			var cur_last_dir := neighbouring_coords_last_dir[cur_neighbour_coords]
			# Find all paths lenghts from the current neighbour coords to the result current coords and save them as calculated weights
			_find_all_room_paths_lengths(cur_neighbour_coords, cur_coords, 1, {}, calculated_weights, cur_last_dir)
	
	# Aggregate calculated weights according to the placement type config
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


func _calculate_weights_placement_type_neighbour(placement_type: SecretPlacementType, cur_coords: Vector2i) -> float:
	# Prepare array for calculated weights
	var calculated_weights: Array[float] = []
	
	# Find and check current coords neighbours in placement type specified range and type
	_find_room_neighbours_placement_type_weights(
		cur_coords,
		cur_coords,
		placement_type,
		calculated_weights,
		[],
	)
	
	# Aggregate calculated weights according to the placement type config
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


func _calculate_weights_placement_type_path(placement_type: SecretPlacementType, cur_coords: Vector2i, start_room_types_coords: Array[Vector2i]) -> float:
	# Prepare array for calculated weights
	var calculated_weights: Array[float] = []
	
	# Find all room paths lengths for each starter room found
	for start_room_coords in start_room_types_coords:
		_find_all_room_paths_lengths(start_room_coords, cur_coords, 0, {}, calculated_weights, Direction.NONE)
	
	# Aggregate calculated weights according to the placement type config
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


func _find_room_neighbours_placement_type_weights(
	start_coords: Vector2i,
	cur_coords: Vector2i,
	placement_type: SecretPlacementType,
	neighbours_weights: Array[float],
	checked_neighbours_coords: Array[Vector2i],
	last_dir: Direction = Direction.NONE,
) -> void:
	# Calculate current range from the start coords to current coords
	var cur_range: int = abs(start_coords.x - cur_coords.x) + abs(start_coords.y - cur_coords.y)
	
	# Calculate weights for the current room
	if last_dir != Direction.NONE and cur_range >= placement_type.check_range_min and cur_range <= placement_type.check_range_max:
		# Check if the current room exists
		var cur_room_instance_data := _map_state.get_room_instance(cur_coords)
		if cur_room_instance_data != null:
			# Gather data about the room instance
			var cur_room_has_barricade := cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[last_dir])
			var cur_room_has_secret := cur_room_instance_data.get_secret_type_kind() != RoomSecretType.Kind.NONE
			
			# Calculate weight based on the placement type neighbour type parameter
			if placement_type.neighbour_type == SecretPlacementTypeNeighbour.NeighbourType.ANY:
				neighbours_weights.append(1)
				
			elif placement_type.neighbour_type == SecretPlacementTypeNeighbour.NeighbourType.NONSECRET:
				if not cur_room_has_secret and not cur_room_has_barricade:
					neighbours_weights.append(1)
				
			elif placement_type.neighbour_type == SecretPlacementTypeNeighbour.NeighbourType.BARRICADE:
				if cur_room_has_barricade:
					neighbours_weights.append(1)
	
	# If current range exceeds check range max, then stop processing it
	if cur_range >= placement_type.check_range_max:
		return
	
	# Make sure that each coord will only be propagated once
	if cur_coords in checked_neighbours_coords:
		return
	checked_neighbours_coords.append(cur_coords)
	
	# Propagate neighbours check to neighbouring room coords 
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction and the last made direction
		if current_dir == Direction.NONE or (last_dir != Direction.NONE and current_dir == DIRECTION_TO_OPPOSITE_DIRECTION[last_dir]):
			continue
		
		# Calculate weights for a neighbour
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		_find_room_neighbours_placement_type_weights(start_coords, neighbour_coords, placement_type, neighbours_weights, checked_neighbours_coords, current_dir)


func _find_all_room_paths_lengths(
	cur_coords: Vector2i,
	target_coords: Vector2i,
	length: int, 
	visited: Dictionary[Vector2i, bool], 
	paths_lengths_array: Array[float],
	last_dir: Direction = Direction.NONE,
) -> void:
	# Stop further processing if current room is empty and check if they are the target room
	var cur_room_instance_data := _map_state.get_room_instance(cur_coords)
	if cur_room_instance_data == null:
		# Save path length if the current coords are the same as target coords
		if cur_coords == target_coords:
			paths_lengths_array.append(length)
		return
	
	# Check if the current room has a barricade in the same direction made as the last room, if yes then stop further processing
	if last_dir != Direction.NONE and cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[last_dir]):
		return
	
	# Check if current coords are the same as the target coords and save them if they are
	if cur_coords == target_coords:
		paths_lengths_array.append(length)
	
	# Stop further processing if current room is a secret room of any kind
	if cur_room_instance_data.get_secret_type_kind() != RoomSecretType.Kind.NONE:
		return
	
	# Mark current coords as visited in the current recursive branch
	visited[cur_coords] = true
	
	# Check each neighbouring room coords
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction and the last made direction
		if current_dir == Direction.NONE or (last_dir != Direction.NONE and current_dir == DIRECTION_TO_OPPOSITE_DIRECTION[last_dir]):
			continue
		
		# Stop processing the direction if the current room has barricade set in the same direction
		if cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CURRENT_ROOM_DIRECTION_FLAGS[current_dir]):
			continue
		
		# Prepare a recursive check for a given direction if it wasn't visited before
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords not in visited:
			_find_all_room_paths_lengths(neighbour_coords, target_coords, length + 1, visited, paths_lengths_array, current_dir)
	
	# Unmark current coords as visited
	visited.erase(cur_coords)


func _placement_type_aggregate_calculated_weights(placement_type: SecretPlacementType, calculated_weights: Array[float]) -> float:
	var output_weight: float = 0
	
	if placement_type.count_type == SecretPlacementType.CountType.SUM:
		output_weight = calculated_weights.reduce(func(accum, number): return accum + number, 0)
	elif placement_type.count_type == SecretPlacementType.CountType.SUB:
		output_weight = calculated_weights.reduce(func(accum, number): return accum - number, 0)
	elif placement_type.count_type == SecretPlacementType.CountType.MAX:
		output_weight = calculated_weights.max()
	elif placement_type.count_type == SecretPlacementType.CountType.MIN:
		output_weight = calculated_weights.min()
	
	return output_weight


func _find_solutions(result: MapSolverResult, placement_config: SecretPlacementConfig, secret_room_generate_count: int) -> void:
	# Initialize stage state
	result.stage = MapSolverResult.SolveStage.FOUND_SOLUTION
	
	# Calculate probabilities
	result.calculate_probability_result_coords(secret_room_generate_count, placement_config.weight_count_type)
