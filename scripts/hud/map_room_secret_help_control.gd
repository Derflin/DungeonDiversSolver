class_name MapRoomSecretHelpControl
extends Control


## Emitted when the highlighted room entry changes or its pinned state is updated.
signal active_entry_changed(entry: MapParameterEntry, pinned: bool)


## Determine whether help is hidden, temporarily previewed, or pinned open.
enum HelpMode {
	HIDDEN,
	PREVIEW,
	PINNED,
}

## Tolerance used when comparing scroll range with its visible page length.
const SCROLL_OVERFLOW_EPSILON: float = 0.5


@export_group("Layout", "layout_")
## Preferred panel width measured in unscaled HUD units.
@export var layout_preferred_width: float = 260.0
## Smallest panel width allowed before hiding the help panel.
@export var layout_minimum_width: float = 130.0
## Minimum space kept between the panel and viewport edges, in viewport pixels.
@export var layout_viewport_margin: float = 12.0
## Horizontal distance from the drawer to the help panel, in viewport pixels.
@export var layout_drawer_gap: float = 8.0
## Minimum height reserved for the description viewport, in unscaled HUD units.
@export var layout_minimum_description_height: float = 18.0

@export_group("Content Rendering", "content_")
## Width of the room icons inserted into help text, in unscaled HUD units.
@export var content_inline_icon_width: float = 16.0
## Separation between a block heading and its description or image.
@export_range(0, 16, 1) var content_item_separation: int = 2
## Text tint used for RULE and TIP headings.
@export var content_heading_color: Color = Color(0.75, 0.75, 0.75)

@export_group("Interaction", "interaction_")
## Delay before closing a preview after leaving the active entry and panel.
@export var interaction_preview_close_delay: float = 0.16

@export_group("Transitions", "transition_")
## Duration of showing and hiding the complete floating panel.
@export var transition_visibility_duration: float = 0.16
## Duration of fading out the previous description before replacing it.
@export var transition_content_fade_out_duration: float = 0.08
## Duration of revealing the description after a room switch.
@export var transition_content_fade_in_duration: float = 0.14
## Duration of the panel height and position animation.
@export var transition_layout_duration: float = 0.22
## Duration of changing the description scrollbar's opacity.
@export var transition_scroll_bar_fade_duration: float = 0.12


# Currently displayed resource, its source entry, and the drawer used for positioning.
var _mode: HelpMode = HelpMode.HIDDEN
var _active_room: RoomSecretType
var _active_entry: MapParameterEntry
var _drawer_panel: Control
var _ui_scale: float = 1.0

# Request counters invalidate delayed work from superseded transitions and close checks.
var _transition_id: int = 0
var _close_id: int = 0
var _close_scheduled: bool = false

# Independent tweens prevent opacity, content and geometry animations from conflicting.
var _visibility_tween: Tween
var _content_tween: Tween
var _layout_tween: Tween
var _bar_tween: Tween

# Cache scrollbar visibility so range changes don't restart identical fades.
var _scroll_bar_state_initialized: bool = false
var _scroll_bar_required: bool = false

# Compiled matcher used to resolve inline references to secret and special rooms.
var _reference_regex: RegEx


@onready var help_panel: PanelContainer = $HelpPanel
@onready var panel_margin: MarginContainer = $HelpPanel/MarginContainer
@onready var panel_vbox: VBoxContainer = $HelpPanel/MarginContainer/VBoxContainer
@onready var header: HBoxContainer = $HelpPanel/MarginContainer/VBoxContainer/HeaderContainer
@onready var header_room_icon: ScrambleTextureRect = $HelpPanel/MarginContainer/VBoxContainer/HeaderContainer/RoomIcon
@onready var header_room_name: ScrambleLabel = $HelpPanel/MarginContainer/VBoxContainer/HeaderContainer/RoomName
@onready var separator: HSeparator = $HelpPanel/MarginContainer/VBoxContainer/HSeparator
@onready var scroll_container: SmoothScrollContainer = $HelpPanel/MarginContainer/VBoxContainer/DescriptionRegion/DescriptionScrollContainer
@onready var description_contents: VBoxContainer = $HelpPanel/MarginContainer/VBoxContainer/DescriptionRegion/DescriptionScrollContainer/DescriptionContents
@onready var description_scroll_bar: SmoothScrollBar = $HelpPanel/MarginContainer/VBoxContainer/DescriptionRegion/DescriptionScrollBar


