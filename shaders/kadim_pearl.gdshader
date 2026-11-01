shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Kadim Inci (Sacred Pearl) Shader - Luminous Deep-Sea Pearl
// Simulates lustrous pearl nacre, subsurface glow, and gentle celestial aura

uniform vec3 pearl_albedo : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 pearl_emission_color : source_color = vec3(0.65, 0.92, 1.0);
uniform vec3 iridescence_tint : source_color = vec3(0.85, 0.75, 0.95);

uniform float emission_energy : hint_range(0.0, 10.0) = 3.8;
uniform float fresnel_sheen : hint_range(0.0, 2.0) = 1.2;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.05;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.28;

void fragment() {
    float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float fresnel = pow(1.0 - n_dot_v, 3.0);
    
    // Pearlescent color modulation at rim
    vec3 col = mix(pearl_albedo, iridescence_tint, fresnel * 0.4);
    
    ALBEDO = col;
    METALLIC = metallic_val;
    ROUGHNESS = roughness_val;
    
    // Core emission + soft rim halo
    float core_glow = 0.6 + 0.4 * pow(n_dot_v, 1.5);
    float rim_glow = pow(1.0 - n_dot_v, 2.0) * fresnel_sheen;
    EMISSION = pearl_emission_color * ((core_glow + rim_glow * 0.5) * emission_energy);
}

