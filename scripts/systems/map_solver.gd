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

const MAX_PLACEMENT_SCENARIOS: int = 25000
const MAX_VALIDATION_EXPLANATION_ROUTES: int = 128


var text_color_code_gradient: Gradient = Gradient.new()


var _map_state: MapState
var _map_state_all_room_coords: Array[Vector2i]
var _placement_selection_overflow: bool = false


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
	if secret_room_count_max <= 0:
		result.append_status_message("There aren't any secret room to be placed")
		return result
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
	_find_valid_placements(result, secret_room_placement_config, only_hint_placement)
	if only_hint_placement:
		result.append_status_message("Found %d valid placements" % [result.get_result_coords().size()])
		return result
	
	# Calculate weights for valid placements and return them if the only_hint_placement_weights flag is true
	_calculate_weights(result, secret_room_placement_config, only_hint_placement_weights)
	if only_hint_placement_weights:
		# Color code the weight results and save text colors for each valid placement
		result.assign_color_code(text_color_code_gradient, secret_room_placement_config.weight_count_type, true, false)
		
		result.append_status_message("Calculated weights for %d valid placements" % [result.get_result_coords().size()])
		return result
	
	# Find and mark final solutions if possible, otherwise return calculated weights
	if not _find_solutions(result, secret_room_placement_config, secret_room_generate_count):
		result.assign_color_code(text_color_code_gradient, secret_room_placement_config.weight_count_type, true, false)
		return result
	
	# Color code the solution results and save text colors for each found placement
	result.assign_color_code(text_color_code_gradient, secret_room_placement_config.weight_count_type, false, true)
	
	# Assign priority groups to the results.
	result.assign_priority_groups(secret_room_placement_config.weight_count_type)
	
	if not result.result_coords.is_empty():
		result.append_status_message("Found %d valid and possible placements" % [result.get_result_coords().size()])
	else:
		result.append_status_message("No more currently valid placements detected")
	return result


## Finds valid candidate coordinates according to the provided [param placement_config] configuration.
## Saved the valid candidate coordinates in the provided [param result] that is used to store and aggregate the map solver results.
## When [param capture_explanations] is enabled, also records supported placement restriction evidence for the requested hint mode.
func _find_valid_placements(result: MapSolverResult, placement_config: SecretPlacementConfig, capture_explanations: bool = false) -> void:
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
	
	
	# Filter out room coords that don't keep the optional restrictions set in placement config inside the assigned placement types.
	for placement_type_index: int in range(placement_config.placement_types.size()):
		var placement_type: SecretPlacementType = placement_config.placement_types[placement_type_index]
		
		# Filter out processing if the placement type is empty.
		if placement_type == null:
			continue
		
		# Filter out room coords based on the placement type restrictions.
		_filter_results_placement_type_placement_restrictions(result, placement_type, placement_type_index, capture_explanations)


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


