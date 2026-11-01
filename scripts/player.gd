extends CharacterBody3D

# Caretta 3D yüzme + üçüncü şahıs yörünge (orbit / follow) kamerası

@export var swim_speed: float = 6.0
@export var sprint_speed: float = 8.5
@export var vertical_speed: float = 4.0
@export var turn_lerp: float = 8.0
@export var model_yaw_offset: float = PI  # Modelin başı +Z'ye baktığı için 180 derece (PI) çeviriyoruz
@export var mouse_sensitivity: float = 0.003
@export var min_zoom: float = 2.5
@export var max_zoom: float = 14.0
@export var camera_height: float = 1.0

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var base_swim_speed: float = 6.0
var base_sprint_speed: float = 8.5
var is_sprinting: bool = false
var in_hot_zone: bool = false
var is_talking: bool = false
var is_inventory_open: bool = false
var is_suffocating: bool = false
var suffocation_timer_id: int = 0
var inventory: Array = []
var max_inventory: int = 15

signal health_changed(new_health)
signal stamina_changed(new_stamina)
signal inventory_updated(items)
signal badge_unlocked(badge_name, description)

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $TurtleModel
var anim_player: AnimationPlayer = null

const SCENE_BOTTLE_SMALL = preload("res://scenes/bottle_small_collectible.tscn")
const SCENE_BOTTLE_LARGE = preload("res://scenes/bottle_large_collectible.tscn")
const SCENE_GLASS_BOTTLE = preload("res://scenes/glass_bottle_collectible.tscn")
const SCENE_METAL_CAN = preload("res://scenes/metal_can_collectible.tscn")
const SCENE_WATER_BOTTLE = preload("res://scenes/water_bottle_collectible.tscn")
const SCENE_BOOK = preload("res://scenes/book_collectible.tscn")

func _ready():
	add_to_group("player")
	base_swim_speed = swim_speed
	base_sprint_speed = sprint_speed
	spring_arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Kaplumbağanın Sketchfab animasyonlarını bağla
	anim_player = model.find_child("AnimationPlayer", true, false)
	if anim_player:
		if anim_player.has_animation("SwimIdle"):
			anim_player.play("SwimIdle")
		elif anim_player.has_animation("Float"):
			anim_player.play("Float")

	# Oyun açılış monoloğu: İklim fırtınasıyla ekibinden kopan Caretta'nın Son Resif hedefi
	get_tree().create_timer(0.6).timeout.connect(func():
		var hud = get_tree().root.find_child("DialogueBox", true, false)
		if hud and hud.has_method("start_dialogue"):
			hud.start_dialogue([
				{
					"speaker": "🐢 Caretta",
					"text": "(Hafifçe sersemlemiş halde suların içine bakınır)\n\"Of... Neredeyim ben? Ben Antalya kıyılarında doğdum, atalarım 100 milyon yıldır bu sularda yüzüyor... Ama deniz hiç bu kadar kaynamamıştı! O devasa sıcak su dalgası ve asit fırtınası aniden patladı... Şiddetli akıntılar beni Okyanus Kâşifleri ekibimden kopardı!\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Yıl 2050... Küresel ısınma +2.5°C'yi aştı, yüzey suları 31.8°C ile yanıyor ve dünyadaki mercanların çoğu yok oldu. 2026 COP31 Antalya Zirvesi'nden miras kalan 'Son Resif' tohumlarını korumak için kâşiflerle buradaydık.\n\nEkibim batık kanyonun dibindeki ÖÇK Sualtı Gözlem ve İzleme İstasyonu'na sığınmış olmalı. Yerli deniz canlılarıyla konuşup kâşiflerin izini bulmalı, istasyonun kapısını açıp Son Resif'i kurtarmalıyım!\"",
					"color": Color(0.3, 1.0, 0.5)
				}
			])
	)