#region Initialization

## Initializes panel visibility, scrollbar synchronization, inline reference parsing and viewport listeners.
func _ready() -> void:
	# Keep the visual panel hidden by default.
	help_panel.hide()
	help_panel.modulate.a = 0.0
	
	# Synchronize the external scrollbar with the description container's scroll range.
	description_scroll_bar.share(scroll_container.get_v_scroll_bar())
	description_scroll_bar.modulate.a = 0.0
	scroll_container.get_v_scroll_bar().changed.connect(_update_scroll_bar_state)
	
	# Compile the token pattern once for each description's inline room reference.
	_reference_regex = RegEx.new()
	var error: Error = _reference_regex.compile("\\{(room|icon|name):(secret|special):([A-Za-z0-9_]+)\\}")
	assert(error == OK, "MapRoomSecretHelpControl: Could not compile help room reference pattern")
	
	# Connect the viewport size changed signal to handle resizing of the panel.
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Populate room scramble texture.
	_fill_scramble_textures()


## Populates the icon scramble pool from the loaded secret-room catalog.
func _fill_scramble_textures() -> void:
	var icons: Array[Texture2D] = []
	
	# Collect usable static textures for intermediate header animation frames.
	for room: RoomSecretType in GameData.room_secret_types.get_all():
		if room == null:
			continue
		
		var texture: Texture2D = room.get_static_texture()
		if texture != null:
			icons.append(texture)
	
	# Supply the complete pool to the header's scramble control.
	header_room_icon.scramble_textures = icons

#endregion


#region Public Help Interface

## Returns whether a room description is retained by explicit activation.
func is_pinned() -> bool:
	return _mode == HelpMode.PINNED


## Returns whether a room is actively displayed in preview or pinned mode.
func is_open() -> bool:
	return _mode != HelpMode.HIDDEN


## Returns the parameter entry associated with the active room description.
func get_active_entry() -> MapParameterEntry:
	return _active_entry


## Returns whether the given viewport position is within the visible help panel.
func contains_viewport_point(viewport_position: Vector2) -> bool:
	# Return false if the help panel isn't currently visible.
	if not help_panel.visible:
		return false
	
	# Convert the viewport position to local one and check if it lies inside the help panel.
	var local: Vector2 = help_panel.make_canvas_position_local(viewport_position)
	return Rect2(Vector2.ZERO, help_panel.size).has_point(local)


## Displays temporary help unless a pinned selection is already active.
func request_preview(room: RoomSecretType, entry: MapParameterEntry, drawer: Control, ui_scale: float) -> void:
	# Filter out processing if help panel is already pinned or there isn't a valid help description available for the room.
	if is_pinned() or not _is_valid_help(room):
		return
	
	# Display the help panel in preview mode.
	_mode = HelpMode.PREVIEW
	_select_room(room, entry, drawer, ui_scale)


## Pins a room description, switches pinned rooms, or toggles the active selection off.
func request_pin(room: RoomSecretType, entry: MapParameterEntry, drawer: Control, ui_scale: float) -> void:
	# Filter out processing if there isn't a valid help description available for the room.
	if not _is_valid_help(room):
		return
	
	# Activating the already pinned entry acts as a toggle.
	if is_pinned() and _active_entry == entry:
		dismiss()
		return
	
	# Display the help panel in pinned mode.
	_mode = HelpMode.PINNED
	_select_room(room, entry, drawer, ui_scale)


## Clears the current selection and begins the panel's hide transition.
func dismiss() -> void:
	# Filter out processing if the help panel is already in hidden mode.
	if _mode == HelpMode.HIDDEN:
		return
	
	# Set the help panel mode to hidden.
	_mode = HelpMode.HIDDEN
	
	# Invalidate delayed content and close callbacks from the previous selection.
	_transition_id += 1
	_cancel_pending_close()
	_stop_content_and_layout_tweens()
	header_room_name.cancel_animation()
	header_room_icon.cancel_animation()
	_active_room = null
	_active_entry = null
	active_entry_changed.emit(null, false)
	
	# Stop any already running visibility tween.
	_stop_tween(_visibility_tween)
	
	# Initialize hide transtion animation.
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(help_panel, "modulate:a", 0.0, transition_visibility_duration)
	_visibility_tween.tween_callback(_finish_hide)


