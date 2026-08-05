extends Node2D

var room_instance_data: RoomInstanceData


func create(_room_instance_data: RoomInstanceData) -> void:
	room_instance_data = _room_instance_data
	
	print("Room Cell Initialized - %s", str(room_instance_data))

func _ready() -> void:
	print("Room Cell Ready")
	pass
