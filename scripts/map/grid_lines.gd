extends Node2D


const GRID_LINE_WIDTH = 1
const GRID_OUTER_CELL_COUNT = 2


var grid_offset: Vector2 = Vector2(0.5, 0.5)


@export var grid_parent_node: GridSpace

@export_group("Internal Lines", "internal_")
@export var internal_line_color: Color = Color.from_rgba8(200, 144, 110, 40)

@export_group("External Lines", "external_")
@export var external_line_color: Color = Color.from_rgba8(115, 39, 44, 40)


func _draw() -> void:
	if GameSettings.map_grid_size.x <= 0 or GameSettings.map_grid_size.y <= 0:
		return
		
	_draw_square_segments()
	
	
func _draw_square_segments() -> void:
	for grid_x in range(-GRID_OUTER_CELL_COUNT, GameSettings.map_grid_size.x + GRID_OUTER_CELL_COUNT):
		for grid_y in range(-GRID_OUTER_CELL_COUNT, GameSettings.map_grid_size.y + GRID_OUTER_CELL_COUNT):
			var rect_from = _grid_point_to_local(Vector2i(grid_x, grid_y))
			var rect_to = _grid_point_to_local(Vector2i(grid_x + 1, grid_y + 1))
			var rect_size = rect_to - rect_from
			var color = external_line_color if grid_x < 0 or grid_x >= GameSettings.map_grid_size.x or grid_y < 0 or grid_y >= GameSettings.map_grid_size.y else internal_line_color			
			_draw_square_segment(Rect2(rect_from, rect_size), color)
	
	
func _grid_point_to_local(grid_point: Vector2i) -> Vector2:
	# grid_room_size + 2 * GRID_LINE_WIDTH - GRID LINE WIDTH -> Square size + border from each side
	return Vector2(
		grid_point.x * (GameSettings.map_grid_room_size.x + GRID_LINE_WIDTH) + grid_offset.x,
		grid_point.y * (GameSettings.map_grid_room_size.y + GRID_LINE_WIDTH) + grid_offset.y,
	)
	
	
func _draw_square_segment(rect_coords: Rect2, color: Color) -> void:
	draw_rect(rect_coords, color, false, 1.0)
	
	
func get_grid_size() -> Vector2:
	return Vector2(
		(GameSettings.map_grid_size.x + 2 * GRID_OUTER_CELL_COUNT) * (GameSettings.map_grid_room_size.x + GRID_LINE_WIDTH) + GRID_LINE_WIDTH,
		(GameSettings.map_grid_size.y + 2 * GRID_OUTER_CELL_COUNT) * (GameSettings.map_grid_room_size.y + GRID_LINE_WIDTH) + GRID_LINE_WIDTH,
	)


func get_grid_offset() -> Vector2:
	return Vector2(
		(GRID_OUTER_CELL_COUNT) * (GameSettings.map_grid_room_size.x + GRID_LINE_WIDTH),
		(GRID_OUTER_CELL_COUNT) * (GameSettings.map_grid_room_size.y + GRID_LINE_WIDTH),
	)


func get_map_rect() -> Rect2:
	return Rect2(
		position - get_grid_offset(),
		get_grid_size(),
	)
