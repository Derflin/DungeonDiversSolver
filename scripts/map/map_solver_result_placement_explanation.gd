class_name MapSolverResultPlacementExplanation
extends Node2D


@export_group("Geometry")
## Color used for straight connections between map coordinates.
@export var connection_color: Color = Color(0.95, 0.75, 0.40, 0.9)
## Color used for paths connecting multiple map coordinates.
@export var path_color: Color = Color(0.95, 0.75, 0.40, 0.9)
## Color used for highlighting individual rooms.
@export var marker_color: Color = Color(0.9, 0.75, 0.3, 0.35)
## Width of the lines used when drawing connections and paths.
@export var line_width: float = 1.0
## Inset from actual room-cell bounds; zero covers the entire room.
@export_range(0.0, 4.0, 0.5) var marker_inset: float = 0.0
## Space left clear around the current candidate's room border.
@export_range(0.0, 6.0, 0.5) var cursor_line_gap: float = 1.0

@export_group("Annotations")
## Color used for numerical annotations.
@export var annotation_color: Color = Color(1, 1, 1, 1)
## Background color used behind numerical annotations.
@export var annotation_background: Color = Color(0.07, 0.07, 0.08, 0.88)
## Font size used for numerical annotations.
@export var annotation_font_size: int = 16

@export_group("Room Annotations", "room_annotation_")
## Leave room values at full scale for pixel-art readability.
@export_range(0.5, 1.0, 0.05) var room_annotation_scale: float = 0.75
## Tightly fitted padding, in local pixels.
@export var room_annotation_padding: Vector2 = Vector2(1.0, 0.0)

@export_group("Line Annotations", "line_annotation_")
## Visual size relative to the native font size.
@export_range(0.5, 1.0, 0.05) var line_annotation_scale: float = 0.75
## Padding around the downscaled line annotations.
@export var line_annotation_padding: Vector2 = Vector2(1.0, 0.0)
## Earliest radius used for line label placement around the cursor.
@export_range(0.0, 100.0, 1.0) var line_annotation_min_distance: float = 20.0
## Maximum permitted radius for the CENTER of a line annotation.
@export_range(1.0, 200.0, 1.0) var line_annotation_max_distance: float = 48.0
## Spacing between attempts to move a label along its line.
@export_range(1.0, 20.0, 1.0) var line_annotation_distance_step: float = 6.0
## Spacing for alternative placements to either side of the line.
@export_range(0.0, 20.0, 1.0) var line_annotation_side_step: float = 6.0
## Extra separation when testing annotation rectangle overlaps.
@export_range(0.0, 5.0, 0.5) var line_annotation_clearance: float = 1.0


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


## Returns the exact bounds of [param coords] in this overlay's local space.
func _room_rect_local(coords: Vector2i) -> Rect2:
	var grid_rect: Rect2 = _grid_space.get_room_rect(coords)
	var top_left: Vector2 = to_local(_grid_space.to_global(grid_rect.position))
	var bottom_right: Vector2 = to_local(_grid_space.to_global(grid_rect.end))
	return Rect2(top_left, bottom_right - top_left).abs()


## Prepares a local room rect and adjusts it to set it's center to be positioned in the center of the current scene.
func _candidate_room_rect() -> Rect2:
	var room_size: Vector2 = _room_rect_local(Vector2i.ZERO).size
	return Rect2(-room_size * 0.5, room_size)


## Draws a line between two map coordinates while leaving the candidate room's interior clear for it's own display.
func _draw_segment(from_coords: Vector2i, to_coords: Vector2i, color: Color) -> void:
	_draw_local_segment(_point(from_coords), _point(to_coords), color)


