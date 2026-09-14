class_name MapParametersControl
extends Control


var _map_parameter_entry = preload("res://scenes/hud/map_parameter_entry.tscn")

var _drawer_open: bool = false
var _drawer_tween: Tween
var _drawer_collapsed_visible_width: float = 0.0
var _drawer_effective_ui_scale: int = 1


@onready var drawer_root: Control = $DrawerAnchor/DrawerRoot
@onready var drawer_panel: PanelContainer = $DrawerAnchor/DrawerRoot/DrawerPanel
@onready var drawer_scroll_bar: VScrollBar = $DrawerAnchor/DrawerRoot/DrawerScrollBar
@onready var drawer_strip: PanelContainer = $DrawerAnchor/DrawerRoot/DrawerStrip
@onready var drawer_toggle_button: Button = $DrawerAnchor/DrawerRoot/DrawerStrip/VBoxContainer/DrawerToggleButton
@onready var scroll_container: ScrollContainer = $DrawerAnchor/DrawerRoot/DrawerPanel/MarginContainer/ScrollContainer
@onready var drawer_contents: VBoxContainer = $DrawerAnchor/DrawerRoot/DrawerPanel/MarginContainer/ScrollContainer/DrawerContents

@onready var map_grid_settings_container := $DrawerAnchor/DrawerRoot/DrawerPanel/MarginContainer/ScrollContainer/DrawerContents/MapGridSettingsMarginContainer/ContainerContents/MapGridSettingsContainer
@onready var map_secret_settings_container := $DrawerAnchor/DrawerRoot/DrawerPanel/MarginContainer/ScrollContainer/DrawerContents/MapSecretSettingsMarginContainer/ContainerContents/MapSecretSettingsContainer


@export_group("Drawer Layout", "drawer_")
@export var drawer_width_offset: float = 0.0
@export var drawer_collapsed_width_offset: float = 0.0
@export var drawer_slide_duration: float = 0.2
@export var drawer_screen_vertical_margin: float = 8.0
@export_range(1, 4, 1)
var drawer_preferred_ui_scale: int = 2
@export_range(1, 4, 1)
var drawer_minimum_ui_scale: int = 2

@export_group("Drawer Toggle Button", "drawer_toggle_")
@export var drawer_toggle_expand_icon: Texture2D
@export var drawer_toggle_collapse_icon: Texture2D


func _ready() -> void:
	# Populate static and dynamic map parameter entries
	_populate_parameter_entries()
	
	# Initialize drawer scrollbar
	initialize_drawer_scrollbar()
	
	# Attach node resized signal to handle resizing and refreshing drawer layout and call it
	resized.connect(_on_control_resized)
	
	# Refresh drawer layout after initializing all the map parameter entries 
	call_deferred("_refresh_drawer_layout")
	
	# Attach signal listener when other submenu opens, to close this submenu if opened
	GameState.map_solver_submenu_opened.connect(_on_other_menu_submenu_opened)


func _populate_parameter_entries() -> void:
	_create_static_map_grid_size_entry()
	_create_dynamic_secret_settings_entries()


func initialize_drawer_scrollbar() -> void:
	# Hide ScrollContainer scrollbar
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	
	# Sync DrawerScrollBar with the ScrollContainer scrollbar
	var internal_scroll_bar := scroll_container.get_v_scroll_bar()
	drawer_scroll_bar.share(internal_scroll_bar)
	
	# Connect signals to manage DrawerScrollBar state and update it
	internal_scroll_bar.changed.connect(_update_drawer_scroll_bar_visibility)
	call_deferred("_update_drawer_scroll_bar_visibility")


func _create_static_map_grid_size_entry() -> void:
	# Initialize static map grid size parameter entry
	var parameter_entry_map_grid_size := _map_parameter_entry.instantiate()
	map_grid_settings_container.add_child(parameter_entry_map_grid_size, true)
	parameter_entry_map_grid_size.initialize_map_grid_size()
	
	# Set node custom node name
	parameter_entry_map_grid_size.name = "%s (%s)" % [
		parameter_entry_map_grid_size.get_script().get_global_name(), 
		"map_grid_size",
	]


