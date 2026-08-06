@tool
class_name RoomCell
extends Node2D


@export var cell_size := Vector2(17, 17): 
	set(value): 
		cell_size = value 
		queue_redraw() 

@export var show_editor_guide := true: 
	set(value): 
		show_editor_guide = value 
		queue_redraw()

@export var room_instance_data: RoomInstanceData:
	set(value):
		if room_instance_data == value:
			return
			
		_disconnect_room_instance_data()
		
		room_instance_data = value
		
		_connect_room_instance_data()
		
		if is_node_ready():
			refresh_visuals()
			
			
@onready var connection_sprites: Dictionary = {
	RoomInstanceData.ConnectionDirectionFlags.UP: $Content/Connections/ConnectionUp,
	RoomInstanceData.ConnectionDirectionFlags.DOWN: $Content/Connections/ConnectionDown,
	RoomInstanceData.ConnectionDirectionFlags.LEFT: $Content/Connections/ConnectionLeft,
	RoomInstanceData.ConnectionDirectionFlags.RIGHT: $Content/Connections/ConnectionRight,
	RoomInstanceData.ConnectionDirectionFlags.UPPER_LEFT: $Content/Connections/ConnectionUpperLeft,
	RoomInstanceData.ConnectionDirectionFlags.UPPER_RIGHT: $Content/Connections/ConnectionUpperRight,
	RoomInstanceData.ConnectionDirectionFlags.DOWN_LEFT: $Content/Connections/ConnectionDownLeft,
	RoomInstanceData.ConnectionDirectionFlags.DOWN_RIGHT: $Content/Connections/ConnectionDownRight,
}

@onready var barricade_sprites: Dictionary = {
	RoomInstanceData.BarricadeDirectionFlags.UP: $Content/Barricades/BarricadeUp,
	RoomInstanceData.BarricadeDirectionFlags.DOWN: $Content/Barricades/BarricadeDown,
	RoomInstanceData.BarricadeDirectionFlags.LEFT: $Content/Barricades/BarricadeLeft,
	RoomInstanceData.BarricadeDirectionFlags.RIGHT: $Content/Barricades/BarricadeRight,
}


func create(_room_instance_data: RoomInstanceData) -> void:
	room_instance_data = _room_instance_data
	
	print("Room Cell Initialized - %s", str(room_instance_data))


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
		
	_connect_room_instance_data()
	refresh_visuals()
	
	
func _connect_room_instance_data() -> void:
	if room_instance_data == null:
		return
		
	if not room_instance_data.changed.is_connected(refresh_visuals):
		room_instance_data.changed.connect(refresh_visuals)
		
		
func _disconnect_room_instance_data() -> void:
	if room_instance_data == null:
		return
		
	if room_instance_data.changed.is_connected(refresh_visuals):
		room_instance_data.changed.disconnect(refresh_visuals)
		
		
func refresh_visuals() -> void:
	if not is_node_ready():
		return
		
	_clear_visuals()
	
	if room_instance_data == null:
		return
		
	_refresh_room_shadow()
	_refresh_room_content()
	
	
func _clear_visuals() -> void:
	$Shadow.visible = false
	
	$Content/Floor.texture = null
	$Content/Floor.visible = false
	
	$Content/Background.texture = null
	$Content/Background.visible = false
	
	for child_node: Node in $Content/Connections.get_children():
		if child_node is Sprite2D:
			child_node.texture = null
			child_node.visible = false
	
	for child_node: Node in $Content/Barricades.get_children():
		if child_node is Sprite2D:
			child_node.texture = null
			child_node.visible = false
			
	$Content/Icon.texture = null
	$Content/Icon.visible = false
	
	
func _refresh_room_shadow() -> void:
	$Shadow.visible = true
	

func _refresh_room_content() -> void:
	_refresh_room_content_floor()
	_refresh_room_content_background()
	_refresh_room_content_connections()
	_refresh_room_content_barricades()
	_refresh_room_content_icon()
	

