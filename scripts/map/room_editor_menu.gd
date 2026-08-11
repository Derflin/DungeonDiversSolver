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
# Changed from the orig: Changed default check for open submenu hovered status in order to keep the opened submenu always highlighted unless when it would be closed
func get_selected_by_mouse(check_open_submenu_hover: bool = false) -> int:
	if has_open_submenu():
		if not check_open_submenu_hover:
			return active_submenu_idx
		
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


# Changed from the orig: Changed center_angle parameter assignment, so that it would allow different button placement in submenus
func open_submenu(submenu, idx):
	active_submenu_idx = idx
	last_selected_submenu_idx = -1
	queue_redraw()
	
	var ring_width = submenu.get_total_ring_width()
	
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

# Changed from the orig: Added get_selected_by_mouse true flag to preserve original selection when the submenu is closed, so that the custom always highlighted submenu option wouldn't conflict with this function 
func _on_submenu_cancelled():
	var submenu = get_open_submenu()
	_disconnect_submenu_signals(submenu)
	
	set_selected_item(get_selected_by_mouse(true))
	if selected == -1 or selected == active_submenu_idx:
		get_viewport().set_input_as_handled()
	
	active_submenu_idx = -1
	queue_redraw()
	
	# Changed from the orig: Added custom signal
	after_submenu_closed.emit()


# Changed from the orig: Added selection_changed signal emitters
func set_selected_item(itemidx):
	if selected == itemidx:
		return

	selected = itemidx
	if selected >= 0 and selected < menu_items.size():
		item_hovered.emit(menu_items[selected])
		selection_changed.emit(menu_items[selected])
	else:
		selection_changed.emit(null)

	queue_redraw()


func open_menu(center_position: Vector2) -> void:
	super.open_menu(center_position)
	
	# Changed from the orig: Added custom signal
	after_menu_opened.emit()


func close_menu():
	super.close_menu()
	
	# Changed from the orig: Added custom signal
	after_menu_closed.emit()


func _connect_submenu_signals(submenu : RadialMenu):
	super._connect_submenu_signals(submenu)
	
	# Changed from the orig: Connected custom selection_changed signal
	if submenu is RoomEditorRadialMenu:
		submenu.selection_changed.connect(_on_submenu_selection_changed)


func _disconnect_submenu_signals(submenu: RadialMenu):
	# Changed from the orig: Disconnected custom selection_changed signal
	if submenu is RoomEditorRadialMenu:
		submenu.selection_changed.disconnect(_on_submenu_selection_changed)
	
	super._disconnect_submenu_signals(submenu)


func _on_submenu_selection_changed(item) -> void:
	selection_changed.emit(item)
