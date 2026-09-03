class_name MapSolverResultCoord
extends RefCounted


var coords: Vector2i = Vector2i(-1, -1)
var calculated_weight: float = -1
var probability: float = 1.0
var text_color: Color = Color.WHITE


func _init(_coords: Vector2i, _calculated_weight: float = -1, _probability: float = 1.0) -> void:
	coords = _coords
	calculated_weight = _calculated_weight
	probability = _probability
