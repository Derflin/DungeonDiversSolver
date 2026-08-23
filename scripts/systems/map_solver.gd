class_name MapSolver
extends RefCounted


func find_secret_room_locations(
	room_instance_grid: Dictionary[Vector2i, RoomInstanceData], 
	secret_room_kind: RoomSecretType.Kind,
	only_hint_placement: bool = false,
	only_hint_placement_weights: bool = false,
) -> MapSolverResult:
	# Prepare return output value
	var result = MapSolverResult.new()
	
	# Check if GameData has specified secret room kind
	if not GameData.room_secret_types.has_type(secret_room_kind):
		return result
	
	# Gather secret room type data
	var secret_room_type = GameData.room_secret_types.get_type(secret_room_kind)
	var secret_room_placement_config: SecretPlacementConfig = secret_room_type.placement_config
	
	# Check if secret room type data has any placement configuration assigned
	if secret_room_placement_config == null:
		return result
	
	# Find valid placements and return them if the only_hint_placement flag is true
	_find_valid_placements(result, room_instance_grid, secret_room_placement_config)
	if only_hint_placement:
		return result
	
	# Calculate weights for valid placements and return them if the only_hint_placement_weights flag is true
	_calculate_weights(result, room_instance_grid, secret_room_placement_config)
	if only_hint_placement_weights:
		return result
	
	# Find and mark final solutions
	_find_solutions(result, secret_room_placement_config, secret_room_kind)
	
	return result


func _find_valid_placements(result: MapSolverResult, room_instance_grid: Dictionary[Vector2i, RoomInstanceData], placement_config: SecretPlacementConfig) -> void:
	result.stage = MapSolverResult.SolveStage.FOUND_VALID_PLACEMENTS
	
	for column in GameSettings.map_grid_room_size.x:
		for row in GameSettings.map_grid_room_size.y:
			pass
			#TODO: check if SecretPlacementConfig parameters are passed
			#TODO: --- check if any room in specified distance exists
			#TODO: --- check if neighbours parameters are kept
			#TODO: --- check if any of the neighbour has barricade connecting to the room, then check the allow/require barricade check
			#TODO: --- check if any of the neighbour is special/secret room, then check the allow/require special/secret room check
			#TODO: check if SecretPlacementType parameters passed in SecretPlacementConfig are passed and if they do restrict the placement 
			
			#TODO: if all passed then save the possible coords inside the result
			#TODO: else continue at any stage the checks weren't passed


func _calculate_weights(result: MapSolverResult, room_instance_grid: Dictionary[Vector2i, RoomInstanceData], placement_config: SecretPlacementConfig) -> void:
	result.stage = MapSolverResult.SolveStage.CALCULATED_WEIGHTS
	
	#TODO: first initialize room weights to 0s, for all the rooms that were returned as valid placements
	
	#TODO: then it should go through every SecretPlacementType set in SecretPlacementConfig and call appropriate function for them
	#TODO: --- each function should calculate weights for each coords in valid placements and adjust them based on the count_type and save calculated weights in the MapSolverResult
	#TODO: at this point it would be recommended to look through calculated weights, find min and max and then color code them based on the count_type set in SecretPlacementConfig


func _find_solutions(result: MapSolverResult, placement_config: SecretPlacementConfig, secret_room_kind: RoomSecretType.Kind) -> void:
	result.stage = MapSolverResult.SolveStage.FOUND_SOLUTION
	
	#TODO: at this point it's required to check gamesettings for how many secret rooms of a given kind should be placed and how many already are placed
	#TODO: sort MapSolverResultCoord results inside the MapSolverResult according to the calculated weights and count_type saved in SecretPlacementConfig
	#TODO: then we have to go through each sorted valid placement until the amount of secret rooms to set will be satisfied
	#TODO: --- if there would be not enough valid placements to satisfy the requirements, we would have to mark it somehow
	#TODO: --- if there would be multiple valid placements with the same weight, then each of them would be a valid option but the possibility percent would be set accordingly
	#TODO: --- for all the other remaining valid placements that have possibility percent set to 0%, we would have to remove them from the result 
