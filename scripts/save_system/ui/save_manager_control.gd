class_name SaveManagerControl
extends Control


const FIRST_PAGE: int = 1
const FIRST_SLOT: int = 1
const SLOTS_PER_PAGE: int = 5


@export var save_slot_entry_scene: PackedScene
@export var save_list_entry_scene: PackedScene


@onready var title_label: Label = $OuterMargin/MainPanel/MainContents/Header/TitleLabel
@onready var slot_view_button: Button = $OuterMargin/MainPanel/MainContents/Header/SlotViewButton
@onready var list_view_button: Button = $OuterMargin/MainPanel/MainContents/Header/ListViewButton
@onready var close_button: Button = $OuterMargin/MainPanel/MainContents/Header/CloseButton

@onready var slot_view: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView
@onready var slot_grid: GridContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotScroll/SlotGrid
@onready var previous_page_button: Button = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/PreviousPageButton
@onready var page_buttons: HBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/PageButtons
@onready var next_page_button: Button = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/SlotView/SlotPagination/NextPageButton

@onready var list_view: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView
@onready var sort_option: OptionButton = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SortRow/SortOption
@onready var saves_list: VBoxContainer = $OuterMargin/MainPanel/MainContents/Content/LeftPanel/LeftMargin/LeftContents/ListView/SavesScroll/SavesList

@onready var save_details: SaveDetails = $OuterMargin/MainPanel/MainContents/Content/SaveDetails
@onready var status_label: Label = $OuterMargin/MainPanel/MainContents/StatusLabel
@onready var confirmation_dialog: ModalConfirmationDialog = $ModalConfirmationDialog


var _operation_mode: SaveUIEnums.OperationMode = SaveUIEnums.OperationMode.LOAD
var _browse_mode: SaveUIEnums.BrowseMode = SaveUIEnums.BrowseMode.LIST_VIEW
var _sort_mode: SaveUIEnums.SortMode = SaveUIEnums.SortMode.LAST_SAVED_DESCENDING

var _current_page: int = FIRST_PAGE
var _selected_entry: SaveBrowserEntry = null

var _cached_screenshot: Image = null

var _tree_was_paused: bool = false
var _is_busy: bool = false

var _visible_slot_entries: Array[SaveSlotEntry] = []
var _visible_list_entries: Array[SaveListEntry] = []


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
	
	# Connect list view nodes signals.
	sort_option.item_selected.connect(_on_sort_option_selected)
	
	# Connect save details scene signals.
	save_details.save_requested.connect(_on_save_requested)
	save_details.load_requested.connect(_on_load_requested)
	save_details.delete_requested.connect(_on_delete_requested)
	
	# Populate and initialize the sort options for the list view display.
	_setup_sort_options()
	
	# Initialize status label initial text.
	status_label.text = ""
	
	# Make sure that save manager control is hidden by default.
	visible = false


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
	_cached_screenshot = screenshot
	
	# Set save manager as not busy.
	_is_busy = false
	
	# Reset status label text.
	status_label.text = ""
	
	# Refresh and initialize save browser entries.
	SaveManager.refresh_user_saves()
	
	# Set the selected save browser entry as the first one available.
	#_selected_entry = SaveManager.get_user_slot_entry(FIRST_SLOT)
	_selected_entry = _get_first_sorted_existing_save()
	
	# Set display title label text.
	title_label.text = "Save Game"
	
	# Make the display visible.
	visible = true
	
	# Set the tree paused state as true.
	get_tree().paused = true
	
	# Update save manager interfaces.
	_refresh_interface()


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
	_cached_screenshot = null
	
	# Set save manager as not busy.
	_is_busy = false
	
	# Reset status label text.
	status_label.text = ""
	
	# Refresh and initialize save browser entries.
	SaveManager.refresh_user_saves()
	
	# Set the selected save browser entry as the first one available.
	#_selected_entry = SaveManager.get_user_slot_entry(FIRST_SLOT)
	_selected_entry = _get_first_sorted_existing_save()
	
	# Set display title label text.
	title_label.text = "Load Game"
	
	# Make the display visible.
	visible = true
	
	# Set the tree paused state as true.
	get_tree().paused = true
	
	# Update save manager interfaces.
	_refresh_interface()


