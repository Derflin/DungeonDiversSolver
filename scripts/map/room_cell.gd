@tool
class_name RoomCell
extends Node2D


@export var cell_size := Vector2(15, 15): 
	set(value): 
		cell_size = value 
		queue_redraw() 

@export var show_editor_guide := true: 
	set(value): 
		show_editor_guide = value 
		queue_redraw()


var room_instance_data: RoomInstanceData


func create(_room_instance_data: RoomInstanceData) -> void:
	room_instance_data = _room_instance_data
	
	print("Room Cell Initialized - %s", str(room_instance_data))


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void: 
	if not Engine.is_editor_hint(): 
		return 
		
	if not show_editor_guide: 
		return 
		
	var half_size := cell_size / 2.0
	var line_width := 1.0
	var inset := line_width / 2.0
		
	var guide_rect := Rect2(
		-half_size + Vector2.ONE * inset, 
		cell_size - Vector2.ONE * line_width
	) 
		
	# Outer room boundary. 
	draw_rect( 
		guide_rect, 
		Color(0.3, 0.7, 1.0, 0.8), 
		false, 
		1.0
	) 
	
	# Horizontal center line. 
	draw_line( 
		Vector2(-half_size.x, 0), 
		Vector2(half_size.x, 0), 
		Color(0.3, 0.7, 1.0, 0.35), 
		1.0 
	) 
	
	# Vertical center line. 
	draw_line( 
		Vector2(0, -half_size.y), 
		Vector2(0, half_size.y), 
		Color(0.3, 0.7, 1.0, 0.35), 
		1.0 
	)
