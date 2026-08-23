class_name MapSolverResultCoord
extends RefCounted


var coords: Vector2i = Vector2i(-1, -1)
var calculated_weight: float = -1
var possibility: float = 1.0

func _init(_coords: Vector2i, _calculated_weight: float, _possibility: float) -> void:
	coords = _coords
	calculated_weight = _calculated_weight
	possibility = _possibility
