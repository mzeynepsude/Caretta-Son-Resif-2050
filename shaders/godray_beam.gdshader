shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// Celestial Underwater Sunbeam (God Ray) Shader
// Simulates piercing shafts of celestial sunlight filtering through deep ocean water

uniform vec4 beam_color : source_color = vec4(0.48, 0.85, 1.0, 0.22);
uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform float beam_intensity : hint_range(0.0, 5.0) = 1.4;

void fragment() {
    vec2 uv = UV;
    
    // Vertical beam falloff: bright at top (UV.y = 0), gently dissipates near bottom (UV.y = 1)
    float vertical_fade = pow(1.0 - uv.y, 0.75);
    
    // Horizontal / radial edge softness (feathers sides to 0)
    float horizontal_fade = sin(uv.x * 3.14159);
    horizontal_fade = pow(horizontal_fade, 1.4);
    
    // Subtle scrolling caustic waves along the beam
    float wave1 = sin(uv.y * 12.0 - TIME * speed * 2.0 + uv.x * 6.0) * 0.5 + 0.5;
    float wave2 = cos(uv.y * 22.0 - TIME * speed * 1.4 - uv.x * 8.0) * 0.5 + 0.5;
    float caustics = 0.75 + 0.25 * (wave1 * wave2);
    
    float alpha = vertical_fade * horizontal_fade * caustics * beam_color.a * beam_intensity;
    
    ALBEDO = beam_color.rgb * beam_intensity;
    ALPHA = clamp(alpha, 0.0, 1.0);
}

