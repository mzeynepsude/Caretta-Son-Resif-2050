extends Area3D

# Deri Sırtlı Bilge Dev (Dermochelys coriacea)
# Kutupları görmüş, 80-90 yıllık devasa gezgin kaplumbağa NPC'si

var player_near: bool = false
var base_y: float = 0.0
@onready var anim_player = find_child("AnimationPlayer", true, false)

var dialogues = [
	{
		"speaker": "Deri Sırtlı Bilge Dev (Dermochelys coriacea)",
		"text": "(Ağır ve bilgece süzülür, derin ve yorgun bir ses tonuyla)\n\"Ah küçük kuzenim... Uzak okyanusları aşıp buraya kadar yüzdüm ama sular ne kadar da ılık... Bana biraz serinlik getirsen olmaz mı? Şöyle dondurucu, berrak bir parça buz...\"",
		"color": Color(0.35, 0.75, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Buz mu? O da ne demek bilge dev? Plastik gibi bir şey mi? Yenebiliyor mu?\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "Deri Sırtlı Bilge Dev (Dermochelys coriacea)",
		"text": "(Hafifçe kıkırdar, ardından gözleri buğulanır)\n\"Aa, doğru ya... Unuttum! Artık buzlar yoktu değil mi? Yaşlandım artık, aklım hep o serin gençliğime, buzulların okyanusları kapladığı zamanlara gidiyor...\"",
		"color": Color(0.35, 0.75, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Buzulları gerçekten gördün mü? Nasıldı oralar bilge dev?\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "Deri Sırtlı Bilge Dev (Dermochelys coriacea)",
		"text": "\"Ben dondurucu kutup denizlerine kadar yüzebilen tek deniz sürüngeniyim. Okyanusların ötesinde göğe uzanan masmavi devasa buz dağları vardı. Üzerlerinde bembeyaz dev kutup ayıları dolaşır, kıyılarda yüz binlerce penguen serin sulara dalardı...\"",
		"color": Color(0.35, 0.75, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Peki ne oldu o heybetli buz dağlarına? Neden yok oldular?\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "Deri Sırtlı Bilge Dev (Dermochelys coriacea)",
		"text": "\"İnsanların bacalarından ve araçlarından çıkan dumanlar gökyüzünü bir sera gibi sardı. Dünya ısındı... O koca buzullar derin iniltilerle çatlamaya, koca parçalar gürültüyle okyanusa gömülüp erimeye başladı. Sular kabardı, kıyı şehirlerini yuttu. Küresel ısınma bir masal değil küçük Caretta; gözlerimle gördüğüm en büyük felakettir.\"",
		"color": Color(0.35, 0.75, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"O koca buzulları geri getiremesek bile batık şehirdeki atıkları temizleyip 'Son Resif'i kurtarabiliriz! ÖÇK Gözlem İstasyonu'ndaki kâşiflere ulaşıp denizleri yeniden canlandıracağım!\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "Deri Sırtlı Bilge Dev (Dermochelys coriacea)",
		"text": "\"Senin gözlerindeki bu kâşif ateşi bana umut veriyor. Al bu 'Kutup Gezgini' rozetini! Okyanus Kâşifleri'nin izinden git ve denizleri yeniden yaşanabilir kıl!\"",
		"color": Color(0.35, 0.75, 1.0)
	}
]

func _ready():
	base_y = position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Yavaş, bilgece yüzme animasyonu
	if anim_player:
		if anim_player.has_animation("Float"):
			anim_player.play("Float")
		elif anim_player.has_animation("SwimIdle"):
			anim_player.play("SwimIdle")
		anim_player.speed_scale = 0.5

	# Deri Sırtlı kaplumbağaya özgü koyu arduvaz mavisi deri tonlaması
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for mi in mesh_instances:
		var mat = mi.get_active_material(0)
		if mat:
			var mat_dup = mat.duplicate()
			if mat_dup is StandardMaterial3D:
				mat_dup.albedo_color = Color(0.42, 0.52, 0.68)
				mi.material_override = mat_dup

func _process(_delta: float):
	var t = Time.get_ticks_msec() * 0.001
	# Ağır ağır suda bilgece süzülme ve kanat salınımı (sabit taban konumu etrafında)
	position.y = base_y + sin(t * 1.1) * 0.18
	rotation.z = sin(t * 0.7) * 0.05
	rotation.x = cos(t * 0.9) * 0.03

func _unhandled_input(event):
	if not player_near:
		return
		
	var is_interact_action = false
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_F or event.physical_keycode == KEY_E or event.physical_keycode == KEY_F):
		is_interact_action = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		is_interact_action = true

	if is_interact_action:
		var hud = get_tree().root.find_child("DialogueBox", true, false)
		if hud and not hud.is_active and hud.exit_cooldown <= 0.0:
			get_viewport().set_input_as_handled()
			var hint = get_tree().root.find_child("InteractHint", true, false)
			if hint:
				hint.visible = false
			hud.start_dialogue(dialogues, "Kutup Gezgini", "Deri Sırtlı Bilge Dev'den kutup ayılarını, eriyen buzulları ve küresel ısınmayı dinledin.")

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_near = true
		update_hint()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_near = false
		var hint = get_tree().root.find_child("InteractHint", true, false)
		if hint and hint.text.find("Bilge Dev") != -1:
			hint.visible = false

func update_hint():
	var hint = get_tree().root.find_child("InteractHint", true, false)
	var hud = get_tree().root.find_child("DialogueBox", true, false)
	if hint:
		var dialog_open = hud and hud.is_active
		if player_near and not dialog_open:
			hint.text = "💬 [E / F / (A)] Deri Sırtlı Bilge Dev ile Konuş"
			hint.visible = true
		else:
			hint.visible = false
