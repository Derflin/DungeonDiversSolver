class_name SecretPlacementConfig
extends Resource


enum CountType {
	NONE = -1,
	MIN = 10,
	MAX = 20,
}


@export_group("Room Placement", "room_")
## Distance from other non-secret rooms including current position
@export var room_distance: int = 1
@export var room_neighbours_min: int = 1
@export var room_neighbours_max: int = 4

@export_group("Neighbours Restrictions", "neighbour_")
@export var neighbour_allow_barricade: bool = false
@export var neighbour_require_barricade: bool = false
@export var neighbour_allow_special: bool = true
@export var neighbour_require_special: bool = false
@export var neighbour_allow_secret: bool = true
@export var neighbour_require_secret: bool = false

@export_group("Placement Types")
@export var placement_types: Array[SecretPlacementType] = []

@export_group("Weight Calculation", "weight_")
@export var weight_count_type: CountType = CountType.NONE
