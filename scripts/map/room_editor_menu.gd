@tool
class_name RoomEditorRadialMenu
extends RadialMenu


## Signal is sent after a mouse click is detected outside of the opened menu.
signal outside_click_menu_closed
## Signal is sent after a mouse click is detected inside the opened menu in the center section.
signal inside_click_menu_closed

## Signal is sent after menu is opened and fully processed.
signal after_menu_opened
## Signal is sent after menu is closed and fully processed.
signal after_menu_closed
## Signal is sent after submenu is opened and fully processed.
signal after_submenu_opened
## Signal is sent after submenu is closed and fully processed.
signal after_submenu_closed

## Signal is sent when the selected item is changed. This includes item changed to null.
signal selection_changed(item)

## Signal is sent when a toggleable item is selected.
signal item_toggled(id, is_toggled, position)


enum SubmenuAngleMode {
	ALIGN_TO_PARENT,
	FIXED,
}


const RADIAL_MENU_INPUT_BLOCKER_GROUP: StringName = &"blocks_radial_menu_input"


var submenu_angle_mode: SubmenuAngleMode = SubmenuAngleMode.ALIGN_TO_PARENT
var fixed_center_angle := -PI / 2.0


# Overloaded from RadialMenu
func _input(event: InputEvent) -> void:
	# Changed from the orig: Added filter for mouse input events if mouse hovers over any nodes in the radial menu input blocker custom global group
	if event is InputEventMouse and _is_mouse_over_radial_menu_input_blocker():
		return
	
	_radial_input(event)


func _is_mouse_over_radial_menu_input_blocker() -> bool:
	# Get current deepest hovered controled node
	var hovered_control := get_viewport().gui_get_hovered_control()
	
	# Cast it into a Node variable
	var node: Node = hovered_control
	
	# Check if the current node or any of it's parents are set inside the radial menu input blocker custom global group
	while node != null:
		if node.is_in_group(RADIAL_MENU_INPUT_BLOCKER_GROUP):
			return true
		
		node = node.get_parent()
	
	return false


# Overloaded from RadialMenu
func _handle_mouse_buttons(event) -> void:
	# Changed from the orig: Removed mouse wheel action detection
	# Changed from the orig: Mapped input event action to match the one set in the project input settings
	if event.is_action_pressed("map_select"):
		if not is_submenu:
			get_viewport().set_input_as_handled()
		activate_selected()


# Overloaded from RadialMenu
func activate_selected() -> void:
	if selected != -1 and menu_items[selected].id is Control:
		open_submenu(menu_items[selected].id, selected)	
	else:	
		signal_id()	

	if selected == -1:
		close_menu()
		
		# Changed from the orig: Added custom signals based on the mouse clicked position from the center - used for detecting inner and outer clicks outside off the radial menu
		var mouse_position = get_local_mouse_position()
		var centered_mouse_position = mouse_position
		var distance_from_center = centered_mouse_position.distance_to(Vector2(radius, radius))
		if distance_from_center > radius:
			outside_click_menu_closed.emit()
		else:
			inside_click_menu_closed.emit()
		return
	
	# Changed from the orig: Added custom handle for custom toggleable actions
	var item: Dictionary = menu_items[selected]
	if item.get("toggleable", false):
		item["is_toggled"] = not item.get("is_toggled", false)
		
		queue_redraw()
		
		item_toggled.emit(item.id, item["is_toggled"], opened_at_position)
		return


# Overloaded from RadialMenu
func _on_submenu_item_selected(id, _position) -> void:	
	# Changed from the orig: Removed code responsible for automated closing of the radial menu after selecting any option 
	#var submenu = get_open_submenu()
	#_disconnect_submenu_signals(submenu)
	#active_submenu_idx = -1	
	#close_menu()
	
	item_selected.emit(id, opened_at_position)


