class_name SmoothScrollContainer
extends ScrollContainer


## Links a SmoothScrollBar instance for vertical scroll bar to be managed by this instance.
@export var smooth_v_scroll_bar: SmoothScrollBar = null
## Links a SmoothScrollBar instance for horizontal scroll bar to be managed by this instance.
@export var smooth_h_scroll_bar: SmoothScrollBar = null
## Allow to change default up/down scroll wheel movement affecting vertical scroll bar by holding shift, which causes it to affect the horizontal scroll.
@export var shift_wheel_scrolls_horizontally: bool = true

## How quickly the scroll bar approaches its target in scroll bar units per frame.
@export_range(1.0, 50.0, 0.5)
var smooth_speed: float = 8.0
## Distance moved by one wheel step in scroll bar units.
@export var wheel_scroll_amount: float = -1.0
## Minimum scroll speed in one scroll bar unit per second that will be used during scrolling animation easing.
@export_range(0.0, 500.0, 1.0)
var minimum_scroll_speed: float = 60.0


var _smooth_v_scroll_logic: SmoothScrollLogic
var _smooth_h_scroll_logic: SmoothScrollLogic


func _ready() -> void:
	# Initialize smooth scroll logic script instances for the internal built-in scroll container scroll bars. 
	_smooth_v_scroll_logic = SmoothScrollLogic.new(get_v_scroll_bar())
	_smooth_h_scroll_logic = SmoothScrollLogic.new(get_h_scroll_bar())
	
	# Sync current class instance parameters to the initialized smooth scroll logic script instances.
	_update_smooth_scroll_settings()
	
	# Connect value changed signals from the internal built-in scroll container scroll bars.
	get_v_scroll_bar().value_changed.connect(_on_v_scroll_bar_value_changed)
	get_h_scroll_bar().value_changed.connect(_on_h_scroll_bar_value_changed)
	
	# Disable smooth scrolling processing.
	set_process(false)


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


## Handles managing the smooth scroll movement every frame for the built-in scroll container scroll bars if the smooth scroll bars aren't assigned in this instance.
func _process(delta: float) -> void:
	var processing := false
	
	# Manage internal vertical scroll bar logic instance if the smooth vertical scroll bar isn't assigned in this instance.
	if smooth_v_scroll_bar == null:
		_smooth_v_scroll_logic.process(delta)
		
		if _smooth_v_scroll_logic.active:
			processing = true
	
	# Manage internal horizontal scroll bar logic instance if the smooth horizontal scroll bar isn't assigned in this instance.
	if smooth_h_scroll_bar == null:
		_smooth_h_scroll_logic.process(delta)
		
		if _smooth_h_scroll_logic.active:
			processing = true
	
	# Set processing state.
	set_process(processing)


## Handle syncing vertical scroll bar change by calling it if it was assigned.
func _scroll_vertical(direction: float, factor: float) -> void:
	# Handle internal vertical scroll bar processing if the smooth vertical scroll bar wasn't assigned.
	if smooth_v_scroll_bar == null:
		# Propagate call to the smooth scroll logic.
		_smooth_v_scroll_logic.scroll_wheel(direction, factor)
		
		# Trigger smooth scrolling processing.
		set_process(true)
		
		return
	
	# Handle scroll bar movement through the assigned vertical scroll bar.
	smooth_v_scroll_bar.scroll_wheel(direction, factor)


## Handle syncing horizontal scroll bar change by calling it if it was assigned.
func _scroll_horizontal(direction: float, factor: float) -> void:
	# Filter out processing if the horizontal scroll bar wasn't assigned.
	if smooth_h_scroll_bar == null:
		# Propagate call to the smooth scroll logic.
		_smooth_h_scroll_logic.scroll_wheel(direction, factor)
		
		# Trigger smooth scrolling processing.
		set_process(true)
		
		return
	
	# Handle scroll bar movement through the assigned horizontal scroll bar.
	smooth_h_scroll_bar.scroll_wheel(direction, factor)


## Handle value changed signal if the internal scroll container vertical scroll bar value was changed internally or externally.
func _on_v_scroll_bar_value_changed(new_value: float) -> void:
	_smooth_v_scroll_logic.handle_value_changed(new_value)


## Handle value changed signal if the internal scroll container horizontal scroll bar value was changed internally or externally.
func _on_h_scroll_bar_value_changed(new_value: float) -> void:
	_smooth_h_scroll_logic.handle_value_changed(new_value)


## Sync current class instance parameters into the smooth scroll logic instances for the built-in scroll container scroll bars.
func _update_smooth_scroll_settings() -> void:
	_smooth_v_scroll_logic.smooth_speed = smooth_speed
	_smooth_v_scroll_logic.wheel_scroll_amount = wheel_scroll_amount
	_smooth_v_scroll_logic.minimum_scroll_speed = minimum_scroll_speed
	
	_smooth_h_scroll_logic.smooth_speed = smooth_speed
	_smooth_h_scroll_logic.wheel_scroll_amount = wheel_scroll_amount
	_smooth_h_scroll_logic.minimum_scroll_speed = minimum_scroll_speed
