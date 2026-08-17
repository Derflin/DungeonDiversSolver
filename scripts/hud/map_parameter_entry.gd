class_name MapParameterEntry
extends HBoxContainer


enum ParameterType {
	NONE = -1,
	MAP_GRID_SIZE = 10,
	SECRET_TYPE_MAX_COUNT = 20,
}


var parameter_type: ParameterType = ParameterType.NONE
var secret_type_kind: RoomSecretType.Kind = RoomSecretType.Kind.NONE


func _ready() -> void:
	pass


func initialize_map_grid_size() -> void:
	parameter_type = ParameterType.MAP_GRID_SIZE


func initialize_secret_type_max_count(_secret_type_kind: RoomSecretType.Kind) -> void:
	parameter_type = ParameterType.SECRET_TYPE_MAX_COUNT
	secret_type_kind = _secret_type_kind 


func initialize_parameter_nodes() -> void:
	#TODO: gather
	pass
