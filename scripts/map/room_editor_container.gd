extends Node2D


@onready var room_editor_menu = $RoomEditorMenu


@export var icon_delete_room_texture: Texture2D
@export var icon_barricades_texture: Texture2D
@export var icon_connections_texture: Texture2D
@export var icon_specials_texture: Texture2D
@export var icon_secrets_texture: Texture2D


func _ready() -> void:
	# Initialize submenu items.
	var submenu_barricades = create_submenu(room_editor_menu)
	var submenu_connections = create_submenu(room_editor_menu)
	var submenu_specials = create_submenu(room_editor_menu)
	var submenu_secrets = create_submenu(room_editor_menu)
	
	#TODO: add sub-menu option initialization
	
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
	
	submenu.icon_scale = parent_menu.icon_scale
	submenu.show_titles = parent_menu.show_titles
	
	submenu.offset_transform_enabled = parent_menu.offset_transform_enabled
	submenu.offset_transform_position = parent_menu.offset_transform_position
	submenu.offset_transform_scale = parent_menu.offset_transform_scale
	submenu.offset_transform_visual_only = parent_menu.offset_transform_visual_only
	
	return submenu
