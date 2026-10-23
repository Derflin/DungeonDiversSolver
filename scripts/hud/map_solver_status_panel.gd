class_name MapSolverStatusPanel
extends PanelContainer


@export_group("Animation", "animation_")
@export var animation_enabled: bool = true
@export_range(0.0, 1.0, 0.01)
var animation_show_duration: float = 0.2
@export_range(0.0, 1.0, 0.01)
var animation_hide_duration: float = 0.2
@export_range(0.0, 1.0, 0.01)
var animation_resize_duration: float = 0.2


var _panel_animation: Tween

@onready var content_root: Control = $ContentRoot
@onready var margin_container: MarginContainer = $ContentRoot/MarginContainer
@onready var status_label: ScrambleLabel = $ContentRoot/MarginContainer/StatusContainer/StatusLabel


func _ready() -> void:
	# Initialize initial state
	hide()
	modulate.a = 0.0
	
	# Connect content changed signals to cause manual update propagation to content size
	status_label.minimum_size_changed.connect(_update_content_size)


func show_status_panel(status_text: String) -> void:
	# Stop existing animation
	_kill_panel_animation()
	
	# Calculate panel target width for animating it
	var target_size := _measure_target_size(status_text)
	
	# Show status panel or change it's state if it's already visible
	if not visible:
		_show_status(status_text, target_size)
	else:
		_change_status(status_text, target_size)


func _show_status(status_text: String, target_size: Vector2) -> void:
	# Show status panel
	show()
	
	# Initialize status panel data
	# Height of panel status is not animated, so it's also immediately assigned
	custom_minimum_size.y = target_size.y
	
	# Reset labels and texture rect content to empty
	status_label.set_text_immediate("")
	
	# If animation is disabled, then simply set the desired status
	if not animation_enabled:
		# Initialize status panel styles
		modulate.a = 1.0
		custom_minimum_size.x = target_size.x
		
		# Assign text to scramble labels without animations
		status_label.set_text_immediate(status_text)
		
		_update_content_size()
		return
	
	# Assign text to scramble labels
	status_label.change_text(status_text)
	
	# Initialize status panel styles before animation
	modulate.a = 0.0
	custom_minimum_size.x = _get_collapsed_width()
	
	# Initialize animation with animated opacity and size transition
	_panel_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_animation.tween_property(self, "modulate:a", 1.0, animation_show_duration)
	_panel_animation.tween_property(self, "custom_minimum_size:x", target_size.x, animation_resize_duration)


func _change_status(status_text: String, target_size: Vector2) -> void:
	# Initialize status panel data
	# Height of panel status is not animated, so it's also immediately assigned
	custom_minimum_size.y = target_size.y
	
	# If animation is disabled, then simply set the desired status
	if not animation_enabled:
		# Initialize status panel styles
		custom_minimum_size.x = target_size.x
		
		# Assign text to scramble labels without animations
		status_label.set_text_immediate(status_text)
		
		_update_content_size()
		return
	
	# Assign text to scramble labels
	status_label.change_text(status_text)
	
	# Initialize animation with animated opacity transition
	_panel_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_animation.tween_property(self, "custom_minimum_size:x", target_size.x, animation_resize_duration)


func hide_status_panel() -> void:
	# Filter out processing if the status panel is already hidden
	if not visible:
		return
	
	# Stop existing animation
	_kill_panel_animation()
	
	# Calculate collapsed width of the status panel
	var collapsed_target_width := _get_collapsed_width()
	
	# If animation is disabled, then simply set the desired status
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


func _measure_target_size(status_text: String) -> Vector2:
	# Gather previously used data
	var previous_status_text := status_label.text
	
	# Simulate putting new data
	status_label.text = status_text
	_update_content_size()
	
	# Calculate content width with simulated contents
	var content_size := margin_container.get_combined_minimum_size()
	var panel_style := get_theme_stylebox("panel")
	var panel_style_size := panel_style.get_minimum_size() if panel_style != null else Vector2.ZERO
	var target_size := content_size + panel_style_size
	
	# Restore old data before simulation
	status_label.text = previous_status_text
	_update_content_size()
	
	return target_size


func _update_content_size() -> void:
	# Required since ContentRoot control node doesn't propagate contents minimum sizes from MarginContainer node back to the PanelContainer above ContentRoot
	margin_container.reset_size()


func _get_collapsed_width() -> float:
	# Get status panel style
	var panel_style := get_theme_stylebox("panel")
	if panel_style == null:
		return 0.0
	
	# Return status panel minimum size from it's style
	return panel_style.get_minimum_size().x


func _kill_panel_animation() -> void:
	if _panel_animation != null and _panel_animation.is_valid():
		_panel_animation.kill()
	
	_panel_animation = null