## Closes save manager display.
func close() -> void:
	# Filter out processing if the save manager display is already closed.
	if not visible:
		return
	
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Make the display hidden.
	visible = false
	
	# Set the save manager internal display state.
	_cached_screenshot = null
	_selected_entry = null
	
	# Reset status label text.
	status_label.text = ""
	
	# Clear save details scene.
	save_details.clear_details()
	
	# Clear all save browser entries.
	_clear_slot_entries()
	_clear_list_entries()
	_clear_container(page_buttons)
	
	# Return tree paused state to what was set before opening the save manager display.
	get_tree().paused = _tree_was_paused

#endregion


#region Interface Refresh

## Updates state of display interfaces that might change based on internal fields values like browse mode or other user selected settings.
func _refresh_interface() -> void:
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
	_update_details()
	
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
func _update_details() -> void:
	# Clear save details if there isn't any save browser entry set as selected.
	if _selected_entry == null:
		save_details.clear_details()
		return
	
	# Show save browser entry set as selected.
	save_details.show_entry(_selected_entry, _operation_mode, _cached_screenshot)

#endregion


#region Browse Mode

## Handles slot view button pressed signal to set the save manager browse mode to slot view.
func _on_slot_view_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Update displayed status message.
	_set_status("")
	
	# Set slot view browse mode.
	_set_browse_mode(SaveUIEnums.BrowseMode.SLOT_VIEW)


## Handles list view button pressed signal to set the save manager browse mode to list view.
func _on_list_view_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Update displayed status message.
	_set_status("")
	
	# Set list view browse mode.
	_set_browse_mode(SaveUIEnums.BrowseMode.LIST_VIEW)


## Sets a [param new_mode] for the browser, updates selected save entry for it and refreshes itnerfaces that might have been affected by the changes.
func _set_browse_mode(new_mode: SaveUIEnums.BrowseMode) -> void:
	#TODO: Reserved for the later implementation of examples view.
	if new_mode == SaveUIEnums.BrowseMode.EXAMPLES_VIEW:
		return
	
	# Update view mode buttons and filter out processing if the new selected browse mode is the same as the one already set.
	if _browse_mode == new_mode:
		_update_view_buttons()
		return
	
	# Save new browse mode.
	_browse_mode = new_mode
	
	# Set selected save entry depending on the browse mode.
	match _browse_mode:
		SaveUIEnums.BrowseMode.SLOT_VIEW:
			_prepare_selection_for_slot_view()
		SaveUIEnums.BrowseMode.LIST_VIEW:
			_prepare_selection_for_list_view()
	
	# Update save manager interfaces.
	_refresh_interface()


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
		_selected_entry = SaveManager.get_new_user_save_entry()
		return
	
	# Otherwise set the first sorted save browser entry as the one selected. 
	_selected_entry = _get_first_sorted_existing_save()

#endregion


#region Selection

## Sets provided [param entry] as the selected one and updates the display elements dependant on the selected entry.
func _select_entry(entry: SaveBrowserEntry) -> void:
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Set entry as the selected one.
	_selected_entry = entry
	
	# Update displayed status message.
	_set_status("")
	
	# Update save details display.
	_update_details()
	
	# Updated selected entry highlight.
	_update_selection_highlights()


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
	
	# Set current page counter to first one if current page counter doesn't belong to any page that exists for the existing saves. 
	var pages := _get_available_page_numbers()
	if not pages.has(_current_page):
		_current_page = FIRST_PAGE


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

