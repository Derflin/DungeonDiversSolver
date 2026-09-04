@abstract
class_name SecretPlacementType
extends Resource


enum CountType {
	NONE = -1,
	SUM = 10,
	SUB = 20,
	MAX = 30,
	MIN = 40,
}


@export var count_type: CountType = CountType.NONE