## Cancels pending work and hides the panel without playing its transition.
func hide_immediate() -> void:
	# Set the help panel mode to hidden.
	_mode = HelpMode.HIDDEN
	
	# Invalidate delayed content and close callbacks from the previous selection.
	_transition_id += 1
	_cancel_pending_close()
	_stop_content_and_layout_tweens()
	_stop_tween(_visibility_tween)
	_stop_tween(_bar_tween)
	header_room_name.cancel_animation()
	header_room_icon.cancel_animation()
	_active_room = null
	_active_entry = null
	help_panel.modulate.a = 0.0
	help_panel.hide()
	active_entry_changed.emit(null, false)


## Recalculates the active panel after the drawer's position or scale changes.
func refresh_layout() -> void:
	_on_viewport_resized()

#endregion


#region Room Selection and Transitions

## Stores a requested room and starts its initial display or description transition.
func _select_room(room: RoomSecretType, entry: MapParameterEntry, drawer: Control, ui_scale: float) -> void:
	# Determine whether a description must be built for the first time or replaced.
	var first_open: bool = not help_panel.visible or _active_room == null
	var room_changed: bool = _active_room != room
	
	# Store the room, entry and drawer geometry used by later layout calculations.
	_active_room = room
	_active_entry = entry
	_drawer_panel = drawer
	_ui_scale = maxf(1.0, ui_scale)
	_cancel_pending_close()
	
	# Emit signal that hint panel active entry was changed.
	active_entry_changed.emit(entry, is_pinned())
	
	# Filter out processing if the room hasn't changed and the help panel was already opened.
	if not room_changed and not first_open:
		return
	
	# Invalidate previous transitions before starting the newest request.
	_transition_id += 1
	var request_id: int = _transition_id
	_stop_content_and_layout_tweens()
	_stop_tween(_visibility_tween)
	
	# Reject the request when the viewport cannot accommodate the minimum panel width.
	if not _update_panel_width():
		hide_immediate()
		return
	
	# Update the header immediately and select the appropriate content transition.
	help_panel.show()
	header_room_name.change_text(room.get_display_name())
	header_room_icon.change_texture(room.get_static_texture())
	if first_open:
		description_contents.modulate.a = 1.0
		_populate_description(room)
		_measure_then_layout(request_id, false, true)
	else:
		_switch_description_after_fade(room, request_id)


## Replaces description blocks after the current body has faded out.
func _switch_description_after_fade(room: RoomSecretType, request_id: int) -> void:
	# Fade out existing help description contents before replacing its dynamically generated content.
	_content_tween = create_tween()
	_content_tween.tween_property(description_contents, "modulate:a", 0.0, transition_content_fade_out_duration)
	
	# Allow the fade interval to finish before changing the content tree.
	await get_tree().create_timer(transition_content_fade_out_duration).timeout
	
	# Filter out processing if transition version has changed or if the help panel mode was changed to hidden.
	if request_id != _transition_id or _mode == HelpMode.HIDDEN:
		return
	
	# Make sure that description contents node is set fully transparent.
	description_contents.modulate.a = 0.0
	
	# Build the requested room's blocks, then recalculate the layout.
	_populate_description(room)
	_measure_then_layout(request_id, true, false)


## Measures wrapped description blocks before sizing and revealing the panel.
func _measure_then_layout(request_id: int, animate_height: bool, first_open: bool) -> void:
	# Wait for next processing frame to allow wrapped labels and containers to report their new minimum dimensions.
	await get_tree().process_frame
	
	# Filter out processing if transition version has changed or if the help panel mode was changed to hidden.
	if request_id != _transition_id or _mode == HelpMode.HIDDEN:
		return
	
	# Measure text wrapping and image dimensions using the content viewport width.
	_measure_description_content()
	
	# Apply the resulting minimum heights before determining the panel's target height.
	await get_tree().process_frame
	
	# Filter out processing if transition version has changed or if the help panel mode was changed to hidden.
	if request_id != _transition_id or _mode == HelpMode.HIDDEN:
		return
	
	_measure_description_content()
	_apply_target_layout(animate_height)
	
	# New description always start at the beginning of the scrollable body.
	_reset_scroll_to_top()
	
	# Prepare contents transition animation.
	if first_open:
		_visibility_tween = create_tween()
		_visibility_tween.tween_property(help_panel, "modulate:a", 1.0, transition_visibility_duration)
	else:
		_content_tween = create_tween()
		_content_tween.tween_property(description_contents, "modulate:a", 1.0, transition_content_fade_in_duration)


