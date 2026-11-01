shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Kadim Midye Outer Shell - Ancient Encrusted Pinna Nobilis Shader
// Simulates ancient calcified shell, marine moss/algae, barnacles, and radial growth ridges

uniform vec3 shell_base_color : source_color = vec3(0.20, 0.22, 0.19);
uniform vec3 moss_deep_color : source_color = vec3(0.08, 0.28, 0.10);
uniform vec3 moss_vibrant_color : source_color = vec3(0.18, 0.46, 0.15);
uniform vec3 barnacle_color : source_color = vec3(0.68, 0.65, 0.58);

uniform float moss_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float barnacle_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.90;

// Procedural hash & noise functions
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    
    // Multi-scale procedural texturing
    float n_macro = fbm(uv * 6.0);
    float n_micro = fbm(uv * 24.0);
    float n_detail = fbm(uv * 60.0);
    
    // Upward-facing moss bias based on world normal
    vec3 w_norm = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    float up_bias = clamp(w_norm.y * 0.7 + 0.3, 0.0, 1.0);
    
    // Longitudinal radial ridges along V
    float rib_pattern = sin(uv.x * 3.14159 * 16.0);
    float ridge_peak = clamp(rib_pattern * 0.5 + 0.5, 0.0, 1.0);
    
    // Moss growth is heavy on ridges, in upward areas, and clustered by noise
    float moss_mask = smoothstep(0.35, 0.70, (n_macro * 0.5 + n_micro * 0.3 + ridge_peak * 0.2) * up_bias + (moss_coverage - 0.5));
    vec3 active_moss = mix(moss_deep_color, moss_vibrant_color, n_detail);
    
    // Barnacle / calcified encrustation flecks
    float barnacle_mask = step(0.72, n_detail) * barnacle_intensity * (1.0 - moss_mask * 0.6);
    
    // Combine base shell, moss, and barnacles
    vec3 col = shell_base_color;
    // Shell growth rings tone modulation
    col *= (0.85 + 0.30 * n_macro);
    col = mix(col, active_moss, moss_mask);
    col = mix(col, barnacle_color, barnacle_mask);
    
    ALBEDO = col;
    ROUGHNESS = mix(roughness_val, 0.65, moss_mask * 0.4);
    METALLIC = 0.03;
    
    // Subtle procedural bump/normal perturbation
    float bump = (n_micro * 0.6 + n_detail * 0.4) * 0.2;
    NORMAL = normalize(NORMAL + vec3(dFdx(bump) * 2.0, dFdy(bump) * 2.0, 0.0));
}

