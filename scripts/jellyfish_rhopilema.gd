extends Area3D

# Kızıldeniz İstilacısı Göçmen Denizanası (Rhopilema nomadica)
# Süveyş Kanalı üzerinden Akdeniz'e göç eden yakıcı, zehirli ve istilacı dev tür.
# Trilyonlarca yakıcı nematosist hücresiyle Caretta'nın göz ve ağız mukozasını yakar (-15 HP).

@export var sting_damage: float = 15.0
@export var hit_cooldown_time: float = 2.0

var base_y: float = 0.0
var time_offset: float = 0.0
var hit_cooldown: float = 0.0

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")

func _ready():
	base_y = position.y
	time_offset = randf() * 10.0
	body_entered.connect(_on_body_entered)

func _process(delta: float):
	if hit_cooldown > 0.0:
		hit_cooldown -= delta
		
	var t = Time.get_ticks_msec() * 0.001 + time_offset
	var pulse = sin(t * 1.8)
	if visual_root:
		visual_root.position.y = sin(t * 0.9) * 0.35
		visual_root.scale.y = 1.0 + pulse * 0.12
		visual_root.scale.x = 1.0 - pulse * 0.06
		visual_root.scale.z = 1.0 - pulse * 0.06

func _on_body_entered(body: Node3D):
	if hit_cooldown > 0.0:
		return
	if body.is_in_group("player"):
		hit_cooldown = hit_cooldown_time
		if body.has_method("take_damage"):
			body.take_damage(sting_damage)
		if get_tree().root.has_node("AudioManager"):
			get_tree().root.get_node("AudioManager").play_sfx("damage")
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("show_screen_danger_alert"):
			hud.show_screen_danger_alert("⚡ İSTİLACI DENİZANASI ÇARPTI! Yakıcı nematosist zehri (-%d Can)!" % int(sting_damage))

