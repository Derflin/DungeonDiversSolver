class_name MapSolverResultPlacementExplanation
extends Node2D


@export_group("Geometry")
## Color used for straight connections between map coordinates.
@export var connection_color: Color = Color(0.95, 0.75, 0.40, 0.9)
## Color used for paths connecting multiple map coordinates.
@export var path_color: Color = Color(0.4, 0.9, 0.8, 0.9)
## Color used for highlighting individual rooms.
@export var marker_color: Color = Color(0.9, 0.75, 0.3, 0.35)
## Width of the lines used when drawing connections and paths.
@export var line_width: float = 1.0

@export_group("Annotations")
## Color used for numerical annotations.
@export var annotation_color: Color = Color(1, 1, 1, 1)
## Background color used behind numerical annotations.
@export var annotation_background: Color = Color(0.07, 0.07, 0.08, 0.88)
## Font size used for numerical annotations.
@export var annotation_font_size: int = 16
## Vertical offset applied to numerical annotation positions.
@export var annotation_y_offset: float = -3.0


## Placement explanations that should currently be displayed.
var _explanations: Array[MapSolverPlacementExplanation] = []
## Grid space reference used to convert map coordinates into positions.
var _grid_space: GridSpace
## Font used for drawing numerical annotations.
var _font: Font


## Configures the visualization with provided [param explanations] list of placement explanations and provided [param grid_space] and [param font], which are references required for drawing them.
## Calling this function triggers a request to redraw the already displayed explanations.
func configure(explanations: Array[MapSolverPlacementExplanation], grid_space: GridSpace, font: Font) -> void:
	# Store the explanations data and drawing references.
	_explanations = explanations.duplicate()
	_grid_space = grid_space
	_font = font
	
	# Request an update of the displayed explanations.
	queue_redraw()


## Clears the currently stored placement explanations and requests an update of their visualization.
func clear_data() -> void:
	_explanations.clear()
	queue_redraw()


## Checks and returns bool value indicating if any of the stored placement explanations contains any geometry or numerical annotations to display.
func has_visuals() -> bool:
	for explanation in _explanations:
		if explanation.has_visuals():
			return true
	
	return false


## Converts and returns the provided [param coords] that represent the coordinates on the grid into local coordinates relative to this expplanation visualization.
func _point(coords: Vector2i) -> Vector2:
	var grid_local: Vector2 = _grid_space.get_room_center_from_coords(coords)
	return to_local(_grid_space.to_global(grid_local))


## Draws a straight connection between two map coordinates using the provided color.
func _draw_segment(from_coords: Vector2i, to_coords: Vector2i, color: Color) -> void:
	# Convert both coords points into local drawing coordinates.
	var start: Vector2 = _point(from_coords)
	var finish: Vector2 = _point(to_coords)
	
	# Draw the connection between both points.
	draw_line(start, finish, color, line_width, false)


## Draws a numerical annotation at the provided local position.
## The annotation is horizontally centered and uses a background rectangle to make it more noticable over other elements.
func _draw_number(center: Vector2, number: float) -> void:
	# Filter out processing if no font reference was provided.
	if _font == null:
		return
	
	# Calculate all the parameters needed to draw a numerical annotation with the background rect.
	var text_value: String = String.num(number, 2).trim_suffix(".0")
	var text_size: Vector2 = _font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, annotation_font_size)
	var text_position: Vector2 = center + Vector2(-text_size.x * 0.5, annotation_y_offset)
	var background_rect: Rect2 = Rect2(text_position + Vector2(-2, -text_size.y), text_size + Vector2(4, 4))
	
	# Draw the background and the numerical value.
	draw_rect(background_rect, annotation_background, true)
	draw_string(_font, text_position, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, annotation_font_size, annotation_color)


## Generates a direction independant identifier for a segment based on the provided [param a] and [param b] coords.
func _segment_key(a: Vector2i, b: Vector2i) -> String:
	# Normalize the endpoint order.
	if a.x > b.x or (a.x == b.x and a.y < b.y):
		var tmp: Vector2i = a
		a = b
		b = tmp
	
	# Return an identifier based on the normalized coordinates.
	return "%s|%s" % [str(a), str(b)]


## Draws the stored placement explanations.
## Geometry including connections, paths and room highlights are drawn first.
## Annotations are colleced separately and rendered afterward to prevent geometry from covering it.
func _draw() -> void:
	# Filter out processing if the required grid space reference is missing.
	if _grid_space == null:
		return
	
	# Prepare variables for tracking previously drawn segments, repeated annotations on matching segments and storing pending annotations.
	var drawn_segments: Dictionary = {}
	var repeated_measurements: Dictionary = {}
	var pending_annotations: Array[Dictionary] = []
	
	# Process each placement explanation to draw it contents.
	for explanation: MapSolverPlacementExplanation in _explanations:
		# Draw straight connections between map coordinates and prepare their annotations.
		for segment: Dictionary in explanation.segments:
			# Get endpoints for the segment and generate segment identifier.
			var from_coords: Vector2i = segment["from"]
			var to_coords: Vector2i = segment["to"]
			var segment_key: String = _segment_key(from_coords, to_coords)
			
			# Draw the segment if it hasn't been drawn yet.
			if not drawn_segments.has(segment_key):
				drawn_segments[segment_key] = true
				
				_draw_segment(from_coords, to_coords, connection_color)
			
			# Check whether this segment requires an annotation.
			if bool(segment.get("show_value", false)):
				# Determine how many annotations already exist for a segment connecting these endpoints.
				var repeat_index: int = int(repeated_measurements.get(segment_key, 0))
				repeated_measurements[segment_key] = repeat_index + 1
				
				# Calculate the segment endpoint.
				var start: Vector2 = _point(from_coords)
				var finish: Vector2 = _point(to_coords)
				var midpoint: Vector2 = (start + finish) * 0.5
				
				# Offset repeated annotations to avoid drawing multiple values directly on top of each other.
				var annotation_offset: Vector2 = Vector2(0.0, -8.0 * float(repeat_index))
				
				# Store the annotations for drawing afterward.
				pending_annotations.append({
					"position": midpoint + annotation_offset,
					"value": float(segment.get("value", 0.0)),
				})
		
		# Draw paths consisting of multiple ordered coordinates and prepare their annotations.
		for path: Dictionary in explanation.paths:
			# Convert the path coordinates into drawing positions.
			var points := PackedVector2Array()
			for coords: Vector2i in path["coords"]:
				points.append(_point(coords))
			
			# Draw the path if it contains at least 2 points.
			if points.size() >= 2:
				draw_polyline(points, path_color, line_width, false)
			
			# Check whether this path requires an annotation.
			if bool(path.get("show_value", false)) and points.size() > 0:
				# Find middle point in the path's point array.
				var middle_index: int = floori(float(points.size()) / 2.0)
				
				# Store the path annotation for later drawing.
				pending_annotations.append({
					"position": points[middle_index],
					"value": float(path.get("value", 0.0)),
				})
		
		## Draw the highlighted rooms and prepare their annotations.
		for room: Dictionary in explanation.room_values:
			# Calculate the center of the room.
			var room_center: Vector2 = _point(room["coords"])
			
			# Draw the room highlight.
			draw_rect(Rect2(room_center - Vector2(7, 7), Vector2(14, 14)), marker_color, true)
			
			# Store the associated numerical value.
			pending_annotations.append({
				"position": room_center,
				"value": float(room.get("value", 0.0)),
			})
	
	# Draw every collected annotation after the geometry draw finished.
	for annotation: Dictionary in pending_annotations:
		_draw_number(annotation["position"], float(annotation["value"]))
