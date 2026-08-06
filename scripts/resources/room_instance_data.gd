class_name RoomInstanceData
extends Resource

enum ConnectionDirectionFlags {
	NONE = 0,
	UP = 1 << 0,
	DOWN = 1 << 1,
	LEFT = 1 << 2,
	RIGHT = 1 << 3,
	UPPER_LEFT = 1 << 4,
	UPPER_RIGHT = 1 << 5,
	DOWN_LEFT = 1 << 6,
	DOWN_RIGHT = 1 << 7,
}

enum BarricadeDirectionFlags {
	NONE = 0,
	UP = 1 << 0,
	DOWN = 1 << 1,
	LEFT = 1 << 2,
	RIGHT = 1 << 3,
}


@export var corridor_type: RoomCorridorType
@export var special_type: RoomSpecialType = null
@export var secret_type: RoomSecretType = null

@export_group("Connections", "connection_")
@export_flags(
	"Up:1",
	"Down:2",
	"Left:4",
	"Right:8",
	"Upper Left:16",
	"Upper Right:32",
	"Down Left:64",
	"Down Right:128",
)
var connection_directions_mask: int = ConnectionDirectionFlags.NONE

@export_group("Barricades", "barricade_")
@export_flags(
	"Up:1",
	"Down:2",
	"Left:4",
	"Right:8",
)
var barricade_directions_mask: int = BarricadeDirectionFlags.NONE


func _ready() -> void:
	corridor_type = GameData.room_corridor_types.get_default_type()
		

func create(_corridor_type: RoomCorridorType, _special_type: RoomSpecialType = null, _secret_type: RoomSecretType = null, _connection_directions_mask: ConnectionDirectionFlags = ConnectionDirectionFlags.NONE, _barricade_directions_mask: BarricadeDirectionFlags = BarricadeDirectionFlags.NONE) -> void:
	corridor_type = _corridor_type
	special_type = _special_type
	secret_type = _secret_type
	
	connection_directions_mask = _connection_directions_mask
	barricade_directions_mask = _barricade_directions_mask


func has_connection(direction: ConnectionDirectionFlags) -> bool:
	return (connection_directions_mask & direction) != 0
	
	
func enable_connection(direction: ConnectionDirectionFlags) -> void:
	connection_directions_mask |= direction
	
	
func disable_connection(direction: ConnectionDirectionFlags) -> void:
	connection_directions_mask &= ~direction
	
	
func has_barricade(direction: BarricadeDirectionFlags) -> bool:
	return (barricade_directions_mask & direction) != 0
	
	
func enable_barricade(direction: BarricadeDirectionFlags) -> void:
	barricade_directions_mask |= direction
	
	
func disable_barricade(direction: BarricadeDirectionFlags) -> void:
	barricade_directions_mask &= ~direction
	
