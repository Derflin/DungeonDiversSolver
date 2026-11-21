class_name UIScaleCalculator
extends RefCounted


## Returns the largest uniform scale that fits [param natural_size] inside [param available_size] using the provided [param coverage] limits.
## The [param limit_enabled] flag applies the optional [param maximum_scale] upper bound.
static func calculate_scale(natural_size: Vector2, available_size: Vector2, coverage: Vector2, limit_enabled: bool = true, maximum_scale: float = 2.0, minimum_scroll_scale: float = 0.0) -> float:
	# Validate the measured content size and available layout space.
	if natural_size.x <= 0.0 or natural_size.y <= 0.0:
		return 1.0
	
	# Calculate the available layout area after applying each coverage limit.
	var allowed_size := Vector2(
		maxf(0.0, available_size.x) * clampf(coverage.x, 0.01, 1.0),
		maxf(0.0, available_size.y) * clampf(coverage.y, 0.01, 1.0),
	)
	
	 # Calculate the scale permitted by each axis.
	var width_fit := allowed_size.x / natural_size.x
	var height_fit := allowed_size.y / natural_size.y
	var result := minf(width_fit, height_fit)
	
	# Apply the preferred maximum scale when enabled.
	if limit_enabled:
		result = minf(result, maxf(0.01, maximum_scale))
	
	# Preserve the minimum preferred scale when vertical scrolling is available.
	if minimum_scroll_scale > 0.0:
		result = minf(width_fit, maxf(result, minimum_scroll_scale))
	
	return maxf(0.01, minf(result, width_fit))