## Filters placement candidates inside provided [param result] using optional provided [param placement_type] specific restrictions.
## When provided [param capture_explanations] flag is set, stores evidence on each placement candidate that passes a supported restriction, preserving the placement type's provided [param placement_type_index].
func _filter_results_placement_type_placement_restrictions(result: MapSolverResult, placement_type: SecretPlacementType, placement_type_index: int, capture_explanations: bool = false) -> void:
	# Check if placement type should validate placement restrictions, and if yes then prepare initial data needed for filtering.
	var prepared_placement_type_data: Dictionary[String, Variant] = {}
	if placement_type is SecretPlacementTypeIntersection:
		# Prepare a list of intersected base rooms coords.
		var intersect_group_coords_1 := _find_room_types_coords(placement_type.intersect_room_type_1)
		var intersect_group_coords_2 := _find_room_types_coords(placement_type.intersect_room_type_2)
		
		# Save the data inside the outputted data.
		prepared_placement_type_data = {
			"intersect_group_coords_1": intersect_group_coords_1,
			"intersect_group_coords_2": intersect_group_coords_2,
		}
		
	elif placement_type is SecretPlacementTypeLoop:
		# Prepare a dict with coords as key and values represeting each separated room group.
		var room_connections_groups := _find_group_room_connections()
		
		# Save the data inside the outputted data.
		prepared_placement_type_data = {
			"room_connections_groups": room_connections_groups,
		}
		
	elif placement_type is SecretPlacementTypePath:
		# Prepare a list of starter base rooms coords.
		var start_room_group_coords := _find_room_types_coords(placement_type.start_room)
		
		# Prepare a dict with coords as key and values represeting each separated room group.
		var room_connections_groups := _find_group_room_connections()
		
		# Save the data inside the outputted data.
		prepared_placement_type_data = {
			"start_room_group_coords": start_room_group_coords,
			"room_connections_groups": room_connections_groups,
		}
		
	else:
		# Ignore every other placement type that wasn't specified until now.
		return
	
	# Validate placement types for each coords saved in the result.
	var filtered_coords: Array[Vector2i] = []
	var result_coords_all := result.get_result_coords()
	for cur_coords in result_coords_all:
		var cur_coords_valid := false
		
		# Prepare placement explanation for storing optional placement validation evidence.
		var cur_explanation: MapSolverPlacementExplanation = null
		if capture_explanations:
			cur_explanation = MapSolverPlacementExplanation.new()
			cur_explanation.placement_type_index = placement_type_index
		
		# Validate placement based on the placement type.
		if placement_type is SecretPlacementTypeIntersection:
			cur_coords_valid = _filter_results_placement_type_placement_restrictions_intersection(prepared_placement_type_data, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypeLoop:
			cur_coords_valid = _filter_results_placement_type_placement_restrictions_loop(prepared_placement_type_data, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypePath:
			cur_coords_valid = _filter_results_placement_type_placement_restrictions_path(prepared_placement_type_data, cur_coords, cur_explanation)
		
		# Store placement explanation only for coordinates that are valid and that stored any explanation.
		if cur_coords_valid and cur_explanation != null and cur_explanation.has_visuals():
			result.add_placement_explanation(cur_coords, cur_explanation)
		
		# Filter out coordinates that aren't valid.
		if not cur_coords_valid:
			filtered_coords.append(cur_coords)
	
	# Remove all the coords that were marked as filtered.
	for filtered_coord in filtered_coords:
		result.unassign_coord_from_result(filtered_coord)


## Checks if [param cur_coords] room lies on an eligible rectangle edge defined by two configured groups of source rooms.
## Provided [param prepared_placement_type_data] dictionary contains lists of room instances for those two groups.
## When [param cur_explanation] is provided, records one unlabelled segment from the candidate to each distinct source participating in a qualifying pair.
## Without [param cur_explanation] or if it's null, returns immediately after the first valid pair is found.
func _filter_results_placement_type_placement_restrictions_intersection(prepared_placement_type_data: Dictionary[String, Variant], cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation = null) -> bool:
	# Avoid recording the same side more than once across valid pairs.
	var recorded_segments: Dictionary[String, bool] = {}
	var has_valid_pair: bool = false
	
	# Check if the current room coordinates align with X and Y axis for any set of points between the first and second intersect groups.
	for intersect_1_coords: Vector2i in prepared_placement_type_data["intersect_group_coords_1"]:
		for intersect_2_coords: Vector2i in prepared_placement_type_data["intersect_group_coords_2"]:
			# Calculate the intersection rectangle boundaries.
			var min_x: int = mini(intersect_1_coords.x, intersect_2_coords.x)
			var max_x: int = maxi(intersect_1_coords.x, intersect_2_coords.x)
			var min_y: int = mini(intersect_1_coords.y, intersect_2_coords.y)
			var max_y: int = maxi(intersect_1_coords.y, intersect_2_coords.y)
			
			# Check if coords are on one of the vertical edges.
			var on_vertical_edge: bool = (
				(cur_coords.x == min_x or cur_coords.x == max_x)
				and cur_coords.y >= min_y
				and cur_coords.y <= max_y
			)
			
			# Check if coords are on one of the horizontal edges.
			var on_horizontal_edge: bool = (
				(cur_coords.y == min_y or cur_coords.y == max_y)
				and cur_coords.x >= min_x
				and cur_coords.x <= max_x
			)
			
			# Ignore pairs that don't support this candidate.
			if not on_vertical_edge and not on_horizontal_edge:
				continue
			
			# Set flag that a valid pair was found.
			has_valid_pair = true
			
			# Early exit the lookup pair process if the explanation doesn't have to be prepared.
			if cur_explanation == null:
				return true
			
			# Determine the two possible intermediate corners defining l-shaped route between the intersected rooms.
			var corner_1: Vector2i = Vector2i(intersect_1_coords.x, intersect_2_coords.y)
			var corner_2: Vector2i = Vector2i(intersect_2_coords.x, intersect_1_coords.y)
			
			# Check whether the candidate belongs to the first route.
			var on_first_route: bool = (
				(cur_coords.x == intersect_1_coords.x and cur_coords.y >= min_y and cur_coords.y <= max_y)
				or
				(cur_coords.y == intersect_2_coords.y and cur_coords.x >= min_x and cur_coords.x <= max_x)
			)
			
			# Choose the route containing the candidate.
			var selected_corner: Vector2i = corner_1 if on_first_route else corner_2
			var route_coords: Array[Vector2i] = [intersect_1_coords, selected_corner, intersect_2_coords]
			
			# Store each unique perimeter segment of the selected route.
			for i: int in range(route_coords.size() - 1):
				var from_coords: Vector2i = route_coords[i]
				var to_coords: Vector2i = route_coords[i + 1]
				
				# Skip zero length segments.
				if from_coords == to_coords:
					continue
				
				# Normalize orientation so reversed edges have the same key.
				var a: Vector2i = from_coords
				var b: Vector2i = to_coords
				if a.x > b.x or (a.x == b.x and a.y > b.y):
					var temporary: Vector2i = a
					a = b
					b = temporary
				var segment_key: String = "%s|%s" % [str(a), str(b)]
				if recorded_segments.has(segment_key):
					continue
				recorded_segments[segment_key] = true
				
				cur_explanation.segments.append({
					"from": a,
					"to": b,
					"value": 0.0,
					"show_value": false,
					"highlight_rooms": true,
				})
	
	return has_valid_pair


## Checks if [param cur_coords] room has at least 2 neighbouring rooms that belong to the same room group.
## Provided [param prepared_placement_type_data] dictionary contains a dictionary with room coords used as keys and their assigned group number as values.
func _filter_results_placement_type_placement_restrictions_loop(prepared_placement_type_data: Dictionary[String, Variant], cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation = null) -> bool:
	var cur_coords_valid: bool = false
	
	# Check if there are at least 2 negihbours to the current room that have the same group other than -1.
	var neighbours_groups_count: Dictionary[int, int] = {}
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction.
		if current_dir == Direction.NONE:
			continue
		
		# Calculate count of groups based on the neighbours.
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords in prepared_placement_type_data["room_connections_groups"]:
			# Check if the room doesn't have a blockade in the direction of the current coords, if yes then skip counting it.
			var neighbour_room_instance_data := _map_state.get_room_instance(neighbour_coords)
			if neighbour_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[current_dir]):
				continue
			
			# Add group instance to the count.
			var neighbour_group_id = prepared_placement_type_data["room_connections_groups"][neighbour_coords]
			if neighbour_group_id in neighbours_groups_count:
				neighbours_groups_count[neighbour_group_id] += 1
			else:
				neighbours_groups_count[neighbour_group_id] = 1
	
	# Check if any of the neighbours group count is highier than 1, ignoring group id -1.
	for group_id in neighbours_groups_count:
		if group_id != -1 and neighbours_groups_count[group_id] >= 2:
			cur_coords_valid = true
			break
	
	# Collect every accessible cycle passing through this candidate when visual explanations are requested.
	if cur_coords_valid and cur_explanation != null:
		var unused_path_lengths: Array[float] = []
		var initial_route: Array[Vector2i] = [cur_coords]
		
		for current_dir: Direction in Direction.values():
			# For each direction apart from the default NONE direction.
			if current_dir == Direction.NONE:
				continue
			
			# Ignore neighbours outside the prepared connected room groups.
			var neighbour_coords: Vector2i = cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
			if neighbour_coords not in prepared_placement_type_data["room_connections_groups"]:
				continue
			
			var group_id: int = int(prepared_placement_type_data["room_connections_groups"][neighbour_coords])
			if group_id == -1 or int(neighbours_groups_count.get(group_id, 0)) < 2:
				continue
			
			# Check if the room doesn't have a blockade in the direction of the current coords, if yes then skip counting it.
			var neighbour_room_instance_data := _map_state.get_room_instance(neighbour_coords)
			if neighbour_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[current_dir]):
				continue
			 
			# Record all possible loop paths starting from the neighbour to the missing candidate room to close one loop.
			_find_all_room_paths_lengths(
				neighbour_coords,
				cur_coords,
				1,
				{},
				unused_path_lengths,
				current_dir,
				{},
				false,
				initial_route,
				false,
				cur_explanation,
			)
			
			# Limit explanation generation.
			if cur_explanation.paths.size() >= MAX_VALIDATION_EXPLANATION_ROUTES:
				break
	
	return cur_coords_valid


