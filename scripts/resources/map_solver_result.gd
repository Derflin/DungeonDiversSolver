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
