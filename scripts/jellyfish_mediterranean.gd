extends Area3D

# Akdeniz Yerli Denizanası (Cotylorhiza tuberculata - "Sahanda Yumurta Denizanası")
# Kadim, zararsız ve zehirsiz Akdeniz türüdür.
# Caretta'nın doğadaki en sevdiği ve temel besin kaynağıdır. Tüketildiğinde can yeniler (+25 HP).

@export var heal_amount: float = 25.0

var base_y: float = 0.0
var time_offset: float = 0.0
var is_consumed: bool = false

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var bell_mesh: MeshInstance3D = get_node_or_null("VisualRoot/Bell")

func _ready():
	base_y = position.y
	time_offset = randf() * 10.0
	body_entered.connect(_on_body_entered)
	_ensure_egg_yolk_yellow()

func _ensure_egg_yolk_yellow():
	# Yerli Sahanda Yumurta Denizanası'nın (Cotylorhiza tuberculata)
	# altın sarısı kubbesini ve kehribar ışıltısını PBR materyallerle garantiye al
	if visual_root:
		var tex = load("res://assets/colorful_jellyfish/textures/Jellyfish1_baseColor.jpeg")
		for mesh_inst in visual_root.find_children("*", "MeshInstance3D", true, false):
			var m = StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if tex:
				m.albedo_texture = tex
			m.albedo_color = Color(1.0, 0.92, 0.25, 0.88)
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = Color(0.95, 0.80, 0.15)
			m.emission_energy_multiplier = 0.6
			m.rim_enabled = true
			m.rim = 0.9
			m.rim_tint = 0.6
			mesh_inst.material_override = m

func _process(_delta: float):
	if is_consumed:
		return
	var t = Time.get_ticks_msec() * 0.001 + time_offset
	# Suda nabız gibi kasılıp süzülme (Jellyfish swimming pulse)
	var pulse = sin(t * 2.2)
	if visual_root:
		visual_root.position.y = sin(t * 1.2) * 0.25
		visual_root.scale.y = 1.0 + pulse * 0.15
		visual_root.scale.x = 1.0 - pulse * 0.08
		visual_root.scale.z = 1.0 - pulse * 0.08

func _on_body_entered(body: Node3D):
	if is_consumed:
		return
	if body.is_in_group("player"):
		is_consumed = true
		set_deferred("monitoring", false)
		if body.has_method("apply_healing"):
			body.apply_healing(heal_amount)
		if body.has_signal("badge_unlocked"):
			body.badge_unlocked.emit(
				"Sahanda Yumurta Ziyafeti",
				"İlk kez yerli Sahanda Yumurta Denizanası (Cotylorhiza tuberculata) tükettin; Akdeniz'in doğal şifasıyla canını tazeledin (+25 Can)!"
			)
		if get_tree().root.has_node("AudioManager"):
			get_tree().root.get_node("AudioManager").play_sfx("heal")
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("show_screen_heal_alert"):
			hud.show_screen_heal_alert("💚 YERLİ DENİZANASI TÜKETİLDİ! Doğal besin (+%d Can)" % int(heal_amount))
		queue_free()

