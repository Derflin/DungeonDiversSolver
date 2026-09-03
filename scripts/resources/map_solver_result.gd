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


func intialize_result_coords_possibilities() -> void:
	for result in result_coords:
		result.possibility = 0.0


func get_all_result_coords_possibilites() -> Array[float]:
	var result: Array[float] = []
	
	for result_coord in result_coords:
		result.append(result_coord.possibility)
	
	return result


func assign_possibility_to_result_coords(coords: Vector2i, possibility: float) -> void:
	for result in result_coords:
		if result.coords == coords:
			result.possibility = possibility
			break


func calculate_possibility_result_coords(expected_room_count: int, weight_count_type: SecretPlacementConfig.CountType) -> void:
	var remaining_room_count := expected_room_count
	
	# Initialize result coords possibility to default value
	intialize_result_coords_possibilities()
	
	# Sort result coords according to the calculated weights and the weight count type from placement config
	if weight_count_type == SecretPlacementConfig.CountType.MIN:
		# Sort ascending
		result_coords.sort_custom(func(a, b): return a.calculated_weight < b.calculated_weight)
	elif weight_count_type == SecretPlacementConfig.CountType.MAX:
		# Sort descending
		result_coords.sort_custom(func(a, b): return a.calculated_weight > b.calculated_weight)
	else:
		return
	
	# Calculate possibility for each result coords
	var processed_index := -1
	var cur_weight_calculated_possibility: float = 1.0
	for cur_index in range(result_coords.size()):
		# Stop looking through result coords if the room count satisfied
		if remaining_room_count <= 0:
			break
		
		# Gather data about current result coords
		var cur_result_coords = result_coords[cur_index]
		processed_index += 1
				
		# Check if the remaining result coords are enough fullfil the remaining room count
		if result_coords.size() - processed_index < remaining_room_count:
			cur_result_coords.possibility = 1.0
			remaining_room_count -= 1
			continue
		
		# Check if the 
		if cur_index == 0 or result_coords[cur_index - 1].calculated_weight != cur_result_coords.calculated_weight:
			cur_weight_calculated_possibility = 1.0
			
			# Check how many next result coords have the same weight as the current one
			var count_same_weight := 0
			for weight_check_index in range(cur_index + 1, result_coords.size()):
				if result_coords[weight_check_index].calculated_weight == cur_result_coords.calculated_weight:
					count_same_weight += 1
				else:
					break
			
			# Adjust calculated possibility for the current weight and the remaining room count based on the count of result coords with the same weight as the current one
			if count_same_weight > expected_room_count:
				cur_weight_calculated_possibility /= count_same_weight
				remaining_room_count = count_same_weight
		
		# Assign calculated possibility for the current weight and adjust the remaining room count
		cur_result_coords.possibility = cur_weight_calculated_possibility
		remaining_room_count -= 1
	
	# Remove result coords that have possibility equal to 0.0
	var deleted_room_indexes: Array[int] = []
	for cur_index in range(result_coords.size()):
		if result_coords[cur_index].possibility <= 0.0:
			deleted_room_indexes.append(cur_index)
	deleted_room_indexes.reverse()
	for cur_index in deleted_room_indexes:
		result_coords.remove_at(cur_index)


func assign_color_code(text_color_gradient: Gradient, weight_count_type: SecretPlacementConfig.CountType, use_weights: bool = false, use_possibilities: bool = false) -> void:
	# Filter out processing if all function state flags are disabled
	if not use_weights and not use_possibilities:
		return
	
	# Filter out processing if weight count type is none
	if weight_count_type == SecretPlacementConfig.CountType.NONE:
		return
	
	# Calculate min and max values based on the function state flags
	var min_value: float
	var max_value: float
	if use_weights:
		var all_weights := get_all_result_coords_weights()
		min_value = all_weights.min()
		max_value = all_weights.max()
	elif use_possibilities:
		min_value = 0.0
		max_value = 1.0
	
	# Assign colors to results
	for result_coord in result_coords:
		if use_weights:
			# Calculate main color percantage
			var base_value := result_coord.calculated_weight
			var main_color_percentage: float = (base_value - min_value) / (max_value - min_value)
			
			# Assign text color based on the provided text color gradient
			if weight_count_type == SecretPlacementConfig.CountType.MIN:
				result_coord.text_color = text_color_gradient.sample(1.0 - main_color_percentage)
			elif weight_count_type == SecretPlacementConfig.CountType.MAX:
				result_coord.text_color = text_color_gradient.sample(main_color_percentage)
		else:
			# Calculate main color percentage
			var main_color_percentage := result_coord.possibility
			
			# Assign text color based on the provided text color gradient
			result_coord.text_color = text_color_gradient.sample(main_color_percentage)
