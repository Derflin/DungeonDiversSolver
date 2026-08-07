class_name GridSpace
extends Node2D

signal grid_space_parameters_changed


@onready var grid_lines: Node2D = $GridBackground/GridLines
@onready var rooms_container: Node2D = $Rooms


@export_group("Grid Parameters")
@export var grid_size: Vector2i = Vector2i(17, 17):
	set(value): 
		grid_size = value
		if grid_lines != null:
			grid_lines.grid_size = grid_size
			grid_lines.queue_redraw()
			grid_space_parameters_changed.emit()

@export var grid_room_size: Vector2i = Vector2i(15, 15):
	set(value): 
		grid_room_size = value
		if grid_lines != null:
			grid_lines.grid_room_size = grid_room_size
			grid_lines.queue_redraw()
			grid_space_parameters_changed.emit()
	

func get_map_rect() -> Rect2:
	return Rect2(
		grid_lines.position - grid_lines.get_grid_offset(),
		grid_lines.get_grid_size(),
	)


func append_room(room: RoomCell) -> void:
	rooms_container.add_child(room)
