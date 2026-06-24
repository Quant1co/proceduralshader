shader_type spatial;

uniform float scale : hint_range(1.0, 20.0) = 4.0;
uniform int octaves : hint_range(1, 16) = 14;
uniform float lacunarity : hint_range(1.0, 4.0) = 2.0;
uniform float gain : hint_range(0.0, 1.0) = 0.5;
uniform int warp_iterations : hint_range(0, 8) = 5;
uniform float warp_strength : hint_range(0.0, 5.0) = 2.0;
uniform float turbulence : hint_range(0.0, 10.0) = 4.0;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float crack_detail : hint_range(1.0, 10.0) = 5.0;
uniform int voronoi_search : hint_range(1, 3) = 2;
uniform vec4 color_hot : source_color = vec4(1.0, 0.9, 0.2, 1.0);
uniform vec4 color_warm : source_color = vec4(1.0, 0.3, 0.0, 1.0);
uniform vec4 color_cool : source_color = vec4(0.15, 0.02, 0.0, 1.0);
uniform vec4 color_crust : source_color = vec4(0.08, 0.05, 0.03, 1.0);

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float gradient_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float turbulence_noise(vec2 p, int oct) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < oct; i++) {
        value += amplitude * abs(gradient_noise(p * frequency) * 2.0 - 1.0);
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return value;
}

float fbm(vec2 p, int oct) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < oct; i++) {
        value += amplitude * gradient_noise(p * frequency);
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return value;
}

vec2 domain_warp(vec2 p, int iterations) {
    vec2 q = p;
    for (int i = 0; i < iterations; i++) {
        float nx = fbm(q + vec2(1.7, 9.2), 8);
        float ny = fbm(q + vec2(8.3, 2.8), 8);
        q = p + warp_strength * vec2(nx, ny);
    }
    return q;
}

float voronoi_extended(vec2 p, int search_radius) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float min_dist1 = 1.0;
    float min_dist2 = 1.0;

    for (int y = -search_radius; y <= search_radius; y++) {
        for (int x = -search_radius; x <= search_radius; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash22(i + neighbor);
            vec2 diff = neighbor + point - f;
            float dist = dot(diff, diff);
            if (dist < min_dist1) {
                min_dist2 = min_dist1;
                min_dist1 = dist;
            } else if (dist < min_dist2) {
                min_dist2 = dist;
            }
        }
    }
    return sqrt(min_dist2) - sqrt(min_dist1);
}

void fragment() {
    vec2 uv = UV * scale;

    vec2 warped = domain_warp(uv, warp_iterations);

    float turb = turbulence_noise(warped * turbulence, octaves);

    float cracks = voronoi_extended(warped * crack_detail, voronoi_search);
    float crack_mask = smoothstep(0.0, 0.12, cracks);

    float flow = fbm(warped * 2.0 + turb * 2.0, octaves);

    float heat = (1.0 - crack_mask) * flow;
    heat = pow(heat, 0.8);

    float micro = fbm(warped * scale * 3.0, octaves);

    vec3 lava_col = mix(color_warm.rgb, color_hot.rgb, pow(heat, 2.0));
    lava_col *= (1.0 + heat * glow_intensity);
    vec3 crust_col = mix(color_cool.rgb, color_crust.rgb, micro);

    vec3 col = mix(lava_col, crust_col, crack_mask * 0.85);

    float deep_glow = (1.0 - smoothstep(0.0, 0.05, cracks));
    col += color_hot.rgb * deep_glow * glow_intensity * 0.5;

    ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
    
    // Применяем математически идентичное свечение,
    // как в StandardMaterial3D для запечённой текстуры:
    EMISSION = ALBEDO * vec3(1.0, 0.25, 0.0) * 1.5;
    
    ROUGHNESS = 0.85;
}
