class_name SecretPlacementTypeNeighbour
extends SecretPlacementType


enum NeighbourType {
	ANY = -1,
	NONSECRET = 10,
	BARRICADE = 20,
}


@export var check_range_min: int = 1
@export var check_range_max: int = 1
@export var neighbor_type: NeighbourType = NeighbourType.ANY


func _init() -> void:
	count_type = CountType.SUM_MAX


#TODO: define some functions
