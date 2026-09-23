class_name SmoothScrollLogic
extends RefCounted


## How quickly the scroll bar approaches its target in pixels per frame.
var smooth_speed: float = 8.0
## Distance moved by one wheel step in scroll bar units.
var wheel_scroll_amount: float = -1.0
## Minimum scroll speed in one scroll bar unit per second that will be used during scrolling animation easing.
var minimum_scroll_speed: float = 60.0


var scroll_bar: ScrollBar
var target_value: float
var active: bool = false
var _changing_value_internally := false


func _init(scroll_bar_instance: ScrollBar) -> void:
	scroll_bar = scroll_bar_instance
	
	# Initialize target value to the current value on the scroll bar.
	target_value = scroll_bar.value


## Handles calculating and managing the smooth scroll movement every frame.
func process(delta: float) -> void:
	# Filter out processing if the scroll bar animation isn't being processed.
	if not active:
		return
	
	# Calculate difference between target value and current value.
	var difference := target_value - scroll_bar.value
	
	# Finish processing if the calculated difference is less then set epsilon to minimize easing interpolation into infinity.
	if abs(difference) <= 0.01:
		_set_value_internally(target_value)
		active = false
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
		scroll_bar.value + movement
	)


## Modifies target value on scroll bar based on the scroll wheel movement and triggers smooth scrolling processing.
func scroll_wheel(direction: float, factor: float = 1.0) -> void:
	# Synchronize the target value with the current scroll bar value if scroll bar animation isn't being processed.
	if not active:
		target_value = scroll_bar.value
	
	# Adjust target value to include new scroll movement.
	target_value += direction * _get_wheel_scroll_amount() * factor
	target_value = clamp(target_value, scroll_bar.min_value, get_max_scroll_value())
	
	# Initialize scroll bar animation as it being processed and active.
	active = true


## Modifies target value on scroll bar by a given amount and triggers smooth scrolling processing.
func smooth_scroll_by(amount: float) -> void:
	# Synchronize the target value with the current scroll bar value if scroll bar animation isn't being processed.
	if not active:
		target_value = scroll_bar.value
	
	# Adjust target value to include modified scroll amount.
	target_value = clamp(target_value + amount, scroll_bar.min_value, get_max_scroll_value())
	
	# Initialize scroll bar animation as it being processed and active.
	active = true


## Modifies target value on scroll bar by setting a new value to it and triggers smooth scrolling processing.
func smooth_scroll_to(new_value: float) -> void:
	# Adjust target value to include modified scroll amount.
	target_value = clamp(new_value, scroll_bar.min_value, get_max_scroll_value())
	
	# Initialize scroll bar animation as it being processed and active.
	active = true


## Returns mouse wheel scroll amount based on the scroll bar parameters.
func _get_wheel_scroll_amount() -> float:
	if wheel_scroll_amount >= 0.0:
		return wheel_scroll_amount
	
	if scroll_bar.page > 0.0:
		return scroll_bar.page / 8.0
	
	return (scroll_bar.max_value - scroll_bar.min_value) / 16.0


## Returns max scroll value based on the scroll bar parameters.
func get_max_scroll_value() -> float:
	return max(scroll_bar.min_value, scroll_bar.max_value - scroll_bar.page)


## Sets a new value to a scroll bar value and during it marks it as being changed to prevent multiple sources changing it at the same time. 
func _set_value_internally(new_value: float) -> void:
	_changing_value_internally = true
	scroll_bar.value = new_value
	_changing_value_internally = false


## Handle value changed signal if the scroll bar value was changed internally or externally.
func handle_value_changed(new_value: float) -> void:
	# Filter out processing if the value is being changed internally by the scroll bar itself and not by external source.
	if _changing_value_internally:
		return
	
	target_value = new_value
	
	# Initialize scroll bar animation as it not being processed and active.
	active = false