func _create_dynamic_secret_settings_entries() -> void:
	# Prepare secret parameter entries for all secret types
	var secret_room_type_kinds_ordered = RoomSecretType.ROOM_SECRET_TYPE_CREATE_ORDER
	for secret_room_type_kind in secret_room_type_kinds_ordered:
		# Check if secret room type exists in the current game data
		if not GameData.room_secret_types.has_type(secret_room_type_kind):
			continue
		
		# Initialize dynamic map secret parameter entry
		var parameter_entry_secret_type_count_max := _map_parameter_entry.instantiate()
		map_secret_settings_container.add_child(parameter_entry_secret_type_count_max)
		parameter_entry_secret_type_count_max.initialize_secret_type_count_max(secret_room_type_kind)
		
		# Set node custom node name
		var secret_room_type_id = GameData.room_secret_types.get_type(secret_room_type_kind).get_id()
		parameter_entry_secret_type_count_max.name = "%s (%s_%s)" % [
			parameter_entry_secret_type_count_max.get_script().get_global_name(),
			"count_max",
			secret_room_type_id,
		]


func _refresh_drawer_layout() -> void:
	# Check if node was already initialized
	if not is_node_ready():
		return
	
	# Check if any tween is running and kill it if it does
	if _drawer_tween:
		_drawer_tween.kill()
	
	# Set base drawer scale
	drawer_root.scale = Vector2.ONE
	
	# Calculate total_height
	var natural_panel_size := _get_natural_drawer_size()
	var strip_size := drawer_strip.get_combined_minimum_size()
	var natural_total_height := natural_panel_size.y + strip_size.y
	
	# Update drawer collapsed visible width
	_drawer_collapsed_visible_width = _calculate_collapsed_visible_width()
	
	# Calculate effective drawer scale
	_drawer_effective_ui_scale = _calculate_ui_scale(natural_total_height)
	
	# Apply scroll fallback if the height too big to fit into base drawer scale
	_apply_scroll_fallback(natural_panel_size, strip_size)
	
	# Position DrawerStrip directly under DrawerPanel and DrawerScrollBar next to it
	_position_drawer_strip()
	_position_drawer_scroll_bar()
	
	# Set calculated effective drawer scale
	drawer_root.scale = Vector2.ONE * float(_drawer_effective_ui_scale)
	
	# Position DrawerRoot based on the drawer scale
	_position_drawer_root()
	
	# Initialize drawer state to be instantly set according to the parameters
	_set_drawer_open(_drawer_open, true)


func _on_drawer_toggle_button_pressed() -> void:
	_set_drawer_open(not _drawer_open)
	
	# Emit signal that map parameters submenu was opened
	GameState.map_parameters_submenu_opened.emit()


func _set_drawer_open(open: bool, instant: bool = false) -> void:
	# Set drawer status
	_drawer_open = open
	
	# Check if any tween is running and kill if it does
	if _drawer_tween:
		_drawer_tween.kill()
	
	# Calculate target position
	var target_position := Vector2(
		_get_drawer_target_x(), 
		0.0,
	)
	
	# Set target position for drawer
	if instant:
		drawer_panel.position = target_position
	else:
		_drawer_tween = create_tween()
		_drawer_tween.set_trans(Tween.TRANS_QUAD)
		_drawer_tween.set_ease(Tween.EASE_OUT)
		_drawer_tween.tween_property(drawer_panel, "position", target_position, drawer_slide_duration)
	
	# Update drawer toggle button state
	_update_drawer_toggle_button()


func _get_drawer_target_x() -> float:
	# If drawer is open, return 0 size x offset
	if _drawer_open:
		return 0.0
	
	# If drawer is closed, return size x offset of the drawer that should be hidden from the view
	return maxf(0.0, drawer_panel.size.x - _drawer_collapsed_visible_width)


func _update_drawer_toggle_button() -> void:
	# Change drawer toggle button text and icon based on the drawer open status
	if _drawer_open:
		drawer_toggle_button.text = "▶"
		drawer_toggle_button.icon = drawer_toggle_collapse_icon
	else:
		drawer_toggle_button.text = "◀"
		drawer_toggle_button.icon = drawer_toggle_expand_icon


func _on_control_resized() -> void:
	call_deferred("_refresh_drawer_layout")


func _calculate_ui_scale(total_height_1x: float) -> int:
	# Calculate drawer height
	var available_height := size.y - drawer_screen_vertical_margin * 2.0
	
	# Get drawer minimum ui scale
	var drawer_minimum_scale := mini(drawer_minimum_ui_scale, drawer_preferred_ui_scale)
	
	# Check which biggest ui scale would fit the calculated drawer height after scaling it up
	for scale_candidate in range(drawer_preferred_ui_scale, drawer_minimum_scale - 1, -1):
		if total_height_1x * scale_candidate <= available_height:
			return scale_candidate
	
	# Return fallback ui scale value
	return drawer_minimum_scale


