class_name RoomEditorRadialMenu
extends RadialMenu


signal outside_click_menu_closed
signal inside_click_menu_closed

signal after_menu_opened
signal after_menu_closed
signal after_submenu_opened
signal after_submenu_closed

signal selection_changed(item)


enum SubmenuAngleMode {
	ALIGN_TO_PARENT,
	FIXED,
}


var submenu_angle_mode: SubmenuAngleMode = SubmenuAngleMode.ALIGN_TO_PARENT
var fixed_center_angle := -PI / 2.0


# Overloaded from RadialMenu
func _handle_mouse_buttons(event) -> void:
	# Changed from the orig: Removed mouse wheel action detection
	# Chagned from the orig: Mapped input event action to match the one set in the project input settings
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


# Overloaded from RadialMenu
func _on_submenu_item_selected(id, position) -> void:
	var submenu = get_open_submenu()
	
	# Changed from the orig: Removed code responsible for automated closing of the radial menu after selecting any option 
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
func calc_move_to_fit(submenu: Variant):
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
		var scale = submenu.offset_transform_scale.x
		var visual_radius = submenu.radius * scale
		var center_phase := fposmod(moved_to_position.x, 1.0)
		visual_radius = roundf(visual_radius - center_phase) + center_phase
		submenu.radius = visual_radius / scale
	
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
	if selected == -1 or selected == active_submenu_idx:
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
	
	# Changed from the orig: Connected custom selection_changed signal
	if submenu is RoomEditorRadialMenu:
		submenu.selection_changed.connect(_on_submenu_selection_changed)


# Overloaded from RadialMenu
func _disconnect_submenu_signals(submenu: RadialMenu):
	# Changed from the orig: Disconnected custom selection_changed signal
	if submenu is RoomEditorRadialMenu:
		submenu.selection_changed.disconnect(_on_submenu_selection_changed)
	
	super._disconnect_submenu_signals(submenu)


func _on_submenu_selection_changed(item: Variant) -> void:
	selection_changed.emit(item)
