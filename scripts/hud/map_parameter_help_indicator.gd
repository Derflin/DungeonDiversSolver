class_name MapParameterHelpIndicator
extends Control


enum IndicatorState {
	UNAVAILABLE,
	AVAILABLE,
	PREVIEW,
	PINNED,
}


@export_group("Icon Textures", "icon_")
## Information texture displayed when help is available or unavailable.
@export var icon_information: Texture2D
## Unlocked texture displayed while the associated help panel is previewed.
@export var icon_unlocked: Texture2D
## Locked texture displayed while the associated help panel is pinned.
@export var icon_locked: Texture2D

@export_group("Indicator Appearance", "indicator_")
## Color of the circular outline surrounding the indicator.
@export var indicator_outline_color: Color = Color(0.15, 0.13, 0.12, 1.0)
## Thickness of the indicator's circular outline.
@export_range(0.0, 3.0, 0.25) var indicator_outline_width: float = 1.0
## Free space between the indicator's background and the displayed texture.
@export_range(0.0, 5.0, 0.5) var indicator_icon_padding: float = 1.5

@export_group("Background Colors", "indicator_")
## Background color used when room help is available.
@export var indicator_available_background: Color = Color(0.85, 0.72, 0.46, 1.0)
## Background color used while room help is being previewed.
@export var indicator_preview_background: Color = Color(0.75, 0.62, 0.39, 1.0)
## Background color used while room help is pinned.
@export var indicator_pinned_background: Color = Color(0.98, 0.81, 0.45, 1.0)
## Background color used when a secret room has no help content.
@export var indicator_unavailable_background: Color = Color(0.36, 0.35, 0.35, 0.95)

@export_subgroup("Icon Colors", "indicator_")
## Tint used for the information texture when help is available.
@export var indicator_available_icon_color: Color = Color(0.16, 0.14, 0.12, 1.0)
## Tint used for the unlocked texture while help is previewed.
@export var indicator_preview_icon_color: Color = Color(0.16, 0.14, 0.12, 1.0)
## Tint used for the locked texture while help is pinned.
@export var indicator_pinned_icon_color: Color = Color(0.16, 0.14, 0.12, 1.0)
## Tint used for the information texture when help is unavailable.
@export var indicator_unavailable_icon_color: Color = Color(0.72, 0.70, 0.68, 1.0)

@export_subgroup("Unavailable Slash", "indicator_")
## Thickness of the diagonal slash displayed over unavailable help.
@export_range(0.5, 3.0, 0.25) var indicator_unavailable_slash_width: float = 1.0
## Color of the diagonal slash displayed over unavailable help.
@export var indicator_unavailable_slash_color: Color = Color(0.16, 0.15, 0.15, 1.0)
## Length of the slash relative to the radius of the indicator.
@export_range(0.25, 1.5, 0.05) var indicator_unavailable_slash_length_factor: float = 0.75

@export_group("Transitions", "transition_")
## Enables animated transitions between help availability and selection states.
@export var transition_enabled: bool = true
## Duration of indicator texture and color transitions.
@export_range(0.0, 1.0, 0.01) var transition_duration: float = 0.16


# Current logical state and the tween responsible for visual transitions.
var _state: IndicatorState = IndicatorState.AVAILABLE
var _state_initialized: bool = false
var _state_tween: Tween = null

# Animated drawing properties used to blend textures and indicator colors.
var _background_color: Color = Color.WHITE:
	set(value):
		_background_color = value
		queue_redraw()

var _icon_color: Color = Color.WHITE:
	set(value):
		_icon_color = value
		queue_redraw()

var _icon_blend: Vector3 = Vector3(1.0, 0.0, 0.0):
	set(value):
		_icon_blend = value
		queue_redraw()

var _slash_opacity: float = 0.0:
	set(value):
		_slash_opacity = value
		queue_redraw()


#region Initialization

## Initializes the indicator as a noninteractive, independently drawn control node.
func _ready() -> void:
	# Allow the surrounding parameter entry to handle all pointer interactions.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Redraw the circle when the surrounding row changes its allocated height.
	resized.connect(queue_redraw)
	
	# Apply the initial appearance without showing a transition on first display.
	set_indicator_state(_state, false)

#endregion


#region Indicator State

