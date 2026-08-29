class_name MapSolverDropdown
extends Button


signal option_selected(option_id: int)


const OPTION_SCENE: PackedScene = preload("res://scenes/hud/map_solver_dropdown_option.tscn")


var selected_option_id: int = -1
var _option_texts: Dictionary = {}
var _option_icons: Dictionary = {}
var _submenu_rest_position: Vector2
var _animation: Tween


@onready var submenu_panel: PanelContainer = %SubmenuPanel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var options_list: VBoxContainer = %OptionsList


@export_group("Submenu", "submenu_")
@export var submenu_gap: float = 2.0
@export var submenu_min_width: float = 0.0
@export var submenu_close_on_selection: bool = true

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
	
	# If no animation is active, then set the submenu panel position directly
	if _animation == null or not _animation.is_valid():
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
	
	# Show submenu
	submenu_panel.show()
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		submenu_panel.position = _submenu_rest_position
		submenu_panel.modulate.a = 1.0
		return
	
	# Prepare submenu panel initial position before animation starts
	submenu_panel.position = _submenu_rest_position - Vector2(0.0, animation_slide_distance)
	submenu_panel.modulate.a = 0.0
	
	# Initialize animation with animated position and opacity transitions
	_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(submenu_panel, "position", _submenu_rest_position, animation_open_duration)
	_animation.tween_property(submenu_panel, "modulate:a", 1.0, animation_open_duration)


#TODO: add comments
func _hide_submenu() -> void:
	# Filter out processing if the submenu panel is not visible
	if not submenu_panel.visible:
		return
	
	# Reset show/hide state of the submenu
	_kill_animation()
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		submenu_panel.hide()
		submenu_panel.position = _submenu_rest_position
		submenu_panel.modulate.a = 1.0
		return
	
	# Calculate submenu target position after animation end
	var target_position = _submenu_rest_position - Vector2(0.0, animation_slide_distance)
	
	# Initialize animation with animated position and opacity transitions
	_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(submenu_panel, "position", target_position, animation_close_duration)
	_animation.tween_property(submenu_panel, "modulate:a", 0.0, animation_close_duration)
	
	# Prepare signal connection after animation ends to finalize hiding submenu
	_animation.finished.connect(_on_close_animation_finished)


func _on_close_animation_finished() -> void:
	# Filter out processing if button is pressed and the submenu is supposed to be visible
	if button_pressed:
		return
	
	# Hide submenu panel and set it's state
	submenu_panel.hide()
	submenu_panel.position = _submenu_rest_position
	submenu_panel.modulate.a = 1.0


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
