class_name RoomConnectionTextureGenerator
extends RefCounted


const ROOM_SIZE := Vector2i(15, 15)
const CONNECTION_SIZE := Vector2i(17, 17)
const ROOM_OFFSET := Vector2i(1, 1)

const SCAN_STEP_BY_DIRECTION := {
	RoomInstanceData.ConnectionDirectionFlags.UP: Vector2i(0, 1),
	RoomInstanceData.ConnectionDirectionFlags.DOWN: Vector2i(0, -1),
	RoomInstanceData.ConnectionDirectionFlags.LEFT: Vector2i(1, 0),
	RoomInstanceData.ConnectionDirectionFlags.RIGHT: Vector2i(-1, 0),
	RoomInstanceData.ConnectionDirectionFlags.UPPER_LEFT: Vector2i(1, 1),
	RoomInstanceData.ConnectionDirectionFlags.UPPER_RIGHT: Vector2i(-1, 1),
	RoomInstanceData.ConnectionDirectionFlags.DOWN_LEFT: Vector2i(1, -1),
	RoomInstanceData.ConnectionDirectionFlags.DOWN_RIGHT: Vector2i(-1, -1),
}

const BARRICADE_DRAW_ORDER := [
	RoomInstanceData.BarricadeDirectionFlags.UP,
	RoomInstanceData.BarricadeDirectionFlags.RIGHT,
	RoomInstanceData.BarricadeDirectionFlags.DOWN,
	RoomInstanceData.BarricadeDirectionFlags.LEFT,
]


static func generate_for_direction(floor_visual_data: ResolvedVisualData, corridor_type: RoomCorridorType, barricade_mask: int, direction: int) -> Texture2D:
	var floor_image := get_image_from_visual_data(floor_visual_data)
	if floor_image == null:
		return null
	
	return generate_from_floor_image(floor_image, corridor_type, barricade_mask, direction)


static func generate_from_floor_image(floor_image: Image, corridor_type: RoomCorridorType, barricade_mask: int, direction: int) -> Texture2D:
	if floor_image == null:
		return null
	if corridor_type == null:
		return null
	if corridor_type.connections_texture == null:
		return null
	
	var composed_room := _compose_room_image(floor_image, corridor_type, barricade_mask)
	
	var connection_frame: int = corridor_type.CONNECTION_FRAME_BY_DIRECTION[direction]
	
	var connection_mask := _extract_frame_image(
		corridor_type.connections_texture, 
		corridor_type.connections_texture_hframes, 
		corridor_type.connections_texture_vframes, 
		connection_frame,
	)
	
	if connection_mask == null:
		return null
		
	var result := Image.create_empty(CONNECTION_SIZE.x, CONNECTION_SIZE.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	
	var scan_step: Vector2i = SCAN_STEP_BY_DIRECTION[direction]
	
	for y in range(CONNECTION_SIZE.y):
		for x in range(CONNECTION_SIZE.x):
			var mask_color := connection_mask.get_pixel(x, y)
			
			if mask_color.a <= 0.0:
				continue
			
			var source_pos := _connection_to_room_pos(Vector2i(x, y))
			var sampled_color := _sample_first_opaque_pixel(composed_room, source_pos, scan_step)
			
			if sampled_color.a <= 0.0:
				continue
			
			sampled_color.a *= mask_color.a
			result.set_pixel(x, y, sampled_color)
	
	return ImageTexture.create_from_image(result)


static func get_image_from_visual_data(visual_data: ResolvedVisualData) -> Image:
	if visual_data == null:
		return null
	
	if visual_data is ResolvedTextureVisualData:
		var texture_data: ResolvedTextureVisualData = visual_data
		return _extract_frame_image(texture_data.texture, texture_data.hframes, texture_data.vframes, max(texture_data.frame, 0))
	
	if visual_data is ResolvedSpriteFramesVisualData:
		var sprite_frames_data: ResolvedSpriteFramesVisualData = visual_data
		if sprite_frames_data.sprite_frames == null:
			return null
		
		var frame_texture := sprite_frames_data.sprite_frames.get_frame_texture(sprite_frames_data.animation_name, sprite_frames_data.frame)
		
		if frame_texture == null:
			return null
		
		var image := frame_texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		return image
	
	return null


static func _compose_room_image(floor_image: Image, corridor_type: RoomCorridorType, barricade_mask: int) -> Image:
	var result := floor_image.duplicate()
	result.convert(Image.FORMAT_RGBA8)
	
	if corridor_type.barricades_texture == null:
		return result
	
	for barricade_flag in BARRICADE_DRAW_ORDER:
		if (barricade_mask & barricade_flag) == 0:
			continue
		
		var barricade_frame: int = corridor_type.BARRICADE_FRAME_BY_DIRECTION[barricade_flag]
		
		var barricade_image := _extract_frame_image(
			corridor_type.barricades_texture,
			corridor_type.barricades_texture_hframes,
			corridor_type.barricades_texture_vframes,
			barricade_frame,
		)
		
		if barricade_image == null:
			continue
		
		result.blend_rect(barricade_image, Rect2i(Vector2i.ZERO, ROOM_SIZE), Vector2i.ZERO)
	
	return result


static func _extract_frame_image(texture: Texture2D, hframes: int, vframes: int, frame: int) -> Image:
	if texture == null:
		return
	
	var sheet := texture.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	
	var frame_width := sheet.get_width() / hframes
	var frame_height := sheet.get_height() / vframes
	
	var frame_x := (frame % hframes) * frame_width
	var frame_y := int(frame / hframes) * frame_height
	
	return sheet.get_region(Rect2i(frame_x, frame_y, frame_width, frame_height))


static func _connection_to_room_pos(connection_pos: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(connection_pos.x - ROOM_OFFSET.x, 0, ROOM_SIZE.x - 1),
		clampi(connection_pos.y - ROOM_OFFSET.y, 0, ROOM_SIZE.y - 1),
	)


static func _sample_first_opaque_pixel(image: Image, start_pos: Vector2i, scan_step: Vector2i) -> Color:
	var pos := start_pos
	var max_steps := max(ROOM_SIZE.x, ROOM_SIZE.y) + 2
	
	for _i in range(max_steps):
		if pos.x < 0 or pos.x >= ROOM_SIZE.x or pos.y < 0 or pos.y >= ROOM_SIZE.y:
			break
		
		var color := image.get_pixel(pos.x, pos.y)
		if color.a > 0.0:
			return color
		
		pos += scan_step
	
	return Color(0, 0, 0, 0)
