class_name MapSolverDropdown
extends Button


signal option_selected(option_id: int)


const OPTION_SCENE: PackedScene = preload("res://scenes/hud/map_solver_dropdown_option.tscn")


var selected_option_id: int = -1
var _option_texts: Dictionary = {}
var _option_icons: Dictionary = {}
var _submenu_rest_position: Vector2
var _animation: Tween

var _submenu_original_parent: Node
var _submenu_is_in_overlay_container: bool = false
var _submenu_original_scale: Vector2


@onready var submenu_panel: PanelContainer = %SubmenuPanel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var options_list: VBoxContainer = %OptionsList


@export_group("Submenu", "submenu_")
@export var submenu_gap: float = 2.0
@export var submenu_min_width: float = 0.0
@export var submenu_close_on_selection: bool = true
## Used to reparent the SubmenuPanel node into itself when submenu would become visible. If null, the submenu will remain a child of this dropdown.
@export var submenu_overlay_container: Control = null

@export_group("Animation", "animation_")
@export var animation_enabled: bool = true
@export_range(0.0, 1.0, 0.01)
var animation_open_duration: float = 0.12
@export_range(0.0, 1.0, 0.01)
var animation_close_duration: float = 0.12
@export var animation_slide_distance: float = 8.0

@export_group("Selection", "selection_")
@export var copy_selected_text_to_button: bool = false
@export var copy_selected_icon_to_button: bool = false

@export_group("Scroll Container", "scroll_")
@export var scroll_bottom_screen_edge_offset: int = 20
@export var scroll_bar_vertical_width: float = 3.0


func _ready() -> void:
	# Initialize submenu panel state
	submenu_panel.hide()
	submenu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_submenu_original_parent = submenu_panel.get_parent()
	_submenu_original_scale = submenu_panel.get_scale()
	
	# Connect signals to manage submenu state and update it now and after every resized event signal detected
	resized.connect(_update_submenu_geometry)
	call_deferred("_update_submenu_geometry")


func _update_submenu_geometry() -> void:
	# Calculate submenu panel position
	_submenu_rest_position = Vector2(
		0.0,
		size.y + submenu_gap,
	)
	
	# Set submenu panel minimum width
	submenu_panel.custom_minimum_size.x = max(size.x, submenu_min_width)
	
	# If no animation is active and the submenu panel is not located inside the overlay container, then set the submenu panel position directly
	if not _submenu_is_in_overlay_container and (_animation == null or not _animation.is_valid()):
		submenu_panel.position = _submenu_rest_position
	
	# Initialize scroll container
	call_deferred("_initialize_scroll_container")


func _initialize_scroll_container() -> void:
	# Get effective container scale
	var effective_scale: Vector2 = get_global_transform().get_scale()
	
	# Calculate scroll container min height based on the option list contents and viewport height
	var scroll_container_max_height := (get_viewport_rect().size.y - _submenu_rest_position.y) / effective_scale.y - scroll_bottom_screen_edge_offset
	var options_list_height := options_list.size.y
	var scroll_container_minimum_height: float = min(scroll_container_max_height, options_list_height)
	
	# Assign calculated minimum height inside the scroll container
	scroll_container.custom_minimum_size.y = scroll_container_minimum_height
	
	# Hide vertical scroll when it's not necessary to display all the options list, otherwise restore it's base parameters
	var vertical_scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()
	if scroll_container_minimum_height > options_list_height:
		# Set custom vertical scroll bar width
		vertical_scrollbar.custom_minimum_size.x = 0.0
		vertical_scrollbar.custom_maximum_size.x = 0.0
	else:
		# Set custom veritcal scroll bar width
		vertical_scrollbar.custom_minimum_size.x = scroll_bar_vertical_width
		vertical_scrollbar.custom_maximum_size.x = scroll_bar_vertical_width
	
	# Force resetting size for submenu panel to adjust it to the changed vertical scrollbar
	submenu_panel.reset_size()

func clear_options() -> void:
	# Remove and free every child node listed inside options list
	for child in options_list.get_children():
		options_list.remove_child(child)
		child.queue_free()
	
	# Clear local variables holding data related to the option nodes listed in the options list
	_option_texts.clear()
	_option_icons.clear()
	
	# Set selected option to default unselected
	selected_option_id = -1


