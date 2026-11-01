extends Node3D

# COP31: Caretta - Son Resif 2050
# Akdeniz Sualtı Çevre, Atmosfer ve Görsel Zenginleştirme Yöneticisi (Environment Builder)
# 1. Su Yüzeyi Tavanı (Glittering Water Surface): Yukarı bakıldığında sonsuz siyahlık yerine güneşin vurduğu ışıltılı su yüzeyi.
# 2. Deniz Karı & Plankton Parçacıkları (Marine Snow): Subnautica / Abzû tarzı suda asılı duran, derinlik ve akıntı hissi veren mikro partiküller.
# 3. Akdeniz Karstik Kanyon Falezleri (Perimeter Cliffs): Haritanın sınırlarında yükselen görkemli sualtı kanyon duvarları ve kayalıklar.
# 4. Posidonia Çayırları (Posidonia oceanica Belts): Akdeniz'in akciğerleri olan deniz erişteleri ve yosunlu resif kayaları.

var water_surface: MeshInstance3D = null
var marine_snow: CPUParticles3D = null
var player_ref: Node3D = null
var sway_time: float = 0.0
var seagrass_blades: Array = []

func _ready():
	_create_water_surface()
	_create_marine_snow()
	_create_perimeter_cliffs()
	_create_posidonia_meadows()

func _process(delta: float):
	# Deniz karı parçacık sistemini oyuncunun etrafında merkezle (kesintisiz 3B derinlik)
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
	if player_ref and marine_snow:
		marine_snow.global_position = Vector3(player_ref.global_position.x, 16.0, player_ref.global_position.z)
	
	# Akdeniz deniz çayırlarının akıntıyla doğal dalgalanması (Sine wave gentle sway)
	sway_time += delta
	for blade_data in seagrass_blades:
		var blade: Node3D = blade_data[0]
		var base_rz: float = blade_data[1]
		var base_rx: float = blade_data[2]
		var phase: float = blade_data[3]
		if is_instance_valid(blade):
			blade.rotation.z = base_rz + sin(sway_time * 1.8 + phase) * 0.12
			blade.rotation.x = base_rx + cos(sway_time * 1.3 + phase) * 0.08

# 1. Su Yüzeyi (Water Ceiling) - 20-25m yükseltildi (Y: 40.0)
func _create_water_surface():
	water_surface = MeshInstance3D.new()
	water_surface.name = "WaterSurfaceCeiling"
	
	var plane = PlaneMesh.new()
	plane.size = Vector2(350.0, 350.0)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	water_surface.mesh = plane
	water_surface.position = Vector3(0.0, 40.0, 0.0)
	
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.28, 0.72, 0.90, 0.65)
	mat.roughness = 0.2
	mat.metallic = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.22, 0.60, 0.82, 1.0)
	mat.emission_energy_multiplier = 1.1
	
	water_surface.material_override = mat
	add_child(water_surface)

# 2. Deniz Karı & Yüzen Planktonlar (Marine Snow / Plankton Dust)
func _create_marine_snow():
	marine_snow = CPUParticles3D.new()
	marine_snow.name = "MarineSnowParticles"
	marine_snow.amount = 450
	marine_snow.lifetime = 10.0
	marine_snow.preprocess = 4.0
	marine_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	marine_snow.emission_box_extents = Vector3(55.0, 26.0, 55.0)
	marine_snow.gravity = Vector3(0.0, 0.15, 0.0) # Suyun kaldırma kuvvetiyle yavaşça yükselen zerrecikler
	marine_snow.initial_velocity_min = 0.15
	marine_snow.initial_velocity_max = 0.45
	marine_snow.scale_amount_min = 0.6
	marine_snow.scale_amount_max = 1.8
	
	# Parçacık görseli: Küçük ışıldayan sualtı zerresi
	var particle_mesh = BoxMesh.new()
	particle_mesh.size = Vector3(0.09, 0.09, 0.09)
	
	var p_mat = StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = Color(0.72, 0.96, 1.0, 0.75)
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particle_mesh.material = p_mat
	
	marine_snow.mesh = particle_mesh
	add_child(marine_snow)

