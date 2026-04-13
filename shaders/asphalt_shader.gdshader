shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable;
uniform float scale:     hint_range(1.0, 32.0) = 12.0;
uniform float threshold: hint_range(0.0, 1.0)  = 0.5;
uniform vec4  color1:    source_color = vec4(0.12, 0.12, 0.12, 1.0);
uniform vec4  color2:    source_color = vec4(0.32, 0.32, 0.32, 1.0);
uniform bool  baking_mode = false;

void fragment() {
	vec2 uv = UV * scale;

	float n1 = texture(noise_texture, uv).r;
	float n2 = texture(noise_texture, uv * 2.3 + vec2(0.5,  0.0)).r;
	float n3 = texture(noise_texture, uv * 4.7 + vec2(0.3,  0.7)).r;

	float combined = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
	combined = pow(combined, 1.5);
	combined = smoothstep(threshold - 0.1, threshold + 0.1, combined);

	vec3 col = mix(color1.rgb, color2.rgb, combined);
	COLOR    = vec4(col, 1.0);
}