# Overloaded from RadialMenu
func get_selected_by_mouse(check_open_submenu_hover: bool = false) -> int:
	if has_open_submenu():
		# Changed from the orig: Changed default check for open submenu hovered status in order to keep the opened submenu always highlighted unless when it would be closed
		if not check_open_submenu_hover:
			return active_submenu_idx
		
		if get_open_submenu().get_selected_by_mouse() != -1:
			# we don't change the selection while a submenu has a valid selection
			return active_submenu_idx
		
	var s = selected
	var mpos = get_local_mouse_position() - center_offset
	var lsq = mpos.length_squared()
	# Changed from the orig: Removed 400 limit from the "inner_limit" variable
	var inner_limit = (radius-width)*(radius-width)
	var outer_limit = (radius+width*outside_selection_factor)*(radius+width*outside_selection_factor)
	if is_submenu :
		inner_limit = pow(get_inner_outer()[0], 2)
	# make selection ring wider than the actual ring of items
	if lsq < inner_limit or lsq > outer_limit:
		# being outside the selection limit only cancels your selection if you've
		# moved the mouse outside since having made the selection...
		if has_left_center:
			s = -1
	else:
		has_left_center = true
		s = get_itemindex_from_vector(mpos)
	return s


# Overloaded from RadialMenu
func calc_move_to_fit(_submenu: Variant):
	# Changed from the orig: Removed entire calculation, since the radial menu is meant to be centered at a certain point without any adjustment to fit the screen
	return null


# Overloaded from RadialMenu
func open_submenu(submenu: Variant, idx: Variant):
	active_submenu_idx = idx
	last_selected_submenu_idx = -1
	queue_redraw()
	
	var ring_width = submenu.get_total_ring_width()
	
	# Changed from the orig: Changed center_angle parameter assignment, so that it would allow different button placement in submenus
	if submenu is RoomEditorRadialMenu and submenu.submenu_angle_mode == RoomEditorRadialMenu.SubmenuAngleMode.FIXED:
		submenu.center_angle = submenu.fixed_center_angle
	else:
		submenu.center_angle = center_angle - (menu_items.size()/2.0*item_angle) + idx * item_angle + item_angle/2.0
	
	submenu.decorator_ring_position = decorator_ring_position

	# Changed from the orig: Replaced submenu radius assignment, so that it would include proper radius calculation including the offset_transform parameters
	submenu.radius = radius + ring_width + gap_size * 2.0
	if submenu.offset_transform_enabled:
		var local_scale = submenu.offset_transform_scale.x
		var visual_radius = submenu.radius * local_scale
		var center_phase := fposmod(moved_to_position.x, 1.0)
		visual_radius = roundf(visual_radius - center_phase) + center_phase
		submenu.radius = visual_radius / local_scale
	
	submenu.center_radius = center_radius  # submenu needs this to determine whether to draw labels
	submenu.is_submenu = true
	submenu.position = moved_to_position - submenu.center_offset
			
	get_parent().add_child(submenu)
	_connect_submenu_signals(submenu)
	
	# Changed from the orig: Added custom signal
	after_submenu_opened.emit()
	
	# now make sure we have room to display the menu
	var move = calc_move_to_fit(submenu)
	if not move:
		submenu.open_menu(moved_to_position)
		return
	
	if show_animation:
		state = MenuState.moving
		set_tween("position", position+move)
	else: 
		moved_to_position += move
		position = moved_to_position - center_offset
		queue_redraw()
		submenu.open_menu(moved_to_position)


# Custom function called outside to set center_angle so that first element would be put centered at the top of the radial menu
func align_first_item_up() -> void:
	var count = menu_items.size()
	
	if count == 0:
		return
		
	var angle_per_item = TAU / count
	
	center_angle = PI / 2.0 - angle_per_item / 2.0


# Overloaded from RadialMenu
func _on_submenu_cancelled() -> void:
	var submenu = get_open_submenu()
	_disconnect_submenu_signals(submenu)
	
	# Changed from the orig: Added get_selected_by_mouse true flag to preserve original selection when the submenu is closed, so that the custom always highlighted submenu option wouldn't conflict with this function 
	set_selected_item(get_selected_by_mouse(true))
	# Changed from the orig: Removed conditional in order to stop submenu mouse selection to affect main menu during the process of closing the submenu
	get_viewport().set_input_as_handled()
	
	active_submenu_idx = -1
	queue_redraw()
	
	# Changed from the orig: Added custom signal
	after_submenu_closed.emit()


# Overloaded from RadialMenu
func set_selected_item(itemidx: Variant):
	if selected == itemidx:
		return

	# Changed from the orig: Added selection_changed signal emitters
	selected = itemidx
	if selected >= 0 and selected < menu_items.size():
		item_hovered.emit(menu_items[selected])
		selection_changed.emit(menu_items[selected])
	else:
		selection_changed.emit(null)

	queue_redraw()


# Overloaded from RadialMenu
func open_menu(center_position: Vector2) -> void:
	super.open_menu(center_position)
	
	# Changed from the orig: Added custom signal
	after_menu_opened.emit()


