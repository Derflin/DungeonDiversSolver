extends Node2D


const GRID_LINE_WIDTH = 1
const GRID_OUTER_CELL_COUNT = 2


var grid_size: Vector2i
var grid_room_size: Vector2i


@export var grid_parent_node: RoomGrid

@export_group("Internal Lines", "internal_")
@export var internal_line_color: Color = Color.from_rgba8(200, 144, 110, 40)

@export_group("External Lines", "external_")
@export var external_line_color: Color = Color.from_rgba8(115, 39, 44, 40)


func _ready() -> void:
	grid_size = grid_parent_node.grid_size
	grid_room_size = grid_parent_node.grid_room_size
	

func _draw() -> void:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return
		
	_draw_square_segments()
	
	
func _draw_square_segments() -> void:
	for grid_x in range(grid_size.x + 2 * GRID_OUTER_CELL_COUNT):
		for grid_y in range(grid_size.y + 2 * GRID_OUTER_CELL_COUNT):
			var rect_from = _grid_point_to_local(Vector2i(grid_x, grid_y))
			var rect_to = _grid_point_to_local(Vector2i(grid_x + 1, grid_y + 1))
			var rect_size = rect_to - rect_from
			var color = external_line_color if grid_x < GRID_OUTER_CELL_COUNT or grid_x >= (grid_size.x + GRID_OUTER_CELL_COUNT) or grid_y < GRID_OUTER_CELL_COUNT or grid_y >= (grid_size.y + GRID_OUTER_CELL_COUNT) else internal_line_color			
			_draw_square_segment(Rect2(rect_from, rect_size), color)
	
	
func _grid_point_to_local(grid_point: Vector2i) -> Vector2:
	# grid_room_size + 2 * GRID_LINE_WIDTH - GRID LINE WIDTH -> Square size + border from each side
	return Vector2(
		grid_point.x * (grid_room_size.x + GRID_LINE_WIDTH),
		grid_point.y * (grid_room_size.y + GRID_LINE_WIDTH),
	)
	
	
func _draw_square_segment(rect_coords: Rect2, color: Color) -> void:
	draw_rect(rect_coords, color, false, 1.0)
	
	
func get_grid_size() -> Vector2:
	return Vector2(
		(grid_size.x + 2 * GRID_OUTER_CELL_COUNT) * (grid_room_size.x + 1.0) + 1.0,
		(grid_size.y + 2 * GRID_OUTER_CELL_COUNT) * (grid_room_size.y + 1.0) + 1.0,
	)
