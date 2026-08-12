extends Node2D


signal room_editor_action_delete_triggered
signal room_editor_action_barricade_change_triggered(barricade_direction: RoomInstanceData.BarricadeDirectionFlags, state: bool)
signal room_editor_action_connection_change_triggered(connection_direction: RoomInstanceData.ConnectionDirectionFlags, state: bool)
signal room_editor_action_special_set_triggered(special_room_kind: RoomSpecialType.Kind, state: bool)
signal room_editor_action_secret_set_triggered(secret_room_kind: RoomSecretType.Kind, state: bool)


const barricade_direction_menu_order: Array[RoomInstanceData.BarricadeDirectionFlags] = [
	RoomInstanceData.BarricadeDirectionFlags.UP,
	RoomInstanceData.BarricadeDirectionFlags.RIGHT,
	RoomInstanceData.BarricadeDirectionFlags.DOWN,
	RoomInstanceData.BarricadeDirectionFlags.LEFT,
]

const connection_direction_menu_order: Array[RoomInstanceData.ConnectionDirectionFlags] = [
	RoomInstanceData.ConnectionDirectionFlags.UP,
	RoomInstanceData.ConnectionDirectionFlags.UPPER_RIGHT,
	RoomInstanceData.ConnectionDirectionFlags.RIGHT,
	RoomInstanceData.ConnectionDirectionFlags.DOWN_RIGHT,
	RoomInstanceData.ConnectionDirectionFlags.DOWN,
	RoomInstanceData.ConnectionDirectionFlags.DOWN_LEFT,
	RoomInstanceData.ConnectionDirectionFlags.LEFT,
	RoomInstanceData.ConnectionDirectionFlags.UPPER_LEFT,
]


@onready var room_editor_menu = $RoomEditorMenu
@onready var room_editor_menu_hover_label = $HoverLabel


@export_group("Main menu - Icons", "icon_")
@export var icon_delete_room_texture: Texture2D
@export var icon_barricades_texture: Texture2D
@export var icon_connections_texture: Texture2D
@export var icon_specials_texture: Texture2D
@export var icon_secrets_texture: Texture2D

@export_group("Submenu - Barricades - Direction Icons", "icon_barricades_directions_")
@export var icon_barricades_directions_spritesheet_texture: Texture2D
@export_range(1.0, 128.0, 1.0)
var icon_barricades_directions_spritesheet_texture_hframe: int = 4
@export_range(1.0, 128.0, 1.0)
var icon_barricades_directions_spritesheet_texture_vframe: int = 1

@export_group("Submenu - Barricades - Connection Icons", "icon_connections_directions_")
@export var icon_connections_directions_spritesheet_texture: Texture2D
@export_range(1.0, 128.0, 1.0)
var icon_connections_directions_spritesheet_texture_hframe: int = 8
@export_range(1.0, 128.0, 1.0)
var icon_connections_directions_spritesheet_texture_vframe: int = 1


func _ready() -> void:
	initialize_room_editor_menu()


