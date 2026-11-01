extends Control

# Genshin Impact Tarzı Estetik Diyalog Sistemi (Genshin-Style Dialogue System)
# Şampanya altın filigran bordür, özel isim plaketi (Nameplate), zarif elmas imleç ve daktilo akışı

@onready var panel = $Panel
@onready var nameplate_panel = find_child("NameplatePanel", true, false)
@onready var speaker_label = find_child("SpeakerLabel", true, false)
@onready var page_label = find_child("PageLabel", true, false)
@onready var text_label = find_child("TextLabel", true, false)
@onready var prompt_label = find_child("PromptLabel", true, false)

var active_dialogues: Array = []
var pending_badge_title: String = ""
var pending_badge_desc: String = ""

var current_index = 0
var is_active = false
var just_opened = false
var exit_cooldown = 0.0
var input_cooldown = 0.0

var text_tween: Tween = null
var is_typing: bool = false

signal dialogue_finished

func _ready():
	visible = false
	if text_label:
		text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD

func _process(delta: float):
	if exit_cooldown > 0.0:
		exit_cooldown -= delta
	if input_cooldown > 0.0:
		input_cooldown -= delta
		
	# Genshin Impact: İlerleme göstergesinin zarif altın nabız animasyonu
	if is_active and prompt_label:
		var pulse = (sin(Time.get_ticks_msec() * 0.007) + 1.0) * 0.5
		prompt_label.modulate = Color(1.0, 0.88, 0.52, lerp(0.65, 1.0, pulse))

func start_dialogue(dialogue_list: Array = [], badge_title: String = "", badge_desc: String = ""):
	if is_active or exit_cooldown > 0.0:
		return
		
	if dialogue_list.size() > 0:
		active_dialogues = dialogue_list
	else:
		return
		
	pending_badge_title = badge_title
	pending_badge_desc = badge_desc
	
	current_index = 0
	is_active = true
	just_opened = true
	input_cooldown = 0.35
	visible = true
	show_current_line()
	
	# Oyuncunun hareketini durdur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if "is_talking" in player:
			player.is_talking = true
		player.velocity = Vector3.ZERO
	
	# Aynı karede basılan tuşun hemen sonraki satıra geçmesini engelle
	await get_tree().process_frame
	just_opened = false

func show_current_line():
	if current_index >= active_dialogues.size():
		return
	var line = active_dialogues[current_index]
	var speaker: String = line.get("speaker", "Bilinmeyen")
	var speaker_color: Color = line.get("color", Color(0.35, 0.85, 1.0))
	
	# Genshin Impact: İsim plaketinde elmas (primogem) vurgulu isim
	if speaker_label:
		speaker_label.text = "◆ %s ◆" % speaker
		speaker_label.modulate = Color(1.0, 0.92, 0.72) # Sıcak şampanya altın tonu
	
	if page_label:
		page_label.text = "✦ %d / %d ✦" % [current_index + 1, active_dialogues.size()]
		page_label.modulate = Color(0.80, 0.85, 0.92, 0.85)
	
	# Genshin Impact: Konuşan karaktere göre altın bordüre hafif biyolojik/elemental ton yansıt
	if nameplate_panel:
		var np_base = nameplate_panel.get_theme_stylebox("panel")
		if np_base:
			var dyn_np = np_base.duplicate() as StyleBoxFlat
			dyn_np.border_color = Color(0.88, 0.76, 0.50).lerp(speaker_color, 0.35)
			dyn_np.shadow_color = Color(speaker_color.r, speaker_color.g, speaker_color.b, 0.35)
			nameplate_panel.add_theme_stylebox_override("panel", dyn_np)
			
	var base_style = panel.get_theme_stylebox("panel")
	if base_style:
		var dyn_style = base_style.duplicate() as StyleBoxFlat
		dyn_style.border_color = Color(0.86, 0.74, 0.48).lerp(speaker_color, 0.25)
		dyn_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		panel.add_theme_stylebox_override("panel", dyn_style)
		
	text_label.text = line.get("text", "")
	if current_index >= active_dialogues.size() - 1:
		prompt_label.text = "Tamamla [ Boşluk / E ]  ▼"
	else:
		prompt_label.text = "Devam Et [ Boşluk / E ]  ▼"
	
	# Daktilo akışı (pürüzsüz harf harf beliriş)
	if text_tween and text_tween.is_running():
		text_tween.kill()
		
	text_label.visible_ratio = 0.0
	is_typing = true
	text_tween = create_tween()
	var duration = clamp(text_label.text.length() * 0.011, 0.3, 0.95)
	text_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	text_tween.finished.connect(func(): is_typing = false)

func _unhandled_input(event):
	if not is_active or just_opened or input_cooldown > 0.0 or get_tree().paused:
		return
		
	var should_advance = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E or event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER:
			should_advance = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			should_advance = true

	if should_advance:
		get_viewport().set_input_as_handled()
		# Eğer metin daktilo akışındaysa, basışta metnin tamamını anında aç ve 0.18s bekle (kazara satır atlamasını engeller)
		if is_typing and text_tween and text_tween.is_running():
			text_tween.kill()
			text_label.visible_ratio = 1.0
			is_typing = false
			input_cooldown = 0.18
		else:
			# Metin zaten açıksa bir sonraki repliğe geç
			advance()

func advance():
	current_index += 1
	input_cooldown = 0.20
	if current_index < active_dialogues.size():
		show_current_line()
	else:
		finish()

func finish():
	is_active = false
	visible = false
	exit_cooldown = 0.8
	dialogue_finished.emit()
	
	# Oyuncu kontrolünü serbest bırak
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if "is_talking" in player:
			player.is_talking = false
		if pending_badge_title != "":
			player.badge_unlocked.emit(pending_badge_title, pending_badge_desc)
			pending_badge_title = ""
			pending_badge_desc = ""
