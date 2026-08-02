class_name RoomInstanceData
extends Resource

@export var corridor_type: RoomCorridorType
@export var special_type: RoomSpecialType
@export var secret_type: RoomSecretType

@export_group("Barricades")
@export var barricade_top: bool = false
@export var barridade_right: bool = false
@export var barricade_down: bool = false
@export var barricade_left: bool = false
