class_name SmoothScrollContainer
extends ScrollContainer


## Links a SmoothScrollBar instance for vertical scroll bar to be managed by this instance.
@export var smooth_v_scroll_bar: SmoothScrollBar = null
## Links a SmoothScrollBar instance for horizontal scroll bar to be managed by this instance.
@export var smooth_h_scroll_bar: SmoothScrollBar = null
## Allow to change default up/down scroll wheel movement affecting vertical scroll bar by holding shift, which causes it to affect the horizontal scroll.
@export var shift_wheel_scrolls_horizontally: bool = true


## Handles mouse wheel scroll inputs.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	if not event.pressed:
		return
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if shift_wheel_scrolls_horizontally and event.shift_pressed:
				_scroll_horizontal(-1.0, event.factor)
			else:
				_scroll_vertical(-1.0, event.factor)
			
		MOUSE_BUTTON_WHEEL_DOWN:
			if shift_wheel_scrolls_horizontally and event.shift_pressed:
				_scroll_horizontal(1.0, event.factor)
			else:
				_scroll_vertical(1.0, event.factor)
			
		MOUSE_BUTTON_WHEEL_LEFT:
			_scroll_horizontal(-1.0, event.factor)
			
		MOUSE_BUTTON_WHEEL_RIGHT:
			_scroll_horizontal(1.0, event.factor)
			
		_:
			return
	
	# Stop propagating the wheel handling to ScrollContainer default implementation.
	accept_event()


## Handle syncing vertical scroll bar change by calling it if it was assigned.
func _scroll_vertical(direction: float, factor: float) -> void:
	# Filter out processing if the vertical scroll bar wasn't assigned.
	if smooth_v_scroll_bar == null:
		return
	
	# Handle scroll bar movement through the assigned vertical scroll bar.
	smooth_v_scroll_bar.scroll_wheel(direction, factor)

## Handle syncing horizontal scroll bar change by calling it if it was assigned.
func _scroll_horizontal(direction: float, factor: float) -> void:
	# Filter out processing if the horizontal scroll bar wasn't assigned.
	if smooth_h_scroll_bar == null:
		return
	
	# Handle scroll bar movement through the assigned horizontal scroll bar.
	smooth_h_scroll_bar.scroll_wheel(direction, factor)