func add_option(option_id: int, option_text: String, option_icon: Texture2D = null, _is_disabled: bool = false) -> void:
	# Instantiate the option scene
	var option := OPTION_SCENE.instantiate() as MapSolverDropdownOption
	
	# Assign instantiated option scene as child to the options list
	options_list.add_child(option)
	
	# Initialize the option instance
	option.setup(option_id, option_text, option_icon, _is_disabled)
	
	# Connect selected signal from option to local function
	option.selected.connect(_on_option_selected)
	
	# Save option text and icon inside local parameters
	_option_texts[option_id] = option_text
	_option_icons[option_id] = option_icon


func _on_option_selected(option_id: int) -> void:
	# Save selected option
	selected_option_id = option_id
	
	# Set the option text as current button text
	if copy_selected_text_to_button:
		text = _option_texts.get(option_id, text)
	
	# Set the option icon as current button icon
	if copy_selected_icon_to_button:
		icon = _option_icons.get(option_id, icon)
	
	# Propagate option selected signal
	option_selected.emit(option_id)
	
	# Close submenu panel
	if submenu_close_on_selection:
		close_dropdown()


func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		_show_submenu()
	else:
		_hide_submenu()


func open_dropdown() -> void:
	if button_pressed:
		return
	
	button_pressed = true


func close_dropdown() -> void:
	if not button_pressed:
		return
	
	button_pressed = false


func is_dropdown_open() -> bool:
	return button_pressed


func _show_submenu() -> void:
	# Reset show/hide state of the submenu
	_kill_animation()
	_update_submenu_geometry()
	
	# Move submenu to overlay container and sync it's scale
	if submenu_overlay_container != null:
		_move_submenu_to_overlay_container()
		_sync_submenu_scale_with_overlay_container()
	
	# Show submenu
	submenu_panel.show()
	
	# Play submenu open animation
	play_submenu_open_animation()


func play_submenu_open_animation() -> void:
	# Use different animation based on the submenu overlay container parameter set up
	if submenu_overlay_container != null:
		# Prepare submenu position
		var submenu_target_position := _get_submenu_target_global_position()
		
		# If animation is disabled, then simply set the desired state
		if not animation_enabled:
			submenu_panel.global_position = submenu_target_position
			submenu_panel.modulate.a = 1.0
			return
		
		# Prepare submenu panel initial position before animation starts
		submenu_panel.global_position = submenu_target_position - Vector2(0.0, animation_slide_distance)
		submenu_panel.modulate.a = 0.0
		
		# Initialize animation with animated position and opacity transitions
		_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_animation.tween_property(submenu_panel, "global_position", submenu_target_position, animation_open_duration)
		_animation.tween_property(submenu_panel, "modulate:a", 1.0, animation_open_duration)
		
	else:
		# Prepare submenu position
		var submenu_target_position := _submenu_rest_position
		
		# If animation is disabled, then simply set the desired state
		if not animation_enabled:
			submenu_panel.position = submenu_target_position
			submenu_panel.modulate.a = 1.0
			return
		
		# Prepare submenu panel initial position before animation starts
		submenu_panel.position = submenu_target_position - Vector2(0.0, animation_slide_distance)
		submenu_panel.modulate.a = 0.0
		
		# Initialize animation with animated position and opacity transitions
		_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_animation.tween_property(submenu_panel, "position", submenu_target_position, animation_open_duration)
		_animation.tween_property(submenu_panel, "modulate:a", 1.0, animation_open_duration)


func _hide_submenu() -> void:
	# Filter out processing if the submenu panel is not visible
	if not submenu_panel.visible:
		return
	
	# Reset show/hide state of the submenu
	_kill_animation()
	
	# Play submenu close animation
	play_submenu_close_animation()
	
	# Prepare signal connection after animation ends to finalize hiding submenu
	if _animation != null and _animation.is_valid():
		_animation.finished.connect(_on_close_animation_finished)


