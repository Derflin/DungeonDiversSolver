class_name SaveManagerControl
extends Control


const FIRST_PAGE: int = 1
const FIRST_SLOT: int = 1
const SLOTS_PER_PAGE: int = 5
const NAVIGATION_BUTTON_VARIATION: StringName = &"SaveNavigationButton"

@export var save_slot_entry_scene: PackedScene
@export var save_list_entry_scene: PackedScene

@export_group("Display Transitions", "transition_display_")
@export_range(0.01, 0.50, 0.01)
var transition_display_fade_out_duration: float = 0.27
@export_range(0.01, 0.50, 0.01)
var transition_display_fade_in_duration: float = 0.30

@export_group("Entry Transitions", "transition_entry_")
@export_range(0.01, 0.50, 0.01)
var transition_entry_fade_out_duration: float = 0.17
@export_range(0.01, 0.50, 0.01)
var transition_entry_fade_in_duration: float = 0.20


@onready var title_label: Label = $OuterMargin/MainPanel/MainContents/Header/TitleLabel
@onready var slot_view_button: Button = $OuterMargin/MainPanel/MainContents/Header/SlotViewButton
@onready var list_view_button: Button = $OuterMargin/MainPanel/MainContents/Header/ListViewButton
@onready var close_button: Button = $OuterMargin/MainPanel/MainContents/Header/CloseButton

@onready var slot_view: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView
@onready var slot_grid: GridContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotScroll/SlotGrid
@onready var previous_page_button: Button = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/PreviousPageButton
@onready var page_buttons_area: Control = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/PageButtonsArea
@onready var page_buttons: HBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/PageButtonsArea/PageButtonsCenter/PageButtons
@onready var next_page_button: Button = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/NextPageButton

@onready var list_view: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView
@onready var sort_option: OptionButton = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SortRow/SortOption
@onready var saves_search_edit: LineEdit = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SearchEdit 
@onready var saves_list: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SavesScroll/MarginContainer/SavesList
@onready var saves_list_new_save_section: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SavesScroll/MarginContainer/SavesList/NewSaveSection
@onready var saves_list_existing_saves_container: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SavesScroll/MarginContainer/SavesList/ExistingSavesContainer

@onready var save_details: SaveDetails = $OuterMargin/MainPanel/MainContents/Content/SaveDetails
@onready var status_label: Label = $OuterMargin/MainPanel/MainContents/StatusLabel
@onready var confirmation_dialog: ModalConfirmationDialog = $ModalConfirmationDialog


var _operation_mode: SaveUIEnums.OperationMode = SaveUIEnums.OperationMode.LOAD
var _browse_mode: SaveUIEnums.BrowseMode = SaveUIEnums.BrowseMode.LIST_VIEW
var _sort_mode: SaveUIEnums.SortMode = SaveUIEnums.SortMode.LAST_SAVED_DESCENDING

var _search_query: String = ""
var _search_total_count: int = 0
var _search_result_count: int = 0
var _updating_search_edit: bool = false

var _current_page: int = FIRST_PAGE
var _selected_entry: SaveBrowserEntry = null

var _cached_thumbnail: Image = null
var _cached_game_metadata: Array[Dictionary] = []

var _tree_was_paused: bool = false
var _is_busy: bool = false
var _is_transitioning: bool = false

var _display_transition_tween: Tween = null
var _saves_list_transition_tween: Tween = null
var _saves_slot_transition_tween: Tween = null

var _visible_slot_entries: Array[SaveSlotEntry] = []
var _visible_list_entries: Array[SaveListEntry] = []

var _pagination_rebuild_queued: bool = false

var _confirmation_pending: bool = false

var _new_save_target_slot: int = -1
var _has_explicit_new_save_target: bool = false