## Hides the panel after a completed dismissal while preserving newer selections.
func _finish_hide() -> void:
	if _mode == HelpMode.HIDDEN:
		help_panel.hide()


## Cancels transitions controlling description opacity and panel geometry.
func _stop_content_and_layout_tweens() -> void:
	_stop_tween(_content_tween)
	_stop_tween(_layout_tween)


## Stops a running tween while retaining values already applied to its target.
func _stop_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

#endregion


#region Preview Lifetime

## Monitors pointer presence and schedules dismissal of temporary previews.
func _process(_delta: float) -> void:
	# Filter out processing if the help panel mode is currently set to hidden.
	if _mode == HelpMode.HIDDEN or not help_panel.visible:
		return
	
	# Pinned content is controlled by activation rather than pointer position.
	if _mode == HelpMode.PINNED:
		return
	
	# Get pointer position and check whether the help panel in preview mode should still be open.
	var pointer_position: Vector2 = get_viewport().get_mouse_position()
	if _pointer_is_over_active_row_or_panel(pointer_position):
		if _close_scheduled:
			_cancel_pending_close()
	elif not _close_scheduled:
		_schedule_preview_close()


## Checks whether the pointer is inside the active row or visible help panel.
func _pointer_is_over_active_row_or_panel(viewport_position: Vector2) -> bool:
	# Check if pointer is over the help panel.
	if contains_viewport_point(viewport_position):
		return true
	
	# Check if saved active entry is valid.
	if not is_instance_valid(_active_entry):
		return false
	
	# Check if pointer is over the saved active entry.
	return _active_entry.contains_row_viewport_point(viewport_position)


## Delays closing a preview while the pointer crosses between interactive regions.
func _schedule_preview_close() -> void:
	# Mark preview close scheduled.
	_close_scheduled = true
	_close_id += 1
	var request_id: int = _close_id
	
	# Give the pointer time to cross the gap between the room entries or the panel.
	await get_tree().create_timer(interaction_preview_close_delay).timeout
	
	# Filter out processing if close version has changed.
	if request_id != _close_id:
		return
	
	# Unmark the preview close scheduled.
	_close_scheduled = false
	
	# Hide help panel if it's still in the preview mode and the current help panel doesn't need to be displayed.
	if _mode == HelpMode.PREVIEW:
		var pointer_position: Vector2 = get_viewport().get_mouse_position()
		if not _pointer_is_over_active_row_or_panel(pointer_position):
			dismiss()


## Invalidates any previously scheduled preview dismissal.
func _cancel_pending_close() -> void:
	_close_id += 1
	_close_scheduled = false

#endregion


#region Help Content

## Checks whether a room contains content supported by the current renderer.
func _is_valid_help(room: RoomSecretType) -> bool:
	return room != null and room.has_help_content()


## Rebuilds the description controls in the order stored by the room resource.
func _populate_description(room: RoomSecretType) -> void:
	# Remove the previous room's generated controls before generating new blocks.
	for child: Node in description_contents.get_children():
		description_contents.remove_child(child)
		child.queue_free()
	
	# Preserve resource order while creating supported text and image blocks..
	for block: RoomSecretHelpBlock in room.help_blocks:
		if block == null or not block.has_renderable_content():
			continue
		
		match block.block_type:
			RoomSecretHelpBlock.BlockType.RULE, RoomSecretHelpBlock.BlockType.TIP:
				_add_text_block(block)
			RoomSecretHelpBlock.BlockType.IMAGE:
				_add_image_block(block)
			RoomSecretHelpBlock.BlockType.ANIMATION:
				_add_animation_block(block)


## Creates a container for one independently spaced help-content block.
func _new_content_item() -> VBoxContainer:
	# Create a block container with independent spacing and no pointer interception.
	var item := VBoxContainer.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", content_item_separation)
	
	# Append the block in the order defined by the resource.
	description_contents.add_child(item)
	
	return item


