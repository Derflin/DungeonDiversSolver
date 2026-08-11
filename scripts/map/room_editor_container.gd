extends Node2D


@onready var room_editor_menu = $RoomEditorMenu


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
	for barricade_direction: RoomInstanceData.BarricadeDirectionFlags in room_corridor_type.BARRICADE_FRAME_BY_DIRECTION:
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
			}
		)
	
	# Populate connections submenu.
	submenu_connections.menu_items = []
	for connection_direction: RoomInstanceData.ConnectionDirectionFlags in room_corridor_type.CONNECTION_FRAME_BY_DIRECTION:
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
			}
		)
	
	# Populate specials submenu.
	submenu_specials.menu_items = []
	for room_special_type in room_special_types:
		submenu_specials.menu_items.append(
			{
				"texture": room_special_type.get_static_texture(),
				"title": "Special - " + room_special_type.get_display_name(),
				"id": "action_special_" + room_special_type.get_id(),
			}
		)
	
	# Populate secrets submenu.
	submenu_secrets.menu_items = []
	for room_secret_type in room_secret_types:
		submenu_secrets.menu_items.append(
			{
				"texture": room_secret_type.get_static_texture(),
				"title": "Secret - " + room_secret_type.get_display_name(),
				"id": "action_secret_" + room_secret_type.get_id(),
			}
		)
	
	# Initialize menu items.
	room_editor_menu.menu_items = [
		{"texture": icon_delete_room_texture, "title": "Remove room", "id": "action_remove_room"},
		{"texture": icon_barricades_texture, "title": "Room Barricades", "id": submenu_barricades},
		{"texture": icon_connections_texture, "title": "Room Connections", "id": submenu_connections},
		{"texture": icon_specials_texture, "title": "Specials Setup", "id": submenu_specials},
		{"texture": icon_secrets_texture, "title": "Secrets Setup", "id": submenu_secrets},
	]


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
	var row = frame / hframes
	
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		frame_size
	)
	
	return atlas
