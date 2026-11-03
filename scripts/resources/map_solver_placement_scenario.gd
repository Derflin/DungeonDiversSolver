class_name MapSolverPlacementScenario
extends RefCounted


var selected_coords: Array[Vector2i] = []
var probability: float = 1.0


func _init(_selected_coords: Array[Vector2i] = [], _probability: float = 1.0) -> void:
	selected_coords = _selected_coords.duplicate()
	probability = _probability


func is_complete(required_count: int) -> bool:
	return selected_coords.size() == required_count