# 3. Çevre Resif Falezleri (Perimeter Undersea Cliffs & Ridges)
func _create_perimeter_cliffs():
	var cliff_root = Node3D.new()
	cliff_root.name = "PerimeterCliffs"
	add_child(cliff_root)
	
	var cliff_mat = StandardMaterial3D.new()
	cliff_mat.albedo_color = Color(0.24, 0.35, 0.38, 1.0)
	cliff_mat.roughness = 0.88
	cliff_mat.metallic = 0.05
	
	var cliff_positions = [
		# Kuzey kanyon duvarları (-Z ufku)
		Vector3(0, 14, -85), Vector3(-45, 16, -88), Vector3(45, 15, -82),
		Vector3(-80, 18, -75), Vector3(80, 17, -78),
		# Güney kanyon duvarları (+Z ufku)
		Vector3(0, 15, 85), Vector3(-50, 17, 82), Vector3(50, 16, 88),
		Vector3(-85, 18, 75), Vector3(85, 19, 80),
		# Doğu resif sırtları (+X ufku)
		Vector3(92, 16, 0), Vector3(88, 18, -40), Vector3(90, 17, 40),
		# Batı açık deniz sırtları (-X ufku - Araştırma İstasyonu arkası)
		Vector3(-110, 18, -25), Vector3(-105, 20, 20), Vector3(-108, 19, -60)
	]
	
	for i in range(cliff_positions.size()):
		var pos = cliff_positions[i]
		var cliff = MeshInstance3D.new()
		cliff.name = "Cliff_%d" % i
		
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = randf_range(8.0, 16.0)
		cylinder.bottom_radius = randf_range(18.0, 30.0)
		cylinder.height = randf_range(48.0, 68.0)
		cylinder.radial_segments = 9 # Doğal pürüzlü kaya silüeti
		
		cliff.mesh = cylinder
		cliff.material_override = cliff_mat
		cliff.position = pos
		cliff.rotation.y = randf_range(0, TAU)
		cliff.rotation.z = randf_range(-0.08, 0.08)
		cliff_root.add_child(cliff)

