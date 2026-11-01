extends Node3D

# Akdeniz Tekil / Çift Balık Yapay Zekâsı (Mediterranean Fish AI)
# Doğal devriye yüzüşü, iskelet/yüzme animasyonu, gövde salınımı ve Caretta'dan kaçınma

@export var species_name: String = "Levrek"
@export var patrol_radius_x: float = 4.5
@export var patrol_radius_z: float = 4.5
@export var swim_speed: float = 0.9
@export var vertical_bobbing: float = 0.4

var home_position: Vector3
var current_angle: float = 0.0
var time_offset: float = 0.0
var base_child_rot_y: Dictionary = {}

func _ready():
	home_position = position
	time_offset = randf_range(0.0, 20.0)
	
	# İskelet animasyonunu otomatik bul ve başlat
	var anim_players = find_children("*", "AnimationPlayer", true, false)
	for ap in anim_players:
		if ap.has_animation("Swimming"):
			var anim = ap.get_animation("Swimming")
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.speed_scale = randf_range(0.85, 1.2)
			ap.play("Swimming")
		elif ap.has_animation("Angelfish|Swim"):
			var anim = ap.get_animation("Angelfish|Swim")
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.speed_scale = randf_range(0.85, 1.2)
			ap.play("Angelfish|Swim")
			
	for c in get_children():
		if c is Node3D:
			base_child_rot_y[c] = c.rotation.y

func _process(delta: float):
	var t = Time.get_ticks_msec() * 0.001 + time_offset
	current_angle += swim_speed * delta * 0.7
	
	# Organik lemniscate (sekiz figürü) sualtı yüzüş rotası
	var target_x = home_position.x + sin(current_angle) * patrol_radius_x
	var target_y = home_position.y + sin(current_angle * 1.5) * vertical_bobbing
	var target_z = home_position.z + cos(current_angle * 2.0) * (patrol_radius_z * 0.6)
	
	var target_pos = Vector3(target_x, target_y, target_z)
	
	# Caretta yaklaştığında hafif süzülüp kaçınma
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 3.5:
			var flee_dir = (global_position - player.global_position).normalized()
			flee_dir.y = 0.15
			target_pos += flee_dir * (3.5 - dist) * 1.2
			
	var move_vec = target_pos - position
	if move_vec.length() > 0.04:
		var target_yaw = atan2(move_vec.x, move_vec.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 3.5 * delta)
		
	position = position.lerp(target_pos, 2.2 * delta)
	
	# İskeletsiz balık modelleri için organik yüzme kuyruk salınımı
	for c in base_child_rot_y.keys():
		if is_instance_valid(c):
			var base_y = base_child_rot_y[c]
			c.rotation.y = base_y + sin(t * 7.5) * 0.14
			c.position.y += sin(t * 5.0) * 0.0015

