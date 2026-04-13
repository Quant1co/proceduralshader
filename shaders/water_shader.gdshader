shader_type spatial;

uniform vec4  water_color:   source_color = vec4(0.0, 0.4, 0.8, 0.85);
uniform float wave_speed:    hint_range(0.1, 5.0)  = 1.0;
uniform float wave_height:   hint_range(0.0, 2.0)  = 0.3;
uniform float scale:         hint_range(1.0, 16.0) = 4.0;
uniform sampler2D noise_texture: repeat_enable;

void vertex() {
	vec2  uv     = VERTEX.xz * 0.1 * scale;
	float wave1  = texture(noise_texture, uv + vec2(TIME * wave_speed * 0.05, 0.0)).r;
	float wave2  = texture(noise_texture, uv * 1.5 + vec2(0.0, TIME * wave_speed * 0.03)).r;
	float height = (wave1 * 0.7 + wave2 * 0.3) * wave_height;
	VERTEX.y    += height;
}

void fragment() {
	ALBEDO    = water_color.rgb;
	ALPHA     = water_color.a;
	ROUGHNESS = 0.05;
	METALLIC  = 0.0;
	SPECULAR  = 0.9;
}