func initialize_room_editor_menu() -> void:
	# Initialize submenu items.
	var submenu_barricades = create_submenu(room_editor_menu)
	var submenu_connections = create_submenu(room_editor_menu)
	var submenu_specials = create_submenu(room_editor_menu)
	var submenu_secrets = create_submenu(room_editor_menu)
	
	# Gather catalog data
	var room_corridor_type: RoomCorridorType = GameData.room_corridor_types.get_default_type()
	var room_special_types: Array[RoomSpecialType] = GameData.room_special_types.get_all()
	var room_secret_types: Array[RoomSecretType] = GameData.room_secret_types.get_all()
	
	# Populate barricades submenu.
	submenu_barricades.menu_items = []
	for barricade_direction: RoomInstanceData.BarricadeDirectionFlags in barricade_direction_menu_order:
		submenu_barricades.menu_items.append(
			{
				"texture": get_frame_texture(
					icon_barricades_directions_spritesheet_texture,
					room_corridor_type.BARRICADE_FRAME_BY_DIRECTION[barricade_direction],
					icon_barricades_directions_spritesheet_texture_hframe,
					icon_barricades_directions_spritesheet_texture_vframe
				),
				"title": "Barricade - " + room_corridor_type.BARRICADE_DISPLAY_NAME_BY_DIRECTION[barricade_direction],
				"id": "action_barricade_" + str(barricade_direction),
				"toggleable": true,
			}
		)
	submenu_barricades.submenu_angle_mode = RoomEditorRadialMenu.SubmenuAngleMode.FIXED
	submenu_barricades.align_first_item_up()
	submenu_barricades.fixed_center_angle = submenu_barricades.center_angle
	
	# Populate connections submenu.
	submenu_connections.menu_items = []
	for connection_direction: RoomInstanceData.ConnectionDirectionFlags in connection_direction_menu_order:
		submenu_connections.menu_items.append(
			{
				"texture": get_frame_texture(
					icon_connections_directions_spritesheet_texture,
					room_corridor_type.CONNECTION_FRAME_BY_DIRECTION[connection_direction],
					icon_connections_directions_spritesheet_texture_hframe,
					icon_connections_directions_spritesheet_texture_vframe
				),
				"title": "Connection - " + room_corridor_type.CONNECTION_DISPLAY_NAME_BY_DIRECTION[connection_direction],
				"id": "action_connection_" + str(connection_direction),
				"toggleable": true,
			}
		)
	submenu_connections.submenu_angle_mode = RoomEditorRadialMenu.SubmenuAngleMode.FIXED
	submenu_connections.align_first_item_up()
	submenu_connections.fixed_center_angle = submenu_connections.center_angle
	
	# Populate specials submenu.
	submenu_specials.menu_items = []
	for room_special_type in room_special_types:
		submenu_specials.menu_items.append(
			{
				"texture": room_special_type.get_static_texture(),
				"title": "Special - " + room_special_type.get_display_name(),
				"id": "action_special_" + room_special_type.get_id(),
				"toggleable": true,
			}
		)
	submenu_specials.submenu_angle_mode = RoomEditorRadialMenu.SubmenuAngleMode.FIXED
	submenu_specials.align_first_item_up()
	submenu_specials.fixed_center_angle = submenu_specials.center_angle
	
	# Populate secrets submenu.
	submenu_secrets.menu_items = []
	for room_secret_type in room_secret_types:
		submenu_secrets.menu_items.append(
			{
				"texture": room_secret_type.get_static_texture(),
				"title": "Secret - " + room_secret_type.get_display_name(),
				"id": "action_secret_" + room_secret_type.get_id(),
				"toggleable": true,
			}
		)
	submenu_secrets.submenu_angle_mode = RoomEditorRadialMenu.SubmenuAngleMode.FIXED
	submenu_secrets.align_first_item_up()
	submenu_secrets.fixed_center_angle = submenu_secrets.center_angle
	
	# Initialize menu items.
	room_editor_menu.menu_items = [
		{"texture": icon_specials_texture, "title": "Specials Setup", "id": submenu_specials},
		{"texture": icon_secrets_texture, "title": "Secrets Setup", "id": submenu_secrets},
		{"texture": icon_delete_room_texture, "title": "Remove room", "id": "action_remove_room"},
		{"texture": icon_connections_texture, "title": "Room Connections", "id": submenu_connections},
		{"texture": icon_barricades_texture, "title": "Room Barricades", "id": submenu_barricades},
	]


