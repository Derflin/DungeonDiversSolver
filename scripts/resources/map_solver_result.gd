class_name MapSolverResult
extends RefCounted


enum SolveStage {
	NONE,
	FOUND_VALID_PLACEMENTS,
	CALCULATED_WEIGHTS,
	FOUND_SOLUTION,
}


var stage: SolveStage = SolveStage.NONE
var result_coords: Array[MapSolverResultCoord] = []
var status_msg: Array[String] = []


func get_result_coords() -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	
	for result in result_coords:
		if result.coords not in output:
			output.append(result.coords)
	
	return output


func assign_coord_to_result(coords: Vector2i) -> void:
	var result_coord := MapSolverResultCoord.new(coords)
	
	var coords_exist := false
	for result in result_coords:
		if result.coords == coords:
			coords_exist = true
			break
	
	if not coords_exist:
		result_coords.append(result_coord)


func unassign_coord_from_result(coords: Vector2i) -> void:
	for result in result_coords:
		if result.coords == coords:
			result_coords.erase(result)


func initialize_result_coords_weights() -> void:
	for result in result_coords:
		result.calculated_weight = 0


func get_status_message() -> String:
	return "\n".join(status_msg)


func append_status_message(text: String) -> void:
	status_msg.append(text)


func clear_status_message() -> void:
	status_msg.clear()


func get_all_result_coords_weights() -> Array[float]:
	var result: Array[float] = [] 
	
	for result_coord in result_coords:
		result.append(result_coord.calculated_weight)
	
	return result


func assign_weight_to_result_coords(coords: Vector2i, weight: float) -> void:
	for result in result_coords:
		if result.coords == coords:
			result.calculated_weight = weight
			break


## Assigns weights from the provided [param weights_by_coords] dictionary containing calculated weights values for each coord.
## If the existing coord in the result wouldn't exist in the provided dictionary, then it would be assigned a weight of value 0. 
func assign_weights_to_result_coords(weights_by_coords: Dictionary[Vector2i, float]) -> void:
	for result_coord: MapSolverResultCoord in result_coords:
		result_coord.calculate_weight = weights_by_coords.get(result_coord.coords, 0.0)


func initialize_result_coords_probabilities() -> void:
	for result in result_coords:
		result.probability = 0.0


func get_all_result_coords_probabilities() -> Array[float]:
	var result: Array[float] = []
	
	for result_coord in result_coords:
		result.append(result_coord.probability)
	
	return result


func assign_probability_to_result_coords(coords: Vector2i, probability: float) -> void:
	for result in result_coords:
		if result.coords == coords:
			result.probability = probability
			break


## Prepares and returns the map solver placement weight groups list for the current;y stored result coords.
## Uses the provided [param weight_count_type] to determine the sort type that will be applied to the result coords and in which order they will be grouped together.
func get_placement_weight_groups(weight_count_type: SecretPlacementConfig.CountType) -> Array[MapSolverPlacementWeightGroup]:
	var groups: Array[MapSolverPlacementWeightGroup] = []
	
	# Return empty groups if the provided weight count type is none.
	if weight_count_type == SecretPlacementConfig.CountType.NONE:
		return groups
	
	# Sort the existing result coords according to the provided weight count type.
	var sorted_coords: Array[MapSolverResultCoord] = result_coords.duplicate()
	if weight_count_type == SecretPlacementConfig.CountType.MAX:
		sorted_coords.sort_custom(func(a: MapSolverResultCoord, b: MapSolverResultCoord) -> bool: return a.calculated_weight > b.calculated_weight)
	elif weight_count_type == SecretPlacementConfig.CountType.MIN:
		sorted_coords.sort_custom(func(a: MapSolverResultCoord, b: MapSolverResultCoord) -> bool: return a.calculated_weight < b.calculated_weight)
	else:
		return groups
	
	# Prepare placement weight groups based on the sorted result coords and their calculated weights.
	for candidate: MapSolverResultCoord in sorted_coords:
		if groups.is_empty() or not is_equal_approx(candidate.calculated_weight, groups[-1].weight):
			groups.append(MapSolverPlacementWeightGroup.new(candidate.calculated_weight))
		groups[-1].coords.append(candidate.coords)
	
	return groups


