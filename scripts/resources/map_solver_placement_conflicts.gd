class_name MapSolverPlacementConflicts
extends RefCounted


var _neighbours: Dictionary[Vector2i, Dictionary] = {}


func register_coord(coords: Vector2i) -> void:
	if not _neighbours.has(coords):
		_neighbours[coords] = {}


func add_conflict(coords_a: Vector2i, coords_b: Vector2i) -> void:
	register_coord(coords_a)
	register_coord(coords_b)
	
	var neighbours_a: Dictionary = _neighbours[coords_a]
	var neighbours_b: Dictionary = _neighbours[coords_b]
	
	neighbours_a[coords_b] = true
	neighbours_b[coords_a] = true


func are_incompatible(coords_a: Vector2i, coords_b: Vector2i) -> bool:
	if not _neighbours.has(coords_a):
		return false
	
	var neighbours_a: Dictionary = _neighbours[coords_a]
	
	return neighbours_a.has(coords_b)


func conflicts_with_any(coords: Vector2i, selected_coords: Array[Vector2i]) -> bool:
	for selected_coords_elem: Vector2i in selected_coords:
		if are_incompatible(coords, selected_coords_elem):
			return true
	
	return false
