class_name MapSolverStatePanel
extends PanelContainer


var _panel_animation: Tween
var _solver_label_static_text: String
var _first_separator_static_text: String
var _second_separator_static_text: String

@onready var content_root: Control = $ContentRoot
@onready var margin_container: MarginContainer = $ContentRoot/MarginContainer
@onready var solver_label: ScrambleLabel = $ContentRoot/MarginContainer/StateContainer/SolverLabel
@onready var first_separator_label: ScrambleLabel = $ContentRoot/MarginContainer/StateContainer/FirstSeparatorLabel
@onready var state_label: ScrambleLabel = $ContentRoot/MarginContainer/StateContainer/StateLabel
@onready var second_separator_label: ScrambleLabel = $ContentRoot/MarginContainer/StateContainer/SecondSeparatorLabel
@onready var state_icon: ScrambleTextureRect = $ContentRoot/MarginContainer/StateContainer/StateIcon
@onready var state_room_type_label: ScrambleLabel = $ContentRoot/MarginContainer/StateContainer/StateRoomTypeLabel


@export_group("Animation", "animation_")
@export var animation_enabled: bool = true
@export_range(0.0, 1.0, 0.01)
var animation_show_duration: float = 0.2
@export_range(0.0, 1.0, 0.01)
var animation_hide_duration: float = 0.2
@export_range(0.0, 1.0, 0.01)
var animation_resize_duration: float = 0.2


func _ready() -> void:
	# Initialize initial state
	hide()
	modulate.a = 0.0
	
	# Save initial text state for labels that are meant to display static texts
	_solver_label_static_text = solver_label.text
	_first_separator_static_text = first_separator_label.text
	_second_separator_static_text = second_separator_label.text
	
	# Connect content changed signals to cause manual update propagation to content size
	state_label.minimum_size_changed.connect(_update_content_size)
	state_icon.minimum_size_changed.connect(_update_content_size)
	state_room_type_label.minimum_size_changed.connect(_update_content_size)


func show_state_panel(state_text: String, state_icon_texture: Texture2D, state_room_type_text: String) -> void:
	# Stop existing animation
	_kill_panel_animation()
	
	# Calculate panel target width for animating it
	var target_size := _measure_target_size(state_text, state_icon_texture, state_room_type_text)
	
	# Show state panel or change it's state if it's already visible
	if not visible:
		_show_state(state_text, state_icon_texture, state_room_type_text, target_size)
	else:
		_change_state(state_text, state_icon_texture, state_room_type_text, target_size)


func _show_state(state_text: String, state_icon_texture: Texture2D, state_room_type_text: String, target_size: Vector2) -> void:
	# Show state panel
	show()
	
	# Initialize state panel data
	state_icon.texture = state_icon_texture
	# Height of panel state is not animated, so it's also immediately assigned
	custom_minimum_size.y = target_size.y
	
	# Reset labels and texture rect content to empty
	state_icon.set_texture_immediate(null)
	solver_label.set_text_immediate("")
	first_separator_label.set_text_immediate("")
	state_label.set_text_immediate("")
	second_separator_label.set_text_immediate("")
	state_room_type_label.set_text_immediate("")
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		# Initialize state panel styles
		modulate.a = 1.0
		custom_minimum_size.x = target_size.x
		
		# Assign icon to scramble texture rect without animations
		state_icon.set_texture_immediate(state_icon_texture)
		
		# Assign text to scramble labels without animations
		state_label.set_text_immediate(state_text)
		state_room_type_label.set_text_immediate(state_room_type_text)
		
		_update_content_size()
		return
	
	# Assign icon to scramble texture rect
	state_icon.change_texture(state_icon_texture)
	
	# Assign text to scramble labels
	solver_label.change_text(_solver_label_static_text)
	first_separator_label.change_text(_first_separator_static_text)
	state_label.change_text(state_text)
	second_separator_label.change_text(_second_separator_static_text)
	state_room_type_label.change_text(state_room_type_text)
	
	# Initialize state panel styles before animation
	modulate.a = 0.0
	custom_minimum_size.x = _get_collapsed_width()
	
	# Initialize animation with animated opacity and size transition
	_panel_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_animation.tween_property(self, "modulate:a", 1.0, animation_show_duration)
	_panel_animation.tween_property(self, "custom_minimum_size:x", target_size.x, animation_resize_duration)


