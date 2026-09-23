class_name SmoothScrollBar
extends ScrollBar


## How quickly the scroll bar approaches its target in pixels per frame.
@export_range(1.0, 50.0, 0.5)
var smooth_speed: float = 8.0
## Distance moved by one wheel step in scroll bar units.
@export var wheel_scroll_amount: float = -1.0
## Minimum scroll speed in one scroll bar unit per second that will be used during scrolling animation easing.
@export_range(0.0, 500.0, 1.0)
var minimum_scroll_speed: float = 60.0


var target_value: float
var _changing_value_internally := false


func _ready() -> void:
	# Initialize target value to the current value on the scroll bar.
	target_value = value
	
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


## Handles calculating and managing the smooth scroll movement every frame.
func _process(delta: float) -> void:
	# Calculate difference between target value and current value.
	var difference := target_value - value
	
	# Finish processing if the calculated difference is less then set epsilon to minimize easing interpolation into infinity.
	if abs(difference) <= 0.01:
		_set_value_internally(target_value)
		set_process(false)
		return
	
	# Calculate scroll movement.
	var weight := 1.0 - exp(-smooth_speed * delta)
	var movement := difference * weight
	
	# Adjust scroll movement if it's slower than defined minimum movement.
	var minimum_movement := minimum_scroll_speed * delta
	if abs(movement) < minimum_movement:
		movement = sign(difference) * minimum_movement
	
	# Make sure to not overshoot the remaining movement distance.
	if abs(movement) > abs(difference):
		movement = difference
	
	# Set calculated scroll value.
	_set_value_internally(
		value + movement
	)


## Modifies target value on scroll bar based on the scroll wheel movement and triggers smooth scrolling processing.
func scroll_wheel(direction: float, factor: float = 1.0) -> void:
	# Synchronize the target value with the current scroll bar value if scroll bar animation isn't being processed.
	if not is_processing():
		target_value = value
	
	# Adjust target value to include new scroll movement.
	target_value += direction * _get_wheel_scroll_amount() * factor
	target_value = clamp(target_value, min_value, get_max_scroll_value())
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Modifies target value on scroll bar by a given amount and triggers smooth scrolling processing.
func smooth_scroll_by(amount: float) -> void:
	# Synchronize the target value with the current scroll bar value if scroll bar animation isn't being processed.
	if not is_processing():
		target_value = value
	
	# Adjust target value to include modified scroll amount.
	target_value = clamp(target_value + amount, min_value, get_max_scroll_value())
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Modifies target value on scroll bar by setting a new value to it and triggers smooth scrolling processing.
func smooth_scroll_to(new_value: float) -> void:
	# Adjust target value to include modified scroll amount.
	target_value = clamp(new_value, min_value, get_max_scroll_value())
	
	# Trigger smooth scrolling processing.
	set_process(true)


## Returns mouse wheel scroll amount based on the scroll bar parameters.
func _get_wheel_scroll_amount() -> float:
	if wheel_scroll_amount >= 0.0:
		return wheel_scroll_amount
	
	if page > 0.0:
		return page / 8.0
	
	return (max_value - min_value) / 16.0


## Returns max scroll value based on the scroll bar parameters.
func get_max_scroll_value() -> float:
	return max(min_value, max_value - page)


## Sets a new value to a scroll bar value and during it marks it as being changed to prevent multiple sources changing it at the same time. 
func _set_value_internally(new_value: float) -> void:
	_changing_value_internally = true
	value = new_value
	_changing_value_internally = false


## Handle value changed signal if the scroll bar value was changed internally or externally.
func _on_value_changed(new_value: float) -> void:
	# Filter out processing if the value is being changed internally by the scroll bar itself and not by external source.
	if _changing_value_internally:
		return
	
	target_value = new_value
	
	# Disable smooth scrolling processing.
	set_process(false)
