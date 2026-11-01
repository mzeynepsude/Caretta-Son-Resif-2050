shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// CARETTA: SON RESİF 2050 - Batık Gökdelen Duvar Shader'ı (Original Architectural Ruin Facade)
// Orijinal Sketchfab gökdelen mimari rengi (çelik/beton arduvaz mavisi) korunur,
// üzerine deniz dibinden yukarıya tırmanan yosunlaşma, beton aşınması ve çöküntü çatlakları eklenir.
// %100 OPAK - Şeffaflık/transparanlık YOKTUR.

uniform vec3 original_wall_color : source_color = vec3(0.432, 0.577, 0.800);
uniform vec3 moss_deep_color : source_color = vec3(0.06, 0.22, 0.08);
uniform vec3 moss_vibrant_color : source_color = vec3(0.16, 0.44, 0.15);
uniform vec3 mineral_stain_color : source_color = vec3(0.25, 0.34, 0.38);
uniform vec3 crack_color : source_color = vec3(0.12, 0.16, 0.18);

uniform float seabed_y = -7.5;
uniform float moss_height = 24.0;
uniform float weathering_strength : hint_range(0.0, 1.0) = 0.55;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.40;

varying vec3 world_pos;
varying vec3 world_normal;

// Simplex/hash noise utilities
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

float fbm2D(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; ++i) {
        v += a * noise2D(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // 1. Orijinal gökdelen duvar rengi (Slate blue concrete/steel)
    vec3 col = original_wall_color;
    
    // 2. Yükseklik gradyanı (Deniz tabanından yukarıya yosunlaşma)
    float h = world_pos.y - seabed_y;
    float h_norm = clamp(h / moss_height, 0.0, 1.0);
    float moss_grad = pow(1.0 - h_norm, 0.75);
    
    // Yatay ve dikey gürültü ile organik yosun yamaları
    vec2 uv_xz = world_pos.xz * 0.25;
    float n_moss = fbm2D(uv_xz + vec2(world_pos.y * 0.15, world_pos.y * 0.05)) * 0.5 + 0.5;
    float moss_amount = clamp(moss_grad * 1.35 * n_moss, 0.0, 1.0);
    vec3 current_moss = mix(moss_deep_color, moss_vibrant_color, n_moss);
    
    // 3. Batık mineral tortusu ve dikey su akıntı çizgileri (Vertical water runoff)
    float runoff_noise = noise2D(vec2(world_pos.x + world_pos.z, world_pos.y * 0.08)) * 0.5 + 0.5;
    float runoff_streak = pow(runoff_noise, 3.0) * weathering_strength * 0.6;
    col = mix(col, mineral_stain_color, runoff_streak);
    
    // 4. Beton aşınması ve yüzey greni (Concrete spalling / patina)
    float micro_patina = noise2D(world_pos.xy * 0.8 + world_pos.zy * 0.8) * 0.12;
    col += micro_patina * weathering_strength;
    
    // 5. Yapısal çöküntü çatlakları (Structural ruin cracks)
    vec2 crack_uv = vec2(world_pos.x * 0.4 + world_pos.z * 0.4, world_pos.y * 0.35);
    float crack_n = abs(noise2D(crack_uv * 2.0));
    float crack_mask = smoothstep(0.08, 0.0, crack_n) * crack_intensity * (1.0 - h_norm * 0.5);
    col = mix(col, crack_color, crack_mask);
    
    // 6. Yosun tabakasını birleştir (Alt kısımlar yoğun batık yosunlu, yukarılar orijinal arduvaz mavisi gökdelen)
    col = mix(col, current_moss, moss_amount);
    
    ALBEDO = col;
    ROUGHNESS = mix(0.85, 0.65, moss_amount * 0.5);
    METALLIC = mix(0.05, 0.0, moss_amount);
    
    // Mikro yüzey pürüzlülüğü
    float bump = (micro_patina + crack_mask * 0.5) * 0.2;
    NORMAL = normalize(NORMAL + vec3(dFdx(bump) * 2.0, dFdy(bump) * 2.0, 0.0));
}

