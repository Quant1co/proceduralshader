shader_type canvas_item;

uniform float scale : hint_range(1.0, 20.0) = 6.0;
uniform float detail : hint_range(1.0, 16.0) = 12.0;
uniform int octaves : hint_range(1, 16) = 12;
uniform float lacunarity : hint_range(1.0, 4.0) = 2.1;
uniform float gain : hint_range(0.0, 1.0) = 0.5;
uniform float vein_sharpness : hint_range(1.0, 20.0) = 8.0;
uniform float vein_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float warp_strength : hint_range(0.0, 5.0) = 1.5;
uniform int warp_iterations : hint_range(0, 6) = 4;
uniform vec4 color_light : source_color = vec4(0.95, 0.93, 0.88, 1.0);
uniform vec4 color_dark : source_color = vec4(0.2, 0.18, 0.15, 1.0);
uniform vec4 color_vein : source_color = vec4(0.4, 0.35, 0.25, 1.0);
uniform bool baking_mode = false;

// Хэш для градиентного шума
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

// Градиентный шум (вычисляется полностью в шейдере)
float gradient_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// FBM с большим числом октав
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

// Domain warping — многократное искажение координат
vec2 domain_warp(vec2 p, int iterations) {
    vec2 q = p;
    for (int i = 0; i < iterations; i++) {
        float nx = fbm(q + vec2(0.0, 0.0), 6);
        float ny = fbm(q + vec2(5.2, 1.3), 6);
        q = p + warp_strength * vec2(nx, ny);
    }
    return q;
}

// Voronoi для трещин мрамора
float voronoi_cracks(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float min_dist1 = 1.0;
    float min_dist2 = 1.0;

    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash22(i + neighbor);
            vec2 diff = neighbor + point - f;
            float dist = length(diff);
            if (dist < min_dist1) {
                min_dist2 = min_dist1;
                min_dist1 = dist;
            } else if (dist < min_dist2) {
                min_dist2 = dist;
            }
        }
    }
    return min_dist2 - min_dist1;
}

void fragment() {
    vec2 uv = UV * scale;

    // Domain warping (тяжёлая операция)
    vec2 warped = domain_warp(uv, warp_iterations);

    // Основной шум с высокой детализацией
    float base = fbm(warped * detail, octaves);

    // Прожилки мрамора через синусоиду искажённых координат
    float vein_pattern = abs(sin((warped.x + warped.y) * 3.0 + base * 6.0));
    vein_pattern = pow(vein_pattern, vein_sharpness);

    // Voronoi трещины (поиск по 25 ячейкам)
    float cracks = voronoi_cracks(uv * 3.0);
    cracks = smoothstep(0.0, 0.08, cracks);

    // Микродетали — ещё один слой FBM
    float micro = fbm(warped * detail * 4.0, octaves);

    // Смешивание
    vec3 col = mix(color_dark.rgb, color_light.rgb, base);
    col = mix(col, color_vein.rgb, vein_pattern * vein_intensity);
    col = mix(col, col * 0.6, (1.0 - cracks) * 0.4);
    col += (micro - 0.5) * 0.08;

    COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}