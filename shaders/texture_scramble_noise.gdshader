shader_type canvas_item;


uniform float noise_amount: hint_range(0.0, 1.0) = 0.0;
uniform float noise_seed = 0.0;

uniform float block_size: hint_range(1.0, 8.0, 1.0) = 1.0;
uniform vec4 noise_color: source_color = vec4(1.0);


float random_value(vec2 position) {
	vec2 value = fract(position * vec2(123.34, 456.21));
	
	value += dot(value, value + 45.32 + noise_seed);
	
	return fract(value.x * value.y);
}


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 base_color = COLOR;
	
	vec2 block_pixel_size = TEXTURE_PIXEL_SIZE * block_size;
	
	vec2 block_position = floor(UV / block_pixel_size);
	
	float noise = random_value(block_position);
	
	float noise_mask = step(1.0 - noise_amount, noise);
	
	// Don't generate noise outside the visible texture.
	noise_mask *= step(0.001, base_color.a);
	
	float blend_amount = noise_mask * noise_color.a;
	
	vec3 final_rgb = mix(base_color.rgb, noise_color.rgb, blend_amount);
	
	COLOR = vec4(final_rgb, base_color.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
