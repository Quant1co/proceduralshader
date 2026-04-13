shader_type canvas_item;

uniform float scale:     hint_range(0.5, 10.0) = 2.5;
uniform float threshold: hint_range(1.0, 10.0) = 4.0;
uniform vec4  color1:    source_color = vec4(0.0, 0.0,  0.5, 1.0);
uniform vec4  color2:    source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform bool  baking_mode = false;

const int MAX_ITER = 100;

int mandelbrot(vec2 c, float escape_radius) {
	vec2 z = vec2(0.0);
	for (int i = 0; i < MAX_ITER; i++) {
		z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
		if (dot(z, z) > escape_radius) return i;
	}
	return MAX_ITER;
}

void fragment() {
	vec2 c    = (UV - vec2(0.5)) * scale + vec2(-0.5, 0.0);
	int  iter = mandelbrot(c, threshold);
	float t   = float(iter) / float(MAX_ITER);

	vec3 col = mix(color1.rgb, color2.rgb, sqrt(t));
	COLOR    = vec4(col, 1.0);
}