func set_room_editor_menu_toggle_action_state(selected_room_cell: RoomCell) -> void:
	var room_instance_data = selected_room_cell.room_instance_data
	
	for menu_item in room_editor_menu.menu_items:
		var menu_item_action = menu_item["id"]
		if menu_item_action is RoomEditorRadialMenu:
			for submenu_item in menu_item_action.menu_items:
				var submenu_item_action = submenu_item["id"]
				
				if not submenu_item.get("toggleable", false):
					continue
				
				if submenu_item_action is not String:
					continue
				
				if submenu_item_action.begins_with("action_barricade_"):
					var filter_split_count = 2
					var action_barricade_direction_id = submenu_item_action.split("_", true, filter_split_count)
					var action_barricade_direction: RoomInstanceData.BarricadeDirectionFlags = -1 if action_barricade_direction_id == null or action_barricade_direction_id.size() <= filter_split_count  else int(action_barricade_direction_id[filter_split_count])
					
					if action_barricade_direction == -1:
						continue

					submenu_item["is_toggled"] = room_instance_data.has_barricade(action_barricade_direction)
				
				elif submenu_item_action.begins_with("action_connection_"):
					var filter_split_count = 2
					var action_connection_direction_id = submenu_item_action.split("_", true, filter_split_count)
					var action_connection_direction: RoomInstanceData.ConnectionDirectionFlags = -1 if action_connection_direction_id == null or action_connection_direction_id.size() <= filter_split_count else int(action_connection_direction_id[filter_split_count])
					
					if action_connection_direction == -1:
						continue

					submenu_item["is_toggled"] = room_instance_data.has_connection(action_connection_direction)
				
				elif submenu_item_action.begins_with("action_special_"):
					var filter_split_count = 2
					var action_special_id = submenu_item_action.split("_", true, filter_split_count)
					action_special_id = null if action_special_id == null or action_special_id.size() <= filter_split_count else action_special_id[filter_split_count]
					
					if action_special_id == null:
						continue
					
					submenu_item["is_toggled"] = room_instance_data.has_special_type_by_id(action_special_id)
				
				elif submenu_item_action.begins_with("action_secret_"):
					var filter_split_count = 2
					var action_secret_id = submenu_item_action.split("_", true, filter_split_count)
					action_secret_id = null if action_secret_id == null or action_secret_id.size() <= filter_split_count else action_secret_id[filter_split_count]
					
					if action_secret_id == null:
						continue
					
					submenu_item["is_toggled"] = room_instance_data.has_secret_type_by_id(action_secret_id)
					
	room_editor_menu.queue_redraw()


func create_submenu(parent_menu: RoomEditorRadialMenu) -> RoomEditorRadialMenu:
	var submenu = RoomEditorRadialMenu.new()
	
	submenu.width = parent_menu.width * 0.85
	submenu.center_radius = parent_menu.center_radius
	submenu.gap_size = parent_menu.gap_size
	submenu.circle_coverage = parent_menu.circle_coverage
	
	submenu.show_animation = parent_menu.show_animation
	submenu.animation_speed_factor = parent_menu.animation_speed_factor
	
	submenu.outside_selection_factor = parent_menu.outside_selection_factor
	
	submenu.icon_scale = parent_menu.icon_scale
	submenu.show_titles = parent_menu.show_titles
	
	submenu.offset_transform_enabled = parent_menu.offset_transform_enabled
	submenu.offset_transform_position = parent_menu.offset_transform_position
	submenu.offset_transform_scale = parent_menu.offset_transform_scale
	submenu.offset_transform_visual_only = parent_menu.offset_transform_visual_only
	
	return submenu


func get_frame_texture(texture: Texture2D, frame: int, hframes: int, vframes: int) -> Texture2D:
	var texture_size = texture.get_size()
	
	var frame_size = Vector2(texture_size.x / hframes, texture_size.y / vframes)
	
	var column = frame % hframes
	@warning_ignore("integer_division")
	var row = frame / hframes
	
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		frame_size
	)
	
	return atlas


func update_room_editor_menu_hover_label_position() -> void:
	const label_offset_y = 1.0
	
	var outer_menu: RoomEditorRadialMenu = room_editor_menu
	if room_editor_menu.has_open_submenu():
		var submenu = room_editor_menu.get_open_submenu()
		if submenu is RoomEditorRadialMenu:
			outer_menu = submenu

	var visual_radius = outer_menu.radius
	if outer_menu.offset_transform_enabled:
		visual_radius *= outer_menu.offset_transform_scale.y
	
	var label_scale := 1.0
	if room_editor_menu_hover_label.offset_transform_enabled:
		label_scale = room_editor_menu_hover_label.offset_transform_scale.y
	
	var label_top_inset = (room_editor_menu_hover_label.size.y * (1.0 - label_scale) / 2.0 )
	
	room_editor_menu_hover_label.position = Vector2(
		room_editor_menu.moved_to_position.x - room_editor_menu_hover_label.size.x / 2.0,
		room_editor_menu.moved_to_position.y + visual_radius - label_top_inset + label_offset_y
	)