# Overloaded from RadialMenu
func close_menu():
	super.close_menu()
	
	# Changed from the orig: Added custom signal
	after_menu_closed.emit()


# Overloaded from RadialMenu
func _connect_submenu_signals(submenu : RadialMenu):
	super._connect_submenu_signals(submenu)
	
	# Changed from the orig: Connected custom selection_changed and item_toggled signals
	if submenu is RoomEditorRadialMenu:
		submenu.selection_changed.connect(_on_submenu_selection_changed)
		submenu.item_toggled.connect(_on_submenu_item_toggled)


# Overloaded from RadialMenu
func _disconnect_submenu_signals(submenu: RadialMenu):
	# Changed from the orig: Disconnected custom selection_changed and item_toggled signals
	if submenu is RoomEditorRadialMenu:
		submenu.selection_changed.disconnect(_on_submenu_selection_changed)
		submenu.item_toggled.disconnect(_on_submenu_item_toggled)
	
	super._disconnect_submenu_signals(submenu)


func _on_submenu_selection_changed(item: Variant) -> void:
	selection_changed.emit(item)


func _on_submenu_item_toggled(id, is_toggled, _position) -> void:
	item_toggled.emit(id, is_toggled, _position)


# Overloaded from RadialMenu
func _draw():
	var count = menu_items.size()	
	if item_angle*count > 2*PI:
		item_angle = 2*PI/count
					
	var start_angle = center_angle - item_angle * (count/2.0)
	
	var inout = get_inner_outer()
	var inner = inout[0]
	var outer = inout[1]
	
	var sw = _get_constant("StrokeWidth")
	
	# Draw the background for each menu item
	for i in range(count):			
		var coords = _calc_segment(inner, outer, start_angle+i*item_angle, start_angle+(i+1)*item_angle)		
		if i == selected: 
			Draw.draw_ring_segment(self, coords, _get_color("SelectedBackground"), _get_color("SelectedStroke"), sw, true)
		else:
			Draw.draw_ring_segment(self, coords, _get_color("Background"), _get_color("Stroke"), sw, true)

	var rw = _get_constant("DecoratorRingWidth")
	var ring_bg = _get_color("RingBackground")
	for i in range(count):
		# Changed from the orig: Added toggleable and is_toggled flags to the menu_items items
		var item: Dictionary = menu_items[i]
		if item.get("toggleable", false) and not item.get("is_toggled", false):
			continue
		
		# draw decorator ring segment
		if decorator_ring_position == Position.outside:	
			#var coords = Draw.calc_ring_segment(outer, outer + rw, start_angle, start_angle+count*item_angle, center_offset)					
			var coords = _calc_segment(outer, outer + rw, start_angle+i*item_angle, start_angle+(i+1)*item_angle)
			Draw.draw_ring_segment(self, coords, ring_bg, ring_bg, 1, true)
		elif decorator_ring_position == Position.inside:			
			#var coords = Draw.calc_ring_segment(inner-rw, inner, start_angle, start_angle+count*item_angle, center_offset)			
			var coords = _calc_segment(inner, inner-rw, start_angle+i*item_angle, start_angle+(i+1)*item_angle)
			Draw.draw_ring_segment(self, coords, ring_bg, ring_bg, 1, true)
			
	# draw selection ring segment
	if selected != -1 and not has_open_submenu():
		var selector_size = _get_constant("SelectorSegmentWidth")		
		var select_coords
		if selector_position == Position.outside:
			select_coords = _calc_segment(outer, outer+selector_size, start_angle+selected*item_angle, start_angle+(selected+1)*item_angle)
			Draw.draw_ring_segment(self, select_coords, _get_color("SelectorSegment"),_get_color("SelectorSegment"), 1, true)	
		elif selector_position == Position.inside:			
			select_coords = _calc_segment(inner-selector_size, inner, start_angle+selected*item_angle, start_angle+(selected+1)*item_angle)
			Draw.draw_ring_segment(self, select_coords, _get_color("SelectorSegment"), _get_color("SelectorSegment"), 1, true)	

	if center_radius != 0:
		_draw_center()
	
	if show_titles and (not has_open_submenu() or get_open_submenu().selected == -1):
		_draw_label()
	
	if DEBUG:
		_debug_draw()


func close_all_menus() -> void:
	active_submenu_idx = -1
	close_menu()
