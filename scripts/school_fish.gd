extends Node3D

# Akdeniz Renkli Balık Sürüsü (School of Colorful Mediterranean Fish)
# Doğal yüzüş yörüngesi, kemik/yüzme animasyonu ve Caretta yaklaştığında dağılma yapay zekâsı

@export var swim_radius_x: float = 6.0
@export var swim_radius_z: float = 6.0
@export var swim_speed: float = 0.85
@export var fish_color_type: String = "Thalassoma" # Thalassoma (Gökkuşağı Lapini), Symphodus (Benekli Lapin), Perciformes (Levrek)

var home_position: Vector3
var current_angle: float = 0.0
var time_offset: float = 0.0
var child_base_rot_y: Dictionary = {}

func _ready():
	home_position = position
	time_offset = randf_range(0.0, 10.0)
	
	# İskelet animasyonlu balıklar (Levrek vb.) için yüzme animasyonunu döngüye al ve başlat
	var anim_players = find_children("*", "AnimationPlayer", true, false)
	for ap in anim_players:
		if ap.has_animation("Swimming"):
			var anim = ap.get_animation("Swimming")
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.speed_scale = randf_range(0.9, 1.25)
			ap.play("Swimming")
		elif ap.has_animation("Angelfish|Swim"):
			var anim = ap.get_animation("Angelfish|Swim")
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.speed_scale = randf_range(0.9, 1.2)
			ap.play("Angelfish|Swim")
			
	# Çocuk düğümlerin temel yönelimlerini kaydet
	var fish_children = get_children()
	for child in fish_children:
		if child is Node3D:
			child_base_rot_y[child] = child.rotation.y

func _process(delta: float):
	var t = Time.get_ticks_msec() * 0.001 + time_offset
	current_angle += swim_speed * delta
	
	# Doğal 3D lemniscate (sekiz figürü) sualtı yüzüş yörüngesi
	var target_x = home_position.x + sin(current_angle) * swim_radius_x
	var target_y = home_position.y + sin(current_angle * 1.8) * 0.65
	var target_z = home_position.z + sin(current_angle * 2.0) * (swim_radius_z * 0.5)
	
	var target_pos = Vector3(target_x, target_y, target_z)
	
	# Caretta yaklaştığında hafifçe kaçışma / dağılma
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 4.0:
			var flee_dir = (global_position - player.global_position).normalized()
			flee_dir.y = 0.2
			target_pos += flee_dir * (4.0 - dist) * 1.3
			
	var move_vec = target_pos - position
	if move_vec.length() > 0.05:
		var target_yaw = atan2(move_vec.x, move_vec.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 4.0 * delta)
		
	position = position.lerp(target_pos, 2.5 * delta)
	
	# Balıkların su içindeki hafif yüzme salınımı (Fish body wiggle)
	var fish_children = get_children()
	for i in range(fish_children.size()):
		var child = fish_children[i]
		if child is Node3D and not (child is OmniLight3D):
			var base_y = child_base_rot_y.get(child, 0.0)
			var phase = t * 7.5 + float(i) * 0.8
			child.rotation.y = base_y + sin(phase) * 0.16
			child.position.y += sin(phase * 0.7) * 0.002