func _unhandled_input(event):
	# Envanter veya diyalog açıkken serbest fare hareketini koru
	if is_inventory_open or is_talking:
		return

	# Fare ile serbest kamera kontrolü
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * mouse_sensitivity
		pivot.rotation.x = clamp(pivot.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-80), deg_to_rad(70))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - 0.4, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + 0.4, min_zoom, max_zoom)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not is_inventory_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float):
	# Konuşma veya Envanter açıkken yüzme hareketini durdur
	if is_talking or is_inventory_open:
		velocity = velocity.lerp(Vector3.ZERO, 8.0 * delta)
		move_and_slide()
		return

	# Gamepad Sağ Analog ile Serbest Kamera Kontrolü
	var joy_rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var joy_ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(joy_rx) > 0.15:
		pivot.rotation.y -= joy_rx * 2.8 * delta
	if abs(joy_ry) > 0.15:
		pivot.rotation.x = clamp(pivot.rotation.x - joy_ry * 2.2 * delta, deg_to_rad(-80), deg_to_rad(70))

	# Klavye (WASD) + Gamepad Sol Analog ile Hareket Vektörü
	var input_vec = Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if Input.is_action_pressed("ui_up"): input_vec.y -= 1
	if Input.is_action_pressed("ui_down"): input_vec.y += 1
	if Input.is_action_pressed("ui_left"): input_vec.x -= 1
	if Input.is_action_pressed("ui_right"): input_vec.x += 1

	var joy_lx = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_ly = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_lx) > 0.15:
		input_vec.x += joy_lx
	if abs(joy_ly) > 0.15:
		input_vec.y += joy_ly

	# Fare Sağ Tuşu (Sağ Tık / RMB) ile Hızlı Yüzme (Shift ile birebir aynı özellik)
	var mouse_sprint := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if mouse_sprint and input_vec.is_zero_approx():
		# Sağ tuşa basılı tutulduğunda klavyede yön tuşuna basılmıyorsa farenin baktığı yöne doğru hızla yüzer
		input_vec.y -= 1.0

	input_vec = input_vec.limit_length(1.0)

	# Kameraya göre yön: kameranın baktığı yöne doğru yüzülür
	var cam_basis: Basis = pivot.global_transform.basis
	var dir: Vector3 = cam_basis.x * input_vec.x + cam_basis.z * input_vec.y

	# Dikey Hareket (Boşluk/C/Ctrl + Gamepad A/B/Trigger'lar)
	var vert := 0.0
	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		vert += 1.0
	if Input.is_physical_key_pressed(KEY_C) or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		vert -= 1.0

	var joy_rt = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var joy_lt = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if joy_rt > 0.15: vert += joy_rt
	if joy_lt > 0.15: vert -= joy_lt

	# Hızlı Yüzme (Shift / Farenin Sağ Tuşu / Gamepad L3 / RB / RT)
	var joy_sprint = Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or joy_rt > 0.6
	var wants_sprint = (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT) or mouse_sprint or joy_sprint) and (input_vec.length() > 0.1 or vert != 0.0) and stamina > 5.0
	is_sprinting = wants_sprint
	
	var current_speed = swim_speed
	if is_sprinting:
		current_speed = sprint_speed
		stamina = max(stamina - 26.0 * delta, 0.0)
		if anim_player:
			anim_player.speed_scale = 1.7
	else:
		stamina = min(stamina + 18.0 * delta, max_stamina)
		if anim_player:
			anim_player.speed_scale = 1.0

	stamina_changed.emit(stamina)

	var target_velocity = dir * current_speed
	target_velocity.y += vert * (vertical_speed * (1.5 if is_sprinting else 1.0))
	velocity = velocity.lerp(target_velocity, 4.0 * delta)
	move_and_slide()

	# Kaplumbağa hareket yönüne doğru döner
	var flat = Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.3:
		var target_yaw = atan2(-flat.x, -flat.z) + model_yaw_offset
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clamp(turn_lerp * delta, 0.0, 1.0))

	# Yüzme animasyonu geçişi
	if anim_player:
		var is_moving = velocity.length() > 0.4
		var target_anim = "SwimForward" if is_moving else "SwimIdle"
		if anim_player.has_animation(target_anim) and anim_player.current_animation != target_anim:
			anim_player.play(target_anim)

	if in_hot_zone:
		take_damage(6.0 * delta)

func take_damage(amount: float):
	health = clamp(health - amount, 0.0, max_health)
	health_changed.emit(health)

func apply_healing(amount: float = 50.0):
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health)

func apply_plastic_ingestion(damage: float = 20.0, slow_duration: float = 4.5):
	take_damage(damage)
	if get_tree().root.has_node("AudioManager"):
		get_tree().root.get_node("AudioManager").play_sfx("damage")
	is_suffocating = true
	suffocation_timer_id += 1
	var current_id = suffocation_timer_id
	swim_speed = max(2.5, base_swim_speed * 0.5)
	sprint_speed = max(3.5, base_sprint_speed * 0.5)
	var hud_warning = get_tree().root.find_child("HUD", true, false)
	if hud_warning and hud_warning.has_method("show_screen_danger_alert"):
		hud_warning.show_screen_danger_alert("⚠️ PLASTİK YUTULDU! Yemek borusu tıkandı (-%d Can & Yavaşlama)!" % int(damage))
	if hud_warning and hud_warning.has_method("show_tutorial_tip"):
		hud_warning.show_tutorial_tip("⚠️ İPUCU: Sarı/kahverengi yerli denizanasını (Cotylorhiza) bulursan canın yenilenir!", 5.5)
	var tree = get_tree()
	if tree:
		tree.create_timer(slow_duration).timeout.connect(func():
			if is_instance_valid(self) and suffocation_timer_id == current_id:
				is_suffocating = false
				swim_speed = base_swim_speed
				sprint_speed = base_sprint_speed
		)
	else:
		is_suffocating = false
		swim_speed = base_swim_speed
		sprint_speed = base_sprint_speed

