extends Node3D

# CARETTA: SON RESİF 2050 - Okyanus Kâşifi Deniz Kaplumbağası AI (Ocean Explorer Sea Turtle)
# Son Resif üzerinde süzülen, flipper çırpan ve Caretta'nın ekibinden olan yoldaş kaplumbağalar.

@export var explorer_name: String = "Kâşif Atlas"
@export var greeting_text: String = "Caretta! Son Resif'in tohumları burada güvende!"
@export var patrol_center: Vector3 = Vector3(-68.0, -4.2, -10.0)
@export var orbit_radius_x: float = 8.5
@export var orbit_radius_z: float = 6.5
@export var orbit_speed: float = 0.32
@export var phase_offset: float = 0.0
@export var altitude_base: float = -4.2
@export var altitude_amplitude: float = 0.65
@export var flipper_speed: float = 0.95
@export var turtle_scale: float = 0.72

@onready var model_node: Node3D = $TurtleModel
@onready var label_node: Label3D = $GreetingLabel

var anim_player: AnimationPlayer = null
var player_ref: Node3D = null

func _ready():
	scale = Vector3(turtle_scale, turtle_scale, turtle_scale)
	
	# Model içerisindeki AnimationPlayer'ı bul ve yüzme animasyonunu başlat
	if model_node:
		anim_player = model_node.find_child("AnimationPlayer", true, false)
		if anim_player:
			if anim_player.has_animation("SwimForward"):
				anim_player.play("SwimForward")
				anim_player.speed_scale = flipper_speed
			elif anim_player.has_animation("Float"):
				anim_player.play("Float")
	
	if label_node:
		label_node.text = "%s\n\"%s\"" % [explorer_name, greeting_text]
		label_node.visible = false
		
	# Başlangıç pozisyonunu ata
	global_position = _calc_path_point(0.0)
	player_ref = get_tree().root.find_child("Player", true, false)

func _process(delta: float):
	var t = Time.get_ticks_msec() * 0.001 * orbit_speed + phase_offset
	var next_pos = _calc_path_point(t)
	
	# Hareketi güncelle
	var move_dir = next_pos - global_position
	global_position = next_pos
	
	# Yüzüş yönüne doğru yumuşakça dönme ve bank yapma
	if move_dir.length_squared() > 0.0001:
		var flat_dir = Vector3(move_dir.x, 0.0, move_dir.z).normalized()
		if flat_dir.length_squared() > 0.01:
			var target_yaw = atan2(-flat_dir.x, -flat_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clamp(5.0 * delta, 0.0, 1.0))
		
		# Dikey eğim (Pitch)
		var pitch_ratio = clamp(move_dir.y / (move_dir.length() + 0.001), -0.5, 0.5)
		rotation.x = lerp_angle(rotation.x, -pitch_ratio * 0.75, clamp(4.0 * delta, 0.0, 1.0))
		
		# Dönüşte yana yatma (Roll / Bank)
		var bank_angle = sin(t) * 0.20
		rotation.z = lerp_angle(rotation.z, bank_angle, clamp(4.0 * delta, 0.0, 1.0))
	
	# Oyuncu yakınsa selam baloncuğunu göster
	if label_node:
		if not player_ref:
			player_ref = get_tree().root.find_child("Player", true, false)
		if player_ref:
			var dist = global_position.distance_to(player_ref.global_position)
			label_node.visible = (dist < 9.0)

func _calc_path_point(t: float) -> Vector3:
	# Organik kıvrımlı Lissajous / elips yörüngesi
	var px = patrol_center.x + sin(t) * orbit_radius_x
	var pz = patrol_center.z + cos(t * 0.85) * orbit_radius_z
	var py = altitude_base + sin(t * 1.7) * altitude_amplitude
	return Vector3(px, py, pz)
