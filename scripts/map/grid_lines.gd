extends Node2D


const GRID_LINE_WIDTH = 1
const GRID_OUTER_CELL_COUNT = 2

enum CellType {
	CELL_NONE = 0,
	CELL_INTERNAL = 1,
	CELL_EXTERNAL = 2,
}


@export var grid_parent_node: GridSpace

@export_group("Internal Lines", "internal_")
@export var internal_line_color: Color = Color.from_rgba8(200, 144, 110, 40)

@export_group("External Lines", "external_")
@export var external_line_color: Color = Color.from_rgba8(115, 39, 44, 40)

@export_group("Line Rendering", "render_")
@export_range(0.1, 2.0, 0.05) var render_minimum_screen_line_width: float = 1.0
@export_range(0.01, 0.25, 0.01) var render_maximum_line_to_cell_ratio: float = 0.1
@export var render_antialiasing_enabled: bool = false


var grid_offset: Vector2 = Vector2(0.5, 0.5)

var _previous_screen_scale: Vector2 = Vector2.ZERO
var _vertical_line_width: float = GRID_LINE_WIDTH
var _horizontal_line_width: float = GRID_LINE_WIDTH


## Keeps track of the effective screen scale of the grid lines and queues redraw it it changes to adjust the grid lines width.
func _process(_delta: float) -> void:
	# Get current effective screen scale that affects the grid lines.
	var screen_scale := _get_effective_screen_scale()
	
	# Save the current screen scale and queue grid lines redraw if the screen scale changed from the last time it was saved.
	if not screen_scale.is_equal_approx(_previous_screen_scale):
		_previous_screen_scale = screen_scale
		queue_redraw()


# Calculates the line widths for the grid and draws line segments for it.
func _draw() -> void:
	# Get current map size and filter out processing if the map size is less then or equal 0 in any axis.
	var map_size := GameSettings.map_grid_size
	if map_size.x <= 0 or map_size.y <= 0:
		return
	
	# Calculate line widths to use for vertical and horizontal lines.
	var screen_scale := _get_effective_screen_scale()
	_vertical_line_width = _calculate_line_width(screen_scale.x, GameSettings.map_grid_room_size.x)
	_horizontal_line_width = _calculate_line_width(screen_scale.y, GameSettings.map_grid_room_size.y)
	
	# Draw lines for each column and row segments.
	_draw_square_segments()


## Checks whether grid lines should use antialiasing based on the current rendering method.
## Uses per-line antialiasing when MSAA 2D is unavailable.
func _should_antialias_grid_lines() -> bool:
	# Preserve the manually configured antialiasing setting.
	if render_antialiasing_enabled:
		return true
	
	# Enable antialiasing for the compatibility renderer.
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Returns how much one local map unit occupies on screen along each axis.
func _get_effective_screen_scale() -> Vector2:
	var transform_to_screen := get_viewport().get_stretch_transform() * get_global_transform_with_canvas()
	return Vector2(transform_to_screen.x.length(), transform_to_screen.y.length())


## Calculates and returns a line width that should be used for the grid taking into account the base provided [param room_size] and the provided [param screen_scale].
## Ensures that the calculated line width won't be bigger then the set maximum line to cell ratio to ensure that it won't overlap the room cell.
func _calculate_line_width(screen_scale: float, room_size: float) -> float:
	var scale := maxf(screen_scale, 0.00001)
	var cell_step_screen := (room_size + GRID_LINE_WIDTH) * scale
	var original_line_screen := GRID_LINE_WIDTH * scale
	var requested_line_screen := maxf(original_line_screen, render_minimum_screen_line_width)
	var maximum_line_screen := cell_step_screen * render_maximum_line_to_cell_ratio
	return minf(requested_line_screen, maximum_line_screen) / scale


## Draws each horizontal and vertical line once per adjacent cell contribution.
func _draw_square_segments() -> void:
	var map_size := GameSettings.map_grid_size
	var min_x := -GRID_OUTER_CELL_COUNT
	var min_y := -GRID_OUTER_CELL_COUNT
	var max_x := map_size.x + GRID_OUTER_CELL_COUNT
	var max_y := map_size.y + GRID_OUTER_CELL_COUNT
	
	# Draw all vertical line runs.
	for grid_x in range(min_x, max_x + 1):
		_draw_edge_runs(true, grid_x, min_y, max_y, map_size, min_x, min_y, max_x, max_y)
	
	# Draw all horizontal line runs.
	for grid_y in range(min_y, max_y + 1):
		_draw_edge_runs(false, grid_y, min_x, max_x, map_size, min_x, min_y, max_x, max_y)


