shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// CARETTA: SON RESİF 2050 - Sualtı Batık Gökdelen Pencereleri (Sunken Opaque Ruin Windows)
// Orijinal Sketchfab koyu yansıtıcı mimari cam rengi korunur,
// taban seviyesinde deniz tabanı tortusu ve yoğun koyu yosun, yukarıda ıslak yansımalı batık cam.
// %100 OPAK - Şeffaflık/transparanlık YOKTUR.

uniform vec3 glass_tint : source_color = vec3(0.061, 0.079, 0.107); // Orijinal Sketchfab koyu mimari camı
uniform vec3 moss_color : source_color = vec3(0.12, 0.42, 0.20);
uniform vec3 moss_deep : source_color = vec3(0.04, 0.15, 0.08);

uniform float seabed_y = -7.5;
uniform float moss_height = 22.0;
uniform float metallic_val = 0.90;
uniform float roughness_val = 0.08;

varying vec3 world_pos;
varying vec3 world_normal;

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
            dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
        mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
            dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
        u.y
    );
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // Yükseklik gradyanı (Deniz tabanından yukarıya doğru tortu/yosun azalır)
    float h_factor = clamp((world_pos.y - seabed_y) / moss_height, 0.0, 1.0);
    float moss_grad = 1.0 - pow(h_factor, 0.60);
    
    // Yosun dalgalanma ve tortu gürültüsü
    float n = noise2D(world_pos.xz * 0.35 + vec2(world_pos.y * 0.25, world_pos.y * 0.12)) * 0.5 + 0.5;
    float moss_amount = clamp(moss_grad * 1.30 * n, 0.0, 1.0);
    
    // Renk harmanı: Alt kısımlar koyu çöküntü yosunu, üst kısımlar orijinal derin sualtı camı
    vec3 current_moss = mix(moss_deep, moss_color, n);
    vec3 final_color = mix(glass_tint, current_moss, moss_amount);
    
    ALBEDO = final_color;
    METALLIC = mix(metallic_val, 0.10, moss_amount);
    ROUGHNESS = mix(roughness_val, 0.85, moss_amount);
    // Kesinlikle ALPHA şeffaflığı YOKTUR - Kalıntı ve çöküntü olarak %100 katı ve opaktır.
}
