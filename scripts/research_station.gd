extends Node3D

# ÖÇK Sualtı Gözlem ve İzleme İstasyonu (Special Protected Area Underwater Monitoring Station)
# Caretta'nın aradığı, insanlardan kalan oşinografi telemetrisini ve "Son Resif" tohum protokolünü barındıran üs.
# Bu istasyon bir son değil; dünyayı ve Akdeniz'i kurtarmak için gereken büyük adımın başlangıç noktasıdır.

@onready var dock_area: Area3D = $DockArea
@onready var beacon_light: OmniLight3D = $Visuals/CenterModule/BeaconLight
@onready var station_aura: OmniLight3D = $StationLights/MainAura
@onready var observation_ring = $Visuals/CenterModule/ObservationRing

var player_near: bool = false
var is_activated: bool = false

var dialogues = [
	{
		"speaker": "📡 İstasyon Yapay Zekâsı (A.T.L.A.S.)",
		"text": "(Bip-bip... [Akustik Sinyal ve Kilit Açılma Sesi])\n\"🚨 Sinyal Doğrulandı: Biyometrik eşleşme tamamlandı... 🐢 Caretta! Dış gövde hava kilidi ve iletişim hattı açılıyor!\"",
		"color": Color(0.25, 0.9, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Sonunda buldum sizi! O sualtı hortumu ve sıcak akıntı beni sizden kopardığında çok korkmuştum... Ekip nerede? İyi misiniz?\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "🧑‍🔬 Okyanus Kâşifleri Ekibi",
		"text": "(Telsizden sevinç dolu sesler)\n\"Caretta! Geldin dostum! Hortumda senden ayrı düştüğümüzde çok endişelendik. Sensörlerden kanyon boyunca atıkları temizleyip getirdiğin canlı çeşitliliği örneklerini izledik! Sayende istasyonun kapıları açıldı!\"",
		"color": Color(0.95, 0.85, 0.3)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Topladığım biyo-örnekleri getirdim! Peki ya istasyonun iletişim vericileri? İnsanlara ulaşabilecek miyiz?\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "🧑‍🔬 Okyanus Kâşifleri Ekibi",
		"text": "\"Evet! Getirdiğin canlı çeşitliliği verileriyle istasyonun uç vericilerini aktif ettik! Bu sinyali yeryüzündeki insanlara iletiyoruz; dünyayı kurtarmak için harekete geçiyorlar! Sen gerçek bir İklim Elçisisin Caretta!\"",
		"color": Color(1.0, 0.85, 0.2)
	}
]

func _ready():
	if dock_area:
		dock_area.body_entered.connect(_on_dock_body_entered)
		dock_area.body_exited.connect(_on_dock_body_exited)

func _process(_delta: float):
	# Tepe işaret fenerinin periyodik nabız gibi yanıp sönmesi
	if beacon_light:
		var beacon_pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		beacon_light.light_energy = lerp(1.0, 3.5, beacon_pulse)

	# İstasyonun ana ışık halesi
	if station_aura:
		var aura_pulse = (sin(Time.get_ticks_msec() * 0.002) + 1.0) * 0.5
		station_aura.light_energy = lerp(2.0, 3.0, aura_pulse)

func _unhandled_input(event):
	if not player_near:
		return

	var is_interact_action = false
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_F or event.physical_keycode == KEY_E or event.physical_keycode == KEY_F):
		is_interact_action = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		is_interact_action = true

	if is_interact_action:
		if is_activated:
			# İstasyon zaten aktif; oyuncu Final Sinematiğini başlatabilir!
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file("res://scenes/final_cutscene.tscn")
			return
		var hud = get_tree().root.find_child("DialogueBox", true, false)
		if hud and not hud.is_active and hud.exit_cooldown <= 0.0:
			get_viewport().set_input_as_handled()
			var hint = get_tree().root.find_child("InteractHint", true, false)
			if hint:
				hint.visible = false
			_activate_station(hud)

func _activate_station(hud):
	is_activated = true
	
	# İstasyon ışıklarını kutlama moduna al (zümrüt/turkuaz parlaklığı)
	if station_aura:
		station_aura.light_color = Color(0.3, 1.0, 0.8)
		station_aura.light_energy = 4.5
		station_aura.omni_range = 35.0

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_healing"):
		player.apply_healing(100.0)

	hud.start_dialogue(dialogues, "İklim Elçisi", "Okyanus Kâşifleri ekibinle yeniden buluştun! 'Son Resif'e giden yolu açtın ve resmi 'İklim Elçisi' unvanını kazandın!")
	var hud_layer = get_tree().root.find_child("HUD", true, false)
	if hud_layer and hud_layer.has_method("show_tutorial_tip"):
		hud_layer.show_tutorial_tip("🪸 [GÖREV 3]: Ekibinle buluştun! 'İklim Elçisi' unvanını aldın. İstasyona yanaşıp [E] ile Final Sinematiği'ni izleyebilirsin!", 9.0)

func _on_dock_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_near = true
		update_hint()

func _on_dock_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_near = false
		var hint = get_tree().root.find_child("InteractHint", true, false)
		if hint and hint.text.find("İstasyon") != -1:
			hint.visible = false

func update_hint():
	var hint = get_tree().root.find_child("InteractHint", true, false)
	var hud = get_tree().root.find_child("DialogueBox", true, false)
	if hint:
		var dialog_open = hud and hud.is_active
		if player_near and not dialog_open:
			if is_activated:
				hint.text = "🎬 [E / F / (A)] Final Sinematiğini Başlat (Son Resif Zaferi)"
			else:
				hint.text = "📡 [E / F / (A)] ÖÇK Sualtı Gözlem ve İzleme İstasyonu'na Bağlan / Giriş Yap"
			hint.visible = true
		else:
			hint.visible = false

