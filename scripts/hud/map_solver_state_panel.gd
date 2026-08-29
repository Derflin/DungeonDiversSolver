class_name MapSolverStatePanel
extends PanelContainer


var _animation: Tween


@onready var state_label: Label = $MarginContainer/StateContainer/StateLabel
@onready var state_icon: TextureRect = $MarginContainer/StateContainer/StateIcon
@onready var state_room_type_label: Label = $MarginContainer/StateContainer/StateRoomTypeLabel


@export_group("Animation", "animation_")
@export var animation_enabled: bool = true
@export_range(0.0, 1.0, 0.01)
var animation_show_duration: float = 0.12
@export_range(0.0, 1.0, 0.01)
var animation_hide_duration: float = 0.12


func _ready() -> void:
	# Initialize initial state
	hide()
	modulate.a = 0.0


func show_state_panel(state_text: String, state_icon_texture: Texture, state_room_type_text: String) -> void:
	# Initialize state panel data
	state_label.text = state_text
	state_icon.texture = state_icon_texture
	state_room_type_label.text = state_room_type_text
	
	# Filter out processing if the state panel is already visible
	if visible:
		return
	
	# Show state panel
	show()
	
	# Stop existing animation
	_kill_state_animation()
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		modulate.a = 1.0
		return
	
	# Initialize animation with animated opacity transition
	_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(self, "modulate:a", 1.0, animation_show_duration)


func hide_state_panel() -> void:
	# Filter out processing if the state panel is already hidden
	if not visible:
		return
	
	# Stop existing animation
	_kill_state_animation()
	
	# If animation is disabled, then simply set the desired state
	if not animation_enabled:
		_on_hide_animation_finished()
		return
	
	# Initialize animation with animated opacity transition
	_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(self, "modulate:a", 0.0, animation_hide_duration)
	
	# Prepare signal connection after animation ends to finalize hiding submenu
	if _animation != null and _animation.is_valid():
		_animation.finished.connect(_on_hide_animation_finished)


func _on_hide_animation_finished() -> void:
	# Hide submenu panel and set it's state
	hide()
	modulate.a = 0.0


func _kill_state_animation() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	
	_animation = null
