class_name SmoothScrollBar
extends ScrollBar


## How quickly the scroll bar approaches its target in scroll bar units per frame.
@export_range(1.0, 50.0, 0.5)
var smooth_speed: float = 8.0
## Distance moved by one wheel step in scroll bar units.
@export var wheel_scroll_amount: float = -1.0
## Minimum scroll speed in one scroll bar unit per second that will be used during scrolling animation easing.
@export_range(0.0, 500.0, 1.0)
var minimum_scroll_speed: float = 60.0


var _smooth_scroll_logic: SmoothScrollLogic


func _ready() -> void:
	# Initialize smooth scroll logic script instance and sync current class instance parameters to it.
	_smooth_scroll_logic = SmoothScrollLogic.new(self)
	_update_smooth_scroll_settings()
	
	# Connect value changed signal to trigger when the value is changed internally or externally by some other script.
	value_changed.connect(_on_value_changed)
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Handles mouse wheel scroll inputs.
func _gui_input(event: InputEvent) -> void:
	# Filter out processing if the input event isn't an mouse button event.
	if not event is InputEventMouseButton:
		return
	
	# Filter out processing if the input event pressed status is false.
	if not event.pressed:
		return
	
	# Calculate scroll direction based on the mouse button wheel button action.
	var direction := 0.0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			direction = -1.0
		MOUSE_BUTTON_WHEEL_DOWN:
			direction = 1.0
		_:
			return
	
	# Handle scroll input and apply it to the scroll bar.
	scroll_wheel(direction, event.factor)
	
	# Stop propagating the wheel handling to ScrollBar default implementation.
	accept_event()


## Handles managing the smooth scroll movement every frame.
func _process(delta: float) -> void:
	# Propagate call to the smooth scroll logic.
	_smooth_scroll_logic.process(delta)
	
	# Stop processing smooth scrolling if the active status on the smooth scroll logic in no longer active.
	if not _smooth_scroll_logic.active:
		set_process(false)


## Modifies target value on scroll bar based on the scroll wheel movement and triggers smooth scrolling processing.
func scroll_wheel(direction: float, factor: float = 1.0) -> void:
	# Propagate call to the smooth scroll logic.
	_smooth_scroll_logic.scroll_wheel(direction, factor)
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Modifies target value on scroll bar by a given amount and triggers smooth scrolling processing.
func smooth_scroll_by(amount: float) -> void:
	# Propagate call to the smooth scroll logic.
	_smooth_scroll_logic.smooth_scroll_by(amount)
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Modifies target value on scroll bar by setting a new value to it and triggers smooth scrolling processing.
func smooth_scroll_to(new_value: float) -> void:
	# Propagate call to the smooth scroll logic.
	_smooth_scroll_logic.smooth_scroll_to(new_value)
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Handle value changed signal if the scroll bar value was changed internally or externally.
func _on_value_changed(new_value: float) -> void:
	# Filter out processing if the value is being changed internally by the scroll bar itself and not by external source.
	_smooth_scroll_logic.handle_value_changed(new_value)
	
	# Disable smooth scrolling processing.
	if not _smooth_scroll_logic.active:
		set_process(false)


## Sync current class instance parameters into the smooth scroll logic instance.
func _update_smooth_scroll_settings() -> void:
	_smooth_scroll_logic.smooth_speed = smooth_speed
	_smooth_scroll_logic.wheel_scroll_amount = wheel_scroll_amount
	_smooth_scroll_logic.minimum_scroll_speed = minimum_scroll_speed
