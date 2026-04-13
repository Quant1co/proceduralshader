shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable;
uniform float scale:     hint_range(1.0, 32.0) = 8.0;
uniform float threshold: hint_range(0.0, 1.0)  = 0.5;
uniform vec4  color1:    source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4  color2:    source_color = vec4(0.20, 0.20, 0.20, 1.0);
uniform bool  baking_mode = false;

float voronoi(vec2 uv) {
	vec2  cell    = floor(uv);
	vec2  frac_uv = fract(uv);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = fract(sin(vec2(
				dot(cell + neighbor, vec2(127.1, 311.7)),
				dot(cell + neighbor, vec2(269.5, 183.3))
			)) * 43758.5453);
			vec2 diff  = neighbor + point - frac_uv;
			min_dist   = min(min_dist, length(diff));
		}
	}
	return min_dist;
}

void fragment() {
	vec2  uv       = UV * scale;
	float n        = texture(noise_texture, uv).r;
	float v        = voronoi(uv * 2.0);

	float combined = mix(n, v, 0.5);
	combined       = clamp(combined, 0.0, 1.0);
	combined = smoothstep(threshold - 0.15, threshold + 0.15, combined);

	vec3 col = mix(color2.rgb, color1.rgb, combined);
	COLOR    = vec4(col, 1.0);
}
