shader_type canvas_item;
render_mode unshaded;

// Experimental grid renderer for Compatibility/WebGL 2.
// It draws repeated cell edges from local grid coordinates using pixel-scale derivatives.
// This is NOT expected to match draw_rect() corner blending pixel-for-pixel.

uniform vec2 map_cells = vec2(17.0, 17.0);
uniform vec2 cell_step = vec2(17.0, 17.0);
uniform vec2 grid_offset = vec2(0.5, 0.5);
uniform float outer_cells = 2.0;

uniform vec4 internal_color : source_color = vec4(0.7843137, 0.5647059, 0.4313725, 0.1568627);
uniform vec4 external_color : source_color = vec4(0.4509804, 0.1529412, 0.1725490, 0.1568627);
uniform float vertical_width = 1.0;
uniform float horizontal_width = 1.0;
uniform float edge_softness_pixels : hint_range(0.25, 2.0, 0.05) = 0.70;

varying vec2 grid_local_position;

void vertex() {
    // Save local map coordinates to recover cell edges in fragment().
    grid_local_position = VERTEX;
}

vec4 cell_color(vec2 cell) {
    // Only cells inside the main grid plus its two-cell outer border contribute.
    if (cell.x < -outer_cells || cell.y < -outer_cells ||
        cell.x >= map_cells.x + outer_cells || cell.y >= map_cells.y + outer_cells) {
        return vec4(0.0);
    }
    if (cell.x >= 0.0 && cell.y >= 0.0 &&
        cell.x < map_cells.x && cell.y < map_cells.y) {
        return internal_color;
    }
    return external_color;
}

vec4 blend_layer(vec4 underlying, vec4 upper_color, float coverage) {
    // Combine one transparent cell-side contribution over the current result.
    float upper_alpha = upper_color.a * clamp(coverage, 0.0, 1.0);
    float combined_alpha = upper_alpha + underlying.a * (1.0 - upper_alpha);
    vec3 premultiplied = upper_color.rgb * upper_alpha +
        underlying.rgb * underlying.a * (1.0 - upper_alpha);
    vec3 combined_rgb = premultiplied / max(combined_alpha, 0.00001);
    return vec4(combined_rgb, combined_alpha);
}

float edge_coverage(float edge_distance, float stroke_width, float local_units_per_pixel) {
    // A smaller softness produces crisper edges, but too small may shimmer.
    float softness_local = max(local_units_per_pixel * edge_softness_pixels, 0.00001);
    float half_width = stroke_width * 0.5;
    float inside = max(0.0, half_width - softness_local * 0.5);
    float outside = half_width + softness_local * 0.5;
    return 1.0 - smoothstep(inside, outside, edge_distance);
}

float segment_span_coverage(float coordinate, float start, float end, float extension, float softness) {
	// Measure the distance beyond the segment's original endpoints.
    float outside = max(max(start - coordinate, coordinate - end), 0.0);

    // Extend the segment slightly to cover intersections.
    float half_softness = max(softness * 0.5, 0.00001);

    return 1.0 - smoothstep(
        extension - half_softness,
        extension + half_softness,
        outside
    );
}

float cell_border_coverage(vec2 cell, vec2 local_point, vec2 pixel_size) {
    // Calculate the four boundaries of the current cell.
    vec2 cell_min = cell * cell_step;
    vec2 cell_max = cell_min + cell_step;

    // Measure distances to the nearest vertical and horizontal borders.
    float vertical_distance = min(
        abs(local_point.x - cell_min.x),
        abs(local_point.x - cell_max.x)
    );
    float horizontal_distance = min(
        abs(local_point.y - cell_min.y),
        abs(local_point.y - cell_max.y)
    );

    // Calculate antialiased line coverage.
    float vertical = edge_coverage(
        vertical_distance, vertical_width, pixel_size.x
    );
    float horizontal = edge_coverage(
        horizontal_distance, horizontal_width, pixel_size.y
    );

    // Extend each segment by half its own stroke width.
    float vertical_span = segment_span_coverage(
        local_point.y, cell_min.y, cell_max.y,
        vertical_width * 0.5,
        pixel_size.y * edge_softness_pixels
    );
    float horizontal_span = segment_span_coverage(
        local_point.x, cell_min.x, cell_max.x,
        horizontal_width * 0.5,
        pixel_size.x * edge_softness_pixels
    );

    // Merge the cell's borders without doubling its own corner opacity.
    return max(vertical * vertical_span, horizontal * horizontal_span);
}

void fragment() {
    // Convert the fragment position into grid-local coordinates.
    vec2 local_point = grid_local_position - grid_offset;
    vec2 grid_point = local_point / cell_step;

    // Find the nearest grid intersection.
    vec2 nearest_corner = floor(grid_point + vec2(0.5));

    // Calculate approximate local units per screen pixel.
    vec2 pixel_size = max(
        fwidth(grid_local_position),
        vec2(0.00001)
    );

    // Identify the four cells surrounding the nearest intersection.
    vec2 top_left = nearest_corner - vec2(1.0, 1.0);
    vec2 top_right = nearest_corner + vec2(0.0, -1.0);
    vec2 bottom_left = nearest_corner + vec2(-1.0, 0.0);
    vec2 bottom_right = nearest_corner;

    // Blend each neighboring cell's complete border contribution.
    vec4 result = vec4(0.0);

    result = blend_layer(
        result, cell_color(top_left),
        cell_border_coverage(top_left, local_point, pixel_size)
    );
    result = blend_layer(
        result, cell_color(top_right),
        cell_border_coverage(top_right, local_point, pixel_size)
    );
    result = blend_layer(
        result, cell_color(bottom_left),
        cell_border_coverage(bottom_left, local_point, pixel_size)
    );
    result = blend_layer(
        result, cell_color(bottom_right),
        cell_border_coverage(bottom_right, local_point, pixel_size)
    );

    COLOR = result;
}
