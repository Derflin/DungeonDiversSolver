extends RadialMenu

signal outside_click_menu_closed
signal inside_click_menu_closed


func _ready() -> void:
	super()
	pass


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
