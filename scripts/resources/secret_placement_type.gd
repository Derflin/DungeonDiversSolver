@abstract
class_name SecretPlacementType
extends Resource


enum CountType {
	NONE = -1,
	SUM = 10,
	SUB = 20,
}


@export var count_type: CountType = CountType.NONE


#TODO: add some classes meant to be overloaded or default