var can_break_shipwrecks: bool = false

func enable_wreck_breaker():
	can_break_shipwrecks = true
	badge_unlocked.emit("Zırhlı Yarıcı", "Metal Zırh Gücü: Batık çelik kapılarını ve demir ızgaraları parçalama gücü kazandın!")

func apply_speed_boost(multiplier: float = 1.25):
	base_swim_speed = clamp(base_swim_speed * multiplier, 6.0, 10.0)
	base_sprint_speed = clamp(base_sprint_speed * multiplier, 12.0, 18.0)
	if is_suffocating:
		swim_speed = max(2.5, base_swim_speed * 0.5)
		sprint_speed = max(4.5, base_sprint_speed * 0.5)
	else:
		swim_speed = base_swim_speed
		sprint_speed = base_sprint_speed

func enhance_bioluminescence():
	var light = find_child("BioluminescenceLight", true, false)
	if not light:
		light = OmniLight3D.new()
		light.name = "BioluminescenceLight"
		light.light_color = Color(0.3, 0.95, 0.85)
		light.light_energy = 2.4
		light.omni_range = 16.0
		add_child(light)
	else:
		light.light_energy = 2.8
		light.omni_range = 22.0

func has_item_with_keyword(keyword: String) -> bool:
	for item in inventory:
		if keyword.to_lower() in str(item).to_lower():
			return true
	return false

func remove_item_by_keyword(keyword: String) -> String:
	for i in range(inventory.size()):
		var item_str: String = str(inventory[i])
		if keyword.to_lower() in item_str.to_lower():
			inventory.remove_at(i)
			inventory_updated.emit(inventory)
			return item_str
	return ""

func can_collect_item() -> bool:
	return inventory.size() < max_inventory

func collect_item(item_name: String) -> bool:
	if inventory.size() >= max_inventory:
		var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
		if tree and tree.root:
			var hud = tree.root.find_child("HUD", true, false)
			if hud and hud.has_method("show_screen_heal_alert"):
				hud.show_screen_heal_alert("⚠️ Envanter Dolu! (Maksimum %d/15 Atık)" % max_inventory)
		return false
	inventory.append(item_name)
	inventory_updated.emit(inventory)
	if inventory.size() == 1:
		badge_unlocked.emit("Resif Temizleyicisi", "İlk geri dönüştürülebilir atığı topladın.")
	return true

func drop_item(index: int):
	if index < 0 or index >= inventory.size():
		return
	var item_name = inventory[index]
	inventory.remove_at(index)
	inventory_updated.emit(inventory)
	_spawn_dropped_item(item_name)

func _spawn_dropped_item(item_name: String):
	var scene_to_spawn: PackedScene = SCENE_WATER_BOTTLE
	if "Küçük" in item_name or "0.5L" in item_name:
		scene_to_spawn = SCENE_BOTTLE_SMALL
	elif "Büyük" in item_name or "1.5L" in item_name:
		scene_to_spawn = SCENE_BOTTLE_LARGE
	elif "Cam" in item_name:
		scene_to_spawn = SCENE_GLASS_BOTTLE
	elif "Alüminyum" in item_name or "Metal" in item_name:
		scene_to_spawn = SCENE_METAL_CAN
	elif "Kitap" in item_name or "Kağıt" in item_name:
		scene_to_spawn = SCENE_BOOK

	var drop_node = scene_to_spawn.instantiate()
	
	# Kameranın baktığı yönün 2.2m önüne ve hafif aşağısına bırak
	var cam_forward = -transform.basis.z.normalized()
	if is_inside_tree() and pivot and is_instance_valid(pivot) and pivot.is_inside_tree():
		cam_forward = -pivot.global_transform.basis.z.normalized()
	var spawn_pos = position + cam_forward * 2.2 - Vector3(0, 0.3, 0)
	
	var collectibles_parent = get_parent().find_child("Collectibles", true, false)
	if collectibles_parent:
		collectibles_parent.add_child(drop_node)
	else:
		get_parent().add_child(drop_node)
		
	drop_node.global_position = spawn_pos
	
	# Anında tekrar toplanmaması için 1.5 saniye koruma
	if "can_be_collected" in drop_node:
		drop_node.can_be_collected = false
		var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
		if tree:
			tree.create_timer(1.5).timeout.connect(func():
				if is_instance_valid(drop_node):
					drop_node.can_be_collected = true
			)