## Creates a titled and wrapping rule or tip block.
func _add_text_block(block: RoomSecretHelpBlock) -> void:
	# Filter out processing if the block content doesn't contain any text to be displayed. 
	if block.content_text.strip_edges().is_empty():
		return
	
	# Prepare item container for the block contents.
	var item := _new_content_item()
	
	# Prepare a title label depending on the block type.
	var title_label := Label.new()
	title_label.text = "RULE" if block.block_type == RoomSecretHelpBlock.BlockType.RULE else "TIP"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.modulate = content_heading_color
	item.add_child(title_label)
	
	# Prepare a rich text label for displaying formatted content text from block.
	var content_label := RichTextLabel.new()
	content_label.bbcode_enabled = false
	content_label.fit_content = false
	content_label.custom_minimum_size.y = 0.0
	content_label.scroll_active = false
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(content_label)
	
	# Resolve room references while filling the text control.
	_append_text_with_room_references(content_label, block.content_text)


## Creates a proportional static illustration and optional caption.
func _add_image_block(block: RoomSecretHelpBlock) -> void:
	# Filter out processing if the block doesn't contain any image assigned to itself.
	if block.content_media_image == null:
		return
	
	# Prepare item container for the block contents.
	var item := _new_content_item()
	
	# Prepare a image texture rect and adjust it's size to be centered and keep aspect ratio.
	var image_rect := TextureRect.new()
	image_rect.texture = block.content_media_image
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_rect.custom_minimum_size = Vector2.ONE
	item.add_child(image_rect)
	
	# Add descriptive caption for image.
	_add_media_caption(item, block.content_media_caption)


## Creates an animated illustration using the frames and caption assigned to the help block.
func _add_animation_block(block: RoomSecretHelpBlock) -> void:
	# Skip blocks without an available frame animation.
	if not block.has_renderable_content():
		return
	
	# Prepare item container for the block contents.
	var item: VBoxContainer = _new_content_item()
	
	# Prepare an animation rect and configure it.
	var animation_rect := RoomSecretHelpAnimationRect.new()
	animation_rect.custom_minimum_size = Vector2.ONE
	item.add_child(animation_rect)
	
	animation_rect.configure(block.content_media_animation_frames, block.content_media_animation_name)
	
	# Add descriptive caption for animation.
	_add_media_caption(item, block.content_media_caption)


## Adds an optional wrapping caption beneath a help illustration.
func _add_media_caption(item: VBoxContainer, caption_text: String) -> void:
	# Skip empty captions.
	if caption_text.strip_edges().is_empty():
		return
	
	# Prepare a descriptive caption label.
	var caption := Label.new()
	caption.text = caption_text
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(caption)


## Renders text with room icons and names resolved from the current catalogs.
func _append_text_with_room_references(label: RichTextLabel, source: String) -> void:
	# Reset the rich-text stack and prepare to copy literal spans.
	label.clear()
	var cursor: int = 0
	
	# Process placeholders from left to right while preserving surrounding text.
	for reference: RegExMatch in _reference_regex.search_all(source):
		# Append span before the found reference.
		label.add_text(source.substr(cursor, reference.get_start() - cursor))
		
		# Unpack found reference.
		var operation: String = reference.get_string(1)
		var catalog: String = reference.get_string(2)
		var room_id: String = reference.get_string(3)
		
		# Retrieve the referenced room resource from its owning catalog.
		var room: Variant = null
		if catalog == "secret":
			room = GameData.room_secret_types.get_type_by_id(room_id)
		elif catalog == "special":
			room = GameData.room_special_types.get_type_by_id(room_id)
		
		# Include the referenced room type data inside the label.
		if room == null:
			# Show a readable fallback when an identifier cannot be resolved.
			push_warning("MapRoomSecretHelpControl: Unresolved help reference: %s" % reference.get_string())
			label.add_text("[unknown room: %s]" % room_id)
		else:
			# Insert the icon for references that request it.
			if operation == "room" or operation == "icon":
				var icon_texture: Texture2D = room.get_static_texture()
				if icon_texture != null:
					label.add_image(icon_texture, maxi(1, roundi(content_inline_icon_width)), 0)
				else:
					push_warning("MapRoomSecretHelpControl: Help reference has no icon: %s" % room_id)
			
			# Add the display name only for name or combined references.
			if operation == "room":
				label.add_text(" " + room.get_display_name())
			elif operation == "name":
				label.add_text(room.get_display_name())
		
		# Get next cursor index.
		cursor = reference.get_end()
	
	# Preserve any literal text following the last placeholder.
	label.add_text(source.substr(cursor))