## Checks if [param cur_coords] room has at least one neighbour that belongs to the same group as any of the available start room.
## Provided [param prepared_placement_type_data] dictionary contains a dictionary with room coords used as keys and their assigned group number as values and a list of start room coords that should be checked in comparison to the current room coords. 
func _filter_results_placement_type_placement_restrictions_path(prepared_placement_type_data: Dictionary[String, Variant], cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation = null) -> bool:
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
	
	# Collect every accessible route from the configured starting rooms to this candidate when visual explanations are requested.
	if cur_coords_valid and cur_explanation != null:
		var unused_path_lengths: Array[float] = []
		var empty_route: Array[Vector2i] = []
		
		for start_room_coords: Vector2i in prepared_placement_type_data["start_room_group_coords"]:
			# Skip starting rooms that cannot belong to a neighbouring group supporting the candidate according to the existing validator.
			if start_room_coords not in prepared_placement_type_data["room_connections_groups"]:
				continue
			
			var group_id: int = int(prepared_placement_type_data["room_connections_groups"][start_room_coords])
			if group_id not in neighbours_groups:
				continue
			
			# Record all possible paths.
			_find_all_room_paths_lengths(
				start_room_coords,
				cur_coords,
				0,
				{},
				unused_path_lengths,
				Direction.NONE,
				{},
				false,
				empty_route,
				false,
				cur_explanation,
			)
			
			# Limit explanation generation.
			if cur_explanation.paths.size() >= MAX_VALIDATION_EXPLANATION_ROUTES:
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


## Calculates per candidate weights using configured provided [param placement_config].
## Provided [param result] is used to both access the already existing valid candidates and to store the calculated weights for them.
## When [param capture_explanations] flag is enabled, supported weight calculators record visual evidence without modifying their numerical aggregation.
func _calculate_weights(result: MapSolverResult, placement_config: SecretPlacementConfig, capture_explanations: bool = false) -> void:
	# Initialize stage state.
	result.stage = MapSolverResult.SolveStage.CALCULATED_WEIGHTS
	
	# Initialize result coords weights.
	result.initialize_result_coords_weights()
	
	# Calculate coords weights based on the placement config placement types.
	var combined_weights: Dictionary[Vector2i, float] = {}
	for placement_type_index: int in range(placement_config.placement_types.size()):
		var placement_type: SecretPlacementType = placement_config.placement_types[placement_type_index]

		# Filter out processing if the placement type is none.
		if placement_type == null:
			continue
		
		# Filter out processing if the placement type doesn't contribute to the calculated weight calculation.
		if not placement_type.contributes_to_weight():
			continue
		
		# Calculate the weight for the placement type.
		var type_weights: Dictionary[Vector2i, float] = _calculate_weight_placement_type(result, placement_type, placement_type_index, capture_explanations)
		
		# Aggregate each calculated weight inside the combined weights dictionary.
		for coords: Vector2i in type_weights:
			var type_weight: float = type_weights[coords]
			
			# Initialize the weight inside the combined weights if it wasn't assigned previously.
			if not combined_weights.has(coords):
				combined_weights[coords] = type_weight
				continue
			
			# Aggregate calculated weight with the previous ones according to the placement configuration weight aggregation.
			var previous_weight: float = combined_weights[coords]
			match placement_config.placement_types_weight_aggregation:
				SecretPlacementConfig.PlacementTypesAggregation.LAST:
					combined_weights[coords] = type_weight
				SecretPlacementConfig.PlacementTypesAggregation.SUM:
					combined_weights[coords] = previous_weight + type_weight
				SecretPlacementConfig.PlacementTypesAggregation.SUB:
					combined_weights[coords] = previous_weight - type_weight
				SecretPlacementConfig.PlacementTypesAggregation.MIN:
					combined_weights[coords] = minf(previous_weight, type_weight)
				SecretPlacementConfig.PlacementTypesAggregation.MAX:
					combined_weights[coords] = maxf(previous_weight, type_weight)
	
	# Assign calculated weights to the result.
	result.assign_weights_to_result_coords(combined_weights)


