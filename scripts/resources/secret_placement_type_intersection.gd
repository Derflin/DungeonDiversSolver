class_name SecretPlacementTypeIntersection
extends SecretPlacementType


@export var intersect_room_type_1: RoomType = null
@export var intersect_room_type_2: RoomType = null


func contributes_to_weight() -> bool:
	return false