## Rebuilds pagination controls by clearing out existing ones and populating new ones based on the available pages for which saves exist.
func _rebuild_pagination() -> void:
	# Clear out existing page buttons.
	_clear_container(page_buttons)
	
	# Get list of available page numbers for which saves exist or that should be available in navigation.
	var pages := _get_available_page_numbers()
	
	# Populate page buttons for each page on the list.
	for page: int in pages:
		# Create new button.
		var button := Button.new()
		
		# Initialize button state and display.
		button.text = str(page)
		button.toggle_mode = true
		
		# Set button pressed state based on current page number and the button page number.
		button.button_pressed = page == _current_page
		
		# Connect button pressed signal to the local handler function.
		button.pressed.connect(_on_page_number_pressed.bind(page))
		
		# Add the page button to the page container.
		page_buttons.add_child(button)
	
	# Update state of the pagination buttons along with their interactions.
	_update_pagination_navigation()


## Returns a list of available page numbers based on the existing saves.
func _get_available_page_numbers() -> Array[int]:
	# Prepare a dictionary for marking which pages exist for the existing saves.
	var page_set: Dictionary[int, bool] = {1: true}
	var saves := SaveManager.get_existing_user_saves()
	for entry: SaveBrowserEntry in saves:
		page_set[_get_page_for_slot(entry.slot)] = true
	
	# Mark the current page as existing if the save manager operation mode is set to save nad the current page isn't listed in the page set.
	# This situation will happen in save mode, if the user will visit pages without any existing saves.
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
	# Filter out processing if the save manager display is busy working on something else.
	if _is_busy:
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
	# Filter out processing if the save manager display is busy working on something else.
	if _is_busy:
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


## Handles page number button pressed signal to change the displayed page to the provided [param page] number.
func _on_page_number_pressed(page: int) -> void:
	# Filter out processing if the save manager display is busy working on something else.
	if _is_busy:
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
	
	# Set the new current page number.
	_current_page = page
	
	# Select the default entry on the current page as the one selected.
	_select_default_entry_for_current_page()
	
	# Update displayed status message.
	_set_status("")
	
	# Update save manager interfaces.
	_refresh_interface()

#endregion


#region List View

## Rebuilds save list view by clearing out existing list entries and populating new ones.
func _rebuild_list_view() -> void:
	# Clear out existing slot entries.
	_clear_list_entries()
	
	# Get list of existing save browser entries.
	var entries := _get_sorted_existing_saves()
	
	# Create a save browser entry placeholder to act as an option to create a new save on top of the list if the save manager operation mode is set to save.
	if _operation_mode == SaveUIEnums.OperationMode.SAVE:
		# Create a new save browser entry placeholder instance.
		var new_save_entry := SaveManager.get_new_user_save_entry()
		
		# Instantiate new list entry.
		var new_save_control := save_list_entry_scene.instantiate() as SaveListEntry
		
		# Add the list entry to the saves list container.
		saves_list.add_child(new_save_control)
		
		# Populate list entry with the save browser entry placeholder details.
		new_save_control.setup(new_save_entry)
		
		# Connect entry placeholder selected signal from the list entry to the local handler function.
		new_save_control.entry_selected.connect(_on_entry_selected)
		
		# Append created list entry placeholder to the field that aggregates all existing list entries.
		_visible_list_entries.append(new_save_control)
		
		# Create a horizontal separator and place it after the list entry placeholder if there are any existing save browser entries for the user saves.  
		if not entries.is_empty():
			var separator := HSeparator.new()
			saves_list.add_child(separator)
	
	# Prepare empty label to be put inside save list view if there wouldn't be any existing save browser entries.
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No saves found."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		saves_list.add_child(empty_label)
		return
	
	# Populate list entries for each existing save.
	for entry: SaveBrowserEntry in entries:
		# Instantiate new list entry.
		var list_control := save_list_entry_scene.instantiate() as SaveListEntry
		
		# Add the list entry to the saves list container.
		saves_list.add_child(list_control)
		
		# Populate list entry with the save browser entry details.
		list_control.setup(entry)
		
		# Connect entry selected signal from the list entry to the local handler function.
		list_control.entry_selected.connect(_on_entry_selected)
		
		# Append created list entry to the field that aggregates all existing list entries.
		_visible_list_entries.append(list_control)


