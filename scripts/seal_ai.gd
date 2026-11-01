extends CharacterBody3D

# Akdeniz Foku (Monachus monachus) - Devriye ve Kovalama Yapay Zekâsı
# Sakince kendi bölgesinde daireler çizerek devriye gezer.
# Caretta yaklaştığında kovalar, ancak aradaki mesafe çok az açıldığı anda
# veya kendi yuvasından biraz uzaklaştığında takibi hemen bırakıp yuvasına döner.

enum State { PATROL, CHASE, RETURN }
var current_state: State = State.PATROL

@export var patrol_speed: float = 3.5
@export var chase_speed: float = 8.5
@export var return_speed: float = 5.0

# Mesafe Eşikleri:
# detect_radius: Oyuncu bu mesafeye kadar yaklaştığında kovalamaya başlar.
# escape_radius: Aradaki mesafe çok az açıldığında (örneğin 14.5m) takibi anında bırakır.
# max_leash_distance: Kendi yuvasından (home_position) en fazla ne kadar uzaklaşabilir.
@export var detect_radius: float = 11.5
@export var escape_radius: float = 14.5
@export var max_leash_distance: float = 18.0

@export var attack_radius: float = 2.6
@export var attack_damage: float = 20.0

var home_position: Vector3
var patrol_angle: float = 0.0
var attack_cooldown: float = 0.0
var re_aggro_timer: float = 0.0

var player: CharacterBody3D = null

func _ready():
	home_position = global_position
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func _physics_process(delta: float):
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if re_aggro_timer > 0.0:
		re_aggro_timer -= delta
		
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return

	var dist_to_player = global_position.distance_to(player.global_position)
	var dist_to_home = global_position.distance_to(home_position)
	
	match current_state:
		State.PATROL:
			patrol_angle += 0.5 * delta
			var target_pos = home_position + Vector3(sin(patrol_angle) * 10.0, sin(patrol_angle * 1.5) * 1.2, cos(patrol_angle) * 10.0)
			move_towards(target_pos, patrol_speed, delta)
			
			# Yalnızca re_aggro soğuma süresi bittiyse, oyuncu yakınsa ve diyalog açık değilse kovalamaya başla
			if dist_to_player < detect_radius and re_aggro_timer <= 0.0 and not _is_dialogue_open():
				current_state = State.CHASE
				set_hud_alert(true)
				
		State.CHASE:
			# Oyuncu herhangi bir NPC ile konuşuyorsa takibi hemen iptal et ve yuvasına dön
			if _is_dialogue_open():
				start_return()
			elif dist_to_player < attack_radius and attack_cooldown <= 0.0:
				attack_player()
			
			# Oyuncu mesafeyi çok az açtığında VEYA fok yuvasından fazla uzaklaştığında kovalamayı HEMEN bırak
			elif dist_to_player > escape_radius or dist_to_home > max_leash_distance:
				start_return()
			else:
				move_towards(player.global_position, chase_speed, delta)
				
		State.RETURN:
			# Doğrudan orijinal yuvasına geri yüz
			move_towards(home_position, return_speed, delta)
			
			# Yuvasına ulaştığında tekrar sakin devriyeye geç
			if dist_to_home < 3.0:
				current_state = State.PATROL

	# Yüzerken gövdenin hafif dalgalanması
	rotation.z = sin(Time.get_ticks_msec() * 0.004) * 0.12

func start_return():
	current_state = State.RETURN
	set_hud_alert(false)
	# Kovalamayı bıraktığında 4 saniye boyunca tekrar saldırmasın (yuvasına rahatça dönsün)
	re_aggro_timer = 4.0

func move_towards(target_pos: Vector3, speed: float, delta: float):
	var dir = (target_pos - global_position).normalized()
	velocity = velocity.lerp(dir * speed, 3.5 * delta)
	move_and_slide()
	
	if velocity.length() > 0.3:
		# Model -Z yönüne baktığı için yönelme açısı
		var target_yaw = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 4.0 * delta)

func attack_player():
	attack_cooldown = 2.5
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
		var knockback = (player.global_position - global_position).normalized() * 8.0
		player.velocity += knockback

func set_hud_alert(active: bool):
	var alert = get_tree().root.find_child("SealAlert", true, false)
	if alert:
		alert.visible = active

func _is_dialogue_open() -> bool:
	var dbox = get_tree().root.find_child("DialogueBox", true, false)
	return dbox != null and "is_active" in dbox and dbox.is_active