#TODO: test it out
func _refresh_room_content_floor() -> void:
	var floor_data = room_instance_data.get_room_floor_visual_data()
	
	if floor_data == null:
		return
		
	apply_sprite_element_visual_data($Content/Floor, floor_data)
	#$Content/Floor.texture = floor_data.texture
	#$Content/Floor.hframes = floor_data.columns
	#$Content/Floor.vframes = floor_data.rows
	##TODO: right now not sure how to handle this
	#$Content/Floor.frame = 0
	#$Content/Floor.visible = $Content/Floor.texture != null
	
	
#TODO: test it out
func _refresh_room_content_background() -> void:
	var background_data = room_instance_data.get_room_background_visual_data()
	
	if background_data == null:
		return
		
	apply_sprite_element_visual_data($Content/Background, background_data)
	#$Content/Background.texture = background_data.texture
	#$Content/Background.hframes = background_data.columns
	#$Content/Background.vframes = background_data.rows
	##TODO: right now not sure how to handle this
	#$Content/Background.frame = 0
	#$Content/Background.visible = $Content/Background.texture != null
	
	
#TODO: test it out
func _refresh_room_content_connections() -> void:
	var connections_data = room_instance_data.get_room_connections_visual_data()
	
	if connections_data == null:
		return
		
	for direction_flag: RoomInstanceData.ConnectionDirectionFlags in connection_sprites:
		var connection_sprite: Sprite2D = connection_sprites[direction_flag]
		var frame_index: int = connections_data.dictionary_frame_per_direction[direction_flag]
		connections_data.frame = frame_index
		
		apply_sprite_element_visual_data(connection_sprite, connections_data)
		#connection_sprite.texture = connections_data.texture
		#connection_sprite.hframes = connections_data.columns
		#connection_sprite.vframes = connections_data.rows
		#connection_sprite.frame = frame_index
		#connection_sprite.visible = connection_sprite.texture != null
	

#TODO: test it out
func _refresh_room_content_barricades() -> void:
	var barricades_data = room_instance_data.get_room_barricades_visual_data()
	
	if barricades_data == null:
		return
		
	for direction_flag: RoomInstanceData.BarricadeDirectionFlags in connection_sprites:
		var barricade_sprite: Sprite2D = barricade_sprites[direction_flag]
		var frame_index: int = barricades_data.dictionary_frame_per_direction[direction_flag]
		barricades_data.frame = frame_index
		
		apply_sprite_element_visual_data(barricade_sprite, barricades_data)
		#barricade_sprite.texture = barricades_data.texture
		#barricade_sprite.hframes = barricades_data.columns
		#barricade_sprite.vframes = barricades_data.rows
		#barricade_sprite.frame = frame_index
		#barricade_sprite.visible = barricade_sprite.texture != null
	

#TODO: test it out
func _refresh_room_content_icon() -> void:
	var icon_data = room_instance_data.get_room_icon_visual_data()
	
	if icon_data == null:
		return
		
	apply_sprite_element_visual_data($Content/Icon, icon_data)
	#$Content/Icon.texture = icon_data.texture
	#$Content/Icon.hframes = icon_data.columns
	#$Content/Icon.vframes = icon_data.rows
	##TODO: right now not sure how to handle this
	#$Content/Icon.frame = 0
	#$Content/Icon.visible = $Content/Icon.texture != null


func _draw() -> void: 
	_draw_editor_guide()


func _draw_editor_guide() -> void:
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
	

#TODO
func apply_sprite_element_visual_data(sprite: Sprite2D, visual_data: ResolvedVisualData) -> void:
	pass
	
	
func apply_sprite_frame(sprite: Sprite2D, sprite_frames: SpriteFrames, animation_name: StringName, frame_index: int) -> void:
	if sprite_frames == null:
		sprite.texture = null
		return
		
	if not sprite_frames.has_animation(animation_name):
		sprite.texture = null
		return
		
	var frame_count = sprite_frames.get_frame_count(animation_name)
	
	if frame_index < 0 or frame_index >= frame_count:
		sprite.texture = null
		return
		
	sprite.texture = sprite_frames.get_frame_texture(animation_name, frame_index)
	
	