func _ready() -> void:
	# Make sure that the save manager control is always being processed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make sure that all the required exported save slot/list entries fields has been assigned.
	assert(
		save_slot_entry_scene != null,
		"SaveManagerControl: SaveSlotEntry scene has not been assigned.",
	)
	assert(
		save_list_entry_scene != null,
		"SaveManagerControl: SaveListEntry scene has not been assigned.",
	)
	
	# Connect header nodes signals.
	slot_view_button.pressed.connect(_on_slot_view_button_pressed)
	list_view_button.pressed.connect(_on_list_view_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Connect slot view nodes signals.
	previous_page_button.pressed.connect(_on_previous_page_button_pressed)
	next_page_button.pressed.connect(_on_next_page_button_pressed)
	page_buttons_area.resized.connect(_on_page_buttons_area_resized)
	
	# Connect list view nodes signals.
	sort_option.item_selected.connect(_on_sort_option_selected)
	saves_search_edit.text_changed.connect(_on_search_text_changed)
	
	# Connect save details scene signals.
	save_details.save_requested.connect(_on_save_requested)
	save_details.load_requested.connect(_on_load_requested)
	save_details.delete_requested.connect(_on_delete_requested)
	
	# Populate and initialize the sort options for the list view display.
	_setup_sort_options()
	
	# Initialize status label initial text.
	status_label.text = ""
	
	# Make sure that save manager control is hidden by default and set as transparent.
	visible = false
	_set_display_alpha(0.0)


func _input(event: InputEvent) -> void:
	# Filter out processing if the save manager isn't currently visible.
	if not is_visible_in_tree():
		return
	
	# Get focus owner and filter out processing if the focus owner isn't one of the focussable elements managed by this scene.
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != saves_search_edit:
		return
	
	# Get current pointer position based on the used pointer and on which actions should be used for further releasing the focus.
	var pointer_position: Vector2
	# Handle mouse as current pointer device.
	if event is InputEventMouseButton:
		# Filter out processing if the mouse event doesn't have pressed flag set.
		if not event.pressed:
			return
		
		# Filter out processing if the mouse event is related in any way to the mouse wheel actions.
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		
		pointer_position = event.position
		
	# Handle touch as current pointer device.
	elif event is InputEventScreenTouch:
		# Filter out processing if the screen touch even doesn't have pressed flag set.
		if not event.pressed:
			return
		
		pointer_position = event.position
		
	# Filter out any other event types.
	else:
		return
	
	# Filter out processing if the input event was performed inside the currently focussed element.
	if focus_owner.get_global_rect().has_point(pointer_position):
		return
	
	# Release focus from the currently focussed element.
	focus_owner.release_focus()


#region Opening/Closing

## Opens save manager display in save mode. 
## Provided [param screenshot] is saved for future to be used as the save thumbnail.
func open_save_mode(screenshot: Image) -> void:
	# Filter out processing if the save manager display is already open.
	if visible:
		return
	
	# Save the tree paused state to return to it after closing the save manager display.
	_tree_was_paused = get_tree().paused
	
	# Set the save manager internal display state.
	_operation_mode = SaveUIEnums.OperationMode.SAVE
	_browse_mode = SaveUIEnums.BrowseMode.LIST_VIEW
	_current_page = FIRST_PAGE
	_cached_thumbnail = SaveManager.prepare_thumbnail(screenshot)
	_cached_game_metadata = SaveManager.capture_current_game_metadata()
	
	# Set save manager as not busy.
	_is_busy = false
	
	# Reset status label text.
	status_label.text = ""
	
	# Refresh and initialize save browser entries.
	SaveManager.refresh_user_saves()
	
	# Reset new save target to use the automatically selected first empty save slot.
	_reset_new_save_target()
	
	# Set the selected entry as the create new save browser entry that uses the first free save slot.
	_selected_entry = _get_new_save_target_entry()
	
	# Set display title label text.
	title_label.text = "Save Game"
	
	# Mark save manager as currently transitioning.
	_set_transitioning(true)
	
	# Prepare the display as fully transparent before showing it.
	_set_display_alpha(0.0)
	
	# Reset save details contents opacity in case a previous transition changed it.
	save_details.reset_content_transition()
	
	# Make the display visible.
	visible = true
	
	# Set the tree paused state as true.
	get_tree().paused = true
	
	# Reset saves search field state.
	_reset_search()
	
	# Update save manager interfaces.
	_refresh_interface()
	
	# Fade in the complete save manager display.
	await _fade_display_to(1.0, transition_display_fade_in_duration)
	
	# Mark transition as finished.
	_set_transitioning(false)


## Opens save manager display in load mode. 
func open_load_mode() -> void:
	# Filter out processing if the save manager display is already open.
	if visible:
		return
	
	# Save the tree paused state to return to it after closing the save manager display.
	_tree_was_paused = get_tree().paused
	
	# Set the save manager internal display state.
	_operation_mode = SaveUIEnums.OperationMode.LOAD
	_browse_mode = SaveUIEnums.BrowseMode.LIST_VIEW
	_current_page = FIRST_PAGE
	_cached_thumbnail = null
	_cached_game_metadata.clear()
	
	# Set save manager as not busy.
	_is_busy = false
	
	# Reset status label text.
	status_label.text = ""
	
	# Refresh and initialize save browser entries.
	SaveManager.refresh_user_saves()
	
	# Set the selected save browser entry as the first one available.
	_selected_entry = _get_first_sorted_existing_save()
	
	# Set display title label text.
	title_label.text = "Load Game"
	
	# Mark save manager as currently transitioning.
	_set_transitioning(true)
	
	# Prepare the display as fully transparent before showing it.
	_set_display_alpha(0.0)
	
	# Reset save details contents opacity in case a previous transition changed it.
	save_details.reset_content_transition()
	
	# Make the display visible.
	visible = true
	
	# Set the tree paused state as true.
	get_tree().paused = true
	
	# Reset saves search field state.
	_reset_search()
	
	# Update save manager interfaces.
	_refresh_interface()
	
	# Fade in the complete save manager display.
	await _fade_display_to(1.0, transition_display_fade_in_duration)
	
	# Mark transition as finished.
	_set_transitioning(false)


## Closes save manager display.
func close() -> void:
	# Filter out processing if the save manager display is already closed.
	if not visible:
		return
	
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Mark save manager as currently transitioning.
	_set_transitioning(true)
	
	# Fade out complete display before hiding and cleaning it.
	await _fade_display_to(0.0, transition_display_fade_out_duration)
	
	# Make the display hidden.
	visible = false
	
	# Reset opacity while hidden so the control has a clean resting state.
	_set_display_alpha(1.0)
	
	# Set the save manager internal display state.
	_cached_thumbnail = null
	_cached_game_metadata.clear()
	_selected_entry = null
	
	# Reset saves search field state.
	_reset_search()
	
	# Reset status label text.
	status_label.text = ""
	
	# Reset state of the new save target to default.
	_reset_new_save_target()
	
	# Clear save details scene.
	save_details.clear_details()
	save_details.reset_content_transition()
	
	# Clear all save browser entries.
	_clear_slot_entries()
	_clear_list_entries()
	_clear_container(page_buttons)
	
	# Return tree paused state to what was set before opening the save manager display.
	get_tree().paused = _tree_was_paused
	
	# Mark transition as finished.
	_set_transitioning(false)


## Closes save manager display after making sure there aren't any unsaved changes in the save manager.
## If there would be any unsaved changes, it will display first the confirmation dialog to the user.
func request_close() -> void:
	# Filter out processing if the save manager display is already closed.
	if not visible:
		return
	
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Filter out processing if another confirmation is already awaiting a response.
	if _confirmation_pending:
		return
	
	# Show user the confirmation dialog and await his response.
	var confirmed := await _confirm_discard_unsaved_changes("Closing the save manager will discard any unsaved changes.")
	
	# Filter out processing if user didn't confirm.
	if not confirmed:
		return
	
	# Perform the close operation.
	close()

#endregion


#region Interface Refresh

## Updates state of display interfaces that might change based on internal fields values like browse mode or other user selected settings.
## Provided [param preserve_details_edits] flag will determine if the save details should preserve the existing edited interactible save fields if the save entry didn't change.
func _refresh_interface(preserve_details_edits: bool = false) -> void:
	# Update state of save views and their buttons that are used to change the active browse view mode.
	_update_view_visibility()
	_update_view_buttons()
	
	# Populate save views depending on the current browse view mode.
	match _browse_mode:
		SaveUIEnums.BrowseMode.SLOT_VIEW:
			_rebuild_slot_view()
		SaveUIEnums.BrowseMode.LIST_VIEW:
			_rebuild_list_view()
		SaveUIEnums.BrowseMode.EXAMPLES_VIEW:
			#TODO: Reserved for the later implementation of examples view.
			pass
	
	# Update save details display.
	_update_details(preserve_details_edits)
	
	# Update selected entry highlight.
	_update_selection_highlights()
	
	# Update state of user interactive elements of the display.
	_apply_interaction_state()


## Updates the different saves views visibility state.
func _update_view_visibility() -> void:
	slot_view.visible = _browse_mode == SaveUIEnums.BrowseMode.SLOT_VIEW
	list_view.visible = _browse_mode == SaveUIEnums.BrowseMode.LIST_VIEW


## Updates the state of view buttons that are responsible for changing into different saves views.
func _update_view_buttons() -> void:
	slot_view_button.button_pressed = _browse_mode == SaveUIEnums.BrowseMode.SLOT_VIEW
	list_view_button.button_pressed = _browse_mode == SaveUIEnums.BrowseMode.LIST_VIEW


## Updates save details displayed inside the save manager control display based on the save browser entry set as selected.
## Provided [param preserve_edits] flag will determine if the save details should preserve the existing edited interactible save fields if the save entry didn't change.
func _update_details(preserve_edits: bool = false) -> void:
	# Clear save details if there isn't any save browser entry set as selected.
	if _selected_entry == null:
		save_details.clear_details()
		return
	
	# Assign currently cached game metadata to the selected save browser entry if it's for the user save and it doesn't currently exist.
	if _selected_entry.is_user_save() and not _selected_entry.exists:
		_selected_entry.game_metadata = _cached_game_metadata.duplicate(true)
	
	# Show save browser entry set as selected.
	save_details.show_entry(_selected_entry, _operation_mode, _cached_thumbnail, preserve_edits)

#endregion


#region Browse Mode

## Handles slot view button pressed signal to set the save manager browse mode to slot view.
func _on_slot_view_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Set slot view browse mode.
	_set_browse_mode(SaveUIEnums.BrowseMode.SLOT_VIEW)
	
	# Update displayed status message.
	_restore_default_status()


## Handles list view button pressed signal to set the save manager browse mode to list view.
func _on_list_view_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Set list view browse mode.
	_set_browse_mode(SaveUIEnums.BrowseMode.LIST_VIEW)
	
	# Update displayed status message.
	_restore_default_status()


## Sets a [param new_mode] for the browser, updates selected save entry for it and refreshes itnerfaces that might have been affected by the changes.
func _set_browse_mode(new_mode: SaveUIEnums.BrowseMode) -> void:
	#TODO: Reserved for the later implementation of examples view.
	if new_mode == SaveUIEnums.BrowseMode.EXAMPLES_VIEW:
		return
	
	# Update view mode buttons and filter out processing if the new selected browse mode is the same as the one already set.
	if _browse_mode == new_mode:
		_update_view_buttons()
		return
	
	# Cache previous selected entry before it could be changed in order to later verify if after the change the entry would still be referring to the same save. 
	var previous_entry_id: String = ""
	if _selected_entry != null:
		previous_entry_id = _selected_entry.entry_id
	
	# Save new browse mode.
	_browse_mode = new_mode
	
	# Set selected save entry depending on the browse mode.
	match _browse_mode:
		SaveUIEnums.BrowseMode.SLOT_VIEW:
			_prepare_selection_for_slot_view()
		SaveUIEnums.BrowseMode.LIST_VIEW:
			_prepare_selection_for_list_view()
	
	# Check if previous selected entry is for the save as the current one along if save mode is enabled in save manager and if yes, then preserve the user edits inside the save details.
	var preserve_details_edits: bool = _operation_mode == SaveUIEnums.OperationMode.SAVE and _selected_entry != null and not previous_entry_id.is_empty() and _selected_entry.entry_id == previous_entry_id
	
	# Update save manager interfaces.
	_refresh_interface(preserve_details_edits)


## Updates selected save browser entry to make sure that it fits the current slot view browse mode. 
func _prepare_selection_for_slot_view() -> void:
	# Handle preparing selected entry if it was already selected before and if it's a user save.
	if _selected_entry != null and _selected_entry.is_user_save() and _selected_entry.slot >= FIRST_SLOT:
		# Check current slot page for the selected entry.
		_current_page = _get_page_for_slot(_selected_entry.slot)
		
		# Update assigned selected save browser entry for the slot view.		
		_selected_entry = SaveManager.get_user_slot_entry(_selected_entry.slot)
		
		return
	
	# Otherwise set the current page as first one and select the default entry on it as the one selected. 
	_current_page = max(FIRST_PAGE, _current_page)
	_selected_entry = null


## Updates selected save browser entry to make sure that it fits the current list view browse mode. 
func _prepare_selection_for_list_view() -> void:
	# Handle preparing selected entry if it was already selected before, it's for the user save and the entry wasn't for not existing slot.
	if _selected_entry != null and _selected_entry.is_user_save() and _selected_entry.exists:
		# Update assigned selected save browser entry for the list view.
		var refreshed_entry := SaveManager.get_user_save(_selected_entry.slot)
		if refreshed_entry != null:
			_selected_entry = refreshed_entry
			return
	
	# Sets the selected entry to entry placeholder for creating new saves if the save manager operation mode is set to save.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		_selected_entry = _get_new_save_target_entry()
		return
	
	# Otherwise set the first sorted save browser entry as the one selected. 
	_selected_entry = _get_first_sorted_existing_save()

#endregion


#region Selection

## Sets provided [param entry] as the selected one and updates the display elements dependant on the selected entry.
func _select_entry(entry: SaveBrowserEntry) -> void:
	# Update selection highlights to restore correct state and filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		_update_selection_highlights()
		return
	
	# Update selection highlights to restore correct state and filter out processing if another confirmation is already awaiting a response.
	if _confirmation_pending:
		_update_selection_highlights()
		return
	
	# Filter out processing if the provided entry doesn't exist.
	if entry == null:
		return
	
	# Check if the selected entry represents the same logical save as the currently selected one.
	var same_entry: bool = _selected_entry != null and _selected_entry.entry_id == entry.entry_id
	
	# Updated selected entry highlight and filter out further processing if the provided entry is the same as the already selected one and there aren't any unsaved changes.
	if same_entry and not save_details.has_unsaved_changes():
		_update_selection_highlights()
		return
	
	# Request confirmation before discarding any existing unsaved edits if there are any.
	if save_details.has_unsaved_changes():
		# Prepare a discard message to be displayed inside the confirmation dialog.
		var discard_message: String
		if same_entry:
			discard_message = "Reloading this save will discard any unsaved changes."
		else:
			discard_message = "Selecting another save will discard any unsaved changes."
		
		# Show user the confirmation dialog and await his response.
		var confirmed := await _confirm_discard_unsaved_changes(discard_message)
		
		# Keep the current entry selection and unsaved changes if the user cancels.
		if not confirmed:
			_update_selection_highlights()
			return
	
	# Selecting an empty slot in the save mode in slot view causes it to become a new create new save default target.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE and _browse_mode == SaveUIEnums.BrowseMode.SLOT_VIEW and entry.is_user_save() and not entry.exists and not entry.is_new_save():
		_set_explicit_new_save_target(entry.slot)
	
	# Mark save manager as currently transitioning between save entries.
	_set_transitioning(true)
	
	# Fade out current save details before replacing their contents.
	await save_details.fade_contents_out()
	
	# Set entry as the selected one.
	_selected_entry = entry
	
	# Update displayed status message.
	_restore_default_status()
	
	# Update save details display.
	_update_details()
	
	# Updated selected entry highlight.
	_update_selection_highlights()
	
	# Fade in newly populated save details back.
	await save_details.fade_contents_in()
	
	# Mark entry transition as finished.
	_set_transitioning(false)


## Updates selected state for existing save slot entries and save list entries.
func _update_selection_highlights() -> void:
	# Get selected entry ID.
	var selected_id := ""
	if _selected_entry != null:
		selected_id = _selected_entry.entry_id
	
	# Update selected state for the existing save slot entries based on the selected entry ID.
	for slot_entry: SaveSlotEntry in _visible_slot_entries:
		var selected := slot_entry.entry != null and slot_entry.entry.entry_id == selected_id
		slot_entry.set_selected(selected)
	
	# Update selected state for the existing save list entries based on the selected entry ID.
	for list_entry: SaveListEntry in _visible_list_entries:
		var selected := list_entry.entry != null and list_entry.entry.entry_id == selected_id
		list_entry.set_selected(selected)


## Handles entry selected signal in order to set the selected status on the correct save browser entry.
func _on_entry_selected(entry: SaveBrowserEntry) -> void:
	# Filter out processing if the provided entry doesn't exist.
	if entry == null:
		return
	
	# Set entry as selected.
	_select_entry(entry)


#endregion


#region New Save Target

## Resets the new save target back to automatic first empty slot behaviour.
func _reset_new_save_target() -> void:
	_new_save_target_slot = -1
	_has_explicit_new_save_target = false


## Sets the provided empty user save [param slot] as the explicitly selected target for the create new save entry.
func _set_explicit_new_save_target(slot: int) -> void:
	# Filter out processing if the provided slot number isn't valid.
	if slot < FIRST_SLOT:
		return
	
	# Filter out processing if the provided slot number is for the existing save entry and not for the empty save slot.
	if SaveManager.has_user_save(slot):
		return
	
	# Set provided slot as the new target for the create new save entry.
	_new_save_target_slot = slot
	_has_explicit_new_save_target = true


## Creates and returns the create new save pseudo entry for the currently selected new save target.
## If the new save target wasn't set explicitly, then it will use an automatic save entry target, which would use the first unused save slot.
func _get_new_save_target_entry() -> SaveBrowserEntry:
	# Prepare an explicit save entry to be used for the create new save if it was set.
	if _has_explicit_new_save_target:
		# Proceed with creating an explicit save entry if it's slot number is valid and it's not for an existing save.
		if _new_save_target_slot >= FIRST_SLOT and not SaveManager.has_user_save(_new_save_target_slot):
			# Create new save entry using the explicit save entry and initialize it's state.
			var explicit_entry := SaveBrowserEntry.create_new_user_save_entry(_new_save_target_slot)
			explicit_entry.browser_hint = "Save to the selected empty slot: Slot %d." % _new_save_target_slot
			
			return explicit_entry
		
		# Reset new save target if it hasn't passed the above checks.
		_reset_new_save_target()
	
	# Select an automatic save entry as the first one available if the explicit new save target wasn't set or it was invalid.
	var automatic_entry := SaveManager.get_new_user_save_entry()
	automatic_entry.browser_hint = "Save to the first available slot."
	
	return automatic_entry

#endregion


#region Slot View

## Rebuilds save slot view by clearing out existing slot entries and populating new ones based on the current pagination.
func _rebuild_slot_view() -> void:
	# Ensure that current page number fits inside the range of valid pages.
	_normalize_current_page()
	
	# Clear out existing slot entries.
	_clear_slot_entries()
	
	# Calculate first and last slot on the page.
	var first_slot := _get_first_slot_on_page(_current_page)
	var last_slot := first_slot + SLOTS_PER_PAGE - 1
	
	# Populate slot entries for each slot on the page.
	for slot: int in range(first_slot, last_slot + 1):
		# Get current save browser entry.
		var entry := SaveManager.get_user_slot_entry(slot)
		
		# Instantiate new slot entry.
		var slot_control := save_slot_entry_scene.instantiate() as SaveSlotEntry
		
		# Add the slot entry to the slot grid.
		slot_grid.add_child(slot_control)
		
		# Populate slot entry with the save browser entry details.
		slot_control.setup(entry, _operation_mode)
		
		# Connect entry selected signal from the slot entry to the local handler function.
		slot_control.entry_selected.connect(_on_entry_selected)
		
		# Append created slot entry to the field that aggregates all existing slot entries.
		_visible_slot_entries.append(slot_control)
	
	# Update pagination buttons and related details.
	_rebuild_pagination()


## Clears out all existing slot entries.
func _clear_slot_entries() -> void:
	# Clear internal list used to aggregate all existing slot entries.
	_visible_slot_entries.clear()
	
	# Clear out all slot entries children assigned to the slot grid container.
	_clear_container(slot_grid)


## Ensures that current page number fits inside the range of valid pages.
## If not then it adjust the current page accordingly.
func _normalize_current_page() -> void:
	# Set current page counter to first one if it's smaller than that.
	if _current_page < FIRST_PAGE:
		_current_page = FIRST_PAGE
	
	# Filter out further normalization if the save manager operation mode is set to save.
	# All the proceeding normalizations are set for save manager load operation mode.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		return
	
	# Get available pages numbers.
	var pages := _get_available_page_numbers()
	
	# Set current page to first one if there aren't any available pages.
	if pages.is_empty():
		_current_page = FIRST_PAGE
		return
	
	# Set current page counter to first one available if current page counter doesn't belong to any page that exists for the existing saves. 
	if not pages.has(_current_page):
		_current_page = pages[0]


## Calculates and returns an integer representing first slot number for the provided [param page] number. 
func _get_first_slot_on_page(page: int) -> int:
	return FIRST_SLOT + (page - 1) * SLOTS_PER_PAGE


## Calculates and returns an integer represeting page number on which the provided [param slot] number resides.
func _get_page_for_slot(slot: int) -> int:
	# Return default first slot static value if the provided slot number is lower than the set first slot static value.
	if slot <= FIRST_SLOT:
		return FIRST_SLOT
	
	# Calculate page number on which the provided slot number resides.
	var page_number: int = int(
		floor(
			float(slot - FIRST_SLOT) / float(SLOTS_PER_PAGE)
		)
	) + 1
	
	return page_number


## Selects a default entry for the current page that will be set as selected.
## For the save operation mode, it will be first slot on the current page.
## For the load operation mode, it will be first existing save on the current page.
func _select_default_entry_for_current_page() -> void:
	# Mark first possible slot as the selected one if the save manager operation mode is set to save.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		_selected_entry = SaveManager.get_user_slot_entry(_get_first_slot_on_page(_current_page))
		return
	
	# Mark first possible existing save as the selected one if the save manager operation mode is set to load.
	_selected_entry = _get_first_existing_save_on_page(_current_page)


## Gets and returns the first SaveBrowserEntry that exists and is set for an existing user save on the provided [param page] number.
func _get_first_existing_save_on_page(page: int) -> SaveBrowserEntry:
	# Calculate first and last slot on the page.
	var first_slot := _get_first_slot_on_page(page)
	var last_slot := first_slot + SLOTS_PER_PAGE - 1
	
	# Checks each slot entry on the current page and returns first one that exists.
	for slot: int in range(first_slot, last_slot + 1):
		var entry := SaveManager.get_user_save(slot)
		
		if entry != null:
			return entry
	
	# Otherwise returns null.
	return null

#endregion


#region Pagination

## Rebuilds pagination using as much available page information as can fit inside the allocated pagination area.
func _rebuild_pagination() -> void:
	# Get list of available page numbers for which saves exist or that should be available in navigation.
	var ideal_pages := _get_available_page_numbers()
	
	# Truncate list of available page numbers in order to make them fit inside the pagination container.
	var visible_pages := _get_pagination_pages_that_fit(ideal_pages)
	
	# Prepare pagination display nodes.
	_render_pagination_pages(visible_pages)
	
	# Update state of the pagination buttons along with their interactions.
	_update_pagination_navigation()


## Renders the display nodes for the pagination using the provided [param pages] numbers.
## Ellipsis labels are automatically inserted wherever one or more numerical pages are omitted between two displayed page buttons.
func _render_pagination_pages(pages: Array[int]) -> void:
	# Clear out existing pagination buttons nodes.
	_clear_container(page_buttons)
	
	# Filter out processing if the provided pages are empty.
	if pages.is_empty():
		return
	
	# Make sure that pages are sorted accordingly.
	var sorted_pages := pages.duplicate()
	sorted_pages.sort()
	
	# Populate pagination display nodes for each page on the list.
	var previous_page: int = -1
	for page: int in sorted_pages:
		# Add ellipsis label if the previous page exists and there is any page break between current one and last one.
		if previous_page != -1 and page > previous_page + 1:
			_add_pagination_ellipsis()
		
		# Add page button for the current page.
		_add_pagination_page_button(page)
		
		# Save current page as the previous page.
		previous_page = page


## Creates one interactive pagination page button for the provided [param page] number and adds it as a child of page buttons container.
func _add_pagination_page_button(page: int) -> void:
	# Create new button.
	var button := Button.new()
	
	# Initialize button state and display.
	if page != _current_page:
		button.text = str(page)
	else:
		button.text = "[" + str(page) + "]"
	button.toggle_mode = true
	
	# Set the theme type variation for the button.
	button.theme_type_variation = NAVIGATION_BUTTON_VARIATION
	
	# Set button pressed state based on current page number and the button page number.
	button.button_pressed = page == _current_page
	
	# Set button disabled state based on the current save manager busy state.
	button.disabled = _is_busy
	
	# Connect button pressed signal to the local handler function.
	button.pressed.connect(_on_page_number_pressed.bind(page))
	
	# Add the page button to the page container.
	page_buttons.add_child(button)


## Creats one non-interactive pagination visual marker indicating skipped pages and adds it as a child of page buttons container.
func _add_pagination_ellipsis() -> void:
	# Create new label.
	var label := Label.new()
	
	# Initialize label state and display.
	label.text = "..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add the label to the page container.
	page_buttons.add_child(label)


## Renders the provided [param pages] list candidate and returns whether its real minimum width fits inside the available space based on the provided [param available_width].
func _pagination_pages_fit(pages: Array[int], available_width: float) -> bool:
	# Prepare pagination display nodes.
	_render_pagination_pages(pages)
	
	# Get current width of page buttons to determine how much width it would require to render the provided pages.
	var required_width := page_buttons.get_combined_minimum_size().x
	
	# Check if the provided pages would fit inside the available width to display them in.
	return required_width <= available_width + 0.5


## Returns pages that should normally never be removed while truncating pagination.
## Those include: page 1, nearest occupied page before current, current page, nearest occupied page after current, last occupied page.
## In load operation mode the page 1 will be replaced by the first available page if any occupied page exists.
## Uses provided [param occupied_pages] to determine what is the previous, next and the last available page that contain any saves at all.
func _get_required_pagination_pages(occupied_pages: Array[int]) -> Array[int]:
	# Prepare variable to store the result to return.
	var pages: Array[int] = []
	
	# Append first available page to the result.
	if _operation_mode == SaveUIEnums.OperationMode.LOAD and not occupied_pages.is_empty():
		_append_unique_page(pages, occupied_pages[0])
	else:
		_append_unique_page(pages, FIRST_PAGE)
	
	# Append previous page to the result if it exists.
	var previous_page := _get_previous_occupied_page(occupied_pages, _current_page)
	if previous_page != -1:
		_append_unique_page(pages, previous_page)
	
	# Append current page to the result.
	_append_unique_page(pages, _current_page)
	
	# Append next page to the result if it exists.
	var next_page := _get_next_occupied_page(occupied_pages, _current_page)
	if next_page != -1:
		_append_unique_page(pages, next_page)
	
	# Append last page to the result if it exists.
	if not occupied_pages.is_empty():
		_append_unique_page(pages, occupied_pages[occupied_pages.size() - 1])
	
	# Make sure that pages are sorted accordingly.
	pages.sort()
	
	return pages


## Finds the nearest occupied page from the provided [param occupied_pages] list before the current page and returns it if it exists. Otherwise it returns -1.
func _get_previous_occupied_page(occupied_pages: Array[int], current_page: int) -> int:
	# Prepare variable to store the result to return along with it's default value.
	var result: int = -1
	
	# Search for the nearest occupied page before the current page.
	for page: int in occupied_pages:
		if page >= current_page:
			break
		result = page
	
	return result


## Finds the nearest occupied page from the provided [param occupied_pages] list after the current page and returns it if it exists. Otherwise it returns -1.
func _get_next_occupied_page(occupied_pages: Array[int], current_page: int) -> int:
	# Prepare variable to store the result to return along with it's default value.
	var result: int = -1
	
	# Search for the nearest occupied page after the current page.
	for page: int in occupied_pages:
		if page > current_page:
			return page
	
	return result


## Appends a [param page] number only if it isn't already present in the current [param pages] list.
func _append_unique_page(pages: Array[int], page: int) -> void:
	if not pages.has(page):
		pages.append(page)


## Finds the most detailed pagination state that fits inside the currently available width for the pagination container.
## Uses provided [param ideal_pages] list to check if it fits and if not it truncates it accordingly and returns the modified pages list.
func _get_pagination_pages_that_fit(ideal_pages: Array[int]) -> Array[int]:
	# Filter out processing and return the default page list containing only first page if the provided page list is empty.
	if ideal_pages.is_empty():
		return [FIRST_PAGE]
	
	# Calculate how much width there is available inside the pagination container.
	var available_width := page_buttons_area.size.x
	
	# Filter out processing and return provided pages list if the available width wasn't initialized yet.
	if available_width <= 0.0:
		return ideal_pages
	
	# Check if by default the provided page list already fits and return it if that's the case.
	if _pagination_pages_fit(ideal_pages, available_width):
		return ideal_pages
	
	# Prepare variables used for truncating the page list.
	var occupied_pages := _get_occupied_page_numbers()
	var required_pages := _get_required_pagination_pages(occupied_pages)
	var working_pages := ideal_pages.duplicate()
	var removable_left: Array[int] = []
	var removable_right: Array[int] = []
	
	# Split optional pages according to which side of the current page they are located on.
	for page: int in working_pages:
		if required_pages.has(page):
			continue
		
		if page < _current_page:
			removable_left.append(page)
		elif page > _current_page:
			removable_right.append(page)
	
	# Sort splitted pages on left and right, so that first elements would be the ones that would be farthest ones from the current page.
	removable_left.sort()
	removable_right.sort()
	removable_right.reverse()
	
	# Check from which side the next page should be truncated from next.
	var remove_left_next := _should_remove_left_first(removable_left, removable_right)
	
	# Keep truncating pages from left and right side until the remaining pages would be able to fit inside the available width or until there would be nothing left to truncate from.
	while not removable_left.is_empty() or not removable_right.is_empty():
		var page_to_remove: int = -1
		
		# Get next page to truncate.
		if remove_left_next:
			if not removable_left.is_empty():
				page_to_remove = removable_left.pop_front()
			elif not removable_right.is_empty():
				page_to_remove = removable_right.pop_front()
		else:
			if not removable_right.is_empty():
				page_to_remove = removable_right.pop_front()
			elif not removable_left.is_empty():
				page_to_remove = removable_left.pop_front()
		
		# Remove the selected page if it exists.
		if page_to_remove != -1:
			working_pages.erase(page_to_remove)
		
		# After every truncation, check if the remaining page list fit and return it if that's the case.
		if _pagination_pages_fit(working_pages, available_width):
			return working_pages
		
		# Change side from which the next page should be removed.
		remove_left_next = not remove_left_next
	
	# Call and return a result of the emergency pagination display if after removing all optional pages the baseline pages still don't fit.
	return _get_emergency_pagination_pages(working_pages, occupied_pages, available_width)


## Checks if the page truncation should be started from the [param left_pages] list or rather from the [param right_pages] list based on their relative distance to the current page.
func _should_remove_left_first(left_pages: Array[int], right_pages: Array[int]) -> bool:
	# Return false if the left page list is empty.
	if left_pages.is_empty():
		return false
	
	# Return true if the right page list is empty.
	if right_pages.is_empty():
		return true
	
	# Check if first left page is located further from the first right page.
	var left_distance := _current_page - left_pages[0]
	var right_distance := right_pages[0] - _current_page
	return left_distance >= right_distance


## Handles unusually narrow layouts where even the normal mandatory pagination baseline from the "_get_pagination_pages_that_fit" function call cannot fit.
## Uses provided [param baseline_pages] list that contains already truncated pages along with provided [param occupied_pages] list to further truncate them.
## After further truncation it uses [param available_width] to check if the further truncated list would fit in the available space.
## Returns further truncated list based on the provided [param baseline_pages] list.
func _get_emergency_pagination_pages(baseline_pages: Array[int], occupied_pages: Array[int], available_width: float) -> Array[int]:
	# Prepare variable for emergency pagination truncation.
	var local_pages := baseline_pages.duplicate()
	var previous_page := _get_previous_occupied_page(occupied_pages, _current_page)
	var next_page := _get_next_occupied_page(occupied_pages, _current_page)
	
	# Prepare a list of pages that are required in the first pass of the emergency pagination truncation.
	var local_required: Array[int] = [_current_page]
	if previous_page != -1:
		_append_unique_page(local_required, previous_page)
	if next_page != -1:
		_append_unique_page(local_required, next_page)
	
	# Perform a first pass of emergency truncation by leaving only the required pages from the just prepared list.
	for page: int in baseline_pages:
		if not local_required.has(page):
			local_pages.erase(page)
	local_pages.sort()
	
	# Return prepared pages list if it fits in the available space.
	if _pagination_pages_fit(local_pages, available_width):
		return local_pages
	
	# Further truncate the page list by only returning the current page if all the previous truncations weren't enough.
	return [_current_page]


## Returns sorted page numbers containing at least one existing user save.
func _get_occupied_page_numbers() -> Array[int]:
	# Prepare a dictionary for marking which pages exist for the existing saves.
	var page_set: Dictionary[int, bool] = {}
	var saves := SaveManager.get_existing_user_saves()
	for entry: SaveBrowserEntry in saves:
		page_set[_get_page_for_slot(entry.slot)] = true
	
	# Prepare a list of pages that will be returned by this function as the available page number list.
	var pages: Array[int] = []
	for page: int in page_set.keys():
		pages.append(page)
	pages.sort()
	
	return pages


## Returns a list of available page numbers based on the existing saves.
func _get_available_page_numbers() -> Array[int]:
	# Get currently occupied pages numbers.
	var occupied_pages := _get_occupied_page_numbers()
	
	# Return first page or the list of occupied pages numbers (if any exist) if current operation mode is set to load.
	if _operation_mode == SaveUIEnums.OperationMode.LOAD:
		if occupied_pages.is_empty():
			return [FIRST_PAGE]
		
		return occupied_pages
	
	# Prepare a dictionary for marking which pages exist for the existing saves.
	var page_set: Dictionary[int, bool] = {FIRST_PAGE: true}
	for page:int in occupied_pages:
		page_set[page] = true
	
	# Mark the current page as existing if the save manager operation mode is set to save and the current page isn't listed in the page set.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE and _current_page not in page_set:
		page_set[_current_page] = false
	
	# Prepare a list of pages that will be returned by this function as the available page number list.
	var pages: Array[int] = []
	for page: int in page_set.keys():
		pages.append(page)
	pages.sort()
	
	return pages


## Updates pagination navigation buttons state to enable/disable them according to the current save manager state.
func _update_pagination_navigation() -> void:
	# Disable pagination navigation if the save manager display is busy working on something else.
	if _is_busy:
		previous_page_button.disabled = true
		next_page_button.disabled = true
		return
	
	# Allow unlimited pagination exploration if the save manager operation mode is set to save.
	# Only limitation is on the previous page button, which shouldn't be able to access page numbers lower than the first slot static value.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		previous_page_button.disabled = _current_page <= FIRST_PAGE
		next_page_button.disabled = false
		return
	
	# Get available page numbers and find current page index position among them.
	var pages := _get_available_page_numbers()
	var current_index := pages.find(_current_page)
	
	# Disable pagination navigation if the index wasn't found.
	if current_index < 0:
		previous_page_button.disabled = true
		next_page_button.disabled = true
		return
	
	# Set pagination navigation disabled state based on the index position.
	previous_page_button.disabled = current_index <= 0
	next_page_button.disabled = current_index >= pages.size() - 1


## Handles previous page button pressed signal to change the displayed page to a previous one available.
func _on_previous_page_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Simply decrement page number if the save manager operation mode is set to save.
	# In this mode user is meant to be able to explore all possible pages.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		# Filter out processing if the page number can't be further decreased.
		if _current_page <= FIRST_PAGE:
			return
		
		# Decrease current page number by decrementing it's value by 1.
		_go_to_page(_current_page - 1)
		return
	
	# Get available page numbers and find current page index position among them.
	var pages := _get_available_page_numbers()
	var current_index := pages.find(_current_page)
	
	# Filter out processing if the index wasn't found.
	if current_index <= 0:
		return
	
	# Decrease current page number by changing it into next smaller available page number.
	_go_to_page(pages[current_index - 1])


## Handles next page button pressed signal to change the displayed page to a next one available.
func _on_next_page_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Simply increment page number if the save manager operation mode is set to save.
	# In this mode user is meant to be able to explore all possible pages.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		# Increase current page number by incrementing it's value by 1.
		_go_to_page(_current_page + 1)
		return
	
	# Get available page numbers and find current page index position among them.
	var pages := _get_available_page_numbers()
	var current_index := pages.find(_current_page)
	
	# Filter out processing if the index wasn't found.
	if current_index < 0:
		return
	
	# Filter out processing if the current index is equal or highier than count of pages.
	if current_index >= pages.size() - 1:
		return
	
	# Increase current page number by changing it into next bigger available page number.
	_go_to_page(pages[current_index + 1])


## Handles page buttons area node resized signal to handle updating all the relevant page buttons area that might be affected by the resize event.
func _on_page_buttons_area_resized() -> void:
	# Filter out processing if the save manager isn't visible.
	if not visible:
		return
	
	# Filter out processing if the save manager browse mode isn't set to slot view, since only it uses the pagination controls.
	if _browse_mode != SaveUIEnums.BrowseMode.SLOT_VIEW:
		return
	
	# Queue pagination control nodes rebuild, since they might have been affected by the resize.
	_queue_pagination_rebuild()


## Queues a single deferred pagination rebuild.
func _queue_pagination_rebuild() -> void:
	# Filter out processing if the pagination rebuild is already queued.
	if _pagination_rebuild_queued:
		return
	
	# Set the pagination rebuild queued flag.
	_pagination_rebuild_queued = true
	
	# Queue the function call to rebuild the pagination.
	call_deferred("_rebuild_pagination_after_layout")


## Rebuilds pagination once the current UI layout has settled.
func _rebuild_pagination_after_layout() -> void:
	# Unset the pagination rebuild queued flag.
	_pagination_rebuild_queued = false
	
	# Filter out processing if the save manager isn't visible.
	if not visible:
		return
	
	# Filter out processing if the save manager browse mode isn't set to slot view, since only it uses the pagination controls.
	if _browse_mode != SaveUIEnums.BrowseMode.SLOT_VIEW:
		return
	
	# Update pagination buttons and related details.
	_rebuild_pagination()


## Handles page number button pressed signal to change the displayed page to the provided [param page] number.
func _on_page_number_pressed(page: int) -> void:
	# Rebuild pagination to restore its correct state and filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		_rebuild_pagination()
		return
	
	# Set the current page number to the provided page number.
	_go_to_page(page)


## Changes currently displayed page to display the provided [param page] number.
func _go_to_page(page: int) -> void:
	# Filter out processing if the provided page number is lower then the first page static value. 
	if page < FIRST_PAGE:
		return
	
	# Filter out processing if the save manager browse mode is set to something else then slot view.
	# Currently only slot view uses pagination, in other cases it should not do anything.
	if _browse_mode != SaveUIEnums.BrowseMode.SLOT_VIEW:
		return
	
	# Filter out processing if the save manager operation mode is set to laod and the provided page number isn't for any of the available page numbers.
	if _operation_mode == SaveUIEnums.OperationMode.LOAD:
		var pages := _get_available_page_numbers()
		if not pages.has(page):
			return
	
	# Update pagination buttons and related details if the provided page number is the same as the current page number.
	if page == _current_page:
		_rebuild_pagination()
		_update_selection_highlights()
		return
	
	# Mark save manager as currently transitioning.
	_set_transitioning(true)
	
	# Set the new current page number.
	_current_page = page
	
	# Update displayed status message.
	_restore_default_status()
	
	# Update pagination immediately while the old page contents are still shown.
	_rebuild_pagination()
	
	# Fade out old page contents.
	await _fade_slot_grid_to(0.0, transition_entry_fade_out_duration)
	
	# Update save manager interfaces related to the slot view and pages.
	_rebuild_slot_view()
	_update_selection_highlights()
	_apply_interaction_state()
	
	# Fade in new page contents.
	await _fade_slot_grid_to(1.0, transition_entry_fade_in_duration)
	
	# Mark entry transition as finished.
	_set_transitioning(false)

#endregion


#region List View

## Rebuilds save list view by clearing out existing list entries and populating new ones.
func _rebuild_list_view() -> void:
	# Stop any partial saves list transition and restore its opacity.
	_reset_save_list_transition()
	
	# Rebuild the pinned create new save section.
	_rebuild_new_save_section()
	
	# Rebuild the existing saves contaienr using the current search and sort settings.
	_rebuild_existing_saves_container()


## Rebuild the create new save section.
func _rebuild_new_save_section() -> void:
	# Clear existing nodes in the new save section.
	_clear_new_save_section()
	
	# Set the new save section visibility based on the current operation mode.
	saves_list_new_save_section.visible = _operation_mode == SaveUIEnums.OperationMode.SAVE
	
	# Filter out processing if the new save section is set to be hidden.
	if not saves_list_new_save_section.visible:
		return
	
	# Create a new save browser entry placeholder instance.
	var new_save_entry := _get_new_save_target_entry()
	
	# Instantiate new list entry.
	var new_save_control := save_list_entry_scene.instantiate() as SaveListEntry
	
	# Add the list entry to the saves list container.
	saves_list_new_save_section.add_child(new_save_control)
	
	# Populate list entry with the save browser entry placeholder details.
	new_save_control.setup(new_save_entry)
	
	# Connect entry placeholder selected signal from the list entry to the local handler function.
	new_save_control.entry_selected.connect(_on_entry_selected)
	
	# Append created list entry placeholder to the field that aggregates all existing list entries.
	_visible_list_entries.append(new_save_control)
	
	# Create a horizontal separator and place it after the list entry placeholder.  
	var separator := HSeparator.new()
	saves_list_new_save_section.add_child(separator)


## Rebuild the existing saves container.
func _rebuild_existing_saves_container() -> void:
	# Clear existing nodes in the existing saves container.
	_clear_existing_saves_container()
	
	# Get list of existing save browser entries.
	var sorted_entries := _get_sorted_existing_saves()
	
	# Save the unfiltered count of save entries.
	_search_total_count = sorted_entries.size()
	
	# Prepare filtered save entries results.
	var entries: Array[SaveBrowserEntry] = []
	for entry: SaveBrowserEntry in sorted_entries:
		if _entry_matches_search(entry):
			entries.append(entry)
	
	# Save the filtered count of save entries.
	_search_result_count = entries.size()
	
	# Prepare empty saves message to be put inside save list view if there wouldn't be any existing save browser entries.
	if entries.is_empty():
		if not _search_query.is_empty() and _search_total_count > 0:
			_add_existing_saves_container_message("No saves match your search.")
		else:
			_add_existing_saves_container_message("No saves found.")
		
		return
	
	# Populate list entries for each existing save.
	for entry: SaveBrowserEntry in entries:
		# Instantiate new list entry.
		var list_control := save_list_entry_scene.instantiate() as SaveListEntry
		
		# Add the list entry to the saves list container.
		saves_list_existing_saves_container.add_child(list_control)
		
		# Populate list entry with the save browser entry details.
		list_control.setup(entry)
		
		# Connect entry selected signal from the list entry to the local handler function.
		list_control.entry_selected.connect(_on_entry_selected)
		
		# Append created list entry to the field that aggregates all existing list entries.
		_visible_list_entries.append(list_control)


## Adds a centered informational message to the saves list.
func _add_existing_saves_container_message(message: String) -> void:
	# Create an empty container for expanding over the whole empty area.
	var empty_container := MarginContainer.new()
	empty_container.add_theme_constant_override("margin_left", 6)
	empty_container.add_theme_constant_override("margin_top", 6)
	empty_container.add_theme_constant_override("margin_right", 6)
	empty_container.add_theme_constant_override("margin_bottom", 6)
	empty_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Create an empty label.
	var empty_label := Label.new()
	empty_label.text = message
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add empty label as a child of the empty container.
	empty_container.add_child(empty_label)
	
	# Add empty container as a child of the existing saves container.
	saves_list_existing_saves_container.add_child(empty_container)


## Clears out all existing list entries set in the new save section.
func _clear_new_save_section() -> void:
	# Clear internal list used to aggregate all existing list entries.
	for child: Node in saves_list_new_save_section.get_children():
		if child is SaveListEntry:
			_visible_list_entries.erase(child)
	
	# Clear out all list entries children assigned to the new save section.
	_clear_container(saves_list_new_save_section)


## Clears out all existing list entries set in the existing saves container.
func _clear_existing_saves_container() -> void:
	# Clear internal list used to aggregate all existing list entries.
	for child: Node in saves_list_existing_saves_container.get_children():
		if child is SaveListEntry:
			_visible_list_entries.erase(child)
	
	# Clear out all list entries children assigned to the existing saves container.
	_clear_container(saves_list_existing_saves_container)


## Clears out all existing list entries.
func _clear_list_entries() -> void:
	# Clear out all list entries children assigned to new save section and existing saves container.
	_clear_new_save_section()
	_clear_existing_saves_container()
	
	# Clear internal list used to aggregate all existing list entries.
	_visible_list_entries.clear()


## Populates and initializes the default sort option for the list view display.
func _setup_sort_options() -> void:
	# Populate sort option items to include all sort modes.
	sort_option.add_item("Last saved - newest first", SaveUIEnums.SortMode.LAST_SAVED_DESCENDING)
	sort_option.add_item("Last saved - oldest first", SaveUIEnums.SortMode.LAST_SAVED_ASCENDING)
	sort_option.add_item("Name - A to Z", SaveUIEnums.SortMode.NAME_ASCENDING)
	sort_option.add_item("Name - Z to A", SaveUIEnums.SortMode.NAME_DESCENDING)
	sort_option.add_item("Slot - ascending", SaveUIEnums.SortMode.SLOT_ASCENDING)
	sort_option.add_item("Slot - descending", SaveUIEnums.SortMode.SLOT_DESCENDING)
	
	# Select the first sort option as the enabled by default.
	sort_option.select(0)


## Handles sort option selected signal to change the current sort mode into the selected option.
func _on_sort_option_selected(index: int) -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Set the current sort mode according to the selected option.
	_sort_mode = sort_option.get_item_id(index) as SaveUIEnums.SortMode
	
	# Update displayed status message.
	_restore_default_status()
	
	# Handle the state and rebuild the list view display to handle the changed sort mode.
	if _browse_mode == SaveUIEnums.BrowseMode.LIST_VIEW:
		_start_save_list_transition()


## Returns a list of existing save browser entries.
func _get_sorted_existing_saves() -> Array[SaveBrowserEntry]:
	# Get list of existing save browser entries.
	var entries := SaveManager.get_existing_user_saves()
	
	# Sort the list according to the set sort mode.
	entries.sort_custom(_compare_existing_entries)
	
	return entries


## Compares two saves browser entries according to the current sort mode set.
func _compare_existing_entries(a: SaveBrowserEntry, b: SaveBrowserEntry) -> bool:
	# Handle all custom sort modes.
	match _sort_mode:
		# Last saved - newest first
		SaveUIEnums.SortMode.LAST_SAVED_DESCENDING:
			if a.timestamp == b.timestamp:
				return a.slot < b.slot
			return a.timestamp > b.timestamp
			
		# Last saved - oldest first
		SaveUIEnums.SortMode.LAST_SAVED_ASCENDING:
			if a.timestamp == b.timestamp:
				return a.slot < b.slot
			return a.timestamp < b.timestamp
			
		# Name - A to Z
		SaveUIEnums.SortMode.NAME_ASCENDING:
			var comparison := a.display_name.naturalnocasecmp_to(b.display_name)
			
			if comparison == 0:
				return a.slot < b.slot
			
			return comparison < 0
			
		# Name - Z to A
		SaveUIEnums.SortMode.NAME_DESCENDING:
			var comparison := a.display_name.naturalnocasecmp_to(b.display_name)
			
			if comparison == 0:
				return a.slot < b.slot
			
			return comparison > 0
			
		# Slot - ascending
		SaveUIEnums.SortMode.SLOT_ASCENDING:
			return a.slot < b.slot
			
		# Slot - descending
		SaveUIEnums.SortMode.SLOT_DESCENDING:
			return a.slot > b.slot
	
	# Default sorting method if the current sort mode won't match any of the defined custom sortings.
	return a.slot < b.slot


## Gets first existing save for the list view according to the current sort mode. 
func _get_first_sorted_existing_save() -> SaveBrowserEntry:
	# Get list of existing save browser entries.
	var entries := _get_sorted_existing_saves()
	
	# Return null if the list doesn't contain any entries.
	if entries.is_empty():
		return null
	
	# Return first available entry.
	return entries[0]

#endregion


#region Search

## Handles changes to the list view search field.
## Provided [param text] string is the current string value assigned to the search field when the signal triggered.
func _on_search_text_changed(text: String) -> void:
	# Filter out processing if the search edit is currently being updated.
	if _updating_search_edit:
		return
	
	# Save search query inside an internal variable.
	_search_query = text.strip_edges()
	
	# Rebuild list view for the existing saves container.
	_start_save_list_transition()


## Checks whether an existing save matches the current search query.
## Returns bool value indicating if the provided [param entry] matches to the search query.
func _entry_matches_search(entry: SaveBrowserEntry) -> bool:
	# Return true if search query is empty.
	if _search_query.is_empty():
		return true
	
	return entry.display_name.containsn(_search_query)


## Resets the current state of the saves search field.
func _reset_search() -> void:
	_search_query = ""
	_search_total_count = 0
	_search_result_count = 0
	
	_updating_search_edit = true
	saves_search_edit.text = ""
	_updating_search_edit = false

#endregion


#region Save Action

## Handles save requested signal to perform and create a new save entry for the provided [param entry].
## If the provided [param entry] save is for the existing user save, then it will first await user confirmation through opened confirmation dialog.
## Provided [param display_name] and [param description] will be saved as the created save entry details. 
func _on_save_requested(entry: SaveBrowserEntry, display_name: String, description: String) -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Filter out processing if the provided save browser entry doesn't exist.
	if entry == null:
		return
	
	# Filter out processing if the provided save browser entry is not for an user created save (doesn't directly allow to overwrite an example save).
	if not entry.is_user_save():
		return
	
	# Filter out processing if the save manager operation mode isn't set to save.
	if _operation_mode != SaveUIEnums.OperationMode.SAVE:
		return
	
	# Handle overwrite save if the save browser entry already had an existing user save assigned to it.
	if entry.exists:
		# Prepare a new entry name to be displayed inside confirmation dialog.
		var name_for_message := display_name.strip_edges()
		if name_for_message.is_empty():
			name_for_message = entry.display_name
		
		# Show user the confirmation dialog and await his response.
		#TODO: make sure that a name_for_message is correct and that it shouldn't be an old name
		var confirmed := await _request_confirmation(
			"Overwrite Save",
			"Overwrite \"%s\"?" % name_for_message,
			"Overwrite",
			"Cancel",
		)
		
		# Filter out processing if the user didn't confirm the overwrite save operation.
		if not confirmed:
			return
	
	# Start save operation and await it's result.
	await _perform_save(entry, display_name, description)


## Initializes and performs a save operation for the given parameters.
func _perform_save(entry: SaveBrowserEntry, display_name: String, description: String) -> void:
	# Marks save manager as currently working on saving operation.
	_set_busy(true, "Saving...")
	
	# Initializes and awaits for the result of saving the save into a provided save browser entry slot.
	var success := await SaveManager.save_user_save(entry.slot, display_name, description, _cached_thumbnail)
	
	# Handle any issues or errors that might have occured during saving operation. 
	if not success:
		_set_busy(false, "Save failed.")
		return
	
	# Refresh currently saved selected save browser entry details. 
	_selected_entry = SaveManager.get_user_save(entry.slot)
	
	# Reset new save target if it was set before and it's for the same slot for which the save operation was just performed.
	if _has_explicit_new_save_target and _new_save_target_slot == entry.slot:
		_reset_new_save_target()
	
	# Marks save manager as no longer busy working on saving operation.
	_set_busy(false, "Saved.")
	
	# Update save manager interfaces.
	_refresh_interface()

#endregion


#region Load Action

## Handles load requested signal to perform a load operation from the provided [param entry] save.
func _on_load_requested(entry: SaveBrowserEntry) -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Filter out processing if the provided save browser entry doesn't exist.
	if entry == null:
		return
	
	# Filter out processing if the provided save browser entry doesn't have an existing user save assigned to it.
	if not entry.exists:
		return
	
	# Filter out processing if the provided save browser entry is not either the user save or an example save.
	if not entry.is_user_save() and not entry.is_example():
		return
	
	# Filter out processing if the save manager operation mode isn't set to load.
	if _operation_mode != SaveUIEnums.OperationMode.LOAD:
		return
	
	#TODO: Reserved for the later examples implementation.
	if entry.is_example():
		return
	
	# Show user the confirmation dialog and await his response.
	var confirmed := await _request_confirmation(
		"Load Save",
		"Load \"%s\"?" % entry.display_name,
		"Load",
		"Cancel",
	)
	
	# Filter out processing if the user didn't confirm the load operation.
	if not confirmed:
		return
	
	# Start load operation and await it's result.
	await _perform_load(entry)


## Initializes and performs a load operation for the given parameters.
func _perform_load(entry: SaveBrowserEntry) -> void:
	# Marks save manager as currently working on loading operation.
	_set_busy(true, "Loading...")
	
	# Initializes and awaits for the result of loading the save from the provided save browser entry slot.
	var success := await SaveManager.load_user_save(entry.slot)
	
	# Handle any issues or errors that might have occured during loading operation. 
	if not success:
		_set_busy(false, "Load failed.")
		return
	
	# Marks save manager as no longer busy working on loading operation.
	_set_busy(false, "Loaded.")
	
	# Close save manager display.
	close()

#endregion


#region Delete Action

## Handles delete requested signal to perform a delete operation on the provided [param entry] save.
func _on_delete_requested(entry: SaveBrowserEntry) -> void:
	# Filter out processing if the save manager display is currently busy working on something else or performing another transition.
	if _is_busy or _is_transitioning:
		return
	
	# Filter out processing if the provided save browser entry doesn't exist.
	if entry == null:
		return
	
	# Filter out processing if the provided save browser entry can't be deleted.
	if not entry.can_delete():
		return
	
	# Show user the confirmation dialog and await his response.
	var confirmed := await _request_confirmation(
		"Delete Save",
		"Delete \"%s\"?\n\nThis cannot be undone." % entry.display_name,
		"Delete",
		"Cancel",
	)
	
	# Filter out processing if the user didn't confirm the load operation.
	if not confirmed:
		return
	
	# Start delete operation and await it's result.
	_perform_delete(entry)


## Initializes and performs a delete operation for the given parameters.
func _perform_delete(entry: SaveBrowserEntry) -> void:
	# Marks save manager as currently working on deleting operation.
	_set_busy(true, "Deleting...")
	
	# Save slot number of save browser entry to be deleted.
	var deleted_slot := entry.slot
	
	# Initializes and awaits for the result of deleting the save from the provided save browser entry slot.
	var success := SaveManager.delete_user_save(deleted_slot)
	
	# Handle any issues or errors that might have occured during deleting operation.
	if not success:
		_set_busy(false, "Delete failed.")
		return
	
	# Select a new save browser entry after previous one was deleted.
	_select_after_delete(deleted_slot)
	
	# Marks save manager as no longer busy working on deleting operation.
	_set_busy(false, "Deleted.")
	
	# Update save manager interfaces.
	_refresh_interface()


## Marks new save browser entry as selected, after deleting a previous save entry from the provided [param deleted_slot] number.
## If save manager browse mode is set to list view, then it will select the first existing save browser entry.
## Otherwise it will try to select a slot that left after deleting it's associated save.
## If in that case the save manager operation mode would be set to load, then it will try to select a first existing save on the current slot page.
func _select_after_delete(deleted_slot: int) -> void:
	# Select a first existing save if the save manager browse mode is set to list view.
	if _browse_mode == SaveUIEnums.BrowseMode.LIST_VIEW:
		# Select an entry placeholder if the save manager operation mode is set to save, otherwise select a first existing user save.
		if _operation_mode == SaveUIEnums.OperationMode.SAVE:
			_selected_entry = SaveManager.get_new_user_save_entry()
		else:
			_selected_entry = _get_first_sorted_existing_save()
			
		return
	
	# Select the deleted slot if possible or the first slot available on the current page or first existing page if the save browser entry doesn't exist anymore for the deleted slot or the current page doesn't have any more existing saves.
	if _browse_mode == SaveUIEnums.BrowseMode.SLOT_VIEW:
		# Select the deleted slot if the save manager operation mode is set to save, since it will still be available.
		if _operation_mode == SaveUIEnums.OperationMode.SAVE:
			_current_page = _get_page_for_slot(deleted_slot)
			_selected_entry = SaveManager.get_user_slot_entry(deleted_slot)
			return

		# Change the current page if there aren't any more existing saves on the current one.
		var pages := _get_available_page_numbers()
		if not pages.has(_current_page):
			if pages.size() > 0:
				_current_page = pages[0]
			else:
				_current_page = FIRST_PAGE
		
		# Get first existing save on the current page. 
		_selected_entry = _get_first_existing_save_on_page(_current_page)
		
		return
	
	# Clear the selected entry if the save manager browse mode is set to some other mode than list view or slot view.
	_selected_entry = null
	return

#endregion


#region Confirmation

## Checks if there aren't any other pending confirmation dialogs and creates a new one if that's case.
## All provided parameters are used as call parameters for requesting confirmation dialog.
func _request_confirmation(title: String, message: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel", focus_cancel: bool = false) -> bool:
	# Filter out processing if there is already an existing confirmation pending.
	if _confirmation_pending:
		return false
	
	# Mark confirmation as currently pending.
	_confirmation_pending = true
	
	# Show user the confirmation dialog and await his response.
	var confirmed := await confirmation_dialog.request_confirmation(
		title,
		message,
		confirm_text,
		cancel_text,
		focus_cancel,
	)
	
	# Mark confirmation as no longer pending.
	_confirmation_pending = false
	
	return confirmed


## Warns user if there would so unsaved changes in the save details that he might lose if he decides to proceed.
## Opens up the confirmation dialog for user to decide if he want to lose the unsaved changes and returns his decision.
## Returns true if there aren't any unsaved changes.
func _confirm_discard_unsaved_changes(action_message: String) -> bool:
	# No confirmation is required if the displayed save details don't have any unsaved changes.
	if not save_details.has_unsaved_changes():
		return true
	
	# Warn user that there are some unsaved changes that he might lose if he decides to proceed.
	return await _request_confirmation(
		"Unsaved Changes",
		"You have unsaved changes to this save's details.\n\n%s" % action_message,
		"Discard Changes",
		"Cancel",
		true,
	)

#endregion


#region Transitions

## Sets flag whether the save manager is currently performing a visual transition to the provided [param transitioning] flag.
func _set_transitioning(transitioning: bool) -> void:
	_is_transitioning = transitioning


## Fades the save manager display target opacity to the provided [param target_alpha] value over the provided [param duration] in seconds.
func _fade_display_to(target_alpha: float, duration: float) -> void:
	# Kill existing animation if it does exist.
	if _display_transition_tween != null and _display_transition_tween.is_valid():
		_display_transition_tween.kill()
	_display_transition_tween = null
	
	# Filter out processing if the display already uses the target opacity.
	if is_equal_approx(modulate.a, target_alpha):
		return
	
	# Create tween for the animation.
	_display_transition_tween = create_tween()
	_display_transition_tween.set_trans(Tween.TRANS_QUAD)
	_display_transition_tween.set_ease(Tween.EASE_OUT)
	
	# Animate styles.
	_display_transition_tween.tween_property(self, "modulate:a", target_alpha, duration)
	
	# Wait until transition finishes.
	await _display_transition_tween.finished
	
	# Remove assigned transition after it has finished.
	_display_transition_tween = null


## Immediately sets the save manager display opacity to the provided [param alpha] value.
func _set_display_alpha(alpha: float) -> void:
	var display_modulate := modulate
	display_modulate.a = alpha
	modulate = display_modulate


## Initialize and start save list transition to animate fade out and in animation for the list save browser entries.
func _start_save_list_transition() -> void:
	# Kill existing animation if it does exist.
	if _saves_list_transition_tween != null and _saves_list_transition_tween.is_valid():
		_saves_list_transition_tween.kill()
	_saves_list_transition_tween = null
	
	# Create tween for the animation.
	var tween := create_tween()
	_saves_list_transition_tween = tween
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Animate styles.
	tween.tween_property(saves_list_existing_saves_container, "modulate:a", 0.0, transition_entry_fade_out_duration)
	
	# Set callback function to trigger after transition ends.
	tween.tween_callback(_refresh_save_list_after_transition)
	
	# Fade in the latest results.
	tween.tween_property(saves_list_existing_saves_container, "modulate:a", 1.0, transition_entry_fade_in_duration)
	
	# Set signal handler to detect finished transition.
	tween.finished.connect(_on_save_list_transition_finished.bind(tween))


## Rebuilds the current search results while they are invisible.
func _refresh_save_list_after_transition() -> void:
	_rebuild_existing_saves_container()
	_update_selection_highlights()
	_apply_interaction_state()
	_restore_default_status()


## Handles save list transition tween finished signal to mark it as done.
## Uses provided [param finished_tween] whether it's the same tween as the one currently active and if yes, then it clears it.
func _on_save_list_transition_finished(finished_tween: Tween) -> void:
	if _saves_list_transition_tween == finished_tween:
		_saves_list_transition_tween = null


## Stops the search/saves list transition and resotres normal visibility.
func _reset_save_list_transition() -> void:
	# Kill existing animation if it does exist.
	if _saves_list_transition_tween != null and _saves_list_transition_tween.is_valid():
		_saves_list_transition_tween.kill()
	_saves_list_transition_tween = null
	
	# Immediately sets the opacity styles to the node.
	var container_modulate := saves_list_existing_saves_container.modulate
	container_modulate.a = 1.0
	saves_list_existing_saves_container.modulate = container_modulate


## Fades the saves slot grid to the provided target opacity [param target_alpha] over the provided [param duration] in seconds.
func _fade_slot_grid_to(target_alpha: float, duration: float) -> void:
	# Kill existing animation if it does exist.
	if _saves_slot_transition_tween != null and _saves_slot_transition_tween.is_valid():
		_saves_slot_transition_tween.kill()
	_saves_slot_transition_tween = null
	
	# Filter out processing if the slot grid already uses the target opacity.
	if is_equal_approx(slot_grid.modulate.a, target_alpha):
		return
	
	# Create tween for the animation.
	var tween := create_tween()
	_saves_slot_transition_tween = tween
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Animate styles.
	tween.tween_property(slot_grid, "modulate:a", target_alpha, duration)
	
	# Wait until transition finishes.
	await tween.finished
	
	# Remove assigned transition after it has finished.
	if _saves_slot_transition_tween == tween:
		_saves_slot_transition_tween = null

#endregion


#region Busy State

## Sets save manager busy state using the provided [param busy] and sets the status message using the provided [param status] text.
func _set_busy(busy: bool, status: String = "") -> void:
	# Set busy state of the save manager.
	_is_busy = busy
	
	# Update displayed status message.
	_set_status(status)
	
	# Update state of user interactive elements of the display.
	_apply_interaction_state()


## Updates interaction state of save manager display buttons based on the busy state of save manager along with it's operating mode.
func _apply_interaction_state() -> void:
	# Check what should be the interaction state.
	var interaction_blocked: bool = _is_busy
	
	# Update disabled state of close button.
	close_button.disabled = interaction_blocked
	
	# Update disabled state of view modes buttons.
	slot_view_button.disabled = interaction_blocked
	list_view_button.disabled = interaction_blocked
	
	# Update disabled state of sort option button/options for the list view.
	sort_option.disabled = interaction_blocked
	
	# Update editable state of the search field for the save list view.
	saves_search_edit.editable = not interaction_blocked
	
	# Update disabled state of slot entry buttons inside the slot entries container.
	for slot_entry: SaveSlotEntry in _visible_slot_entries:
		if interaction_blocked:
			slot_entry.disabled = true
		else:
			slot_entry.disabled = _operation_mode == SaveUIEnums.OperationMode.LOAD and not slot_entry.entry.exists
	
	# Update disabled state of list entry buttons inside the list entries container.
	for list_entry: SaveListEntry in _visible_list_entries:
		list_entry.disabled = interaction_blocked
	
	# Update disabled state of the page buttons inside the pagination container.
	for child: Node in page_buttons.get_children():
		if child is Button:
			child.disabled = interaction_blocked
	
	# Update disabled state of the pagination buttons inside the slot view pagination container.
	if interaction_blocked:
		previous_page_button.disabled = true
		next_page_button.disabled = true
	else:
		_update_pagination_navigation()
	
	# Update user interactions inside save details scene.
	save_details.set_interaction_enabled(not interaction_blocked)

#endregion


#region Status

## Sets a new status label text using the provided [param text].
func _set_status(text: String) -> void:
	status_label.text = text


## Restores the passive/default status message contents.
## Search results are displayed while an active search exists in list view.
func _restore_default_status() -> void:
	# Set status message as the search results if the browse mode is set to list view and there exists a search query that isn't empty.
	if _browse_mode == SaveUIEnums.BrowseMode.LIST_VIEW and not _search_query.is_empty():
		_set_status("%d of %d saves found." % [_search_result_count, _search_total_count])
		return
	
	_set_status("")

#endregion


#region Close Button

## Handles close button pressed signal to manage closing down of the save manager display.
func _on_close_button_pressed() -> void:
	await request_close()

#endregion


#region Helpers

## Clears and frees all children node instances from the provided [param container].
func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

#endregion