#endregion


#region Panel Geometry

## Fits the panel's preferred width into the available space beside the drawer.
func _update_panel_width() -> bool:
	# Filter out processing if the saved drawer panel isn't valid.
	if not is_instance_valid(_drawer_panel):
		return false
	
	# Calculate free viewport space between the drawer and the left margin.
	var available_pixels: float = _drawer_panel.get_global_rect().position.x - layout_viewport_margin - layout_drawer_gap
	var width_1x: float = floorf(minf(layout_preferred_width, available_pixels / _ui_scale))
	
	# Filter out processing if there isn't enough space to fit the minimum panel width.
	if width_1x < layout_minimum_width:
		return false
	
	# Set the panel width and scale.
	help_panel.scale = Vector2.ONE * _ui_scale
	help_panel.size.x  = width_1x
	
	return true


## Sizes generated text and image blocks using the description viewport width.
func _measure_description_content() -> void:
	# Use the width assigned by the container after the current panel layout pass.
	var available_width: float = maxf(1.0, scroll_container.size.x)
	description_contents.custom_minimum_size.x = available_width
	
	# Update the minimum height of every generated block at the available width.
	for item_node: Node in description_contents.get_children():
		if not item_node is VBoxContainer:
			continue
		
		for child_node: Node in item_node.get_children():
			if child_node is RichTextLabel:
				var text_label: RichTextLabel = child_node
				
				# Establish wrapping width before reading the formatted text height.
				text_label.custom_minimum_size.y = 0.0
				text_label.size.x = available_width
				text_label.custom_minimum_size.y = maxf(1.0, ceilf(float(text_label.get_content_height())))
				
			elif child_node is RoomSecretHelpAnimationRect:
				var animation_rect: RoomSecretHelpAnimationRect = child_node
				
				# Reserve enough space for the largest frame without stretching it.
				var frame_size: Vector2 = animation_rect.get_natural_size()
				var shown_width: float = minf(available_width, frame_size.x)
				var shown_height: float = frame_size.y * shown_width / maxf(1.0, frame_size.x)
				animation_rect.custom_minimum_size = Vector2(ceilf(shown_width), ceilf(shown_height))
				
			elif child_node is TextureRect:
				var image_rect: TextureRect = child_node
				if image_rect.texture == null:
					continue
				
				# Fit the illustration inside the same viewport without stretching it.
				var image_size: Vector2 = image_rect.texture.get_size()
				var image_width: float = minf(available_width, image_size.x)
				var image_height: float = image_size.y * image_width / maxf(1.0, image_size.x)
				image_rect.custom_minimum_size = Vector2(ceilf(image_width), ceilf(image_height))


## Returns the height required by the content, bounded by viewport margins.
func _get_target_height() -> float:
	# Gather the minimum heights of the header, separator and measured body.
	var margin_height: float = panel_margin.get_theme_constant("margin_top") + panel_margin.get_theme_constant("margin_bottom")
	var container_spacing: float = panel_vbox.get_theme_constant("separation") * 2.0
	var content_height: float = description_contents.get_combined_minimum_size().y
	var header_height: float = header.get_combined_minimum_size().y
	var separator_height: float = separator.get_combined_minimum_size().y
	
	# Add the container's actual vertical insets and item spacing.
	var natural_height: float = margin_height + container_spacing + header_height + separator_height + content_height
	var viewport_available_height: float = get_viewport_rect().size.y - 2.0 * layout_viewport_margin
	
	# Limit the panel to the screen height left after top and bottom margins.
	var max_height_1x: float = maxf(1.0, viewport_available_height / _ui_scale)
	var min_height_1x: float = minf(
		max_height_1x, 
		margin_height + container_spacing + header_height + separator_height + layout_minimum_description_height
	)
	
	return ceilf(clampf(natural_height, min_height_1x, max_height_1x))


