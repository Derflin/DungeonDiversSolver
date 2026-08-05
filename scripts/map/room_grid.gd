class_name RoomGrid
extends Node2D


var _room_cell_scene
var rooms: Dictionary[Vector2i, RoomInstanceData] = {}

@export_group("Grid Parameters")
@export var grid_size: Vector2i = Vector2i(17, 17)
@export var grid_room_size: Vector2i = Vector2i(15, 15)


func _ready() -> void:
	print("Room Grid Ready")
	
	# Initialize test room instance data
	#room_instance_data = RoomInstanceData.new()
	#rooms[Vector2i(1, 1)] = 
	
	# Initialize room cell scene
	#_room_cell_scene = load("res://scenes/map/room_cell.tscn")
	
	# Initialize test room cell childs
	#for room in rooms.values():
	#	pass
	
	
func create_room(coordinates: Vector2i) -> void:
	var room = RoomInstanceData.new()
	
	#room.corridor_type = 