func open_room_editor(cursor_position: Vector2) -> void:
	room_editor_menu.open_menu(cursor_position)


func close_room_editor() -> void:
	room_editor_menu.close_menu()
	room_editor_menu_hover_label.visible = false


func get_room_editor_visible_status() -> bool:
	return room_editor_menu.visible


func _on_room_editor_menu_selection_changed(item: Variant) -> void:
	if item == null:
		room_editor_menu_hover_label.text = ""
		room_editor_menu_hover_label.visible = false
		return
		
	room_editor_menu_hover_label.text = item["title"].strip_edges()
	if room_editor_menu_hover_label.text.length() > 0:
		room_editor_menu_hover_label.visible = true


func _on_room_editor_menu_after_menu_closed() -> void:
	update_room_editor_menu_hover_label_position()


func _on_room_editor_menu_after_menu_opened() -> void:
	update_room_editor_menu_hover_label_position()


func _on_room_editor_menu_after_submenu_closed() -> void:
	update_room_editor_menu_hover_label_position()


func _on_room_editor_menu_after_submenu_opened() -> void:
	update_room_editor_menu_hover_label_position()


func _on_room_editor_menu_item_selected(id: Variant, position: Variant) -> void:
	print("Item Selected - %s at pos %s" % [id ,position])
	
	if id == "action_remove_room":
		room_editor_action_delete_triggered.emit()
		room_editor_menu.close_all_menus()


func _on_room_editor_menu_item_toggled(id: Variant, is_toggled: Variant, position: Variant) -> void:
	print("Item Toggled - %s set to %s at pos %s" % [id ,is_toggled, position])
	
	var action_id = id
	if action_id is not String:
		return
	
	if action_id.begins_with("action_barricade_"):
		var filter_split_count = 2
		var action_barricade_direction_id = action_id.split("_", true, filter_split_count)
		var action_barricade_direction: RoomInstanceData.BarricadeDirectionFlags = -1 if action_barricade_direction_id == null or action_barricade_direction_id.size() <= filter_split_count  else int(action_barricade_direction_id[filter_split_count])
		
		if action_barricade_direction == -1:
			return
		
		room_editor_action_barricade_change_triggered.emit(action_barricade_direction, is_toggled)
	
	elif action_id.begins_with("action_connection_"):
		var filter_split_count = 2
		var action_connection_direction_id = action_id.split("_", true, filter_split_count)
		var action_connection_direction: RoomInstanceData.ConnectionDirectionFlags = -1 if action_connection_direction_id == null or action_connection_direction_id.size() <= filter_split_count else int(action_connection_direction_id[filter_split_count])
		
		if action_connection_direction == -1:
			return

		room_editor_action_connection_change_triggered.emit(action_connection_direction, is_toggled)
	
	elif action_id.begins_with("action_special_"):
		var filter_split_count = 2
		var action_special_id = action_id.split("_", true, filter_split_count)
		action_special_id = null if action_special_id == null or action_special_id.size() <= filter_split_count else action_special_id[filter_split_count]
		
		if action_special_id == null:
			return
		
		var room_special_type = GameData.room_special_types.get_type_by_id(action_special_id)
		if room_special_type == null:
			return
		
		room_editor_action_special_set_triggered.emit(room_special_type.get_kind(), is_toggled)
	
	elif action_id.begins_with("action_secret_"):
		var filter_split_count = 2
		var action_secret_id = action_id.split("_", true, filter_split_count)
		action_secret_id = null if action_secret_id == null or action_secret_id.size() <= filter_split_count else action_secret_id[filter_split_count]
		
		if action_secret_id == null:
			return
		
		var room_secret_type = GameData.room_secret_types.get_type_by_id(action_secret_id)
		if room_secret_type == null:
			return
		
		room_editor_action_secret_set_triggered.emit(room_secret_type.get_kind(), is_toggled)