## Calculates and assigns the probabilites for the result coords set inside the map solver result.
## Uses the provided [param scenarios] list to go through analyzed scenarios and aggregate calculated probabilites from them.
func calculate_probability_result_coords_from_scenarios(scenarios: Array[MapSolverPlacementScenario]) -> void:
	# Initialize result coords probability to default value.
	initialize_result_coords_probabilities()
	
	# Aggregate calculated probabilites assigned to the provided scenarios for each of the result coords.
	var probability_by_coords: Dictionary[Vector2i, float] = {}
	for scenario: MapSolverPlacementScenario in scenarios:
		for coords: Vector2i in scenario.selected_coords:
			probability_by_coords[coords] = probability_by_coords.get(coords, 0.0) + scenario.probability
	
	# Assign and save the aggregated probabilities inside the result coords.
	for result_coord: MapSolverResultCoord in result_coords:
		result_coord.probability = clampf(probability_by_coords.get(result_coord.coords, 0.0), 0.0, 1.0)
	
	# Remove any result coords that either have invalid probabilities or equal to 0.
	for index: int in range(result_coords.size() - 1, -1, -1):
		if result_coords[index].probability <= 0.0:
			result_coords.remove_at(index)
	


func calculate_probability_result_coords(expected_room_count: int, weight_count_type: SecretPlacementConfig.CountType) -> void:	
	var remaining_room_count := expected_room_count
	
	# Initialize result coords probability to default value
	initialize_result_coords_probabilities()
	
	# Sort result coords according to the calculated weights and the weight count type from placement config
	if weight_count_type == SecretPlacementConfig.CountType.MIN:
		# Sort ascending
		result_coords.sort_custom(func(a, b): return a.calculated_weight < b.calculated_weight)
	elif weight_count_type == SecretPlacementConfig.CountType.MAX:
		# Sort descending
		result_coords.sort_custom(func(a, b): return a.calculated_weight > b.calculated_weight)
	else:
		return
	
	# Calculate probability for each result coords
	var processed_index := -1
	var cur_weight_calculated_probability: float = 1.0
	for cur_index in range(result_coords.size()):
		# Stop looking through result coords if the room count satisfied
		if remaining_room_count <= 0:
			break
		
		# Gather data about current result coords
		var cur_result_coords = result_coords[cur_index]
		processed_index += 1
		
		# Assing 100% probability if the remaining result coords are enough to fulfill the remaining room count
		if result_coords.size() - processed_index < remaining_room_count:
			cur_result_coords.probability = 1.0
			remaining_room_count -= 1
			continue
		
		# Calculate probability for the current weight if current result index is the first one or if it has a different weight then a previous one
		if cur_index == 0 or result_coords[cur_index - 1].calculated_weight != cur_result_coords.calculated_weight:
			cur_weight_calculated_probability = 1.0
			
			# Check how many next result coords have the same weight as the current one
			var count_same_weight := 1
			for weight_check_index in range(cur_index + 1, result_coords.size()):
				if result_coords[weight_check_index].calculated_weight == cur_result_coords.calculated_weight:
					count_same_weight += 1
				else:
					break
			
			# Adjust calculated probability for the current weight and the remaining room count based on the count of result coords with the same weight as the current one
			if count_same_weight > remaining_room_count:
				cur_weight_calculated_probability = float(remaining_room_count) / float(count_same_weight)
				remaining_room_count = count_same_weight
		
		# Assign calculated probability for the current weight and adjust the remaining room count
		cur_result_coords.probability = cur_weight_calculated_probability
		remaining_room_count -= 1
	
	# Remove result coords that have probability equal to 0.0
	var deleted_room_indexes: Array[int] = []
	for cur_index in range(result_coords.size()):
		if result_coords[cur_index].probability <= 0.0:
			deleted_room_indexes.append(cur_index)
	deleted_room_indexes.reverse()
	for cur_index in deleted_room_indexes:
		result_coords.remove_at(cur_index)