func play_submenu_close_animation() -> void:
	# Use different animation based on the submenu overlay container parameter set up
	if submenu_overlay_container != null:
		# Prepare submenu position
		var submenu_target_position := _get_submenu_target_global_position()
		
		# If animation is disabled, then simply set the desired state
		if not animation_enabled:
			_on_close_animation_finished()
			return
		
		# Calculate submenu target position after animation end
		var target_position = submenu_target_position - Vector2(0.0, animation_slide_distance)
		
		# Initialize animation with animated position and opacity transitions
		_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_animation.tween_property(submenu_panel, "global_position", target_position, animation_close_duration)
		_animation.tween_property(submenu_panel, "modulate:a", 0.0, animation_close_duration)
		
	else:
		# Prepare submenu position
		var submenu_target_position := _submenu_rest_position
		
		# If animation is disabled, then simply set the desired state
		if not animation_enabled:
			_on_close_animation_finished()
			return
		
		# Calculate submenu target position after animation end
		var target_position = submenu_target_position - Vector2(0.0, animation_slide_distance)
		
		# Initialize animation with animated position and opacity transitions
		_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_animation.tween_property(submenu_panel, "position", target_position, animation_close_duration)
		_animation.tween_property(submenu_panel, "modulate:a", 0.0, animation_close_duration)


func _on_close_animation_finished() -> void:
	# Filter out processing if button is pressed and the submenu is supposed to be visible
	if button_pressed:
		return
	
	# Calculate submenu panel position based on the submenu overlay container parameter set up
	var submenu_target_position: Vector2
	if submenu_overlay_container != null:
		submenu_target_position = _get_submenu_target_global_position()
	else:
		submenu_target_position = _submenu_rest_position
	
	# Hide submenu panel and set it's state
	submenu_panel.hide()
	submenu_panel.position = submenu_target_position
	submenu_panel.modulate.a = 1.0
	
	# Move submenu from overlay container back to the dropdown
	if submenu_overlay_container != null:
		_return_submenu_from_overlay_container_to_dropdown()


func _kill_animation() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	
	_animation = null


func _input(event: InputEvent) -> void:
	if not is_dropdown_open():
		return
	
	# Handle UI close action to close the dropdown if event detected
	if event.is_action_pressed("ui_cancel"):
		close_dropdown()
		get_viewport().set_input_as_handled()
		return
	
	# Handle mouse events
	if event is InputEventMouseButton and event.pressed:
		# Get mouse position
		var mouse_position := get_viewport().get_mouse_position()
		
		# Detect if mouse position inside dropdown or inside dropdown submenu
		var inside_button := get_global_rect().has_point(mouse_position)
		var inside_submenu := submenu_panel.get_global_rect().has_point(mouse_position)
		
		# Check if mouse position outside dropdown and it's submenu, if yes then close dropdown
		if not inside_button and not inside_submenu:
			close_dropdown()


func _get_submenu_target_global_position() -> Vector2:
	# Get global dropdown rect
	var button_rect := get_global_rect()
	
	# Return submenu global position related to the dropdown rect
	return Vector2(button_rect.position.x, button_rect.end.y + submenu_gap)


func _move_submenu_to_overlay_container() -> void:
	# Filter out processing if the submenu overlay container parameter is unassigned
	if submenu_overlay_container == null:
		return
	
	# Filter out processing if the submenu is already located in the overlay container
	if _submenu_is_in_overlay_container:
		return
	
	# Calculate target global position where to place the submenu
	var target_global_position := _get_submenu_target_global_position()
	
	# Reparent submenu to overlay container
	submenu_panel.reparent(submenu_overlay_container, true)
	_submenu_is_in_overlay_container = true
	
	# Set the global position for submenu placed inside the overlay container
	submenu_panel.global_position = target_global_position


func _sync_submenu_scale_with_overlay_container() -> void:
	# Filter out processing if the submenu overlay container parameter is unassigned
	if submenu_overlay_container == null:
		submenu_panel.scale = _submenu_original_scale
		return
	
	# Get effective container dropdown and submenu overlay container scale
	var effective_scale: Vector2 = get_global_transform().get_scale()
	var overlay_container_effective_scale: Vector2 = submenu_overlay_container.get_global_transform().get_scale()
	
	# Filter out processing if both the current and overlay container scales are the same already
	if effective_scale == overlay_container_effective_scale:
		return
	
	# Calculate difference in scales and assign it to the submenu as local scale to compensate for the difference
	var scale_change_proportion := effective_scale / overlay_container_effective_scale
	submenu_panel.scale = scale_change_proportion


func _return_submenu_from_overlay_container_to_dropdown() -> void:
	# Filter out processing if the submenu overlay container parameter is unassigned
	if not _submenu_is_in_overlay_container:
		return
	
	# Reparent submenu from overlay container back to the dropdown
	submenu_panel.reparent(_submenu_original_parent)
	_submenu_is_in_overlay_container = false
	
	# Update submenu size and parameters to fit the dropdown again
	_update_submenu_geometry()