func _change_state(state_text: String, state_icon_texture: Texture2D, state_room_type_text: String, target_size: Vector2) -> void:
	# Initialize state panel data
	# Height of panel state is not animated, so it's also immediately assigned
	custom_minimum_size.y = target_size.y
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		# Initialize state panel styles
		custom_minimum_size.x = target_size.x
		
		# Assign icon to scramble texture rect without animations
		state_icon.set_texture_immediate(state_icon_texture)
		
		# Assign text to scramble labels without animations
		state_label.set_text_immediate(state_text)
		state_room_type_label.set_text_immediate(state_room_type_text)
		
		_update_content_size()
		return
	
	# Assign icon to scramble texture rect
	state_icon.change_texture(state_icon_texture)
	
	# Assign text to scramble labels
	state_label.change_text(state_text)
	state_room_type_label.change_text(state_room_type_text)
	
	# Initialize animation with animated opacity transition
	_panel_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_animation.tween_property(self, "custom_minimum_size:x", target_size.x, animation_resize_duration)


func hide_state_panel() -> void:
	# Filter out processing if the state panel is already hidden
	if not visible:
		return
	
	# Stop existing animation
	_kill_panel_animation()
	
	# Calculate collapsed width of the state panel
	var collapsed_target_width := _get_collapsed_width()
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		_on_hide_animation_finished(collapsed_target_width)
		return
	
	# Initialize animation with animated opacity transition
	_panel_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_panel_animation.tween_property(self, "modulate:a", 0.0, animation_hide_duration)
	_panel_animation.tween_property(self, "custom_minimum_size:x", collapsed_target_width, animation_hide_duration)
	
	# Prepare signal connection after animation ends to finalize hiding submenu
	if _panel_animation != null and _panel_animation.is_valid():
		_panel_animation.finished.connect(_on_hide_animation_finished.bind(collapsed_target_width))


func _on_hide_animation_finished(target_width: float) -> void:
	# Hide submenu panel and set it's state
	hide()
	modulate.a = 0.0
	custom_minimum_size.x = target_width


func _measure_target_size(state_text: String, state_icon_texture: Texture2D, state_room_type_text: String) -> Vector2:
	# Gather previously used data
	var previous_state_text := state_label.text
	var previous_icon := state_icon.texture
	var previous_room_type_text := state_room_type_label.text
	
	# Simulate putting new data
	state_label.text = state_text
	state_icon.texture = state_icon_texture
	state_room_type_label.text = state_room_type_text
	_update_content_size()
	
	# Calculate content width with simulated contents
	var content_size := margin_container.get_combined_minimum_size()
	var panel_style := get_theme_stylebox("panel")
	var panel_style_size := panel_style.get_minimum_size() if panel_style != null else Vector2.ZERO
	var target_size := content_size + panel_style_size
	
	# Restore old data before simulation
	state_label.text = previous_state_text
	state_icon.texture = previous_icon
	state_room_type_label.text =  previous_room_type_text
	_update_content_size()
	
	return target_size


func _update_content_size() -> void:
	# Required since ContentRoot control node doesn't propagate contents minimum sizes from MarginContainer node back to the PanelContainer above ContentRoot
	margin_container.reset_size()


func _get_collapsed_width() -> float:
	# Get state panel style
	var panel_style := get_theme_stylebox("panel")
	if panel_style == null:
		return 0.0
	
	# Return state panel minimum size from it's style
	return panel_style.get_minimum_size().x


func _kill_panel_animation() -> void:
	if _panel_animation != null and _panel_animation.is_valid():
		_panel_animation.kill()
	
	_panel_animation = null
