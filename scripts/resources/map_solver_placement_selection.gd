class_name MapSolverPlacementSelection
extends RefCounted


var coords: Array[Vector2i] = []


func _init(_coords: Array[Vector2i] = []) -> void:
	coords = _coords.duplicate()