## Updates the displayed indicator state and optionally animates its appearance.
func set_indicator_state(state: IndicatorState, animate: bool = true) -> void:
	# Preserve an existing transition when the requested state has not changed.
	if _state_initialized and _state == state:
		return
	
	# Store the latest requested state and stop any previous transition.
	_state = state
	var first_update: bool = not _state_initialized
	_state_initialized = true
	_stop_state_tween()
	
	# Determine the icon visibility, tint and background for the new state.
	var target_blend: Vector3 = Vector3(1.0, 0.0, 0.0)
	var target_background: Color = indicator_available_background
	var target_icon_color: Color = indicator_available_icon_color
	var target_slash_opacity: float = 0.0
	
	match state:
		IndicatorState.UNAVAILABLE:
			target_background = indicator_unavailable_background
			target_icon_color = indicator_unavailable_icon_color
			target_slash_opacity = 1.0
			
		IndicatorState.AVAILABLE:
			target_background = indicator_available_background
			target_icon_color = indicator_available_icon_color
			
		IndicatorState.PREVIEW:
			target_blend = Vector3(0.0, 1.0, 0.0)
			target_background = indicator_preview_background
			target_icon_color = indicator_preview_icon_color
			
		IndicatorState.PINNED:
			target_blend = Vector3(0.0, 0.0, 1.0)
			target_background = indicator_pinned_background
			target_icon_color = indicator_pinned_icon_color
	
	# Apply the requested appearance immediately during initialization or when animations are disabled.
	if first_update or not animate or not transition_enabled or transition_duration <= 0.0 or not is_inside_tree():
		_icon_blend = target_blend
		_background_color = target_background
		_icon_color = target_icon_color
		_slash_opacity = target_slash_opacity
		return
	
	# Interpolate all visual properties together from their current values.
	_state_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(self, "_icon_blend", target_blend, transition_duration)
	_state_tween.tween_property(self, "_background_color", target_background, transition_duration)
	_state_tween.tween_property(self, "_icon_color", target_icon_color, transition_duration)
	_state_tween.tween_property(self, "_slash_opacity", target_slash_opacity, transition_duration)


## Stops the active visual transition without resetting the already drawn appearance.
func _stop_state_tween() -> void:
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = null

#endregion


#region Indicator Drawing

## Draws the circular indicator, blended icon textures and unavailable slash.
func _draw() -> void:
	# Calculate the indicator circle centered inside the control node's current size.
	var center: Vector2 = size * 0.5
	var outer_radius: float = minf(size.x, size.y) * 0.5
	var inner_radius: float = maxf(0.0, outer_radius - indicator_outline_width)
	
	# Draw the surrounding outline and the current indicator background.
	draw_circle(center, outer_radius, indicator_outline_color)
	draw_circle(center, inner_radius, _background_color)
	
	# Determien the largest square available for the icon textures.
	var icon_size: float = maxf(1.0, inner_radius * 2.0 - indicator_icon_padding * 2.0)
	var icon_rect: Rect2 = Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	
	# Blend available, preview and pinned icon textures during state transitions.
	_draw_indicator_texture(icon_information, icon_rect, _icon_blend.x)
	_draw_indicator_texture(icon_unlocked, icon_rect, _icon_blend.y)
	_draw_indicator_texture(icon_locked, icon_rect, _icon_blend.z)
	
	# Overlay a diagonal slash when the associated secret room has no help content.
	if _slash_opacity > 0.0:
		var slash_extent: float = inner_radius * indicator_unavailable_slash_length_factor
		var slash_offset: Vector2 = Vector2.ONE * slash_extent
		var slash_color: Color = indicator_unavailable_slash_color
		slash_color.a *= _slash_opacity
		draw_line(center - slash_offset, center + slash_offset, slash_color, indicator_unavailable_slash_width, true)


## Draws a texture centered inside the indicator while preserving its original aspect ratio.
func _draw_indicator_texture(texture: Texture2D, target_rect: Rect2, opacity: float) -> void:
	# Filter out empty textures and fully transparent icon layers.
	if texture == null or opacity <= 0.0:
		return
	
	# Scale the source texture uniformly to fit the indicator's icon area.
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	
	var scale_factor: float = minf(target_rect.size.x / texture_size.x, target_rect.size.y / texture_size.y)
	var drawn_size: Vector2 = texture_size * scale_factor
	var drawn_rect: Rect2 = Rect2(target_rect.get_center() - drawn_size * 0.5, drawn_size)
	
	# Draw the icon with its current tint and corss-fade opacity.
	var icon_tint: Color = _icon_color
	icon_tint.a *= opacity
	draw_texture_rect(texture, drawn_rect, false, icon_tint)

#endregion
