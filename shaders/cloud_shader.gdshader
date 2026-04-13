shader_type canvas_item;

uniform sampler2D perlin_noise: repeat_enable;
uniform sampler2D cell_noise:   repeat_enable;

uniform float scale:     hint_range(1.0, 32.0) = 4.0;
uniform float threshold: hint_range(0.0, 1.0)  = 0.5;
uniform bool baking_mode = false;

#define pow2(x) (x * x)

const int   samples = 15;
const float sigma   = float(samples) * 0.25;

float gaussian(vec2 i) {
	return 1.0 / (2.0 * PI * pow2(sigma))
		* exp(-((pow2(i.x) + pow2(i.y)) / (2.0 * pow2(sigma))));
}

vec3 blur(sampler2D sp, vec2 uv, vec2 pixel_size) {
	vec3  col   = vec3(0.0);
	float accum = 0.0;
	for (int x = -samples / 2; x < samples / 2; ++x) {
		for (int y = -samples / 2; y < samples / 2; ++y) {
			vec2  offset = vec2(float(x), float(y));
			float weight = gaussian(offset);
			col   += texture(sp, uv + pixel_size * offset).rgb * weight;
			accum += weight;
		}
	}
	return col / accum;
}

void fragment() {
	vec2 pixel_size = vec2(1.0 / 512.0);

	vec2 uv1 = UV * scale + vec2(TIME * 0.02, TIME * 0.005);
	vec2 uv2 = UV * scale + vec2(TIME * 0.03, TIME * 0.005);

	float noise1 = blur(perlin_noise, uv1, pixel_size).r;
	float noise2 = blur(cell_noise,   uv2, pixel_size).r;

	float cloud = smoothstep(threshold - 0.1, threshold + 0.1, noise1 * noise2);

	if (baking_mode) {
		COLOR = vec4(cloud, cloud, cloud, 1.0);
	} else {
		COLOR = vec4(1.0, 1.0, 1.0, cloud);
	}
}