## Draws the portions of a local-space line lying outside the candidate room rectangle.
## Uses Liang-Barsky line/rectangle clipping to find the entry and exit distances along the segment, then omits the insde span.
func _draw_local_segment(start: Vector2, finish: Vector2, color: Color) -> void:
	var rect: Rect2 = _candidate_room_rect().grow(cursor_line_gap)
	var delta: Vector2 = finish - start
	if delta.is_zero_approx():
		return
	
	# Boundary parameters for left, right, top and bottom planes.
	var p: Array[float] = [-delta.x, delta.x, -delta.y, delta.y]
	var q: Array[float] = [start.x - rect.position.x, rect.end.x - start.x, start.y - rect.position.y, rect.end.y - start.y]
	var entry: float = 0.0
	var exit: float = 1.0
	
	# Find the interval of the segment that lies inside the rectangle.
	for i: int in range(4):
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				# Parallel to, but outside, one rectangle boundary.
				draw_line(start, finish, color, line_width, false)
				return
			continue
		
		var t: float = q[i] / p[i]
		if p[i] < 0.0:
			entry = maxf(entry, t)
		else:
			entry = minf(exit, t)
		
		if entry > exit:
			# The segment doesn't cross the candidate rectangle.
			draw_line(start, finish, color, line_width, false)
			return
	
	# Draw each exterio span, skipping the candidate's interior.
	if entry > 0.0001:
		draw_line(start, start + delta * entry, color, line_width, false)
	if exit < 0.9999:
		draw_line(start + delta * exit, finish, color, line_width, false)


## Format a numerical float value for annotation to only display 2 decimal places and then removes any trailing zeros.
func _format_annotation_value(value: float) -> String:
	return String.num(value, 2).trim_suffix(".0")


## Calculates the complete background rectangle bounds of an annotation.
func _annotation_rect(center: Vector2, number: float, scale_factor: float, padding: Vector2) -> Rect2:
	var label_text: String = _format_annotation_value(number)
	var text_width: float = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, annotation_font_size).x
	var font_height: float = _font.get_ascent(annotation_font_size) + _font.get_descent(annotation_font_size)
	var box_size: Vector2 = Vector2(text_width, font_height) * scale_factor
	box_size += padding * 2.0
	return Rect2(center - box_size * 0.5, box_size)


## Draws a numerical annotation at the provided local [param center] position using the provided [param number] as a text.
## The annotation is horizontally centered and uses a background rectangle to make it more noticable over other elements.
## Uses provided [param scale_factor] to scale the drawn string and then applies provided [param padding] to it for the background.
func _draw_number(center: Vector2, number: float, scale_factor: float, padding: Vector2) -> void:
	# Filter out processing if no font reference was provided.
	if _font == null:
		return
	
	# Draw a tight background rectangle aroudn the actual font metrics.
	draw_rect(
		_annotation_rect(center, number, scale_factor, padding),
		annotation_background,
		true,
	)
	
	# Center the text horizontally and vertivally about the baseline.
	var label_text: String = _format_annotation_value(number)
	var width: float = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, annotation_font_size).x
	var ascent: float = _font.get_ascent(annotation_font_size)
	var descent: float = _font.get_descent(annotation_font_size)
	var baseline: Vector2 = Vector2(-width * 0.5, (ascent - descent) * 0.5)
	
	# Draw the numerical value.
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	draw_string(_font, baseline, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, annotation_font_size, annotation_color)
	
	# Reset draw set transform for future use.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Generates a direction independant identifier for a segment based on the provided [param a] and [param b] coords.
func _segment_key(a: Vector2i, b: Vector2i) -> String:
	# Normalize the endpoint order.
	if a.x > b.x or (a.x == b.x and a.y < b.y):
		var tmp: Vector2i = a
		a = b
		b = tmp
	
	# Return an identifier based on the normalized coordinates.
	return "%s|%s" % [str(a), str(b)]


## Collects occupied room coordinates along an axis-aligned segment.
## Used only when the saved geometry explicitly requests highlights.
func _collect_segment_rooms(from_coords: Vector2i, to_coords: Vector2i, highlighted: Dictionary[Vector2i, bool]) -> void:
	var delta: Vector2i = to_coords - from_coords
	
	# Distance rays are intentionally not interpreted as room routes.
	if delta.x != 0 and delta.y != 0:
		return
	
	# Prepare step offset to the coords based on the delta.
	var step: Vector2i = Vector2i.ZERO
	if delta.x > 0:
		step.x = 1
	elif delta.x < 0:
		step.x = -1
	if delta.y > 0:
		step.y = 1
	elif delta.y < 0:
		step.y = -1
	
	# Highlight room cells.
	var count: int = maxi(absi(delta.x), absi(delta.y))
	for index: int in range(count + 1):
		var coords: Vector2i = from_coords + step * index
		
		# Only highlight actual occupied room cells.
		if _grid_space.has_room_cell_coords(coords):
			highlighted[coords] = true