## Positions the panel beside the drawer and animates geometry when requested.
func _apply_target_layout(animate_height: bool) -> void:
	# Filter out processing if the references to the drawer panel or active entry aren't valid.
	if not is_instance_valid(_drawer_panel) or not is_instance_valid(_active_entry):
		return
	
	# Stop the previous geometry transition before applying a new target.
	_stop_tween(_layout_tween)
	var target_height: float = _get_target_height()
	
	# Position the panel to the left of the visible drawer.
	var drawer_left: float = _drawer_panel.get_global_rect().position.x
	var x: float = roundf(drawer_left - layout_drawer_gap - help_panel.size.x * _ui_scale)
	var entry_center_y: float = _active_entry.get_global_rect().get_center().y
	
	# Align vertically with the active row while staying inside viewport margins.
	var target_y: float = clampf(
		entry_center_y - target_height * _ui_scale * 0.5,
		layout_viewport_margin,
		maxf(layout_viewport_margin, get_viewport_rect().size.y - layout_viewport_margin - target_height * _ui_scale),
	)
	var target_position := Vector2(x, roundf(target_y))
	
	# Apply geometry immediately or interpolate height and position together.
	if animate_height:
		# Animate panel height and vertical alignment together for a consistent transition.
		_layout_tween = create_tween().set_parallel(true)
		_layout_tween.set_trans(Tween.TRANS_QUAD)
		_layout_tween.set_ease(Tween.EASE_OUT)
		_layout_tween.tween_property(help_panel, "size:y", target_height, transition_layout_duration)
		_layout_tween.tween_property(help_panel, "global_position", target_position, transition_layout_duration)
		_layout_tween.chain().tween_callback(_update_scroll_bar_state)
	else:
		help_panel.size.y = target_height
		help_panel.global_position = target_position
		_update_scroll_bar_state()


## Rebuilds the active description and recomputes layout after a viewport resize.
func _on_viewport_resized() -> void:
	# Filter out processing if the current panel mode is set to hidden or the active room reference isn't valid.
	if _mode == HelpMode.HIDDEN or not is_instance_valid(_active_room):
		return
	
	# Invalidate previous layout work and stop transitions during resizing.
	_transition_id += 1
	var request_id: int = _transition_id
	_stop_content_and_layout_tweens()
	_stop_tween(_content_tween)
	
	# Make sure that description contents node is set fully visible.
	description_contents.modulate.a = 1.0
	
	# Recalculate horizontal constraints at the current drawer scale.
	if not _update_panel_width():
		hide_immediate()
		return
	
	# Rebuild text and images so their wrapping matches the new width.
	_populate_description(_active_room)
	_measure_then_layout(request_id, false, false)

#endregion


#region Description Scrolling

## Resets the description viewport and external scrollbar to the beginning.
func _reset_scroll_to_top() -> void:
	# Align the smooth scroll target with the beginning of the new description.
	description_scroll_bar.smooth_scroll_to(0.0)
	
	# Move the visible scroll view and external range position to the same value.
	scroll_container.scroll_vertical = 0
	description_scroll_bar.value = 0.0


## Updates scrollbar opacity and input according to the current scroll range.
func _update_scroll_bar_state() -> void:
	# Filter out processing if the current node isn't ready.
	if not is_node_ready():
		return
	
	# Determine whether the content extends below the scroll viewport.
	var internal: VScrollBar = scroll_container.get_v_scroll_bar()
	var needed: bool = internal.max_value > internal.page + SCROLL_OVERFLOW_EPSILON
	var first_update: bool = not _scroll_bar_state_initialized
	
	# Avoid restarting the opacity tween when the required state is unchanged.
	if not first_update and needed == _scroll_bar_required:
		return
	_scroll_bar_state_initialized = true
	_scroll_bar_required = needed
	
	# Retain the scrollbar's layout width while enabling input only on overflow.
	description_scroll_bar.mouse_filter = Control.MOUSE_FILTER_STOP if needed else Control.MOUSE_FILTER_IGNORE
	_stop_tween(_bar_tween)
	
	# Set the initial state immediately and animate subsequent visibility changes.
	if first_update:
		description_scroll_bar.modulate.a = 1.0 if needed else 0.0
		return
	
	_bar_tween = create_tween()
	_bar_tween.tween_property(description_scroll_bar, "modulate:a", 1.0 if needed else 0.0, transition_scroll_bar_fade_duration)

#endregion


#region HUD Transition Wait Group

## Checks and returns a bool value indicating if the help panel is still visible and needs to finish closing which would delay the creation of save screenshot.
func has_pending_hud_transition() -> bool:
	return is_open() or help_panel.visible

#endregion