## Calculates candidate weights for candidates saved in the provided [param result] contributed by one configured provided [param placement_type].
## When provided [param capture_explanations] flag is set, stores evidence on each placement candidate weight calculation results, preserving the placement type's provided [param placement_type_index].
func _calculate_weight_placement_type(result: MapSolverResult, placement_type: SecretPlacementType, placement_type_index: int, capture_explanations: bool = false) -> Dictionary[Vector2i, float]:
	var type_weights: Dictionary[Vector2i, float] = {}
	
	# Check if placement type should calculate weights, and if yes then prepare initial data needed for calculations.
	var prepared_placement_type_data: Dictionary[String, Variant] = {}
	if placement_type is SecretPlacementTypeCorridor:
		# Doesn't need any additional details.
		pass
		
	elif placement_type is SecretPlacementTypeDistance:
		# Find all the related room types
		var related_room_types_coords: Array[Vector2i] = []
		for room_type in placement_type.related_room_types:
			var room_type_coords := _find_room_types_coords(room_type)
			for cur_coords in room_type_coords:
				if cur_coords not in related_room_types_coords:
					related_room_types_coords.append(cur_coords)
		
		# Save the data inside the outputted data.
		prepared_placement_type_data = {
			"related_room_types_coords": related_room_types_coords,
		}
		
	elif placement_type is SecretPlacementTypeIntersection:
		# Doesn't need any additional details.
		pass
		
	elif placement_type is SecretPlacementTypeLoop:
		# Prepare a dict with coords as key and values represeting each separated room group
		var room_connections_groups := _find_group_room_connections()
		
		# Save the data inside the outputted data.
		prepared_placement_type_data = {
			"room_connections_groups": room_connections_groups,
		}
		
	elif placement_type is SecretPlacementTypeNeighbour:
		# Doesn't need any additional details.
		pass
		
	elif placement_type is SecretPlacementTypePath:
		# Find all the start room types
		var start_room_types_coords: Array[Vector2i] = []
		var room_type_coords := _find_room_types_coords(placement_type.start_room)
		for cur_coords in room_type_coords:
			if cur_coords not in start_room_types_coords:
				start_room_types_coords.append(cur_coords)
		
		# Save the data inside the outputted data.
		prepared_placement_type_data = {
			"start_room_types_coords": start_room_types_coords,
		}
		
	else:
		# Ignore every other placement type that wasn't specified until now.
		return type_weights
	
	# Calculate coords weights based on the placement type
	var result_coords_all := result.get_result_coords()
	for cur_coords in result_coords_all:
		var cur_coords_weight: float = 0.0
		
		# Prepare placement explanation for storing optional weight calculation evidence.
		var cur_explanation: MapSolverPlacementExplanation = null
		if capture_explanations:
			cur_explanation = MapSolverPlacementExplanation.new()
			cur_explanation.placement_type_index = placement_type_index
		
		# Calculate weight based on the placement type and store them inside current explanation if it exists.
		if placement_type is SecretPlacementTypeCorridor:
			cur_coords_weight = _calculate_weights_placement_type_corridor(prepared_placement_type_data, placement_type, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypeDistance:
			cur_coords_weight = _calculate_weights_placement_type_distance(prepared_placement_type_data, placement_type, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypeIntersection:
			cur_coords_weight = _calculate_weights_placement_type_intersection(prepared_placement_type_data, placement_type, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypeLoop:
			cur_coords_weight = _calculate_weights_placement_type_loop(prepared_placement_type_data, placement_type, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypeNeighbour:
			cur_coords_weight = _calculate_weights_placement_type_neighbour(prepared_placement_type_data, placement_type, cur_coords, cur_explanation)
			
		elif placement_type is SecretPlacementTypePath:
			cur_coords_weight = _calculate_weights_placement_type_path(prepared_placement_type_data, placement_type, cur_coords, cur_explanation)
		
		# Store placement explanation only for coordinates that stored any explanation.
		if cur_explanation != null and cur_explanation.has_visuals():
			result.add_placement_explanation(cur_coords, cur_explanation)
		
		# Save the calculated weight for the current coords.
		type_weights[cur_coords] = cur_coords_weight
	
	return type_weights


## Calculates a candidate weight for [param placement_type] corridor by aggregating lengths returned from each valid starting direction from the provided [param cur_coords] position.
## When [param cur_explanation] is provided, records all the calculated corridor lengths.
func _calculate_weights_placement_type_corridor(_prepared_placement_type_data: Dictionary[String, Variant], placement_type: SecretPlacementType, cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation = null) -> float:
	# Prepare array for calculated weights.
	var calculated_weights: Array[float] = []
	
	# Check every starting direction from the current candidate.
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction.
		if current_dir == Direction.NONE:
			continue
		
		# Filter out the coords if neighbour doesn't exist for it.
		var neighbour_coords: Vector2i = cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if not _map_state.has_room_coords(neighbour_coords):
			continue
		
		# Filter out the coords if neighbour is a secret room and they aren't allowed in the placement type.
		var room_instance_data := _map_state.get_room_instance(neighbour_coords)
		if not placement_type.allow_secret_rooms_in_corridor and room_instance_data.has_secret_type():
			continue
		
		# Calculate corridor length.
		var cur_dir_weight: float = _calculate_weights_placement_type_corridor_recursive(placement_type, neighbour_coords, current_dir, 1)
		if cur_dir_weight > 0:
			calculated_weights.append(cur_dir_weight)
			
			# Store calculated path length between two coords as part of explanation.
			if cur_explanation != null:
				var corridor_endpoint: Vector2i = cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir] * int(cur_dir_weight)
				cur_explanation.segments.append({
					"from": cur_coords,
					"to": corridor_endpoint,
					"value": cur_dir_weight,
					"show_value": true,
					"highlight_rooms": true,
				})
	
	# Aggregate calculated weights according to the placement type config.
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


## Recursively measures a single straight corridor in the specified direction according to the provided [param placement_type] restrictions.
## Uses provided [param cur_room_coords] to keep track which room in the corridor is being currently checked.
## Uses provided [param last_dir] to keep track in which direction the current corridor keeps expanding to check current room parameters related to direction and select a next one to be checked.
## Uses provided [param length] to keep track of the checked corridor length.
func _calculate_weights_placement_type_corridor_recursive(placement_type: SecretPlacementType, cur_room_coords: Vector2i, last_dir: Direction, length: int) -> float:
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
	return _calculate_weights_placement_type_corridor_recursive(
		placement_type,
		cur_room_coords + DIRECTION_TO_COORDS_OFFSET[last_dir],
		last_dir,
		length + 1,
	)


## Calculates a candidate weight for [param placement_type] distance by aggregating distances from the provided [param cur_coords] to the related room types.
## Uses provided [param prepared_placement_type_data] to access the related rooms list prepared before calling this function.
## When [param cur_explanation] is provided, records each calculated distance along with from where to where it was calculated.
func _calculate_weights_placement_type_distance(prepared_placement_type_data: Dictionary[String, Variant], placement_type: SecretPlacementType, cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation = null) -> float:
	# Prepare array for calculated weights.
	var calculated_weights: Array[float] = []
	
	#NOTE: Against what the game description may sound like, it appears that this formula is incorrect, since it uses room centers, while the game calculates the distances using the room farthest corners.
	## Calculate absolute distance from each related room types coords to the current room coords
	#for related_room_type_coords in prepared_placement_type_data["related_room_types_coords"]:
	#	calculated_weights.append(cur_coords.distance_to(related_room_type_coords))
	
	# Calculate the grid distance from each related room type to the current room coordinates using the room center + 1 to account for the calculations taking into account farthest corners of the room rather than their centers.
	for related_room_type_coords: Vector2i in prepared_placement_type_data["related_room_types_coords"]:
		var delta: Vector2i = cur_coords - related_room_type_coords
		var distance_x: float = float(absi(delta.x) + 1)
		var distance_y: float = float(absi(delta.y) + 1)
		var distance: float = sqrt(distance_x * distance_x + distance_y * distance_y)
		calculated_weights.append(distance)
		
		# Store calculated distance between two coords as part of explanation.
		# Highlight only the source "to" room, withouth hightlighting any other rooms.
		if cur_explanation != null:
			cur_explanation.segments.append({
				"from": cur_coords,
				"to": related_room_type_coords,
				"value": distance,
				"show_value": true,
				"highlight_to_room": true,
				"fallback_room_coords": related_room_type_coords,
			})
	
	# Aggregate calculated weights according to the placement type config.
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


## Placement type intersection contributes no numerical weight, so by default it returns 0.0.
## Only marked and defined to keep it consistent with other functions and so that it would not be assigned as omitted or unintentional in the future.
func _calculate_weights_placement_type_intersection(_prepared_placement_type_data: Dictionary[String, Variant], _placement_type: SecretPlacementType, _cur_coords: Vector2i, _cur_explanation: MapSolverPlacementExplanation) -> float:
	return 0.0


## Calculates a candidate weight for [param placement_type] loop by checking all possible loops from the provided [param cur_coords] point.
## Uses provided [param prepared_placement_type_data] to access a room connections groups dictionary containing room coords used as keys and their assigned group number as values.
## When [param cur_explanation] is provided, records best representative loop that was found.
func _calculate_weights_placement_type_loop(prepared_placement_type_data: Dictionary[String, Variant], placement_type: SecretPlacementType, cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation) -> float:
	# Prepare array for calculated weights.
	var calculated_weights: Array[float] = []
	
	# Retain only one representative route for the visual explanation.
	var representative_route: Dictionary = {}
	var prefer_shortest: bool = placement_type.count_type == SecretPlacementType.CountType.MIN
	
	# Prepare a dictionary where for each distinct room group, it will have a list of all the neighbouring rooms coords.
	var neighbours_groups_coords: Dictionary[int, Variant] = {}
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction.
		if current_dir == Direction.NONE:
			continue
		
		# Prepare a list of neighbour coords divided into each separate groups.
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords in prepared_placement_type_data["room_connections_groups"]:
			# Check if the room doesn't have a blockade in the direction of the current coords, if yes then skip counting it.
			var neighbour_room_instance_data := _map_state.get_room_instance(neighbour_coords)
			if neighbour_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[current_dir]):
				continue
			
			# Assign neighbour coords to correct group/
			var neighbour_group_id = prepared_placement_type_data["room_connections_groups"][neighbour_coords]
			if neighbour_group_id in neighbours_groups_coords:
				neighbours_groups_coords[neighbour_group_id].append(neighbour_coords)
			else:
				var group_coords: Array[Vector2i] = [neighbour_coords]
				neighbours_groups_coords[neighbour_group_id] = group_coords
	
	# Calculate weights for each neighbours room groups that have at least 2 coords assigned to them (excluding group id -1).
	for group_id in neighbours_groups_coords:
		if group_id == -1:
			continue
		
		var group_coords: Array[Vector2i] = neighbours_groups_coords[group_id]
		if group_coords.size() < 2:
			continue
		
		# Get direction from current room to all neighbour room in the group.
		var neighbouring_coords_last_dir: Dictionary[Vector2i, Direction]
		for cur_neighbour_coords in group_coords:
			var neighbour_offset = cur_neighbour_coords - cur_coords
			for offset_dir in DIRECTION_TO_COORDS_OFFSET:
				if DIRECTION_TO_COORDS_OFFSET[offset_dir] == neighbour_offset:
					neighbouring_coords_last_dir[cur_neighbour_coords] = offset_dir
					break
		
		# Calculate max path lengths from each neighbour coords to the current coords.
		for cur_neighbour_coords in neighbouring_coords_last_dir.keys():
			var cur_last_dir := neighbouring_coords_last_dir[cur_neighbour_coords]
			# Find all paths lenghts from the current neighbour coords to the result current coords and save them as calculated weights.
			var route_start: Array[Vector2i] = []
			if cur_explanation != null:
				route_start.append(cur_coords)
			
			_find_all_room_paths_lengths(
				cur_neighbour_coords, 
				cur_coords, 
				1, 
				{}, 
				calculated_weights, 
				cur_last_dir,
				representative_route,
				prefer_shortest,
				route_start,
				cur_explanation != null,
			)
	
	# Store every saved completed loop route.
	if cur_explanation != null and not representative_route.is_empty():
		for route_coords: Array[Vector2i] in representative_route["routes"]:
			cur_explanation.paths.append({
				"coords": route_coords.duplicate(),
				"value": float(representative_route["value"]),
				"show_value": false,
			})
	
	# Aggregate calculated weights according to the placement type config.
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


## Calculates a candidate weight for [param placement_type] neighbour by checking contribution from neighbouring rooms from the provided [param cur_coords] point.
## When [param cur_explanation] is provided, records each neighbouring coords contribution to the calculated weight.
func _calculate_weights_placement_type_neighbour(_prepared_placement_type_data: Dictionary[String, Variant], placement_type: SecretPlacementType, cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation) -> float:
	# Prepare array for calculated weights.
	var calculated_weights: Array[float] = []
	var contributions_by_coords: Dictionary[Vector2i, int] = {}
	
	# Find and check current coords neighbours in placement type specified range and type.
	_find_room_neighbours_placement_type_weights(
		cur_coords,
		cur_coords,
		placement_type,
		calculated_weights,
		[],
		Direction.NONE,
		contributions_by_coords,
		cur_explanation != null,
	)
	
	# Store calculated contributions per coord for neighbours as part of explanation.
	if cur_explanation != null:
		for room_coords: Vector2i in contributions_by_coords:
			cur_explanation.room_values.append({
				"coords": room_coords,
				"value": float(contributions_by_coords[room_coords]),
			})
	
	# Aggregate calculated weights according to the placement type config.
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


## Calculates a candidate weight for [param placement_type] path by finding all valid paths from the provided [param cur_coords] to the related start room types.
## Uses provided [param prepared_placement_type_data] to access the list of start room coords that should be checked in comparison to the current room coords.
## When [param cur_explanation] is provided, records best representative path that was found.
func _calculate_weights_placement_type_path(prepared_placement_type_data: Dictionary[String, Variant], placement_type: SecretPlacementType, cur_coords: Vector2i, cur_explanation: MapSolverPlacementExplanation) -> float:
	# Prepare array for calculated weights
	var calculated_weights: Array[float] = []
	
	# Select one completed route for visualizing this placement type.
	var representative_route: Dictionary = {}
	var prefer_shortest: bool = placement_type.count_type == SecretPlacementType.CountType.MIN
	
	# Find all room paths lengths for each starter room found
	for start_room_coords in prepared_placement_type_data["start_room_types_coords"]:
		_find_all_room_paths_lengths(
			start_room_coords, 
			cur_coords, 
			0, 
			{}, 
			calculated_weights, 
			Direction.NONE,
			representative_route,
			prefer_shortest,
			[],
			cur_explanation != null,
		)
	
	# Record every saved representative completed path if any exists.
	if cur_explanation != null and not representative_route.is_empty():
		for route_coords: Array[Vector2i] in representative_route["routes"]:
			cur_explanation.paths.append({
				"coords": route_coords.duplicate(),
				"value": float(representative_route["value"]),
				"show_value": false,
			})
	
	# Aggregate calculated weights according to the placement type config
	return _placement_type_aggregate_calculated_weights(placement_type, calculated_weights)


## Records neighbour weight contribution for the provided [param cur_coords] by appending it's contribution to the provided [param neighbours_weights] list.
## Also assigns contribution to the provided [param contributions_by_coords] dictionary that tracks each coord exact weight contribution if the provided [param capture_contributions] flag is set.
func _record_neighbour_weigh_contribution(neighbours_weights: Array[float], cur_coords: Vector2i, contributions_by_coords: Dictionary[Vector2i, int], capture_contributions: bool) -> void:
	# Add neighbour weight contribution to the calculated weights.
	neighbours_weights.append(1)
	
	# Record this weight contribution inside contributions per coords when flag capture contributions is set.
	if capture_contributions:
		contributions_by_coords[cur_coords] = int(contributions_by_coords.get(cur_coords, 0)) + 1


## Recursively checks rooms in the configured [param placement_type] neighbour range.
## Appends all eligible visits to [param neighbour_weights] list.
## Uses provided [param start_coords] and [param cur_coords] to determine current range from the checked coordinates.
## Uses provided [param checked_neighbour_coords] list to keep track which coordinates have already been looked through.
## Uses provided [param last_dir] to keep track in which direction the last move from previous coordinates was taken to not repeat it.
## Uses [param capture_contributions] flag and [param contributions_by_coords] dictionary to keep track of each neighbour coordinates contribution to the calculated weights.
func _find_room_neighbours_placement_type_weights(
	start_coords: Vector2i,
	cur_coords: Vector2i,
	placement_type: SecretPlacementType,
	neighbours_weights: Array[float],
	checked_neighbours_coords: Array[Vector2i],
	last_dir: Direction = Direction.NONE,
	contributions_by_coords: Dictionary[Vector2i, int] = {},
	capture_contributions: bool = false,
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
				_record_neighbour_weigh_contribution(neighbours_weights, cur_coords, contributions_by_coords, capture_contributions)
				
			elif placement_type.neighbour_type == SecretPlacementTypeNeighbour.NeighbourType.NONSECRET:
				if not cur_room_has_secret and not cur_room_has_barricade:
					_record_neighbour_weigh_contribution(neighbours_weights, cur_coords, contributions_by_coords, capture_contributions)
				
			elif placement_type.neighbour_type == SecretPlacementTypeNeighbour.NeighbourType.BARRICADE:
				if cur_room_has_barricade:
					_record_neighbour_weigh_contribution(neighbours_weights, cur_coords, contributions_by_coords, capture_contributions)
	
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
		_find_room_neighbours_placement_type_weights(start_coords, neighbour_coords, placement_type, neighbours_weights, checked_neighbours_coords, current_dir, contributions_by_coords, capture_contributions)


## Records one completed path for a validation stage explanation without saving or aggregating their lenghts.
func _record_validation_explanation_route(explanation: MapSolverPlacementExplanation, route_coords: Array[Vector2i]) -> void:
	# Ignore empty routes and stop storing routes at the visual safety limit.
	if route_coords.is_empty() or explanation.paths.size() >= MAX_VALIDATION_EXPLANATION_ROUTES:
		return
	
	# Prepare the reverse route for direction independant comparison.
	var reversed_route: Array[Vector2i] = route_coords.duplicate()
	reversed_route.reverse()
	
	# Ignore a route if its geometry was already captured.
	for saved_path: Dictionary in explanation.paths:
		var saved_coords: Array = saved_path.get("coords", [])
		if saved_coords == route_coords or saved_coords == reversed_route:
			return
	
	# Save a route for the existing line and room highlight renderer.
	explanation.paths.append({
		"coords": route_coords.duplicate(),
		"value": 0.0,
		"show_value": false,
	})


## Registers a completed route's length by appending the provided [param length] to the provided [param paths_lengths_array] list.
## Uses provided [param capture_route] flag to determine if the current path length should be saved as best representation.
## Best representative is set based on the provided [param prefer_shortest] flag which defined if it prefers shorter or longer paths as representatives.
## The current path lengths is determined based on the provided [param current_route] lsit which stores a list of visited coordinates.
## Uses provided [param representative_route] to keep track of the best recorded representative.
func _record_completed_room_path(length: int, paths_lengths_array: Array[float], representative_route: Dictionary, prefer_shortest: bool, current_route: Array[Vector2i], capture_route: bool) -> void:
	# Save path length.
	paths_lengths_array.append(length)
	
	# Skip capturing route if the capture route flag is unset.
	if not capture_route:
		return
	
	# Determine whether the new path has a better representative length.
	var replace_best: bool = representative_route.is_empty()
	if not replace_best:
		var previous_length: int = int(representative_route["value"])
		replace_best = length < previous_length if prefer_shortest else length > previous_length
	
	# Invalidate all previously selected routes if better one was found.
	if replace_best:
		representative_route["value"] = float(length)
		representative_route["routes"] = [current_route.duplicate()]
		return
	
	# Keep additional distinct routes with the same best length.
	if length == int(representative_route["value"]):
		var selected_routes: Array = representative_route["routes"]
		if not selected_routes.has(current_route):
			selected_routes.append(current_route.duplicate())


## Recursively records every qualifying path length between two coordinates.
## When [param capture_route] flag is set, also tracks an ordered route and stores only the selected representative in [param representative_route].
func _find_all_room_paths_lengths(
	cur_coords: Vector2i,
	target_coords: Vector2i,
	length: int, 
	visited: Dictionary[Vector2i, bool], 
	paths_lengths_array: Array[float],
	last_dir: Direction = Direction.NONE,
	representative_route: Dictionary = {},
	prefer_shortest: bool = false,
	current_route: Array[Vector2i] = [],
	capture_route: bool = false,
	validation_explanation: MapSolverPlacementExplanation = null,
) -> void:
	# Stop route-only traversal if the requested number of visual routes has already been collected. Weighted traversal is not affected.
	if validation_explanation != null and validation_explanation.paths.size() >= MAX_VALIDATION_EXPLANATION_ROUTES:
		return
	
	# Prepare the path through this coordinate only when visual capture is on or for validation stage route-only evidence.
	var route_at_current: Array[Vector2i] = []
	if capture_route or validation_explanation != null:
		route_at_current = current_route.duplicate()
		route_at_current.append(cur_coords)
	
	# Stop further processing if current room is empty and check if they are the target room.
	var cur_room_instance_data := _map_state.get_room_instance(cur_coords)
	if cur_room_instance_data == null:
		# Save path length or record route for validation stage route-only evidence if the current coords are the same as target coords.
		if cur_coords == target_coords:
			if validation_explanation != null:
				_record_validation_explanation_route(validation_explanation, route_at_current)
			else:
				_record_completed_room_path(length, paths_lengths_array, representative_route, prefer_shortest, route_at_current, capture_route)
		return
	
	# Check if the current room has a barricade in the same direction made as the last room, if yes then stop further processing.
	if last_dir != Direction.NONE and cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CONNECTED_ROOM_DIRECTION_FLAGS[last_dir]):
		return
	
	# Check if current coords are the same as the target coords and save them if they are.
	if cur_coords == target_coords:
		if validation_explanation != null:
			_record_validation_explanation_route(validation_explanation, route_at_current)
		else:
			_record_completed_room_path(length, paths_lengths_array, representative_route, prefer_shortest, route_at_current, capture_route)
	
	# Stop further processing if current room is a secret room of any kind.
	if cur_room_instance_data.get_secret_type_kind() != RoomSecretType.Kind.NONE:
		return
	
	# Mark current coords as visited in the current recursive branch.
	visited[cur_coords] = true
	
	# Check each neighbouring room coords.
	for current_dir: Direction in Direction.values():
		# For each direction apart from the default NONE direction and the last made direction.
		if current_dir == Direction.NONE or (last_dir != Direction.NONE and current_dir == DIRECTION_TO_OPPOSITE_DIRECTION[last_dir]):
			continue
		
		# Stop processing the direction if the current room has barricade set in the same direction.
		if cur_room_instance_data.has_barricade(DIRECTION_TO_BARRICADE_CURRENT_ROOM_DIRECTION_FLAGS[current_dir]):
			continue
		
		# Prepare a recursive check for a given direction if it wasn't visited before.
		var neighbour_coords := cur_coords + DIRECTION_TO_COORDS_OFFSET[current_dir]
		if neighbour_coords not in visited:
			_find_all_room_paths_lengths(
				neighbour_coords, 
				target_coords, 
				length + 1, 
				visited, 
				paths_lengths_array, 
				current_dir,
				representative_route,
				prefer_shortest,
				route_at_current,
				capture_route,
				validation_explanation,
			)
	
	# Unmark current coords as visited.
	visited.erase(cur_coords)


func _placement_type_aggregate_calculated_weights(placement_type: SecretPlacementType, calculated_weights: Array[float]) -> float:
	var output_weight: float = 0
	
	# Filter out processing if the provided calculated weights are empty.
	if calculated_weights.size() <= 0:
		return output_weight
	
	if placement_type.count_type == SecretPlacementType.CountType.SUM:
		output_weight = calculated_weights.reduce(func(accum, number): return accum + number, 0)
	elif placement_type.count_type == SecretPlacementType.CountType.SUB:
		output_weight = calculated_weights.reduce(func(accum, number): return accum - number, 0)
	elif placement_type.count_type == SecretPlacementType.CountType.MAX:
		output_weight = calculated_weights.max()
	elif placement_type.count_type == SecretPlacementType.CountType.MIN:
		output_weight = calculated_weights.min()
	
	return output_weight


func _find_solutions(result: MapSolverResult, placement_config: SecretPlacementConfig, secret_room_generate_count: int) -> bool:
	# Set status message and filter out processing if the placement config weight count type is set to none.
	if placement_config.weight_count_type == SecretPlacementConfig.CountType.NONE:
		result.append_status_message("Cannot predict placement for a secret room type without any weight preference set")
		return false
	
	# Set status message and filter out processing if the aren't any rooms left to predict.
	if secret_room_generate_count <= 0:
		result.append_status_message("No rooms remain to be predicted")
		return false
	
	# Prepare placement conflicts lists for each placement coord and group the placement coords based on the calculated weights.
	var conflicts: MapSolverPlacementConflicts = _prepare_placement_conflicts(result, placement_config)
	var weight_groups: Array[MapSolverPlacementWeightGroup] = result.get_placement_weight_groups(placement_config.weight_count_type)
	
	# Look through each weight group and prepare alternative placement scenarios in case of conflicts creating multiple possible selections groups. 
	var scenarios: Array[MapSolverPlacementScenario] = [MapSolverPlacementScenario.new()]
	for weight_group: MapSolverPlacementWeightGroup in weight_groups:
		var next_scenarios: Array[MapSolverPlacementScenario] = []
		for scenario: MapSolverPlacementScenario in scenarios:
			# Prepare variables for the current scenario.
			var remaining_count: int = secret_room_generate_count - scenario.selected_coords.size()
			
			# Append current scenario at the end of next scenarios list in order to keep track of it and later on aggregate results from it.
			if remaining_count <= 0:
				next_scenarios.append(scenario)
				continue
			
			# Find possible selections groups from the current weight group list.
			var selections: Array[MapSolverPlacementSelection] = _find_maximal_group_selections(weight_group, scenario.selected_coords, remaining_count, conflicts)
			
			# Check if the overflow flag hasn't been set or the overflow point hasn't been reached.
			if _placement_selection_overflow or selections.is_empty() or next_scenarios.size() + selections.size() > MAX_PLACEMENT_SCENARIOS:
				result.append_status_message("Placement predictions exceeded scenario limit, weights are still available")
				return false
			
			# Prepare new scenarios based on the results from the current scenario using the current weight group list candidates.
			var branch_probability: float = scenario.probability / float(selections.size())
			for selection: MapSolverPlacementSelection in selections:
				var combined: Array[Vector2i] = scenario.selected_coords.duplicate()
				combined.append_array(selection.coords)
				next_scenarios.append(MapSolverPlacementScenario.new(combined, branch_probability))
		
		# Assign prepared next scenarios list as the current scenarios list.
		scenarios = next_scenarios
	
	# Calculate probabilities from the created selection scenarios.
	result.calculate_probability_result_coords_from_scenarios(scenarios)
	
	# Mark stage state.
	result.stage = MapSolverResult.SolveStage.FOUND_SOLUTION
	
	return true


## Prepares and returns a dictionary containing a list of coords for placements that conflicts with some other coords for placement.
## Uses the provided [param candidates] param to access placement candidates coords and provided [param placement_config] to check and determine if the placement restrictions are abided between placement candidates. 
func _prepare_placement_conflicts(result: MapSolverResult, placement_config: SecretPlacementConfig) -> MapSolverPlacementConflicts:
	var conflicts: MapSolverPlacementConflicts = MapSolverPlacementConflicts.new()
	var candidate_coords: Array[Vector2i] = result.get_result_coords()
	
	# Initialize conflict lookup for every candidate coords.
	for coords: Vector2i in candidate_coords:
		conflicts.register_coord(coords)
	
	# Compare each unique pair of candidates.
	for i: int in range(candidate_coords.size()):
		for j: int in range(i + 1, candidate_coords.size()):
			var a: Vector2i = candidate_coords[i]
			var b: Vector2i = candidate_coords[j]
			
			var offset: Vector2i = a - b
			var distance: int = absi(offset.x) + absi(offset.y)
			
			# Check placement restrictions.
			var incompatible: bool = false
			# Check minimum distance restrictions.
			incompatible = distance < placement_config.room_distance
			# Check secret-neighbour restriction.
			if distance == 1 and not placement_config.neighbour_allow_secret:
				incompatible = true
			
			# Store both directions of the conflict.
			if incompatible:
				conflicts.add_conflict(a, b)
	
	return conflicts


## Find the best maximum selection group of coords from the provided [param weight_group] that is currently being processed while taking into account how many of them needs to be selected based on the provided [param remaining_count].
## Provided [param already_selected] list is used to check which other coords have already been selected and compare them with the provided [param conflicts] to ensure that conflicting coords won't be selected.
func _find_maximal_group_selections(weight_group: MapSolverPlacementWeightGroup, already_selected: Array[Vector2i], remaining_count: int, conflicts: MapSolverPlacementConflicts) -> Array[MapSolverPlacementSelection]:
	# Reset the overflow flag.
	_placement_selection_overflow = false
	
	# Checks which of the placement candidates don't have any conflicts with the already selected coords and are available to select.
	var available: Array[Vector2i] = []
	for coords: Vector2i in weight_group.coords:
		if not conflicts.conflicts_with_any(coords, already_selected):
			available.append(coords)
	
	# Determine the best maximum selection group from the filtered list of available coords.
	var selections: Array[MapSolverPlacementSelection] = []
	var empty_selection: Array[Vector2i] = []
	_collect_maximal_group_selections(available, 0, empty_selection, remaining_count, conflicts, selections)
	
	return selections


## Searches recursively for all possible maximum group selections from the provided [param available] list of coords that would satisfy the provided [param remaining_count] of candidates to be selected.
## Provided [param index] and [param selected_from_group] are the parameters to control the recursive call by tracking currently processed candidate and which candidates have been already selected in the current recursion step.
## Provided [param conflicts] are used to check if the next candidate won't have any conflicts with the already selected candidates.
## Provided [param output] is used to store all the found possible maximum group selections and is used to store and return them after function finishes.
func _collect_maximal_group_selections(available: Array[Vector2i], index: int, selected_from_group: Array[Vector2i], remaining_count: int, conflicts: MapSolverPlacementConflicts, output: Array[MapSolverPlacementSelection]) -> void:
	# Check if the overflow flag hasn't been set and filter out processing if it has been.
	if _placement_selection_overflow:
		return
	
	# Stops further recursive calls if the current index reaches the end of the available list or if the already selected coords list is equal or bigger then the count of remaining coords that need to be selected.
	if index == available.size() or selected_from_group.size() >= remaining_count:
		# Assign current group selection as an possible output if the group selection is maximal.
		if _is_group_selection_maximal(selected_from_group, available, remaining_count, conflicts):
			# Check if the overflow point hasn't been reached.
			if output.size() >= MAX_PLACEMENT_SCENARIOS:
				_placement_selection_overflow = true
				return
			
			# Append current group selection as an possible output.
			output.append(MapSolverPlacementSelection.new(selected_from_group))
		return
	
	# Prepare a new candidate group extended with the next candidate coords and recursively checks for a new combination with it if the next coords don't cause conflicts with already selected candidates.
	var candidate_coords: Vector2i = available[index]
	if not conflicts.conflicts_with_any(candidate_coords, selected_from_group):
		var with_candidate: Array[Vector2i] = selected_from_group.duplicate()
		with_candidate.append(candidate_coords)
		_collect_maximal_group_selections(available, index + 1, with_candidate, remaining_count, conflicts, output)
	
	# Prepare a new candidate group skipping the next candidate and recursively checks for a new combination without it.
	_collect_maximal_group_selections(available, index + 1, selected_from_group, remaining_count, conflicts, output)


## Checks if the provided [param selected_from_group] is an maximal group selection and is an valid candidate group.
## Uses provided [param available] to check what were available candidates, [param remaining_count] to check how many of them were supposed to be selected and [param conflicts] to check their conflicts between each other.
func _is_group_selection_maximal(selected_from_group: Array[Vector2i], available: Array[Vector2i], remaining_count: int, conflicts: MapSolverPlacementConflicts) -> bool:
	# Returns true if the selected candidates group size is bigger or equal to the remaining count of candidates that were supposed to be selected.
	if selected_from_group.size() >= remaining_count:
		return true
	
	# Returns false if any of available candidates weren't selected and there weren't any conflicts with them and the already selected candidates.
	for coords: Vector2i in available:
		if coords not in selected_from_group and not conflicts.conflicts_with_any(coords, selected_from_group):
			return false
	
	# Otherwise return true.
	return true