## Stores one geometry segment for drawing, splitting horizontal and vertical routes into cell to cell edges.
## This prevents partial overlaps from drawing lines over each other.
func _collect_unique_geometry(from_coords: Vector2i, to_coords: Vector2i, color: Color, unique_lines: Dictionary[String, Dictionary]) -> void:
	var delta: Vector2i = to_coords - from_coords
	if delta == Vector2i.ZERO:
		return
	
	# Diagonal distance measurements remain one straight segment.
	if delta.x != 0 and delta.y != 0:
		var diagonal_key: String = _segment_key(from_coords, to_coords)
		if not unique_lines.has(diagonal_key):
			unique_lines[diagonal_key] = {
				"from": from_coords,
				"to": to_coords,
				"color": color,
			}
		return
	
	# Break orthogonal segments into individual neighboring cell links.
	var direction: Vector2i = Vector2i.ZERO
	if delta.x > 0:
		direction.x = 1
	elif delta.x < 0:
		direction.x = -1
	if delta.y > 0:
		direction.y = 1
	elif delta.y < 0:
		direction.y = -1
	
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	for i: int in range(steps):
		var a: Vector2i = from_coords + direction * i
		var b: Vector2i = a + direction
		var key: String = _segment_key(a, b)
		
		if not unique_lines.has(key):
			unique_lines[key] = {
				"from": a,
				"to": b,
				"color": color,
			}


## Returns whether [param rect] would overlap an already placed label saved in the provided [param occupied] list. 
func _annotation_overlaps(rect: Rect2, occupied: Array[Rect2]) -> bool:
	for other: Rect2 in occupied:
		if rect.intersects(other.grow(line_annotation_clearance)):
			return true
	return false


## Searches near the candidate along a measurement line from provided [param a] and [param b] points for a readable annotation position using the provided [param value] number as annotation text.
## Preserves a configurable maximum candidate radius and tries small perpendicular offsets to prevent label collisions by comparing with other annotation saved in provided [param occupied] list.
func _try_draw_line_annotation(a: Vector2, b: Vector2, value: float, occupied: Array[Rect2]) -> bool:
	# Filter out processing if no font reference was provided.
	if _font == null:
		return false
	
	# Identify the endpoint closest to this candidate origin.
	var near: Vector2 = a if a.length_squared() <= b.length_squared() else b
	var far: Vector2 = a if near == a else b
	var line_vector: Vector2 = far - near
	var line_length: float = line_vector.length()
	if is_zero_approx(line_length):
		return false
	
	var direction: Vector2 = line_vector / line_length
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var max_distance: float = minf(line_annotation_max_distance, line_length)
	var candidate_room: Rect2 = _candidate_room_rect().grow(2.0)
	
	# Prefer positions close to the candidate, then move progressively away.
	# Try both sides of the line for each distance before moving farther.
	var attempts: int = maxi(1, ceili((max_distance - line_annotation_min_distance) / line_annotation_distance_step) + 1)
	for attempt: int in range(attempts):
		var distance: float = line_annotation_min_distance + float(attempt) * line_annotation_distance_step
		if distance > max_distance:
			break
		
		for side: int in [0, 1, -1, 2, -2]:
			var center: Vector2 = near + direction * distance
			center += perpendicular * float(side) * line_annotation_side_step
			
			# Keep label centers within the allowed candidate centered radius.
			if center.length() > line_annotation_max_distance:
				continue
			
			var bounds: Rect2 = _annotation_rect(center, value, line_annotation_scale, line_annotation_padding)
			if bounds.intersects(candidate_room):
				continue
			if _annotation_overlaps(bounds, occupied):
				continue
			
			# Keep the occupied area for the next annotation candidate.
			_draw_number(center, value, line_annotation_scale, line_annotation_padding)
			occupied.append(bounds)
			
			return true
	
	# Hide extra label if no collision free position inside the radius.
	return false