func _get_natural_drawer_size() -> Vector2:
	# Remove any width previously forced by this function.
	drawer_panel.custom_minimum_size.x = 0.0
	
	# Check drawer content size based on the set minimum sizes on it's elements
	var content_size := drawer_contents.get_combined_minimum_size()
	
	# By default disable vertical scrolling by assigning it content height size
	scroll_container.custom_minimum_size.y = content_size.y
	
	# Reset drawer panel size in order for it to adjust to just set minimum sizes
	drawer_panel.reset_size()
	
	# Get drawer natural width and add the drawer width offset to it
	var natural_width := drawer_panel.get_combined_minimum_size().x
	drawer_panel.custom_minimum_size.x = natural_width + drawer_width_offset
	
	# Reset drawer panel size in order for it to adjust to just set minimum sizes 
	drawer_panel.reset_size()
	
	return drawer_panel.get_combined_minimum_size()


func _apply_scroll_fallback(natural_panel_size: Vector2, strip_size: Vector2) -> void:
	# Calculate max_panel_height
	var available_height_1x := (size.y - drawer_screen_vertical_margin * 2.0) / float(_drawer_effective_ui_scale)
	var max_panel_height := available_height_1x - strip_size.y
	
	# If content fits inside max_panel_height, then don't enable scroll behaviour
	if natural_panel_size.y <= max_panel_height:
		scroll_container.custom_minimum_size.y = drawer_contents.get_combined_minimum_size().y
		
		drawer_panel.reset_size()
		return
	
	# Calculate scroll height based on the overflowed size
	var overflow := natural_panel_size.y - max_panel_height
	var current_scroll_height := scroll_container.custom_minimum_size.y
	
	# Apply minimum size equal to panel height minus overflow
	scroll_container.custom_minimum_size.y = maxf(1.0, current_scroll_height - overflow)
	
	# Set drawer_panel size to fit max_panel_height
	drawer_panel.size = Vector2(
		natural_panel_size.x,
		max_panel_height,
	)


func _position_drawer_strip() -> void:
	# Reset DrawerStrip size, so that it could adjust itself based on the set scale
	drawer_strip.reset_size()
	
	# Adjust DrawerStrip position based on the DrawerPanel size
	drawer_strip.position = Vector2(
		drawer_panel.size.x - drawer_strip.size.x,
		drawer_panel.size.y,
	)


func _position_drawer_scroll_bar() -> void:
	# Adjust DrawerScrollBar position based on the DrawerPanel position
	drawer_scroll_bar.position = Vector2(
		drawer_panel.size.x - drawer_scroll_bar.size.x,
		0.0
	)
	
	# Set DrawerScrollBar size appropriate to the DrawerPanel size
	drawer_scroll_bar.size.y = drawer_panel.size.y


func _update_drawer_scroll_bar_visibility() -> void:
	# Set DrawerScrollBar visible if the ScrollContainer scrollbar is active and visible
	var internal_scroll_bar := scroll_container.get_v_scroll_bar()
	drawer_scroll_bar.visible = internal_scroll_bar.max_value > internal_scroll_bar.page


func _position_drawer_root() -> void:
	# Calculate total height of drawer_root
	var scale_factor := float(_drawer_effective_ui_scale)
	var total_height := drawer_panel.size.y + drawer_strip.size.y
	
	# Adjust drawer root position
	drawer_root.position = Vector2(
		-drawer_panel.size.x * scale_factor,
		-total_height * scale_factor * 0.5,
	)


func _calculate_collapsed_visible_width() -> float:
	# Prepare initial variables
	var collapsed_width := 0.0
	var panel_left := drawer_panel.get_global_rect().position.x
	
	# Check all map parameter entries visible width
	var entry_containers: Array[VBoxContainer] = [
		map_grid_settings_container,
		map_secret_settings_container,
	]
	for entry_container in entry_containers:
		for child in entry_container.get_children():
			# Ignore child if it's not map parameter entry
			if child is not MapParameterEntry:
				continue
			
			# Get last visible node from the map parameter entry that should be visible when drawer closed
			var parameter_entry := child as MapParameterEntry
			var count_label = parameter_entry.get_node("CountLabel") as Label
			
			# Calculate visible width from drawer start to end on the last visible node
			var count_right := count_label.get_global_rect().end.x
			var entry_visible_width := count_right - panel_left
			
			# Save the biggest calculated visible width
			collapsed_width = maxf(
				collapsed_width,
				entry_visible_width,
			)
	
	# Return calculated collapsed width with added drawer collapsed width offset to it
	return collapsed_width + drawer_collapsed_width_offset


func open_drawer() -> void:
	if not _drawer_open:
		_set_drawer_open(not _drawer_open)


func close_drawer() -> void:
	if _drawer_open:
		_set_drawer_open(not _drawer_open)


func _on_other_menu_submenu_opened() -> void:
	close_drawer()
