class_name RoomEditorRadialMenu
extends RadialMenu

signal outside_click_menu_closed
signal inside_click_menu_closed


func _ready() -> void:
	super()


func _handle_mouse_buttons(event) -> void:
	if event.is_action_pressed("map_select"):
		if not is_submenu:
			get_viewport().set_input_as_handled()
		activate_selected()


func activate_selected() -> void:
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


func _on_submenu_item_selected(id, position) -> void:
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


# Changed from the orig: Added custom assignment to the sub_rect variable to include offset transform params from object parameters
func calc_move_to_fit(submenu):
	var parent_size = get_parent_area_size()
	var parent_rect = Rect2(Vector2.ZERO, parent_size)
	
	var sub_rect: Rect2
	if submenu is RoomEditorRadialMenu:
		sub_rect = submenu.get_offset_transformed_rect()
	else:
		sub_rect = submenu.get_rect()
		
	return null
		
	if not parent_rect.encloses(sub_rect):
		var dx = 0
		var dy = 0
		if sub_rect.position.x + sub_rect.size.x > parent_size.x:
			dx = parent_size.x - sub_rect.position.x - sub_rect.size.x
		elif sub_rect.position.x < 0:
			dx = -sub_rect.position.x
		if sub_rect.position.y + sub_rect.size.y > parent_size.y:
			dy = parent_size.y - sub_rect.position.y - sub_rect.size.y
		elif sub_rect.position.y < 0:
			dy = -sub_rect.position.y
		return Vector2(dx, dy)
	else: 
		return null


# Custom function used inside "calc_move_to_fit" function
func get_offset_transformed_rect() -> Rect2:
	if not offset_transform_enabled:
		return get_rect()
		
	var menu_center = position + center_offset
	
	var local_min = -center_offset
	var local_max = size - center_offset
	
	var visual_min = local_min * offset_transform_scale
	var visual_max = local_max * offset_transform_scale
	
	return Rect2(
		menu_center + visual_min,
		visual_max - visual_min,
	)