# 4. Akdeniz Resif Mercanları & Posidonia Deniz Çayırları (Corals & Marine Flora)
# Oyun Geliştirme Endüstri Standardı: Poisson Disk Sampling (Bridson Algoritması / Mavi Gürültü Dağılımı)
# Bu algoritma beyaz gürültü (kümelenme ve boşluklar) yerine minimum mesafe (r_min) garantisiyle
# doğada bitkilerin besin/ışık rekabeti sonucu oluşturduğu organik ve düzenli dağılımı sağlar.
func _create_posidonia_meadows():
	var meadow_root = Node3D.new()
	meadow_root.name = "PosidoniaMeadows"
	add_child(meadow_root)
	
	# Paylaşımlı Biyolojik Materyaller
	# Posidonia Zümrüt Yeşili Yaprak Materyali
	var leaf_mat_1 = StandardMaterial3D.new()
	leaf_mat_1.albedo_color = Color(0.12, 0.58, 0.24, 1.0)
	leaf_mat_1.roughness = 0.5
	leaf_mat_1.emission_enabled = true
	leaf_mat_1.emission = Color(0.05, 0.22, 0.08, 1.0)
	leaf_mat_1.emission_energy_multiplier = 0.5
	
	# Posidonia Açık Deniz Eriştesi Materyali
	var leaf_mat_2 = StandardMaterial3D.new()
	leaf_mat_2.albedo_color = Color(0.20, 0.68, 0.32, 1.0)
	leaf_mat_2.roughness = 0.45
	leaf_mat_2.emission_enabled = true
	leaf_mat_2.emission = Color(0.08, 0.26, 0.12, 1.0)
	leaf_mat_2.emission_energy_multiplier = 0.4
	
	# Doğal Kireçtaşı Resif Tabanı (Doğal deniz tabanı kayası)
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.32, 0.34, 0.35, 1.0)
	rock_mat.roughness = 0.92
	rock_mat.metallic = 0.05
	
	# Hariç tutulacak alanlar (Binalar, NPC'ler, Oyuncu Doğma Noktası, Son Resif)
	var exclusions = [
		[Vector2(0, 0), 12.0],          # Oyuncu doğma alanı
		[Vector2(-68, -10), 18.0],      # Son Resif Korunağı (The Last Reef Sanctuary)
		[Vector2(-74.7, -26.1), 14.0],  # Araştırma İstasyonu
		[Vector2(-2, -13), 10.0],       # Kadim Midye
		[Vector2(-9, -15), 8.0],        # Yengeç NPC
		[Vector2(3, -18), 8.0],         # Deniz Tavşanı NPC
		[Vector2(14, -25), 8.0],        # Deniz Kestanesi NPC
		[Vector2(-4, -34), 8.0],        # Istakoz NPC
		[Vector2(-15, -25), 14.0],      # Bina 1
		[Vector2(20, -30), 14.0],       # Bina 2
		[Vector2(-5, -45), 14.0],       # Bina 3
		[Vector2(-35, -60), 16.0],      # Bina 4
		[Vector2(28, -55), 16.0],       # Bina 5
		[Vector2(-60, -45), 16.0],      # Bina 6
		[Vector2(15, -65), 16.0],       # Bina 7
		[Vector2(38, -34), 16.0],       # Bina 8
		[Vector2(-25, -68), 16.0],      # Bina 9
		[Vector2(-38, -72), 16.0],      # Bina 10
		[Vector2(-5, -82), 20.0],       # Canavar Bina Kuzey
		[Vector2(56, -58), 20.0],       # Canavar Bina Doğu
		[Vector2(-66, -68), 20.0],      # Canavar Bina Batı
		[Vector2(-52, -92), 20.0],      # Canavar Bina Derin Kuzey
		[Vector2(0, 35), 22.0]          # Termal Sıcak Su Akıntısı Bölgesi
	]
	
	# Poisson Disk Sampling ile minimum 18.0m aralıklı organik deniz çayırı dağılımı
	var meadow_spots = _generate_poisson_spots(170.0, 170.0, 20.0, 30, exclusions, 777)
	
	var plant_scene = load("res://scenes/underwater_plant.tscn")
	var plant_pack_scene = load("res://scenes/underwater_plant_pack.tscn")
	
	for i in range(meadow_spots.size()):
		var spot: Vector3 = meadow_spots[i]
		var garden_patch = Node3D.new()
		garden_patch.name = "PosidoniaPatch_%d" % i
		garden_patch.position = spot
		meadow_root.add_child(garden_patch)
		
		# 1. Doğal Organik Kaya Kaidesi (Düz disk YOK! Alçak, pürüzlü doğal kireçtaşı)
		var rock_base = MeshInstance3D.new()
		rock_base.name = "ReefRockBase"
		var rock_mesh = CylinderMesh.new()
		rock_mesh.top_radius = randf_range(1.6, 2.8)
		rock_mesh.bottom_radius = randf_range(2.2, 3.6)
		rock_mesh.height = 0.18 # İncecik doğal taban, kumsal seviyesinde
		rock_mesh.radial_segments = 7 # Pürüzlü asimetrik kaya formu
		rock_base.mesh = rock_mesh
		rock_base.material_override = rock_mat
		rock_base.position = Vector3(0, 0.08, 0)
		rock_base.rotation.y = randf_range(0, TAU)
		garden_patch.add_child(rock_base)
		
		# İkincil küçük doğal kaya çıkıntısı
		var sub_rock = MeshInstance3D.new()
		var sub_mesh = SphereMesh.new()
		sub_mesh.radius = randf_range(0.35, 0.7)
		sub_mesh.height = randf_range(0.4, 0.75)
		sub_mesh.radial_segments = 6
		sub_rock.mesh = sub_mesh
		sub_rock.material_override = rock_mat
		sub_rock.position = Vector3(randf_range(-1.0, 1.0), 0.15, randf_range(-1.0, 1.0))
		garden_patch.add_child(sub_rock)
		
		# 2. Gerçek 3B Posidonia oceanica Modelleri (Alternatifli Zenginlik)
		if i % 2 == 0 and plant_scene:
			var plant_inst = plant_scene.instantiate()
			plant_inst.position = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
			plant_inst.rotation.y = randf_range(0, TAU)
			var s = randf_range(0.9, 1.2)
			plant_inst.scale = Vector3(s, s, s)
			garden_patch.add_child(plant_inst)
		elif plant_pack_scene:
			var plant_inst = plant_pack_scene.instantiate()
			plant_inst.position = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
			plant_inst.rotation.y = randf_range(0, TAU)
			var s = randf_range(0.9, 1.15)
			plant_inst.scale = Vector3(s, s, s)
			garden_patch.add_child(plant_inst)
		
		# 3. Dalgalanan Doğal Posidonia Erişteleri (Akıntıyla Sallanan Yapraklar)
		var num_blades = randi_range(14, 20)
		for b in range(num_blades):
			var blade = MeshInstance3D.new()
			blade.name = "Blade_%d" % b
			
			var b_mesh = BoxMesh.new()
			var blade_h = randf_range(1.5, 2.6) # Doğal boy çeşitliliği
			var blade_w = randf_range(0.06, 0.10)
			b_mesh.size = Vector3(blade_w, blade_h, 0.015)
			blade.mesh = b_mesh
			blade.material_override = leaf_mat_1 if (b % 2 == 0) else leaf_mat_2
			
			var blade_ang = randf_range(0, TAU)
			var blade_dist = randf_range(0.3, 2.5) # Yamaç etrafında doğal yayılım
			blade.position = Vector3(cos(blade_ang) * blade_dist, blade_h * 0.5, sin(blade_ang) * blade_dist)
			
			var init_rx = randf_range(-0.16, 0.16)
			var init_rz = randf_range(-0.16, 0.16)
			var init_ry = randf_range(0, TAU)
			blade.rotation = Vector3(init_rx, init_ry, init_rz)
			
			garden_patch.add_child(blade)
			
			# Animasyon listesine ekle (su akıntısıyla dalgalanma)
			var phase = randf_range(0, TAU)
			seagrass_blades.append([blade, init_rz, init_rx, phase])
		
		# 4. Biyolüminesans Resif Işıltısı (OmniLight3D)
		var patch_light = OmniLight3D.new()
		patch_light.name = "SanctuaryGlow"
		patch_light.light_energy = 1.1
		patch_light.omni_range = 6.0
		if i % 3 == 0:
			patch_light.light_color = Color(0.25, 0.95, 0.65, 1.0) # Zümrüt parıltı
		elif i % 3 == 1:
			patch_light.light_color = Color(1.0, 0.70, 0.35, 1.0) # Sıcak altın parıltı
		else:
			patch_light.light_color = Color(0.85, 0.45, 0.95, 1.0) # Mercan lavanta parıltı
		patch_light.position = Vector3(0, 1.2, 0)
		garden_patch.add_child(patch_light)

