class_name SecretPlacementTypeCorridor
extends SecretPlacementType


@export var allow_secret_rooms_in_corridor: bool = false


func _init() -> void:
	count_type = CountType.SUM
