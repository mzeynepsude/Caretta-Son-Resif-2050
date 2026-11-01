shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Kadim Midye Inner Shell - Mother-of-Pearl / Nacre (Sedef) Shader
// Simulates lustrous iridescent nacre with view-angle color shifts and ambient pearl reflection

uniform vec3 nacre_base_color : source_color = vec3(0.88, 0.93, 0.96);
uniform vec3 iridescence_cyan : source_color = vec3(0.45, 0.88, 0.95);
uniform vec3 iridescence_pink : source_color = vec3(0.82, 0.70, 0.90);
uniform vec3 pearl_glow_reflection : source_color = vec3(0.20, 0.65, 0.85);

uniform float iridescence_strength : hint_range(0.0, 2.0) = 0.85;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.16;
uniform float inner_glow_intensity : hint_range(0.0, 2.0) = 0.45;

float hash(vec2 p) {
    p = fract(p * vec2(173.34, 356.21));
    p += dot(p, p + 23.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    
    // View angle Fresnel for iridescent sheen
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
    
    // Subtle growth ring waviness on nacre
    float waviness = noise(uv * 18.0) * 0.15;
    float iri_phase = fract(fresnel * 1.5 + waviness + uv.y * 1.2);
    
    // Shifting color palette across viewing angles
    vec3 iri_color = mix(iridescence_cyan, iridescence_pink, sin(iri_phase * 3.14159 * 2.0) * 0.5 + 0.5);
    
    // Blend base nacre with iridescent sheen
    vec3 col = mix(nacre_base_color, iri_color, fresnel * iridescence_strength * 0.65);
    
    // Subtle procedural nacre grain
    float grain = noise(uv * 80.0) * 0.04;
    col += grain;
    
    ALBEDO = col;
    METALLIC = metallic_val;
    ROUGHNESS = roughness_val;
    
    // Proximity to bottom hinge (where the pearl sits, uv.y is low)
    float pearl_proximity = 1.0 - smoothstep(0.0, 0.65, uv.y);
    EMISSION = pearl_glow_reflection * (inner_glow_intensity * (0.3 + 0.7 * pearl_proximity));
}