# Poisson Disk Sampling (Bridson Algoritması / Mavi Gürültü Üreticisi)
func _generate_poisson_spots(width: float, height: float, r_min: float, k: int, exclusion_circles: Array, seed_val: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var cell_size = r_min / sqrt(2.0)
	var grid_w = int(ceil(width / cell_size))
	var grid_h = int(ceil(height / cell_size))
	
	var grid: Array = []
	for gy in range(grid_h):
		var row: Array = []
		for gx in range(grid_w):
			row.append(-1)
		grid.append(row)
		
	var points: Array = []
	var spawn_points: Array = []
	
	# Başlangıç tohum noktası seçimi (engeller dışı)
	for _att in range(200):
		var sx = rng.randf_range(width * 0.1, width * 0.9)
		var sz = rng.randf_range(height * 0.1, height * 0.9)
		var wx = sx - width * 0.5
		var wz = sz - height * 0.5
		var blocked = false
		for ex in exclusion_circles:
			var c: Vector2 = ex[0]
			var r: float = ex[1]
			if Vector2(wx, wz).distance_to(c) < r:
				blocked = true
				break
		if not blocked:
			var idx = points.size()
			points.append(Vector2(sx, sz))
			spawn_points.append(Vector2(sx, sz))
			var gx = int(sx / cell_size)
			var gz = int(sz / cell_size)
			if gx >= 0 and gx < grid_w and gz >= 0 and gz < grid_h:
				grid[gz][gx] = idx
			break
			
	while spawn_points.size() > 0:
		var s_idx = rng.randi_range(0, spawn_points.size() - 1)
		var sp: Vector2 = spawn_points[s_idx]
		var found = false
		
		for _attempt in range(k):
			var angle = rng.randf_range(0.0, TAU)
			var dist = rng.randf_range(r_min, 2.0 * r_min)
			var cx = sp.x + cos(angle) * dist
			var cz = sp.y + sin(angle) * dist
			
			if cx >= 0.0 and cx < width and cz >= 0.0 and cz < height:
				var wx = cx - width * 0.5
				var wz = cz - height * 0.5
				var blocked = false
				for ex in exclusion_circles:
					var c: Vector2 = ex[0]
					var r: float = ex[1]
					if Vector2(wx, wz).distance_to(c) < r:
						blocked = true
						break
				if blocked:
					continue
					
				var gx = int(cx / cell_size)
				var gz = int(cz / cell_size)
				
				var too_close = false
				var min_gy = max(0, gz - 2)
				var max_gy = min(grid_h - 1, gz + 2)
				var min_gx = max(0, gx - 2)
				var max_gx = min(grid_w - 1, gx + 2)
				
				for ny in range(min_gy, max_gy + 1):
					for nx in range(min_gx, max_gx + 1):
						var p_idx = grid[ny][nx]
						if p_idx != -1:
							var p: Vector2 = points[p_idx]
							if Vector2(cx, cz).distance_to(p) < r_min:
								too_close = true
								break
					if too_close:
						break
						
				if not too_close:
					var idx = points.size()
					points.append(Vector2(cx, cz))
					spawn_points.append(Vector2(cx, cz))
					if gx >= 0 and gx < grid_w and gz >= 0 and gz < grid_h:
						grid[gz][gx] = idx
					found = true
					break
					
		if not found:
			spawn_points.remove_at(s_idx)
			
	var spots: Array = []
	for p in points:
		spots.append(Vector3(p.x - width * 0.5, -7.48, p.y - height * 0.5))
	return spots


