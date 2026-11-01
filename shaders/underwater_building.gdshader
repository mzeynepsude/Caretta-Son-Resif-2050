shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// CARETTA: SON RESİF 2050 - Biyolojik Deniz Biyo-Kirlenme ve Yosun Dağılım Shader'ı
// Bilimsel Gerçeklik: Deniz tabanına yakın alanlarda yoğun koyu tortu/yosun,
// yukarıya doğru su akıntısıyla çaprazlama uzanan yosun damarları ve kademeli azalma.

uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 concrete_tint : source_color = vec3(0.58, 0.63, 0.65);
uniform vec3 moss_deep_color : source_color = vec3(0.04, 0.14, 0.08);   // Koyu dip yosunu & tortu
uniform vec3 moss_mid_color : source_color = vec3(0.14, 0.38, 0.20);    // Akdeniz deniz yosunu
uniform vec3 moss_light_color : source_color = vec3(0.28, 0.55, 0.32);  // Canlı uç yosunları

uniform float seabed_y = -7.5;
uniform float building_height = 35.0;
uniform float uv_scale = 0.15;

varying vec3 world_pos;
varying vec3 world_normal;

// Hızlı ve kaliteli 2D Procedural Simplex / Hash Gürültüsü
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

// 2 Katmanlı Çapraz Akıntı Fraktalı (Diagonal Water Runoff Fractal)
float fbm_diagonal(vec2 p) {
	// Çaprazlama akıntı açısı (Diagonal shear)
	vec2 diag_p = vec2(p.x * 0.9 + p.y * 0.45, p.y * 0.85 - p.x * 0.35);
	float v = 0.0;
	v += 0.65 * noise2D(diag_p);
	v += 0.35 * noise2D(diag_p * 2.3 + vec2(1.7, 3.2));
	return v * 0.5 + 0.5; // [0, 1] aralığı
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 3 Yönlü Triplanar koordinat seçimi
	vec3 blending = abs(world_normal);
	blending = normalize(max(blending, 0.00001));
	blending /= (blending.x + blending.y + blending.z);

	vec2 uv_x = world_pos.zy * uv_scale;
	vec2 uv_y = world_pos.xz * uv_scale;
	vec2 uv_z = world_pos.xy * uv_scale;

	vec4 tex_x = texture(base_texture, uv_x);
	vec4 tex_y = texture(base_texture, uv_y);
	vec4 tex_z = texture(base_texture, uv_z);
	vec4 base_tex = tex_x * blending.x + tex_y * blending.y + tex_z * blending.z;

	// Deniz tabanından yüksekliğe göre kademeli yosun eğrisi (Alt katlarda %90+, üstlerde seyrekleşir)
	float height_norm = clamp((world_pos.y - seabed_y) / building_height, 0.0, 1.0);
	float base_moss_factor = 1.0 - pow(height_norm, 0.65); // Tabanda çok yoğun, yukarıda hızlı azalır

	// Çapraz gürültü deseni (Dikey yerine su akıntısıyla çapraz eğim kazanmış yosun hatları)
	vec2 noise_coords = vec2(
		(world_pos.x + world_pos.z) * 0.25,
		world_pos.y * 0.22
	);
	float diag_pattern = fbm_diagonal(noise_coords);

	// Yosun maskesini oluştur: tabanda geniş kütleler, yukarıda sadece en belirgin çapraz hatlar kalır
	float threshold = mix(0.15, 0.72, height_norm);
	float moss_mask = smoothstep(threshold - 0.15, threshold + 0.20, diag_pattern * base_moss_factor * 1.35);

	// Ton Çeşitliliği (Farklı derinlik ve ışığa göre 3 kademeli yeşil/koyu ton)
	float tone_selector = diag_pattern + (1.0 - height_norm) * 0.4;
	vec3 moss_color;
	if (tone_selector < 0.45) {
		moss_color = moss_deep_color;
	} else if (tone_selector < 0.75) {
		moss_color = mix(moss_deep_color, moss_mid_color, (tone_selector - 0.45) / 0.30);
	} else {
		moss_color = mix(moss_mid_color, moss_light_color, (tone_selector - 0.75) / 0.35);
	}

	// Yıpranmış sualtı beton rengi (bazı pencereler ve metal kısımlar korunur)
	vec3 weathered_concrete = base_tex.rgb * concrete_tint;
	// Sualtında kalmış yapının ıslak dip kararması
	weathered_concrete = mix(weathered_concrete * 0.65, weathered_concrete, pow(height_norm, 0.5));

	// Nihai Renk Birleşimi: Beton ile Çapraz Geçişli Yosun Karışımı
	vec3 final_albedo = mix(weathered_concrete, moss_color, moss_mask);

	ALBEDO = final_albedo;
	
	// Yosunlu kısımlar daha mat ve kadifemsi, temiz beton kısımlar ıslak su yansımasına sahip
	ROUGHNESS = mix(0.48, 0.92, moss_mask);
	METALLIC = mix(0.15, 0.0, moss_mask);

	// Normal Haritası: Yosun alanlarına doğal kabartı hissi ver
	vec3 n_x = texture(normal_texture, uv_x).rgb * 2.0 - 1.0;
	vec3 n_y = texture(normal_texture, uv_y).rgb * 2.0 - 1.0;
	vec3 n_z = texture(normal_texture, uv_z).rgb * 2.0 - 1.0;
	vec3 base_norm = normalize(n_x * blending.x + n_y * blending.y + n_z * blending.z);
	NORMAL_MAP = base_norm;
	NORMAL_MAP_DEPTH = mix(1.0, 1.8, moss_mask);
}