## Draws a horizontal/vertical line for the provided segment group by grouping them together based on the style that should be applied to them and their location on map.
func _draw_edge_runs(vertical: bool, line_index: int, segment_start: int, segment_end: int, map_size: Vector2i, min_x: int, min_y: int, max_x: int, max_y: int) -> void:
	# Initialize variables to hold the details about the currently grouped segments by populating them with current segment.
	var run_start := segment_start
	var run_style := _get_edge_layers(vertical, line_index, segment_start, map_size, min_x, min_y, max_x, max_y)
	
	# Process each existing segment after the already initialized one and include the exclusive end segment position to finallzie processing.
	for current_segment in range(segment_start + 1, segment_end + 1):
		var new_style := Vector2i(-1, -1)
		
		# Get style for the current segment if currently selected segment exists.
		if current_segment < segment_end:
			new_style = _get_edge_layers(vertical, line_index, current_segment, map_size, min_x, min_y, max_x, max_y)
		
		# Draw a line for the currently saved run and set current segment as the new run start if the style for the current segment is different then the one saved for the saved run.
		if new_style != run_style:
			_draw_edge_run(vertical, line_index, run_start, current_segment, run_style)
			run_start = current_segment
			run_style = new_style


## Returns a style indicator for the provided current segment based on it and it's neighbour types.
func _get_edge_layers(vertical: bool, line_index: int, segment: int, map_size: Vector2i, min_x: int, min_y: int, max_x: int, max_y: int) -> Vector2i:
	# Initialize state variables for keeping the current segment and it's neighbour types.
	var previous := CellType.CELL_NONE
	var next := CellType.CELL_NONE
	
	# Get current segment and it's neighbour types based on if current segment is for a horizontal or vertical segment and it's position.
	if vertical:
		if line_index > min_x:
			previous = _get_cell_type(line_index - 1, segment, map_size)
		if line_index < max_x:
			next = _get_cell_type(line_index, segment, map_size)
	else:
		if line_index > min_y:
			previous = _get_cell_type(segment, line_index - 1, map_size)
		if line_index < max_y:
			next = _get_cell_type(segment, line_index, map_size)
	
	# Return prepared style indicator consisting of collected segment types.
	return Vector2i(int(previous), int(next))


## Returns the segment type based on it's position on the map.
func _get_cell_type(grid_x: int, grid_y: int, map_size: Vector2i) -> CellType:
	if grid_x >= 0 and grid_x < map_size.x and grid_y >= 0 and grid_y < map_size.y:
		return CellType.CELL_INTERNAL
	
	return CellType.CELL_EXTERNAL


## Draws a line between the provided [param from_segment] start and provided [param to_segment] end points in the grid lines segments coordinates.
## Uses provided [param vertical] flag to define the orientation of the line and provided [param line_index] to define a second axis for the provided segment indexes.
## Uses provided [param layers] to check the neighbouring square segments types to define what colors should be used for them.
func _draw_edge_run(vertical: bool, line_index: int, from_segment: int, to_segment: int, layers: Vector2i) -> void:
	# Calculate start and end points for the line.
	var line_from: Vector2
	var line_to: Vector2
	if vertical:
		line_from = _grid_point_to_local(Vector2i(line_index, from_segment))
		line_to = _grid_point_to_local(Vector2i(line_index, to_segment))
	else:
		line_from = _grid_point_to_local(Vector2i(from_segment, line_index))
		line_to = _grid_point_to_local(Vector2i(to_segment, line_index))
	
	# Get line width that will be used for drawing lin,
	var draw_width := _vertical_line_width if vertical else _horizontal_line_width
	
	# Extend the line ends to fill gaps at the grid intersections.
	var line_extension := draw_width * 0.5
	if vertical:
		line_from.y -= line_extension
		line_to.y += line_extension
	else:
		line_from.x -= line_extension
		line_to.x += line_extension
	
	# Draw line one time for each layer if it does contain some specific cell type in it.
	if layers.x as CellType != CellType.CELL_NONE:
		draw_line(line_from, line_to, _get_cell_color(layers.x as CellType), draw_width, _should_antialias_grid_lines())
	if layers.y as CellType != CellType.CELL_NONE:
		draw_line(line_from, line_to, _get_cell_color(layers.y as CellType), draw_width, _should_antialias_grid_lines())


## Returns a color that is assigned for the provided [param cell_type].
func _get_cell_color(cell_type: CellType) -> Color:
	return internal_line_color if cell_type == CellType.CELL_INTERNAL else external_line_color


func _grid_point_to_local(grid_point: Vector2i) -> Vector2:
	# grid_room_size + 2 * GRID_LINE_WIDTH - GRID LINE WIDTH -> Square size + border from each side
	return Vector2(
		grid_point.x * (GameSettings.map_grid_room_size.x + GRID_LINE_WIDTH) + grid_offset.x,
		grid_point.y * (GameSettings.map_grid_room_size.y + GRID_LINE_WIDTH) + grid_offset.y,
	)


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
