shader_type canvas_item;

// Size of each cell
uniform float cell_size = 32.0;

// Movement direction (ej: vec2(1, 0) derecha, vec2(0, 1) abajo)
uniform vec2 direction = vec2(1.0, 0.0);

// speed
uniform float speed = 40.0;

// Speed of changing color
uniform float color_speed = 0.3;

// -------------------------------------------------

// HSV → RGB
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// Real Pixel's posicion
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;

	// cells movement
	vec2 offset = direction * TIME * speed;
	pixel_pos += offset;

	// Í of each cell
	vec2 cell_id = floor(pixel_pos / cell_size);

	float checker = mod(cell_id.x + cell_id.y, 2.0);

	// Dinamic color based on Position and time
	float hue = fract((cell_id.x + cell_id.y) * 0.05 + TIME * color_speed);

	vec3 rainbow = hsv2rgb(vec3(
		hue,        // tone
		0.8,        // saturation
		mix(0.7, 1.0, checker) // brillo alternado tipo chess
	));

	COLOR = vec4(rainbow, 1.0);
}
