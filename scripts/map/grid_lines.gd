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

@export_group("Small Cell Fading", "small_cells_")
@export var small_cells_fade_enabled: bool = true
@export_range(2.0, 20.0, 0.5) var small_cells_fade_start_screen_size: float = 8.0
@export_range(1.0, 10.0, 0.5) var small_cells_fade_end_screen_size: float = 3.0

@export_group("Web Grid Shader", "web_shader_")
@export var web_shader: Shader
@export var web_shader_force_preview: bool = false
@export_range(0.25, 2.0, 0.05) var web_shader_edge_softness_pixels: float = 0.7


var grid_offset: Vector2 = Vector2(0.5, 0.5)

var _previous_screen_scale: Vector2 = Vector2.ZERO
var _vertical_line_width: float = GRID_LINE_WIDTH
var _horizontal_line_width: float = GRID_LINE_WIDTH

var _small_cell_opacity_multiplier: float = 1.0

var _web_grid_material: ShaderMaterial
var _use_web_shader: bool = false


## Initializes the grid rendering method based on the current platform and configured shader.
func _ready() -> void:
	# Use the custom shader for web builds, or when explicitly enabled.
	_use_web_shader = OS.has_feature("web") or web_shader_force_preview
	
	# Disable the shader renderer if its resource hasn't been assigned.
	if _use_web_shader and web_shader == null:
		push_warning("GridLines: Web grid shader resource is missing. Using the regular renderer.")
		_use_web_shader = false
	
	# Keep the standard grid renderer without a custom material on desktop.
	if not _use_web_shader:
		return
	
	# Create an independent shader material for rendering the grid.
	_web_grid_material = ShaderMaterial.new()
	_web_grid_material.shader = web_shader
	material = _web_grid_material


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
	
	# Measure the smallest visible grid cell dimension in screen pixels.
	var min_cell_screen_size := minf(
		(GameSettings.map_grid_room_size.x + GRID_LINE_WIDTH) * screen_scale.x,
		(GameSettings.map_grid_room_size.y + GRID_LINE_WIDTH) * screen_scale.y,
	)
	_small_cell_opacity_multiplier = _get_small_cell_opacity_multiplier(min_cell_screen_size)
	
	# Select the appropriate drawing method based on the active renderer.
	if _use_web_shader:
		# Draw grid and it's lines using the web shader.
		_draw_web_shader_grid(map_size, screen_scale)
	else:
		# Draw grid lines for each column and row segments.
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
	var local_scale := maxf(screen_scale, 0.00001)
	var cell_step_screen := (room_size + GRID_LINE_WIDTH) * local_scale
	var original_line_screen := GRID_LINE_WIDTH * local_scale
	var requested_line_screen := maxf(original_line_screen, render_minimum_screen_line_width)
	var maximum_line_screen := cell_step_screen * render_maximum_line_to_cell_ratio
	return minf(requested_line_screen, maximum_line_screen) / local_scale


## Draws the complete map grid using the web shader instead of individual line segments.
func _draw_web_shader_grid(map_size: Vector2i, screen_scale: Vector2) -> void:
	# Calculate the physical cell spacing in grid local coordinates.
	var cell_step := Vector2(GameSettings.map_grid_room_size) + Vector2.ONE * GRID_LINE_WIDTH
	
	# Prepare the colors while preserving the existing small cell fading behaviour.
	var internal_color := internal_line_color
	var external_color := external_line_color
	internal_color.a *= _small_cell_opacity_multiplier
	external_color.a *= _small_cell_opacity_multiplier
	
	# Update shader settings using the same data as the regular grid renderer.
	_web_grid_material.set_shader_parameter("map_cells", Vector2(map_size))
	_web_grid_material.set_shader_parameter("cell_step", cell_step)
	_web_grid_material.set_shader_parameter("grid_offset", grid_offset)
	_web_grid_material.set_shader_parameter("outer_cells", float(GRID_OUTER_CELL_COUNT))
	_web_grid_material.set_shader_parameter("internal_color", internal_color)
	_web_grid_material.set_shader_parameter("external_color", external_color)
	_web_grid_material.set_shader_parameter("vertical_width", _vertical_line_width)
	_web_grid_material.set_shader_parameter("horizontal_width", _horizontal_line_width)
	_web_grid_material.set_shader_parameter("edge_softness_pixels", web_shader_edge_softness_pixels)
	
	# Calculate the area covered by the grid including its outer cells.
	var min_corner := _grid_point_to_local(Vector2i(-GRID_OUTER_CELL_COUNT, -GRID_OUTER_CELL_COUNT))
	var max_corner := _grid_point_to_local(map_size + Vector2i(GRID_OUTER_CELL_COUNT, GRID_OUTER_CELL_COUNT))
	
	# Include some extra space around the outermost strokes and their soft edges.
	var minimum_scale := maxf(minf(screen_scale.x, screen_scale.y), 0.00001)
	var padding := maxf(
		8.0,
		maxf(_vertical_line_width, _horizontal_line_width) * 0.5 + web_shader_edge_softness_pixels / minimum_scale
	)
	
	# Render one rectangle containing the complete shader generated grid.
	var grid_rect := Rect2(
		min_corner - Vector2.ONE * padding,
		max_corner - min_corner + Vector2.ONE * padding * 2.0,
	)
	draw_rect(grid_rect, Color.WHITE, true)


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
	# Get the color based on the cell type.
	var color := internal_line_color if cell_type == CellType.CELL_INTERNAL else external_line_color
	
	# Apply small cell opacity multiplier to opacity.
	color.a *= _small_cell_opacity_multiplier
	
	return color


## Returns opacity multiplier that should be applied to the line color opacity if cells become too small to display correctly with grid lines.
## Returns 0 for extremely small cells and 1 when individual cells are clearly visible.
func _get_small_cell_opacity_multiplier(cell_screen_size: float) -> float:
	# Filter out processing if small cell opacity multiplier is disabled.
	if not small_cells_fade_enabled:
		return 1.0
	
	# Fade smoothly as the smallest dimension of a grid cell approaches the screen limit.
	return smoothstep(
		small_cells_fade_end_screen_size,
		small_cells_fade_start_screen_size,
		cell_screen_size,
	)


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
