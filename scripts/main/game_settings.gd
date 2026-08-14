extends Node


signal map_grid_size_parameter_changed(_map_grid_size: Vector2i)
signal map_grid_room_size_parameter_changed(_map_grid_room_size: Vector2i)


@export_group("Map Grid Parameters", "map_grid_")
@export var map_grid_size: Vector2i = Vector2i(17, 17):
	set(value):
		map_grid_size = value
		
		map_grid_size_parameter_changed.emit(map_grid_size)

@export var map_grid_room_size: Vector2i = Vector2i(15, 15):
	set(value): 
		map_grid_room_size = value
		
		map_grid_room_size_parameter_changed.emit(map_grid_room_size)