## Assigns priority groups to the remaining results based on their calculcated weights and the provided [param weight_count_type] to group them.
## Priorities are assigned for each weight group's members incrementally.
func assign_priority_groups(weight_count_type: SecretPlacementConfig.CountType) -> void:
	# Initialize initial value of the priority groups for the result coords.
	for result_coord: MapSolverResultCoord in result_coords:
		result_coord.priority_group = 0
	
	# Group the placement coords based on the calculated weights.
	var groups: Array[MapSolverPlacementWeightGroup] = get_placement_weight_groups(weight_count_type)
	
	# Filter out processing if the groups are empty.
	if groups.is_empty():
		return
	
	# Prepare a dictionary mapping coords to specific result coords.
	var by_coords: Dictionary[Vector2i, MapSolverResultCoord] = {}
	for result_coord: MapSolverResultCoord in result_coords:
		by_coords[result_coord.coords] = result_coord
	
	# Assign priority groups to each of the weight groups members.
	for index: int in range(groups.size()):
		for coords: Vector2i in groups[index].coords:
			if by_coords.has(coords):
				by_coords[coords].priority_group = index + 1


func assign_color_code(text_color_gradient: Gradient, weight_count_type: SecretPlacementConfig.CountType, use_weights: bool = false, use_probabilities: bool = false) -> void:
	# Filter out processing if all function state flags are disabled
	if not use_weights and not use_probabilities:
		return
	
	# Filter out processing if there aren't any results to color code
	if result_coords.is_empty():
		return
	
	# Filter out processing if weight count type is none
	if use_weights and weight_count_type == SecretPlacementConfig.CountType.NONE:
		return
	
	# Mark a single result to always be considered the best if there aren't any others
	if result_coords.size() == 1:
		result_coords[0].text_color = text_color_gradient.sample(1.0)
		return
	
	# Calculate min and max weights based on the function state flags
	var min_weight: float = 0.0
	var max_weight: float = 0.0
	var weights_equal: bool = false
	if use_weights:
		var all_weights := get_all_result_coords_weights()
		min_weight = all_weights.min()
		max_weight = all_weights.max()
		weights_equal = is_equal_approx(min_weight, max_weight)
	
	# Assign colors to results
	for result_coord in result_coords:
		var color_percentage: float = 1.0
		
		# Calculate color percentage for the gradient
		if use_weights:
			if not weights_equal:
				color_percentage = inverse_lerp(min_weight, max_weight, result_coord.calculated_weight)
				
				# Apply calculated color percentages based on provided the placement config
				if weight_count_type == SecretPlacementConfig.CountType.MIN:
					color_percentage = 1.0 - color_percentage
				elif weight_count_type == SecretPlacementConfig.CountType.MAX:
					color_percentage = color_percentage
		else:
			color_percentage = result_coord.probability
		
		# Clamp color percentage and sample the gradient
		color_percentage = clampf(color_percentage, 0.0, 1.0)
		result_coord.text_color = text_color_gradient.sample(color_percentage)


#region Save Data Serialization
# These functions convert this object's persistent state to and from save data.

## Captures this object's persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	var saved_result_coords: Array = []
	for cur_result_coords in result_coords:
		saved_result_coords.append(cur_result_coords.capture_save_data())
	
	return {
		"stage": stage,
		"result_coords": saved_result_coords,
		"status_msg": status_msg.duplicate(true),
	}


## Restores this object's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	var loaded_result_coords: Array[MapSolverResultCoord] = []
	for saved_result_coords in data["result_coords"]:
		var new_result_coords = MapSolverResultCoord.new()
		new_result_coords.restore_save_data(saved_result_coords)
		loaded_result_coords.append(new_result_coords)
	
	stage = data["stage"]
	result_coords = loaded_result_coords
	status_msg = data["status_msg"].duplicate(true)

#endregion
