extends RadialMenu

signal outside_click_menu_closed
signal inside_click_menu_closed


func _ready() -> void:
	super()
	pass


func _handle_mouse_buttons(event):
	if event.is_action_pressed("map_select"):
		if not is_submenu:
			get_viewport().set_input_as_handled()
		activate_selected()


func activate_selected():	
	if selected != -1 and menu_items[selected].id is Control:
		open_submenu(menu_items[selected].id, selected)	
	else:	
		signal_id()	

	if selected == -1:
		close_menu()
		
		var mouse_position = get_local_mouse_position()
		var centered_mouse_position = mouse_position
		var distance_from_center = centered_mouse_position.distance_to(Vector2(radius, radius))
		
		if distance_from_center > radius:
			outside_click_menu_closed.emit()
		else:
			inside_click_menu_closed.emit()


func _on_submenu_item_selected(id, position):	
	var submenu = get_open_submenu()
	item_selected.emit(id, opened_at_position)


# Changed from the orig: Removed 400 limit from the "inner_limit" variable
func get_selected_by_mouse() -> int:
	if has_open_submenu():		
		if get_open_submenu().get_selected_by_mouse() != -1:
			# we don't change the selection while a submenu has a valid selection
			return active_submenu_idx
		
	var s = selected
	var mpos = get_local_mouse_position() - center_offset
	var lsq = mpos.length_squared()
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