## Clears out all existing list entries.
func _clear_list_entries() -> void:
	# Clear internal list used to aggregate all existing list entries.
	_visible_list_entries.clear()
	
	# Clear out all list entries children assigned to saves list container.
	_clear_container(saves_list)


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
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Set the current sort mode according to the selected option.
	_sort_mode = sort_option.get_item_id(index) as SaveUIEnums.SortMode
	
	# Update displayed status message.
	_set_status("")
	
	# Handle the state and rebuild the list view display to handle the changed sort mode.
	if _browse_mode == SaveUIEnums.BrowseMode.LIST_VIEW:
		# Clear and repopulate the list view display.
		_rebuild_list_view()
		
		# Updated selected entry highlight.
		_update_selection_highlights()
		
		# Update state of user interactive elements of the display.
		_apply_interaction_state()


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


#region Save Action

## Handles save requested signal to perform and create a new save entry for the provided [param entry].
## If the provided [param entry] save is for the existing user save, then it will first await user confirmation through opened confirmation dialog.
## Provided [param display_name] and [param description] will be saved as the created save entry details. 
func _on_save_requested(entry: SaveBrowserEntry, display_name: String, description: String) -> void:
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
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
		var confirmed := await confirmation_dialog.request_confirmation(
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
	var success := await SaveManager.save_user_save(entry.slot, display_name, description, _cached_screenshot)
	
	# Handle any issues or errors that might have occured during saving operation. 
	if not success:
		_set_busy(false, "Save failed.")
		return
	
	# Refresh currently saved selected save browser entry details. 
	_selected_entry = SaveManager.get_user_save(entry.slot)
	
	# Marks save manager as no longer busy working on saving operation.
	_set_busy(false, "Saved.")
	
	# Update save manager interfaces.
	_refresh_interface()

#endregion


#region Load Action

## Handles load requested signal to perform a load operation from the provided [param entry] save.
func _on_load_requested(entry: SaveBrowserEntry) -> void:
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
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
	var confirmed := await confirmation_dialog.request_confirmation(
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
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Filter out processing if the provided save browser entry doesn't exist.
	if entry == null:
		return
	
	# Filter out processing if the provided save browser entry can't be deleted.
	if not entry.can_delete():
		return
	
	# Show user the confirmation dialog and await his response.
	var confirmed := await confirmation_dialog.request_confirmation(
		"Delete Save",
		"Delete \"%s\"?\n\nThis cannot be undone.",
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
	# Update disabled state of close button.
	close_button.disabled = _is_busy
	
	# Update disabled state of view modes buttons.
	slot_view_button.disabled = _is_busy
	list_view_button.disabled = _is_busy
	
	# Update disabled state of sort option button/options for the list view.
	sort_option.disabled = _is_busy
	
	# Update disabled state of slot entry buttons inside the slot entries container.
	for slot_entry: SaveSlotEntry in _visible_slot_entries:
		if _is_busy:
			slot_entry.disabled = true
		else:
			slot_entry.disabled = _operation_mode == SaveUIEnums.OperationMode.LOAD and not slot_entry.entry.exists
	
	# Update disabled state of list entry buttons inside the list entries container.
	for list_entry: SaveListEntry in _visible_list_entries:
		list_entry.disabled = _is_busy
	
	# Update disabled state of the page buttons inside the pagination container.
	for child: Node in page_buttons.get_children():
		if child is Button:
			child.disabled = _is_busy
	
	# Update disabled state of the pagination buttons inside the slot view pagination container.
	if _is_busy:
		previous_page_button.disabled = true
		next_page_button.disabled = true
	else:
		_update_pagination_navigation()
	
	# Update user interactions inside save details scene.
	save_details.set_interaction_enabled(not _is_busy)

#endregion


#region Status

## Sets a new status label text using the provided [param text].
func _set_status(text: String) -> void:
	status_label.text = text

#endregion


#region Close Button

## Handles close button pressed signal to manage closing down of the save manager display.
func _on_close_button_pressed() -> void:
	# Filter out processing if the save manager display is currently busy working on something else.
	if _is_busy:
		return
	
	# Close save manager display.
	close()

#endregion


#region Helpers

## Clears and frees all children node instances from the provided [param container].
func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

#endregion