## Draws the stored placement explanations.
## Draws placement explanation in three ordered passes:
## 1. Collect unique geometry, room highlights and annotations.
## 2. Draw room highlights below all connecting lines.
## 3. Draw centered room labels, then place line labels without overlaps.
func _draw() -> void:
	# Filter out processing if the required grid space reference is missing.
	if _grid_space == null:
		return
	
	# Prepare variables for tracking previously drawn lines and storing pending room highlights and annotations.
	var highlighted_rooms: Dictionary[Vector2i, bool] = {}
	var unique_lines: Dictionary[String, Dictionary] = {}
	var room_annotations: Array[Dictionary] = []
	var line_annotations: Array[Dictionary] = []
	
	# First pass: process each placement explanation to collect geometry and annotation requests.
	for explanation: MapSolverPlacementExplanation in _explanations:
		# Check collected segments.
		for segment: Dictionary in explanation.segments:
			var a: Vector2i = segment["from"]
			var b: Vector2i = segment["to"]
			_collect_unique_geometry(a, b, connection_color, unique_lines)
			
			# Store highlighted rooms only for explicitly marked axis-aligned segments.
			if bool(segment.get("highlight_rooms", false)):
				_collect_segment_rooms(a, b, highlighted_rooms)
			
			# Store line annotations.
			if bool(segment.get("show_value", false)):
				line_annotations.append({
					"from": _point(a),
					"to": _point(b),
					"value": float(segment.get("value", 0.0)),
				})
		
		# Check collected paths.
		for path: Dictionary in explanation.paths:
			# Initialize route list by appending collected room coords and marking rooms to be highlighted.
			var route: Array[Vector2i] = []
			for coords: Vector2i in path["coords"]:
				route.append(coords)
				
				# Store highlighted room only for existing rooms.
				if _grid_space.has_room_cell_coords(coords):
					highlighted_rooms[coords] = true
			
			# Save all route edges, sharing the deduplication system.
			for index: int in range(route.size() - 1):
				_collect_unique_geometry(route[index], route[index + 1], path_color, unique_lines)
			
			# Store line annotations.
			if bool(path.get("show_value", false)) and route.size() >= 2:
				line_annotations.append({
					"from": _point(route[0]),
					"to": _point(route[route.size() - 1]),
					"value": float(path.get("value", 0.0)),
				})
		
		# Check collected room highlights details.
		for room: Dictionary in explanation.room_values:
			var coords: Vector2i = room["coords"]
			
			# Store highlighted room only for existing rooms.
			if _grid_space.has_room_cell_coords(coords):
				highlighted_rooms[coords] = true
			
			# Store room annotations.
			room_annotations.append({
				"coords": coords,
				"value": float(room.get("value", 0.0)),
			})
	
	# Second pass: draw the exact actual room cell rectangles first.
	for coords: Vector2i in highlighted_rooms:
		var room_rect: Rect2 = _room_rect_local(coords).grow(-marker_inset)
		if room_rect.has_area():
			draw_rect(room_rect, marker_color, true)
	
	# Draw the deduplicated lines over the room highlights.
	for segment: Dictionary in unique_lines.values():
		_draw_segment(segment["from"], segment["to"], segment["color"])
	
	# Third pass: annotations are drawn above geometry, room values first.
	var occupied_annotations: Array[Rect2] = []
	for entry: Dictionary in room_annotations:
		var center: Vector2 = _point(entry["coords"])
		var number: float = float(entry["value"])
		var bounds: Rect2 = _annotation_rect(center, number, room_annotation_scale, room_annotation_padding)
		
		# Don't render multiple centered labels on top of one another.
		if _annotation_overlaps(bounds, occupied_annotations):
			continue
		
		# Draw room annotation.
		_draw_number(center, number, room_annotation_scale, room_annotation_padding)
		occupied_annotations.append(bounds)
	
	# Draw line annotations.
	for entry: Dictionary in line_annotations:
		_try_draw_line_annotation(entry["from"], entry["to"], float(entry["value"]), occupied_annotations)
