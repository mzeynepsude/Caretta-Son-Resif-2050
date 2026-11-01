extends CanvasLayer

# Caretta Su Altı HUD & İletişim & Envanter Arayüzü

@onready var health_bar = $MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar = $MarginContainer/VBoxContainer/StaminaBar
@onready var warning_label = $CenterContainer/VBoxWarnings/WarningLabel
@onready var seal_alert = $CenterContainer/VBoxWarnings/SealAlert
@onready var badge_panel = $BadgePanel
@onready var badge_title = $BadgePanel/VBoxContainer/BadgeTitle
@onready var badge_desc = $BadgePanel/VBoxContainer/BadgeDesc
@onready var inventory_label = $MarginContainer/VBoxContainer/InventoryLabel

# Envanter Paneli Elemanları
@onready var inventory_panel = get_node_or_null("InventoryPanel")
@onready var item_list_container = get_node_or_null("InventoryPanel/VBoxMain/ScrollContainer/ItemList")
@onready var capacity_label = get_node_or_null("InventoryPanel/VBoxMain/CapacityLabel")
@onready var empty_label = get_node_or_null("InventoryPanel/VBoxMain/EmptyLabel")
@onready var close_btn = get_node_or_null("InventoryPanel/VBoxMain/HBoxHeader/CloseBtn")

var is_inventory_open: bool = false
var is_game_paused: bool = false
var pause_panel: Control = null
var badge_timer_id: int = 0
var is_quest_system_passive: bool = true # Görev atama sistemi pasif duruma getirildi (Öğrendikçe keşif)

# Yeni Eklenen Paneller: Ayarlar (Ses & Gamepad), Görev Günlüğü (J/Q), Rozet Koleksiyonu (B), Radar Harita (M), Kontrol Rehberi (H) ve Dairesel Mini Harita
var settings_panel: Control = null
var journal_panel: Control = null
var badge_collection_panel: Control = null
var map_panel: Control = null
var controls_panel: Control = null
var minimap_container: Control = null
var minimap_view: Control = null
var tutorial_tip_panel: Control = null
var tutorial_tip_label: Label = null
var is_settings_open: bool = false
var is_journal_open: bool = false
var is_badges_open: bool = false
var is_map_open: bool = false
var is_controls_open: bool = false
var video_theater_panel: Control = null
var video_theater_player: VideoStreamPlayer = null
var video_theater_play_btn: Button = null
var btn_fs_theater: Button = null
var is_video_theater_open: bool = false
var is_video_theater_fullscreen: bool = false
var has_shown_task2_tip: bool = false
var unlocked_badges: Array = []
var alert_banner: Label = null
var alert_timer_id: int = 0
var tip_timer_id: int = 0

func _ready():
	badge_panel.visible = false
	warning_label.visible = false
	if seal_alert:
		seal_alert.visible = false
	if inventory_panel:
		inventory_panel.visible = false
	if close_btn:
		close_btn.pressed.connect(close_inventory)
	
	_create_alert_banner()
	_create_pause_menu()
	_create_settings_panel()
	_create_quest_journal_panel()
	_create_badge_collection_panel()
	_create_map_panel()
	_create_circular_minimap()
	_create_controls_guide_panel()
	_create_tutorial_tip_banner()
	_create_video_theater_panel()
	_create_hud_quick_video_button()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)
		player.inventory_updated.connect(_on_inventory_updated)
		player.badge_unlocked.connect(_on_badge_unlocked)
		
	# Başlangıç öğretici görevi (Görev atama pasif modda susturulur)
	if not is_quest_system_passive:
		show_tutorial_tip("💡 [GÖREV 1]: Kanyondaki atıkları temizle ve yerli canlılarla konuşarak kaybettiğin Okyanus Kâşifleri'nin izini sür!", 7.5)

func _process(_delta):
	var player = get_tree().get_first_node_in_group("player")
	if player and "in_hot_zone" in player:
		warning_label.visible = player.in_hot_zone
	if is_map_open and map_panel:
		var mv = map_panel.find_child("MapView", true, false)
		if mv:
			mv.queue_redraw()
	if minimap_view:
		minimap_view.queue_redraw()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		# Tab veya I tuşuna basıldığında envanteri aç/kapat (Standart Ergonomi)
		if event.keycode == KEY_I or event.physical_keycode == KEY_I or event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			if not is_game_paused and not is_badges_open and not is_map_open and not is_journal_open:
				get_viewport().set_input_as_handled()
				toggle_inventory()
		# J veya Q tuşu ile Görev Günlüğü'nü (Journal / Quests) aç/kapat
		elif event.keycode == KEY_J or event.physical_keycode == KEY_J or event.keycode == KEY_Q or event.physical_keycode == KEY_Q:
			if not is_game_paused and not is_inventory_open and not is_badges_open and not is_map_open:
				get_viewport().set_input_as_handled()
				toggle_quest_journal()
		# B tuşu ile Rozet Koleksiyonunu aç/kapat
		elif event.keycode == KEY_B or event.physical_keycode == KEY_B:
			if not is_game_paused and not is_inventory_open and not is_map_open and not is_journal_open:
				get_viewport().set_input_as_handled()
				toggle_badges()
		# M tuşu ile Kuş Bakışı Haritayı aç/kapat
		elif event.keycode == KEY_M or event.physical_keycode == KEY_M:
			if not is_game_paused and not is_inventory_open and not is_badges_open and not is_journal_open:
				get_viewport().set_input_as_handled()
				toggle_map()
		# V tuşu ile Video Tiyatrosu / Sinematik Gösterimini aç/kapat
		elif event.keycode == KEY_V or event.physical_keycode == KEY_V:
			get_viewport().set_input_as_handled()
			toggle_video_theater()
		# H tuşu ile Kontrol ve Öğretici Rehberini aç/kapat
		elif event.keycode == KEY_H or event.physical_keycode == KEY_H:
			get_viewport().set_input_as_handled()
			toggle_controls_guide()
		# F5 tuşu ile Hızlı Kayıt (Quick Save Standartı)
		elif event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			quick_save()
		# ESC tuşu ile açık panelleri kapat veya durdurma menüsü
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if is_video_theater_open:
				if is_video_theater_fullscreen:
					_toggle_video_theater_fullscreen()
				else:
					close_video_theater()
			elif is_settings_open:
				close_settings()
			elif is_game_paused:
				resume_game()
			elif is_journal_open:
				close_quest_journal()
			elif is_badges_open:
				close_badges()
			elif is_map_open:
				close_map()
			elif is_inventory_open:
				close_inventory()
			else:
				var dialogue_box = find_child("DialogueBox", true, false)
				if not dialogue_box or not dialogue_box.is_active:
					pause_game()
		# P tuşu ile durdurma/devam ettirme
		elif event.keycode == KEY_P or event.physical_keycode == KEY_P:
			get_viewport().set_input_as_handled()
			if is_settings_open:
				close_settings()
			elif is_game_paused:
				resume_game()
			else:
				var dialogue_box = find_child("DialogueBox", true, false)
				if not dialogue_box or not dialogue_box.is_active:
					pause_game()

	# Gamepad Düğmeleri (Xbox / PlayStation / Genel Kontrolcü Desteği)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			get_viewport().set_input_as_handled()
			if is_settings_open:
				close_settings()
			elif is_game_paused:
				resume_game()
			else:
				var dialogue_box = find_child("DialogueBox", true, false)
				if not dialogue_box or not dialogue_box.is_active:
					pause_game()
		elif event.button_index == JOY_BUTTON_Y: # Y / Triangle -> Envanter
			if not is_game_paused and not is_badges_open and not is_map_open and not is_journal_open and not is_settings_open:
				get_viewport().set_input_as_handled()
				toggle_inventory()
		elif event.button_index == JOY_BUTTON_X: # X / Square -> Rozetler
			if not is_game_paused and not is_inventory_open and not is_map_open and not is_journal_open and not is_settings_open:
				get_viewport().set_input_as_handled()
				toggle_badges()
		elif event.button_index == JOY_BUTTON_BACK: # Select / Touchpad / Share -> Radar Harita
			if not is_game_paused and not is_inventory_open and not is_badges_open and not is_journal_open and not is_settings_open:
				get_viewport().set_input_as_handled()
				toggle_map()
		elif event.button_index == JOY_BUTTON_DPAD_UP: # D-Pad Yukarı -> Görev Günlüğü
			if not is_game_paused and not is_inventory_open and not is_badges_open and not is_map_open and not is_settings_open:
				get_viewport().set_input_as_handled()
				toggle_quest_journal()
		elif event.button_index == JOY_BUTTON_B: # B / Circle -> Geri / Kapat
			if is_video_theater_open:
				get_viewport().set_input_as_handled()
				close_video_theater()
			elif is_settings_open:
				get_viewport().set_input_as_handled()
				close_settings()
			elif is_journal_open or is_badges_open or is_map_open or is_inventory_open:
				get_viewport().set_input_as_handled()
				close_quest_journal()
				close_badges()
				close_map()
				close_inventory()

func pause_game():
	if is_inventory_open:
		close_inventory()
	if is_journal_open:
		close_quest_journal()
	if is_badges_open:
		close_badges()
	if is_map_open:
		close_map()
	if is_settings_open:
		close_settings()
	is_game_paused = true
	if pause_panel:
		pause_panel.visible = true
	var tree = get_tree()
	if tree:
		tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume_game():
	is_game_paused = false
	if is_settings_open:
		close_settings()
	if pause_panel:
		pause_panel.visible = false
	var tree = get_tree()
	if tree:
		tree.paused = false
	if is_inventory_open or is_badges_open or is_map_open or is_journal_open or is_settings_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_pause_menu():
	pause_panel = Control.new()
	pause_panel.name = "PausePanel"
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.05, 0.08, 0.88)
	pause_panel.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.12, 0.18, 0.95)
	style.border_color = Color(0.2, 0.65, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	var title = Label.new()
	title.text = "🌊 CARETTA: SON RESİF 2050"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Sualtı İklim & Oşinografi Raporu (Oyun Durduruldu)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	vbox.add_child(subtitle)
	
	var sep1 = HSeparator.new()
	sep1.name = "Sep1"
	vbox.add_child(sep1)
	
	var telemetry_text = [
		"📅 Tarih: Yıl 2050 (Paris İklim Anlaşması +2.0°C Kritik Üst Sınırı Aşıldı)",
		"🎯 COP Hedefi: Sanayi Öncesi Döneme Göre +1.5°C'de Tutma & +2.0°C'yi Asla Aşmama",
		"🌡️ Akdeniz Dip Suyu Sıcaklığı: +31.8°C (Tarihi Sıcak Su Dalgası / Marine Heatwave)",
		"🧪 Okyanus Asitliği (pH): 7.6 (Kritik Asitlenme - Kalsiyum Karbonat Eriyikleri)",
		"🫧 Çözünmüş Oksijen (BOD): 1.8 mg/L (Kritik Hipoksi / Boğucu Ölü Bölgeler)",
		"📍 Mevcut Bölge: Akdeniz Batık Şehir & Son Resif Koridoru"
	]
	
	for line in telemetry_text:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96))
		vbox.add_child(lbl)
		
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# 1. Sıra Butonlar (Oyun Akışı & Sinematik Video)
	var hbox_row1 = HBoxContainer.new()
	hbox_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_row1.add_theme_constant_override("separation", 14)
	
	var resume_btn = Button.new()
	resume_btn.text = "▶️ Devam Et (P / ESC)"
	resume_btn.custom_minimum_size = Vector2(195, 42)
	resume_btn.pressed.connect(resume_game)
	hbox_row1.add_child(resume_btn)

	var video_btn = Button.new()
	video_btn.text = "🎬 Sinematik & Tanıtım (V)"
	video_btn.custom_minimum_size = Vector2(225, 42)
	video_btn.pressed.connect(open_video_theater)
	hbox_row1.add_child(video_btn)

	var settings_btn = Button.new()
	settings_btn.text = "⚙️ Ayarlar (Ses & Gamepad)"
	settings_btn.custom_minimum_size = Vector2(215, 42)
	settings_btn.pressed.connect(open_settings)
	hbox_row1.add_child(settings_btn)
	vbox.add_child(hbox_row1)
	
	# 2. Sıra Butonlar (Kayıt, Yeniden Başlat & Ana Menü)
	var hbox_row2 = HBoxContainer.new()
	hbox_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_row2.add_theme_constant_override("separation", 14)

	var save_btn = Button.new()
	save_btn.text = "💾 Oyunu Kaydet (Slot 1)"
	save_btn.custom_minimum_size = Vector2(195, 40)
	save_btn.pressed.connect(func():
		var sm = get_node_or_null("/root/SaveManager")
		if sm:
			sm.save_game(1)
			show_screen_heal_alert("💾 Oyun Slot 1'e Başarıyla Kaydedildi!")
	)
	hbox_row2.add_child(save_btn)
	
	var restart_btn = Button.new()
	restart_btn.text = "🔄 Yeniden Başlat"
	restart_btn.custom_minimum_size = Vector2(165, 40)
	restart_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	hbox_row2.add_child(restart_btn)

	var main_menu_btn = Button.new()
	main_menu_btn.text = "🏠 Ana Menü"
	main_menu_btn.custom_minimum_size = Vector2(145, 40)
	main_menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox_row2.add_child(main_menu_btn)
	vbox.add_child(hbox_row2)
	panel.add_child(vbox)
	center.add_child(panel)
	pause_panel.add_child(center)
	add_child(pause_panel)

# =========================================================================
# OYUN DURDURULDUĞUNDA AYARLAR & GAMEPAD KILAVUZU PANELİ
# =========================================================================
func _create_settings_panel():
	settings_panel = Control.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_panel.visible = false
	
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.09, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(dim)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.1, 0.16, 0.96)
	style.border_color = Color(0.25, 0.82, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0.08, 0.45, 0.65, 0.3)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(860, 520)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	# Başlık Çubuğu
	var hbox_hdr = HBoxContainer.new()
	var title = Label.new()
	title.text = "⚙️ AYARLAR VE KONTROL MERKEZİ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
	hbox_hdr.add_child(title)
	
	var close_b = Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(32, 28)
	close_b.pressed.connect(close_settings)
	hbox_hdr.add_child(close_b)
	vbox.add_child(hbox_hdr)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Sualtı Ses Dengeleme & Gamepad (Oyun Kolu) Tam Entegrasyon Şeması"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	vbox.add_child(sub_lbl)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# İki Sütunlu Ana İçerik
	var hbox_cols = HBoxContainer.new()
	hbox_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_cols.add_theme_constant_override("separation", 24)
	
	# -------------------------------------------------------------------------
	# SOL SÜTUN: SES SEVİYESİ AYARLARI
	# -------------------------------------------------------------------------
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(380, 0)
	left_vbox.add_theme_constant_override("separation", 12)
	
	var audio_card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.12, 0.18, 0.92)
	card_style.border_color = Color(0.25, 0.65, 0.85, 0.6)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	audio_card.add_theme_stylebox_override("panel", card_style)
	
	var audio_inner = VBoxContainer.new()
	audio_inner.add_theme_constant_override("separation", 12)
	
	var sec_title = Label.new()
	sec_title.text = "🔊 SES VE AKUSTİK SEVİYELERİ"
	sec_title.add_theme_font_size_override("font_size", 14)
	sec_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
	audio_inner.add_child(sec_title)
	
	# 1. Ana Ses Slider'ı
	var master_lbl = Label.new()
	master_lbl.name = "MasterLabel"
	master_lbl.text = "Ana Ses Seviyesi (Master): %100"
	master_lbl.add_theme_font_size_override("font_size", 12)
	audio_inner.add_child(master_lbl)
	
	var master_slider = HSlider.new()
	master_slider.name = "MasterSlider"
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.value = 1.0
	master_slider.value_changed.connect(func(val):
		master_lbl.text = "Ana Ses Seviyesi (Master): %%%d" % int(val * 100)
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("set_master_volume"):
			audio.set_master_volume(val)
	)
	audio_inner.add_child(master_slider)
	
	# 2. Ambiance Slider'ı
	var amb_lbl = Label.new()
	amb_lbl.name = "AmbianceLabel"
	amb_lbl.text = "Sualtı Atmosfer & Uğultu: %80"
	amb_lbl.add_theme_font_size_override("font_size", 12)
	audio_inner.add_child(amb_lbl)
	
	var amb_slider = HSlider.new()
	amb_slider.name = "AmbianceSlider"
	amb_slider.min_value = 0.0
	amb_slider.max_value = 1.0
	amb_slider.step = 0.05
	amb_slider.value = 0.8
	amb_slider.value_changed.connect(func(val):
		amb_lbl.text = "Sualtı Atmosfer & Uğultu: %%%d" % int(val * 100)
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("set_ambiance_volume"):
			audio.set_ambiance_volume(val)
	)
	audio_inner.add_child(amb_slider)
	
	# 3. SFX Slider'ı
	var sfx_lbl = Label.new()
	sfx_lbl.name = "SfxLabel"
	sfx_lbl.text = "Kabarcık & Ekolojik Efektler: %80"
	sfx_lbl.add_theme_font_size_override("font_size", 12)
	audio_inner.add_child(sfx_lbl)
	
	var sfx_slider = HSlider.new()
	sfx_slider.name = "SfxSlider"
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 0.8
	sfx_slider.value_changed.connect(func(val):
		sfx_lbl.text = "Kabarcık & Ekolojik Efektler: %%%d" % int(val * 100)
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("set_sfx_volume"):
			audio.set_sfx_volume(val)
			audio.play_sfx("pickup")
	)
	audio_inner.add_child(sfx_slider)
	
	# Hızlı butonlar
	var hbox_quick = HBoxContainer.new()
	hbox_quick.add_theme_constant_override("separation", 10)
	
	var mute_btn = Button.new()
	mute_btn.text = "🔇 Sessize Al"
	mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_btn.pressed.connect(func():
		master_slider.value = 0.0
	)
	hbox_quick.add_child(mute_btn)
	
	var reset_btn = Button.new()
	reset_btn.text = "🔊 Varsayılan"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(func():
		master_slider.value = 1.0
		amb_slider.value = 0.8
		sfx_slider.value = 0.8
	)
	hbox_quick.add_child(reset_btn)
	audio_inner.add_child(hbox_quick)
	
	audio_card.add_child(audio_inner)
	left_vbox.add_child(audio_card)
	
	# İkincil Bilgi Kutusu
	var tips_card = PanelContainer.new()
	var tips_style = StyleBoxFlat.new()
	tips_style.bg_color = Color(0.02, 0.08, 0.12, 0.85)
	tips_style.border_color = Color(0.18, 0.45, 0.6, 0.5)
	tips_style.set_border_width_all(1)
	tips_style.set_corner_radius_all(6)
	tips_style.content_margin_left = 12
	tips_style.content_margin_right = 12
	tips_style.content_margin_top = 8
	tips_style.content_margin_bottom = 8
	tips_card.add_theme_stylebox_override("panel", tips_style)
	
	var tips_lbl = Label.new()
	tips_lbl.text = "💡 Ses İpucu:\n• Poşet tuzağı boğulma/hasar sesi verir.\n• Yerli denizanası (Cotylorhiza) şifa sesi verir.\n• Deparda su kabarcıkları periyodik duyulur."
	tips_lbl.add_theme_font_size_override("font_size", 11)
	tips_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	tips_card.add_child(tips_lbl)
	left_vbox.add_child(tips_card)
	
	# Ekran & Tam Ekran Kartı
	var display_card = PanelContainer.new()
	var disp_style = StyleBoxFlat.new()
	disp_style.bg_color = Color(0.04, 0.12, 0.18, 0.92)
	disp_style.border_color = Color(0.25, 0.65, 0.85, 0.6)
	disp_style.set_border_width_all(1)
	disp_style.set_corner_radius_all(8)
	disp_style.content_margin_left = 16
	disp_style.content_margin_right = 16
	disp_style.content_margin_top = 10
	disp_style.content_margin_bottom = 10
	display_card.add_theme_stylebox_override("panel", disp_style)
	
	var disp_inner = VBoxContainer.new()
	disp_inner.add_theme_constant_override("separation", 6)
	
	var disp_title = Label.new()
	disp_title.text = "🖥️ EKRAN VE GÖRÜNTÜ MODU"
	disp_title.add_theme_font_size_override("font_size", 13)
	disp_title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	disp_inner.add_child(disp_title)
	
	var chk_fs = CheckBox.new()
	chk_fs.name = "CheckFullscreenHud"
	chk_fs.text = "Tam Ekran Modu [F11 / Alt+Enter]"
	var audio_m = get_node_or_null("/root/AudioManager")
	if audio_m and audio_m.has_method("is_fullscreen"):
		chk_fs.button_pressed = audio_m.is_fullscreen()
		audio_m.fullscreen_toggled.connect(func(is_fs):
			chk_fs.button_pressed = is_fs
		)
	else:
		var mode = DisplayServer.window_get_mode()
		chk_fs.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	chk_fs.toggled.connect(func(toggled):
		if audio_m and audio_m.has_method("set_fullscreen"):
			if audio_m.is_fullscreen() != toggled:
				audio_m.set_fullscreen(toggled)
		else:
			if toggled:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(1280, 720))
	)
	disp_inner.add_child(chk_fs)
	display_card.add_child(disp_inner)
	left_vbox.add_child(display_card)
	
	hbox_cols.add_child(left_vbox)
	
	# -------------------------------------------------------------------------
	# SAĞ SÜTUN: GAMEPAD VE KONTROLLER REHBERİ
	# -------------------------------------------------------------------------
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	
	var pad_card = PanelContainer.new()
	var pad_style = StyleBoxFlat.new()
	pad_style.bg_color = Color(0.04, 0.12, 0.18, 0.92)
	pad_style.border_color = Color(0.25, 0.65, 0.85, 0.6)
	pad_style.set_border_width_all(1)
	pad_style.set_corner_radius_all(8)
	pad_style.content_margin_left = 16
	pad_style.content_margin_right = 16
	pad_style.content_margin_top = 12
	pad_style.content_margin_bottom = 12
	pad_card.add_theme_stylebox_override("panel", pad_style)
	
	var pad_inner = VBoxContainer.new()
	pad_inner.add_theme_constant_override("separation", 5)
	
	var pad_title = Label.new()
	pad_title.text = "🎮 GAMEPAD (OYUN KOLU) DÜZENİ"
	pad_title.add_theme_font_size_override("font_size", 14)
	pad_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	pad_inner.add_child(pad_title)
	
	var pad_items = [
		["🕹️ Sol Analog (L-Stick):", "🏊 3D Yüzme & Yön Kontrolü"],
		["🕹️ Sağ Analog (R-Stick):", "👁️ Serbest Kamera & Çevre Bakışı"],
		["🚀 RT / R2 (Sağ Tetik):", "⬆️ Yüzeye Yükselme"],
		["⚓ LT / L2 (Sol Tetik):", "⬇️ Derine Dalış"],
		["⚡ RB / L3 (Çubuk Tıkı):", "💨 Depar & Hızlı Yüzme"],
		["🟢 (A) Butonu:", "💬 Konuş / Atık Teslim Et / Protokol"],
		["🟡 (Y) Butonu:", "🎒 Atık Envanterini Aç / Kapat"],
		["🔵 (X) Butonu:", "🎖️ Rozet Koleksiyonunu Aç / Kapat"],
		["📜 D-Pad Yukarı:", "📋 Görev Günlüğü (Journal)"],
		["🗺️ Select / Back / Touchpad:", "🛰️ Taktik Radar Haritası"],
		["⏸️ Start / Options:", "⏸️ Oyunu Durdurma & Ayarlar"]
	]
	
	for item in pad_items:
		var row = HBoxContainer.new()
		var action_lbl = Label.new()
		action_lbl.text = item[0]
		action_lbl.custom_minimum_size = Vector2(175, 0)
		action_lbl.add_theme_font_size_override("font_size", 11)
		action_lbl.add_theme_color_override("font_color", Color(0.4, 0.92, 1.0))
		row.add_child(action_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = item[1]
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 0.96))
		row.add_child(desc_lbl)
		pad_inner.add_child(row)
		
	var pad_note = Label.new()
	pad_note.text = "✨ Klavye & Fare: WASD Yüzme | Fare Hareketi: Kamera | Fare Sağ Tık (RMB) veya Shift: Hızlı Yüzme | Boşluk/C: Dikey\n🎮 Gamepad: Xbox, PlayStation ve tüm standart USB oyun kolları tak-çalıştır desteklidir."
	pad_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	pad_note.add_theme_font_size_override("font_size", 10)
	pad_note.add_theme_color_override("font_color", Color(0.55, 0.72, 0.8))
	pad_inner.add_child(pad_note)
	
	pad_card.add_child(pad_inner)
	right_vbox.add_child(pad_card)
	hbox_cols.add_child(right_vbox)
	
	vbox.add_child(hbox_cols)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Alt Gezinme Butonları
	var hbox_nav = HBoxContainer.new()
	hbox_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_nav.add_theme_constant_override("separation", 20)
	
	var back_btn = Button.new()
	back_btn.text = "◀️ Durdurma Menüsüne Dön"
	back_btn.custom_minimum_size = Vector2(210, 38)
	back_btn.pressed.connect(close_settings)
	hbox_nav.add_child(back_btn)
	
	var resume_direct_btn = Button.new()
	resume_direct_btn.text = "▶️ Oyuna Devam Et (ESC / P)"
	resume_direct_btn.custom_minimum_size = Vector2(210, 38)
	resume_direct_btn.pressed.connect(func():
		close_settings()
		resume_game()
	)
	hbox_nav.add_child(resume_direct_btn)
	vbox.add_child(hbox_nav)
	
	panel.add_child(vbox)
	center.add_child(panel)
	settings_panel.add_child(center)
	add_child(settings_panel)

func open_settings():
	is_settings_open = true
	if pause_panel:
		pause_panel.visible = false
	if settings_panel:
		settings_panel.visible = true
		_sync_settings_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_settings():
	is_settings_open = false
	if settings_panel:
		settings_panel.visible = false
	if is_game_paused and pause_panel:
		pause_panel.visible = true
	if not is_game_paused and not is_inventory_open and not is_badges_open and not is_map_open and not is_journal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sync_settings_ui():
	if not settings_panel:
		return
	var chk_fs = settings_panel.find_child("CheckFullscreenHud", true, false)
	if chk_fs:
		var audio_m = get_node_or_null("/root/AudioManager")
		if audio_m and audio_m.has_method("is_fullscreen"):
			chk_fs.button_pressed = audio_m.is_fullscreen()
	var audio = get_node_or_null("/root/AudioManager")
	var m_val = audio.master_volume if audio and "master_volume" in audio else 1.0
	var a_val = audio.ambiance_volume if audio and "ambiance_volume" in audio else 0.8
	var s_val = audio.sfx_volume if audio and "sfx_volume" in audio else 0.8
	
	var m_slider = settings_panel.find_child("MasterSlider", true, false)
	var a_slider = settings_panel.find_child("AmbianceSlider", true, false)
	var s_slider = settings_panel.find_child("SfxSlider", true, false)
	var m_lbl = settings_panel.find_child("MasterLabel", true, false)
	var a_lbl = settings_panel.find_child("AmbianceLabel", true, false)
	var s_lbl = settings_panel.find_child("SfxLabel", true, false)
	
	if m_slider: m_slider.set_value_no_signal(m_val)
	if a_slider: a_slider.set_value_no_signal(a_val)
	if s_slider: s_slider.set_value_no_signal(s_val)
	if m_lbl: m_lbl.text = "Ana Ses Seviyesi (Master): %%%d" % int(m_val * 100)
	if a_lbl: a_lbl.text = "Sualtı Atmosfer & Uğultu: %%%d" % int(a_val * 100)
	if s_lbl: s_lbl.text = "Kabarcık & Ekolojik Efektler: %%%d" % int(s_val * 100)

# =========================================================================
# KIRMIZI / YEŞİL EKRAN TEHLİKE VE ŞİFA BANNERI (Rozet yerine)
# =========================================================================
func _create_alert_banner():
	alert_banner = Label.new()
	alert_banner.name = "AlertBanner"
	alert_banner.anchors_preset = Control.PRESET_CENTER_TOP
	alert_banner.anchor_left = 0.5
	alert_banner.anchor_right = 0.5
	alert_banner.offset_left = -320.0
	alert_banner.offset_top = 135.0
	alert_banner.offset_right = 320.0
	alert_banner.offset_bottom = 175.0
	alert_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_banner.add_theme_font_size_override("font_size", 16)
	alert_banner.visible = false
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.02, 0.02, 0.88)
	sb.border_color = Color(1.0, 0.25, 0.25, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	alert_banner.add_theme_stylebox_override("panel", sb)
	add_child(alert_banner)

func show_screen_danger_alert(msg: String):
	if not alert_banner:
		return
	alert_timer_id += 1
	var cur_id = alert_timer_id
	alert_banner.text = msg
	alert_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	var sb = alert_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = Color(1.0, 0.25, 0.25, 0.95)
		sb.bg_color = Color(0.15, 0.02, 0.02, 0.88)
	alert_banner.visible = true
	var tree = get_tree()
	if tree:
		tree.create_timer(3.2).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(alert_banner) and alert_timer_id == cur_id:
				alert_banner.visible = false
		)

func show_screen_heal_alert(msg: String):
	if not alert_banner:
		return
	alert_timer_id += 1
	var cur_id = alert_timer_id
	alert_banner.text = msg
	alert_banner.add_theme_color_override("font_color", Color(0.35, 1.0, 0.6))
	var sb = alert_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = Color(0.2, 0.9, 0.5, 0.95)
		sb.bg_color = Color(0.02, 0.14, 0.06, 0.88)
	alert_banner.visible = true
	var tree = get_tree()
	if tree:
		tree.create_timer(2.6).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(alert_banner) and alert_timer_id == cur_id:
				alert_banner.visible = false
		)

# =========================================================================
# B TUŞU: ROZET VE BAŞARIM KOLEKSİYONU PANELİ
# =========================================================================
func _create_badge_collection_panel():
	badge_collection_panel = Control.new()
	badge_collection_panel.name = "BadgeCollectionPanel"
	badge_collection_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_collection_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	badge_collection_panel.visible = false
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.05, 0.08, 0.75)
	badge_collection_panel.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.11, 0.18, 0.96)
	style.border_color = Color(1.0, 0.84, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(560, 420)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var hbox_hdr = HBoxContainer.new()
	var title = Label.new()
	title.text = "🎖️ KAZANILAN ROZETLER & İKLİM ELÇİSİ DEFTERİ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	hbox_hdr.add_child(title)
	
	var close_b = Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(30, 26)
	close_b.pressed.connect(close_badges)
	hbox_hdr.add_child(close_b)
	vbox.add_child(hbox_hdr)
	
	var count_lbl = Label.new()
	count_lbl.name = "BadgeCountLabel"
	count_lbl.text = "Açılan Başarımlar: 0 / 6"
	count_lbl.add_theme_font_size_override("font_size", 13)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	vbox.add_child(count_lbl)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var list_box = VBoxContainer.new()
	list_box.name = "BadgeList"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)
	vbox.add_child(scroll)
	
	var hint = Label.new()
	hint.text = "İpucu: [B] veya [ESC] tuşuna basarak rozet defterini kapatabilirsin."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.65, 0.75))
	vbox.add_child(hint)
	
	panel.add_child(vbox)
	center.add_child(panel)
	badge_collection_panel.add_child(center)
	add_child(badge_collection_panel)

func toggle_badges():
	if is_badges_open:
		close_badges()
	else:
		open_badges()

func open_badges():
	var dbox = find_child("DialogueBox", true, false)
	if dbox and dbox.is_active:
		return
	is_badges_open = true
	if badge_collection_panel:
		badge_collection_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_badge_collection_ui()

func close_badges():
	is_badges_open = false
	if badge_collection_panel:
		badge_collection_panel.visible = false
	if not is_inventory_open and not is_map_open and not is_journal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_badge_collection_ui():
	if not badge_collection_panel:
		return
	var list_box = badge_collection_panel.find_child("BadgeList", true, false)
	var count_lbl = badge_collection_panel.find_child("BadgeCountLabel", true, false)
	if not list_box:
		return
	for c in list_box.get_children():
		c.queue_free()
		
	if count_lbl:
		count_lbl.text = "Kazanılan Rozetler: %d Adet" % unlocked_badges.size()
		
	if unlocked_badges.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "(Henüz bir rozet kazanmadın. Deniz canlılarıyla konuş, atıkları dönüştür ve istasyona ulaş!)"
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_box.add_child(empty_lbl)
		return
		
	for b in unlocked_badges:
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.16, 0.24, 0.9)
		card_style.border_color = Color(0.3, 0.7, 0.95, 0.6)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		
		var cvbox = VBoxContainer.new()
		var t_lbl = Label.new()
		t_lbl.text = "🎖️ " + b.title
		t_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		t_lbl.add_theme_font_size_override("font_size", 15)
		cvbox.add_child(t_lbl)
		
		var d_lbl = Label.new()
		d_lbl.text = b.desc
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		d_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
		d_lbl.add_theme_font_size_override("font_size", 13)
		cvbox.add_child(d_lbl)
		
		card.add_child(cvbox)
		list_box.add_child(card)

# =========================================================================
# J / Q TUŞLARI: GÖREV GÜNLÜĞÜ (QUEST JOURNAL) & HIZLI KAYIT (F5)
# =========================================================================
func _create_quest_journal_panel():
	journal_panel = Control.new()
	journal_panel.name = "QuestJournalPanel"
	journal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	journal_panel.visible = false
	
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.09, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	journal_panel.add_child(dim)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.1, 0.16, 0.96)
	style.border_color = Color(0.2, 0.85, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0.08, 0.45, 0.65, 0.3)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(620, 480)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var hbox_hdr = HBoxContainer.new()
	var title = Label.new()
	title.text = "📜 KEŞİF GÜNLÜĞÜ (GÖREV ATAMA: PASİF)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.95, 0.8))
	hbox_hdr.add_child(title)
	
	var close_b = Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(30, 26)
	close_b.pressed.connect(close_quest_journal)
	hbox_hdr.add_child(close_b)
	vbox.add_child(hbox_hdr)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "COP31 Paris Eşiği (2050) - Serbest Keşif Modu (Görev atama pasiftir; canlılarla konuştukça ve öğrendikçe ilerleyin)"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	vbox.add_child(sub_lbl)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var list_box = VBoxContainer.new()
	list_box.name = "QuestList"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 12)
	scroll.add_child(list_box)
	vbox.add_child(scroll)
	
	var hint = Label.new()
	hint.text = "İpucu: [J] veya [Q] ile günlüğü aç/kapat | [Tab / I] Envanter | [M] Harita | [F5] Hızlı Kayıt"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	vbox.add_child(hint)
	
	panel.add_child(vbox)
	center.add_child(panel)
	journal_panel.add_child(center)
	add_child(journal_panel)

func toggle_quest_journal():
	if is_journal_open:
		close_quest_journal()
	else:
		open_quest_journal()

func open_quest_journal():
	var dbox = find_child("DialogueBox", true, false)
	if dbox and dbox.is_active:
		return
	is_journal_open = true
	if journal_panel:
		journal_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_quest_journal_ui()

func close_quest_journal():
	is_journal_open = false
	if journal_panel:
		journal_panel.visible = false
	if not is_inventory_open and not is_badges_open and not is_map_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_quest_journal_ui():
	if not journal_panel:
		return
	var list_box = journal_panel.find_child("QuestList", true, false)
	if not list_box:
		return
	for c in list_box.get_children():
		c.queue_free()
		
	var player = get_tree().get_first_node_in_group("player")
	var station = get_tree().root.find_child("ResearchStation", true, false)
	
	var item_count = player.inventory.size() if player and "inventory" in player else 0
	var station_activated = station.is_activated if station and "is_activated" in station else false
	
	var quests = [
		{
			"id": 1,
			"icon": "🧴",
			"title": ("🔍 Kanyon Keşfi & Deniz Atıkları [Pasif]" if is_quest_system_passive else "Görev 1: Atıkları Temizle & Kâşiflerin İzini Sür"),
			"status": ("İNCELENDİ (%d/3 Atık)" % item_count if is_quest_system_passive else ("TAMAMLANDI (3/3)" if item_count >= 3 else "DEVAM EDİYOR (%d/3 Atık)" % item_count)),
			"is_done": item_count >= 3,
			"is_active": item_count < 3,
			"desc": "2050 yılında +2°C ısınan Akdeniz'de sualtı hortumuyla Okyanus Kâşifleri'nden koptun. Kanyondaki atıkları inceleyebilir, yerli deniz canlılarıyla konuşarak ekosistemi serbestçe keşfedebilirsin.",
			"reward": "🏆 Kâşiflerin Rotası & Hız/Zırh Güçlendirmeleri"
		},
		{
			"id": 2,
			"icon": "🧑‍🔬",
			"title": ("🏛️ ÖÇK Araştırma İstasyonu [Pasif]" if is_quest_system_passive else "Görev 2: Kayıp Okyanus Kâşifleri Ekibiyle Buluş"),
			"status": ("AÇILDI" if station_activated else "SERBEST KEŞİF (İstasyon Bölgesi)") if is_quest_system_passive else ("TAMAMLANDI (Ekip Birleşti)" if station_activated else ("AKTİF HEDEF (Kâşiflere Ulaş)" if item_count >= 3 else "KİLİTLİ (Önce 3 Atık Topla)")),
			"is_done": station_activated,
			"is_active": not station_activated and item_count >= 3,
			"desc": "Fırtınada sığınılan ÖÇK İstasyonu. Deniz canlılarından aldığın ipuçlarıyla istasyonun hava kilidine yanaşabilir ve ekibinin izini bulabilirsin.",
			"reward": "🎖️ İklim Elçisi Rozeti & Ekiple Yeniden Buluşma"
		},
		{
			"id": 3,
			"icon": "🪸",
			"title": ("🪸 Son Resif Biyoçeşitlilik Sığınağı [Pasif]" if is_quest_system_passive else "Görev 3: İstasyon Vericilerini Aç & Dünyaya Kurtuluş Sinyalini Gönder"),
			"status": ("İNCELEME BÖLGESİ" if station_activated else "DERİN DENİZ SIĞINAĞI") if is_quest_system_passive else ("AKTİF HEDEF (Kâşiflerle Resife Yüz)" if station_activated else "KİLİTLİ (Önce Ekibinle Buluş)"),
			"is_done": false,
			"is_active": station_activated,
			"desc": "Akdeniz'in en zengin mercan ve deniz florası vahası. Görev zorlaması olmadan, öğrendikçe ve ilerledikçe resifi keşfedebilirsin.",
			"reward": "🌟 Son Resif Muhafızı & Akdeniz'in Geleceği"
		}
	]
	
	for q in quests:
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		if q.is_done:
			card_style.bg_color = Color(0.04, 0.16, 0.14, 0.92)
			card_style.border_color = Color(0.2, 0.9, 0.55, 0.8)
		elif q.is_active:
			card_style.bg_color = Color(0.05, 0.15, 0.22, 0.94)
			card_style.border_color = Color(0.3, 0.8, 1.0, 0.85)
		else:
			card_style.bg_color = Color(0.04, 0.08, 0.12, 0.8)
			card_style.border_color = Color(0.2, 0.35, 0.45, 0.5)
			
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(8)
		card_style.content_margin_left = 14
		card_style.content_margin_right = 14
		card_style.content_margin_top = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)
		
		var cvbox = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		
		var chbox = HBoxContainer.new()
		var t_lbl = Label.new()
		t_lbl.text = "%s %s" % [q.icon, q.title]
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.add_theme_font_size_override("font_size", 14)
		if q.is_done:
			t_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.65))
		elif q.is_active:
			t_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			t_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
		chbox.add_child(t_lbl)
		
		var st_lbl = Label.new()
		st_lbl.text = "[%s]" % q.status
		st_lbl.add_theme_font_size_override("font_size", 12)
		if q.is_done:
			st_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		elif q.is_active:
			st_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			st_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
		chbox.add_child(st_lbl)
		cvbox.add_child(chbox)
		
		var d_lbl = Label.new()
		d_lbl.text = q.desc
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		d_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		d_lbl.add_theme_font_size_override("font_size", 12)
		cvbox.add_child(d_lbl)
		
		var rew_lbl = Label.new()
		rew_lbl.text = q.reward
		rew_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
		rew_lbl.add_theme_font_size_override("font_size", 11)
		cvbox.add_child(rew_lbl)
		
		card.add_child(cvbox)
		list_box.add_child(card)

func quick_save():
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		save_mgr = get_tree().root.find_child("SaveManager", true, false)
	if save_mgr and save_mgr.has_method("save_game"):
		var success = save_mgr.save_game(1)
		if success:
			show_screen_heal_alert("💾 HIZLI KAYIT ALINDI! (Slot 1)")
			var audio = get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_sfx"):
				audio.play_sfx("pickup")

# =========================================================================
# M TUŞU: KUŞ BAKIŞI RADAR HARİTA PANELİ (Binalar Kare, Canlılar Renkli Daire)
# =========================================================================
func _create_map_panel():
	map_panel = Control.new()
	map_panel.name = "MapPanel"
	map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	map_panel.visible = false
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.04, 0.07, 0.82)
	map_panel.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.09, 0.14, 0.98)
	style.border_color = Color(0.2, 0.75, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	
	var hdr = HBoxContainer.new()
	var title = Label.new()
	title.text = "🗺️ AKDENİZ BATIK ŞEHİR & SON RESİF KUŞ BAKIŞI HARİTASI"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	hdr.add_child(title)
	
	var close_b = Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(30, 26)
	close_b.pressed.connect(close_map)
	hdr.add_child(close_b)
	main_vbox.add_child(hdr)
	
	# Harita Çizim Alanı
	var map_view = Control.new()
	map_view.name = "MapView"
	map_view.custom_minimum_size = Vector2(620, 420)
	map_view.draw.connect(_on_map_draw.bind(map_view))
	main_vbox.add_child(map_view)
	
	# Harita Açıklama / Legend
	var legend_panel = PanelContainer.new()
	var leg_sb = StyleBoxFlat.new()
	leg_sb.bg_color = Color(0.02, 0.06, 0.1, 0.85)
	leg_sb.set_corner_radius_all(6)
	leg_sb.content_margin_left = 12
	leg_sb.content_margin_right = 12
	leg_sb.content_margin_top = 6
	leg_sb.content_margin_bottom = 6
	legend_panel.add_theme_stylebox_override("panel", leg_sb)
	
	var leg_hbox = HBoxContainer.new()
	leg_hbox.add_theme_constant_override("separation", 16)
	
	var legends = [
		{"color": Color(0.2, 1.0, 0.4), "text": "🟢 Sen (Caretta)"},
		{"color": Color(1.0, 0.85, 0.2), "text": "🟡 Sarı Yengeç"},
		{"color": Color(0.2, 0.7, 1.0), "text": "🔵 Deniz Tavşanı"},
		{"color": Color(0.25, 0.95, 0.5), "text": "🟢 Taş Kestanesi"},
		{"color": Color(0.75, 0.88, 1.0), "text": "🔘 Zırhlı Böcek"},
		{"color": Color(0.95, 0.98, 1.0), "text": "⚪ Kadim Pina"},
		{"color": Color(0.4, 0.7, 1.0), "text": "🔷 Bilge Dev"},
		{"color": Color(0.1, 0.9, 0.7), "text": "🏛️ İstasyon & Son Resif"}
	]
	for lg in legends:
		var lbl = Label.new()
		lbl.text = lg.text
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", lg.color)
		leg_hbox.add_child(lbl)
	legend_panel.add_child(leg_hbox)
	main_vbox.add_child(legend_panel)
	
	var hint = Label.new()
	hint.text = "İpucu: [M] veya [ESC] ile haritayı kapatabilirsin. Binalar perspektif çatılı karelerle temsil edilmiştir."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.65, 0.75))
	main_vbox.add_child(hint)
	
	panel.add_child(main_vbox)
	center.add_child(panel)
	map_panel.add_child(center)
	add_child(map_panel)

func toggle_map():
	if is_map_open:
		close_map()
	else:
		open_map()

func open_map():
	var dbox = find_child("DialogueBox", true, false)
	if dbox and dbox.is_active:
		return
	is_map_open = true
	if map_panel:
		map_panel.visible = true
		var mv = map_panel.find_child("MapView", true, false)
		if mv:
			mv.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_map():
	is_map_open = false
	if map_panel:
		map_panel.visible = false
	if not is_inventory_open and not is_badges_open and not is_journal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _world_to_map(w_pos: Vector3, map_size: Vector2) -> Vector2:
	# Harita aralığı: X: [-130, 45] -> Toplam 175m, Z: [-65, 10] -> Toplam 75m
	var norm_x = (w_pos.x - (-130.0)) / 175.0
	var norm_y = (w_pos.z - (-65.0)) / 75.0
	return Vector2(norm_x * (map_size.x - 40.0) + 20.0, norm_y * (map_size.y - 40.0) + 20.0)

func _on_map_draw(map_view: Control):
	var size = map_view.size
	# Arka plan okyanus ızgarası
	map_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.07, 0.12, 1.0))
	for gx in range(0, int(size.x), 50):
		map_view.draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(0.06, 0.18, 0.28, 0.5), 1.0)
	for gy in range(0, int(size.y), 45):
		map_view.draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(0.06, 0.18, 0.28, 0.5), 1.0)
		
	# Binaları perspektif çatılı kareler olarak çiz (Kuş bakışı kütle + çatı çizgileri)
	var buildings = [
		{"name": "Building1", "pos": Vector3(-15, 0, -25), "w": 36, "h": 40},
		{"name": "Building2", "pos": Vector3(20, 0, -30), "w": 30, "h": 30},
		{"name": "Building3", "pos": Vector3(-5, 0, -45), "w": 38, "h": 42}
	]
	for b in buildings:
		var center = _world_to_map(b.pos, size)
		var r = Rect2(center - Vector2(b.w * 0.5, b.h * 0.5), Vector2(b.w, b.h))
		map_view.draw_rect(r, Color(0.1, 0.22, 0.32, 0.95))
		map_view.draw_rect(r, Color(0.3, 0.6, 0.8, 0.9), false, 2.0)
		# Çatı perspektif çizgileri (kare içinden çatı tepesine piramit birleşimleri)
		map_view.draw_line(r.position, center, Color(0.25, 0.5, 0.7, 0.7), 1.0)
		map_view.draw_line(Vector2(r.position.x + r.size.x, r.position.y), center, Color(0.25, 0.5, 0.7, 0.7), 1.0)
		map_view.draw_line(Vector2(r.position.x, r.position.y + r.size.y), center, Color(0.25, 0.5, 0.7, 0.7), 1.0)
		map_view.draw_line(r.position + r.size, center, Color(0.25, 0.5, 0.7, 0.7), 1.0)
		map_view.draw_circle(center, 2.5, Color(0.4, 0.75, 0.95))

	# Son Resif Bölgesi & Akdeniz Biyoçeşitlilik Resifleri (Koralijen, Çalı Mercanı, Posidonia)
	var reef_center = _world_to_map(Vector3(-118.0, 0, -26), size)
	map_view.draw_circle(reef_center, 28.0, Color(0.05, 0.45, 0.35, 0.45))
	map_view.draw_arc(reef_center, 28.0, 0, TAU, 32, Color(0.2, 0.9, 0.65, 0.8), 2.0)
	
	# Sağ: Koralijen Resif (Pembe/Mor)
	var r_coralligenous = _world_to_map(Vector3(-118.0, 0, -16.5), size)
	map_view.draw_circle(r_coralligenous, 6.0, Color(0.9, 0.25, 0.6))
	map_view.draw_string(ThemeDB.fallback_font, r_coralligenous + Vector2(8, 4), "Koralijen", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.4, 0.7))

	# Sol: Çalı Mercanı Resifi (Altın Sarısı)
	var r_cladocora = _world_to_map(Vector3(-118.0, 0, -35.5), size)
	map_view.draw_circle(r_cladocora, 6.0, Color(0.95, 0.75, 0.2))
	map_view.draw_string(ThemeDB.fallback_font, r_cladocora + Vector2(8, 4), "Çalı Mercanı", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.8, 0.3))

	# Arka: Posidonia Deniz Çayırı (Zümrüt Yeşili)
	var r_posidonia = _world_to_map(Vector3(-123.5, 0, -26.0), size)
	map_view.draw_circle(r_posidonia, 6.0, Color(0.2, 0.9, 0.35))
	map_view.draw_string(ThemeDB.fallback_font, r_posidonia + Vector2(-36, -8), "Posidonia Çayırı", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.3, 1.0, 0.5))

	map_view.draw_string(ThemeDB.fallback_font, reef_center + Vector2(-30, -32), "🌸 SON RESİF MERKEZİ", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.35, 1.0, 0.75))

	# İstasyon (ÖÇK İstasyonu)
	var station_node = get_tree().root.find_child("ResearchStation", true, false)
	var station_pos = station_node.global_position if station_node else Vector3(-74.6, 0, -26.0)
	var st_map_pos = _world_to_map(station_pos, size)
	map_view.draw_circle(st_map_pos, 11.0, Color(0.1, 0.85, 0.7, 0.95))
	map_view.draw_arc(st_map_pos, 15.0, 0, TAU, 24, Color(0.3, 1.0, 0.85, 0.8), 2.0)
	map_view.draw_string(ThemeDB.fallback_font, st_map_pos + Vector2(-26, 22), "İSTASYON", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.4, 0.95, 0.9))

	# NPC Canlılar (Renkli Yuvarlaklar)
	var npc_markers = [
		{"name": "NpcYengec", "color": Color(1.0, 0.85, 0.2), "label": "Yengeç", "radius": 7.0},
		{"name": "NpcDenizTavsani", "color": Color(0.2, 0.7, 1.0), "label": "D. Tavşanı", "radius": 7.0},
		{"name": "NpcKestane", "color": Color(0.25, 0.95, 0.5), "label": "Kestane", "radius": 7.0},
		{"name": "NpcIstakoz", "color": Color(0.75, 0.88, 1.0), "label": "Böcek", "radius": 7.0},
		{"name": "KadimMidyeNPC", "color": Color(0.95, 0.98, 1.0), "label": "Pina", "radius": 8.0},
		{"name": "DeriSirtliDev", "color": Color(0.4, 0.7, 1.0), "label": "Bilge Dev", "radius": 9.0}
	]
	for m in npc_markers:
		var node = get_tree().root.find_child(m.name, true, false)
		if node:
			var m_pos = _world_to_map(node.global_position, size)
			map_view.draw_circle(m_pos, m.radius, m.color)
			map_view.draw_arc(m_pos, m.radius + 2.0, 0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
			map_view.draw_string(ThemeDB.fallback_font, m_pos + Vector2(-18, -10), m.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, m.color)

	# Oyuncu (Yeşil Caretta imleci)
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		var p_pos = _world_to_map(player_node.global_position, size)
		map_view.draw_circle(p_pos, 7.5, Color(0.2, 1.0, 0.4, 1.0))
		map_view.draw_arc(p_pos, 11.0, 0, TAU, 16, Color(1, 1, 1, 0.85), 2.0)
		map_view.draw_string(ThemeDB.fallback_font, p_pos + Vector2(-16, 20), "🐢 SEN", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.3, 1.0, 0.5))

func toggle_inventory():
	if is_inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory():
	# Diyalog kutusu açıkken envanter açılmasın
	var dialogue_box = find_child("DialogueBox", true, false)
	if dialogue_box and dialogue_box.is_active:
		return

	is_inventory_open = true
	if inventory_panel:
		inventory_panel.visible = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if "is_inventory_open" in player:
			player.is_inventory_open = true
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_inventory_ui()

func close_inventory():
	is_inventory_open = false
	if inventory_panel:
		inventory_panel.visible = false
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if "is_inventory_open" in player:
			player.is_inventory_open = false
	
	if not is_badges_open and not is_map_open and not is_journal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_inventory_ui():
	if not item_list_container:
		return
		
	# Önceki liste elemanlarını temizle
	for child in item_list_container.get_children():
		child.queue_free()
		
	var player = get_tree().get_first_node_in_group("player")
	if not player or not ("inventory" in player):
		return
		
	var items: Array = player.inventory
	if capacity_label:
		capacity_label.text = "Taşınan Geri Dönüştürülebilir Atık: %d / 15 Adet" % items.size()
		
	if items.is_empty():
		if empty_label:
			empty_label.visible = true
		return
	else:
		if empty_label:
			empty_label.visible = false

	# Her atık için bir satır ve Bırak butonu oluştur
	for i in range(items.size()):
		var item_name: String = str(items[i])
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# İkon belirleme
		var icon = "🗑️ "
		if "Reçine" in item_name or "Pelet" in item_name:
			icon = "🧪 "
		elif "Cam" in item_name:
			icon = "🍾 "
		elif "Plastik" in item_name or "Şişe" in item_name:
			icon = "🧴 "
		elif "Alüminyum" in item_name or "Metal" in item_name or "Kutu" in item_name:
			icon = "🥫 "
		elif "Ağ" in item_name:
			icon = "🕸️ "
		elif "Kitap" in item_name or "Kağıt" in item_name:
			icon = "📖 "
			
		var lbl = Label.new()
		lbl.text = icon + item_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)
		
		var drop_btn = Button.new()
		drop_btn.text = "Denize Bırak"
		drop_btn.add_theme_font_size_override("font_size", 12)
		drop_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		drop_btn.pressed.connect(_on_drop_button_pressed.bind(i))
		row.add_child(drop_btn)
		
		item_list_container.add_child(row)

func _on_drop_button_pressed(index: int):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("drop_item"):
		player.drop_item(index)
		refresh_inventory_ui()

func _on_health_changed(new_health: float):
	health_bar.value = new_health
	var fill = health_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		if new_health < 30.0:
			fill.bg_color = Color(0.95, 0.25, 0.25)
		elif new_health < 60.0:
			fill.bg_color = Color(1.0, 0.75, 0.2)
		else:
			fill.bg_color = Color(0.1, 0.88, 0.55)

func _on_stamina_changed(new_stamina: float):
	if stamina_bar:
		stamina_bar.value = new_stamina

func _on_inventory_updated(items: Array):
	inventory_label.text = "🎒 Atıklar: %d / 15" % items.size()
	if is_inventory_open:
		refresh_inventory_ui()
	if not is_quest_system_passive and items.size() >= 3 and not has_shown_task2_tip:
		has_shown_task2_tip = true
		show_tutorial_tip("🧑‍🔬 [GÖREV 2]: Atıklar toplandı! İleri İstasyon'a yüz ve fırtınada sığınan Okyanus Kâşifleri ile buluş!", 7.0)

func _on_badge_unlocked(title: String, desc: String):
	# Koleksiyona ekle (mükerrer kayıt önleme)
	var already_exists = false
	for b in unlocked_badges:
		if b.title == title:
			already_exists = true
			break
	if not already_exists:
		unlocked_badges.append({"title": title, "desc": desc})
		if is_badges_open:
			_refresh_badge_collection_ui()

	badge_timer_id += 1
	var current_id = badge_timer_id
	badge_title.text = "🎖️ ROZET KAZANILDI: " + title
	badge_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	badge_desc.text = desc
	badge_panel.visible = true
	var tree = get_tree()
	if tree:
		tree.create_timer(4.0).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(badge_panel) and badge_timer_id == current_id:
				badge_panel.visible = false
		)

func toggle_controls_guide():
	is_controls_open = not is_controls_open
	if controls_panel:
		controls_panel.visible = is_controls_open

func _create_circular_minimap():
	minimap_container = PanelContainer.new()
	minimap_container.name = "CircularMinimapContainer"
	minimap_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_container.anchor_left = 1.0
	minimap_container.anchor_right = 1.0
	minimap_container.anchor_top = 0.0
	minimap_container.anchor_bottom = 0.0
	minimap_container.offset_left = -166.0
	minimap_container.offset_top = 16.0
	minimap_container.offset_right = -16.0
	minimap_container.offset_bottom = 166.0
	
	# Interface Deck temasına uygun yuvarlak dış çerçeve
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.02, 0.08, 0.13, 0.88)
	frame_style.border_color = Color(0.25, 0.75, 0.95, 0.85)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(75)
	frame_style.shadow_color = Color(0.06, 0.35, 0.55, 0.25)
	frame_style.shadow_size = 4
	minimap_container.add_theme_stylebox_override("panel", frame_style)
	
	minimap_view = Control.new()
	minimap_view.name = "MinimapView"
	minimap_view.custom_minimum_size = Vector2(146, 146)
	minimap_view.draw.connect(_on_minimap_draw.bind(minimap_view))
	minimap_container.add_child(minimap_view)
	
	add_child(minimap_container)

func _on_minimap_draw(view: Control):
	var center = Vector2(73, 73)
	var radius = 64.0
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var player_pos = player.global_position
	
	# 1. Mesafe Halkaları (Concentric Sonar Rings)
	view.draw_arc(center, radius * 0.45, 0, TAU, 32, Color(0.12, 0.42, 0.58, 0.35), 1.0)
	view.draw_arc(center, radius * 0.82, 0, TAU, 40, Color(0.15, 0.5, 0.7, 0.3), 1.0)
	
	# Artı Göstergesi (Subtle Crosshair)
	view.draw_line(center - Vector2(radius * 0.82, 0), center + Vector2(radius * 0.82, 0), Color(0.18, 0.5, 0.65, 0.22), 1.0)
	view.draw_line(center - Vector2(0, radius * 0.82), center + Vector2(0, radius * 0.82), Color(0.18, 0.5, 0.65, 0.22), 1.0)
	
	# 2. Canlı Animasyonlu Sonar Dalgası (Radar Sweep Pulse)
	var pulse = fmod(Time.get_ticks_msec() * 0.00065, 1.0)
	view.draw_arc(center, radius * pulse, 0, TAU, 36, Color(0.2, 0.9, 0.7, 0.4 * (1.0 - pulse)), 1.5)
	
	# Dünya -> Radar Dönüşüm Ölçeği (Menzil: ~75 metre)
	var radar_range = 75.0
	var scale_factor = (radius * 0.82) / radar_range
	
	# 3. Batık Binalar (Gri-Mavi Blok Ayak İzleri)
	var buildings = [Vector3(-15, 0, -25), Vector3(20, 0, -30), Vector3(-5, 0, -45)]
	for b in buildings:
		var rel = Vector2(b.x - player_pos.x, b.z - player_pos.z)
		var m_pos = center + rel * scale_factor
		if m_pos.distance_to(center) < radius - 8:
			view.draw_rect(Rect2(m_pos - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.25, 0.45, 0.6, 0.75))
			view.draw_rect(Rect2(m_pos - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.4, 0.7, 0.9, 0.8), false, 1.0)

	# 4. Deniz Canlıları / NPC'ler
	var target_npcs = [
		{"name": "KadimMidyeNPC", "def": Vector3(-2, -6.8, -13), "col": Color(0.4, 0.85, 1.0)},
		{"name": "NpcDenizTavsani", "def": Vector3(3, -7.1, -18), "col": Color(0.3, 0.95, 0.7)},
		{"name": "NpcKestane", "def": Vector3(14, -7.0, -25), "col": Color(0.85, 0.7, 0.95)},
		{"name": "NpcYengec", "def": Vector3(8, -7.1, -10), "col": Color(0.95, 0.8, 0.3)},
		{"name": "NpcMaviYengec", "def": Vector3(-8, -7.1, -22), "col": Color(0.3, 0.65, 1.0)},
		{"name": "NpcIstakoz", "def": Vector3(-4, -7.1, -34), "col": Color(0.95, 0.45, 0.3)},
		{"name": "DeriSirtliDev", "def": Vector3(-28, -4.5, -28), "col": Color(0.4, 0.7, 0.9)}
	]
	for t in target_npcs:
		var node = get_tree().root.find_child(t.name, true, false)
		var pos = node.global_position if (node and is_instance_valid(node)) else t.def
		var rel = Vector2(pos.x - player_pos.x, pos.z - player_pos.z)
		var m_pos = center + rel * scale_factor
		if m_pos.distance_to(center) < radius - 6:
			view.draw_circle(m_pos, 2.5, t.col)

	# 5. Akdeniz Foku (Tehlike Radar İbresi)
	var seal = get_tree().root.find_child("AkdenizFoku", true, false)
	if seal and is_instance_valid(seal):
		var s_pos = seal.global_position
		var rel_s = Vector2(s_pos.x - player_pos.x, s_pos.z - player_pos.z)
		var m_s = center + rel_s * scale_factor
		if m_s.distance_to(center) < radius - 6:
			var blink = (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
			view.draw_circle(m_s, 3.5, Color(1.0, 0.25, 0.25, lerp(0.6, 1.0, blink)))

	# 6. ÖÇK Sualtı Gözlem İstasyonu (Turkuaz İkon veya Kenar İbresi)
	var st_pos = Vector3(-68.0, 0, -26.0)
	var station_node = get_tree().root.find_child("ResearchStation", true, false)
	if station_node and is_instance_valid(station_node):
		st_pos = station_node.global_position
	var rel_st = Vector2(st_pos.x - player_pos.x, st_pos.z - player_pos.z)
	var st_dist = rel_st.length()
	var st_dir = rel_st.normalized()
	if st_dist * scale_factor < radius - 10:
		var m_st = center + rel_st * scale_factor
		view.draw_circle(m_st, 3.8, Color(0.2, 0.8, 1.0))
		view.draw_circle(m_st, 1.8, Color(1.0, 1.0, 1.0))
	else:
		var edge_st = center + st_dir * (radius - 7)
		view.draw_circle(edge_st, 2.8, Color(0.2, 0.85, 1.0))

	# 7. Son Resif (Zümrüt Yeşili Waypoint / İbre)
	var reef_pos = Vector3(-118.0, 0, -26.0)
	var rel_rf = Vector2(reef_pos.x - player_pos.x, reef_pos.z - player_pos.z)
	var rf_dist = rel_rf.length()
	var rf_dir = rel_rf.normalized()
	if rf_dist * scale_factor < radius - 10:
		var m_rf = center + rel_rf * scale_factor
		view.draw_circle(m_rf, 5.0, Color(0.15, 0.95, 0.6))
		view.draw_circle(m_rf, 2.5, Color(1.0, 1.0, 0.8))
	else:
		# Hedefe yönlendiren üçgen pusula ibresi
		var edge_rf = center + rf_dir * (radius - 7)
		var p1 = edge_rf
		var p2 = edge_rf - rf_dir * 6.5 + Vector2(-rf_dir.y, rf_dir.x) * 3.5
		var p3 = edge_rf - rf_dir * 6.5 - Vector2(-rf_dir.y, rf_dir.x) * 3.5
		view.draw_colored_polygon([p1, p2, p3], Color(0.2, 1.0, 0.65))

	# 8. Merkez: Caretta Kaplumbağa İbresi
	var turtle_model = player.get_node_or_null("TurtleModel")
	var yaw = turtle_model.rotation.y if turtle_model else 0.0
	var fwd = Vector2(-sin(yaw + PI), -cos(yaw + PI)).normalized()
	var right = Vector2(-fwd.y, fwd.x)
	var tip = center + fwd * 7.0
	var wing_l = center - fwd * 4.5 - right * 4.0
	var wing_r = center - fwd * 4.5 + right * 4.0
	view.draw_colored_polygon([tip, wing_l, center - fwd * 2.0, wing_r], Color(0.2, 1.0, 0.6))
	view.draw_circle(center, 1.8, Color(1.0, 1.0, 1.0))

	# 9. Pusula Kuzey (K) Göstergesi ve Alt Kısayol Etiketi
	view.draw_string(ThemeDB.fallback_font, center + Vector2(-4, -radius + 12), "K", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.4, 0.9, 1.0, 0.9))
	view.draw_string(ThemeDB.fallback_font, center + Vector2(-15, radius - 4), "M: Harita", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.6, 0.85, 0.95, 0.8))

func _create_controls_guide_panel():
	controls_panel = PanelContainer.new()
	controls_panel.name = "ControlsGuidePanel"
	controls_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls_panel.anchor_left = 1.0
	controls_panel.anchor_right = 1.0
	controls_panel.anchor_top = 0.0
	controls_panel.anchor_bottom = 0.0
	controls_panel.offset_left = -240.0
	controls_panel.offset_top = 176.0
	controls_panel.offset_right = -16.0
	controls_panel.offset_bottom = 495.0
	controls_panel.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.08, 0.12, 0.82)
	style.border_color = Color(0.2, 0.65, 0.85, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	controls_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	
	var header_hbox = HBoxContainer.new()
	var title = Label.new()
	title.text = "🎮 KONTROL REHBERİ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	header_hbox.add_child(title)
	
	var hint_h = Label.new()
	hint_h.text = "[H: Gizle]"
	hint_h.add_theme_font_size_override("font_size", 11)
	hint_h.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	header_hbox.add_child(hint_h)
	vbox.add_child(header_hbox)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var guide_items = [
		["🏊 Yüz:", "WASD / Sol Analog"],
		["⬆️ Yüksel:", "Boşluk / RT / (A)"],
		["⬇️ Dalış:", "C - Ctrl / LT / (B)"],
		["⚡ Depar:", "Shift / RB / L3"],
		["💬 Etkileşim:", "E - F / (A) Butonu"],
		["📜 Görevler:", "J - Q / D-Pad Yukarı"],
		["🎒 Envanter:", "Tab - I / (Y) Butonu"],
		["🏅 Rozetler:", "B / (X) Butonu"],
		["🗺️ Harita:", "M / Select"],
		["💾 Hızlı Kayıt:", "F5 (Slot 1)"],
		["📊 Menü & Kayıt:", "ESC / P / Start"]
	]
	
	for item in guide_items:
		var row = HBoxContainer.new()
		var action_lbl = Label.new()
		action_lbl.text = item[0]
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_lbl.add_theme_font_size_override("font_size", 11)
		action_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		row.add_child(action_lbl)
		
		var key_lbl = Label.new()
		key_lbl.text = item[1]
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
		row.add_child(key_lbl)
		vbox.add_child(row)
		
	controls_panel.add_child(vbox)
	add_child(controls_panel)

func _create_tutorial_tip_banner():
	tutorial_tip_panel = PanelContainer.new()
	tutorial_tip_panel.name = "TutorialTipPanel"
	tutorial_tip_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_tip_panel.anchor_left = 0.5
	tutorial_tip_panel.anchor_right = 0.5
	tutorial_tip_panel.anchor_top = 1.0
	tutorial_tip_panel.anchor_bottom = 1.0
	tutorial_tip_panel.offset_left = -340.0
	tutorial_tip_panel.offset_right = 340.0
	tutorial_tip_panel.offset_top = -68.0
	tutorial_tip_panel.offset_bottom = -18.0
	tutorial_tip_panel.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.1, 0.15, 0.9)
	style.border_color = Color(0.2, 0.8, 0.6, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tutorial_tip_panel.add_theme_stylebox_override("panel", style)
	
	tutorial_tip_label = Label.new()
	tutorial_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_tip_label.add_theme_font_size_override("font_size", 13)
	tutorial_tip_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.9))
	tutorial_tip_panel.add_child(tutorial_tip_label)
	
	add_child(tutorial_tip_panel)

func show_tutorial_tip(text: String, duration: float = 6.0):
	if not tutorial_tip_panel or not tutorial_tip_label:
		return
	tutorial_tip_label.text = text
	tutorial_tip_panel.visible = true
	tip_timer_id += 1
	var current_id = tip_timer_id
	var tree = get_tree()
	if tree:
		tree.create_timer(duration).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(tutorial_tip_panel) and tip_timer_id == current_id:
				tutorial_tip_panel.visible = false
		)

# =========================================================================
# OYUN İÇİ VİDEO TİYATROSU & SİNEMATİK SUNUM PANELİ
# =========================================================================

func _create_hud_quick_video_button():
	var mc = find_child("MarginContainer", true, false)
	if mc:
		var vbox_tel = mc.find_child("VBoxContainer", true, false)
		if vbox_tel:
			var btn = Button.new()
			btn.name = "BtnHudQuickVideo"
			btn.text = "🎬 Sinematik [V]"
			btn.custom_minimum_size = Vector2(184, 28)
			btn.add_theme_font_size_override("font_size", 11)
			var b_style = StyleBoxFlat.new()
			b_style.bg_color = Color(0.08, 0.22, 0.32, 0.9)
			b_style.border_color = Color(0.86, 0.74, 0.48, 0.85)
			b_style.set_border_width_all(1)
			b_style.set_corner_radius_all(5)
			b_style.content_margin_left = 6
			b_style.content_margin_right = 6
			b_style.content_margin_top = 4
			b_style.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", b_style)
			btn.pressed.connect(open_video_theater)
			vbox_tel.add_child(btn)

func _create_video_theater_panel():
	video_theater_panel = Control.new()
	video_theater_panel.name = "VideoTheaterPanel"
	video_theater_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_theater_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	video_theater_panel.visible = false
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.04, 0.07, 0.92)
	video_theater_panel.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 560)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.16, 0.96)
	style.border_color = Color(0.86, 0.74, 0.48, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	# Header
	var hbox_hdr = HBoxContainer.new()
	hbox_hdr.name = "HBoxHdr" 
	var title = Label.new()
	title.text = "🎬 COP31 SİNEMATİK & VİDEO TİYATROSU [Canlı Sunum Modu]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	hbox_hdr.add_child(title)
	
	var close_btn_hdr = Button.new()
	close_btn_hdr.text = "✕ Kapat [ESC / V]"
	close_btn_hdr.custom_minimum_size = Vector2(140, 32)
	close_btn_hdr.pressed.connect(close_video_theater)
	hbox_hdr.add_child(close_btn_hdr)
	vbox.add_child(hbox_hdr)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Body HBox
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	
	# Video Area (Left)
	var video_box = VBoxContainer.new()
	video_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	video_box.add_theme_constant_override("separation", 8)
	
	var video_frame = AspectRatioContainer.new()
	video_frame.ratio = 1.7778
	video_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	video_theater_player = VideoStreamPlayer.new()
	video_theater_player.name = "HudVideoStreamPlayer"
	var stream = load("res://assets/video/intro_cinematic.ogv")
	if stream:
		video_theater_player.stream = stream
	video_theater_player.expand = true
	video_frame.add_child(video_theater_player)
	video_box.add_child(video_frame)
	
	# Video Controls
	var ctrl_hbox = HBoxContainer.new()
	ctrl_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_hbox.add_theme_constant_override("separation", 12)
	
	video_theater_play_btn = Button.new()
	video_theater_play_btn.text = "⏸ Duraklat"
	video_theater_play_btn.custom_minimum_size = Vector2(120, 36)
	video_theater_play_btn.pressed.connect(func():
		if video_theater_player.is_playing() and not video_theater_player.paused:
			video_theater_player.paused = true
			video_theater_play_btn.text = "▶ Oynat"
		else:
			video_theater_player.paused = false
			if not video_theater_player.is_playing():
				video_theater_player.play()
			video_theater_play_btn.text = "⏸ Duraklat"
	)
	ctrl_hbox.add_child(video_theater_play_btn)
	
	var restart_btn = Button.new()
	restart_btn.text = "🔄 Baştan Oynat"
	restart_btn.custom_minimum_size = Vector2(130, 36)
	restart_btn.pressed.connect(func():
		video_theater_player.stop()
		video_theater_player.paused = false
		video_theater_player.play()
		video_theater_play_btn.text = "⏸ Duraklat"
	)
	ctrl_hbox.add_child(restart_btn)
	
	var chk_loop = CheckBox.new()
	chk_loop.text = "🔁 Döngü (Loop)"
	chk_loop.button_pressed = true
	ctrl_hbox.add_child(chk_loop)
	
	btn_fs_theater = Button.new()
	btn_fs_theater.name = "BtnFullscreenTheater"
	btn_fs_theater.text = "⛶ Tam Ekran Video"
	btn_fs_theater.custom_minimum_size = Vector2(150, 36)
	btn_fs_theater.pressed.connect(_toggle_video_theater_fullscreen)
	ctrl_hbox.add_child(btn_fs_theater)
	
	video_theater_player.finished.connect(func():
		if chk_loop.button_pressed and is_video_theater_open:
			video_theater_player.play()
		else:
			video_theater_play_btn.text = "▶ Oynat"
	)
	
	var back_btn = Button.new()
	back_btn.text = "🚪 Gösterimi Bitir & Oyuna Dön"
	back_btn.custom_minimum_size = Vector2(210, 36)
	back_btn.pressed.connect(close_video_theater)
	ctrl_hbox.add_child(back_btn)
	
	video_box.add_child(ctrl_hbox)
	body_hbox.add_child(video_box)
	
	# Playlist & Info Panel (Right)
	var side_vbox = VBoxContainer.new()
	side_vbox.name = "SideVBox" 
	side_vbox.custom_minimum_size = Vector2(260, 0)
	side_vbox.add_theme_constant_override("separation", 10)
	
	var side_title = Label.new()
	side_title.text = "🎞️ TANITIM VİDEOLARI"
	side_title.add_theme_font_size_override("font_size", 14)
	side_title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	side_vbox.add_child(side_title)

	var info_pnl = PanelContainer.new()
	info_pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ip_style = StyleBoxFlat.new()
	ip_style.bg_color = Color(0.02, 0.06, 0.1, 0.8)
	ip_style.border_color = Color(0.2, 0.4, 0.6, 0.6)
	ip_style.set_border_width_all(1)
	ip_style.set_corner_radius_all(6)
	ip_style.content_margin_left = 12
	ip_style.content_margin_right = 12
	ip_style.content_margin_top = 10
	ip_style.content_margin_bottom = 10
	info_pnl.add_theme_stylebox_override("panel", ip_style)
	
	var info_lbl = Label.new()
	info_lbl.text = "📌 Gösterim Detayları:\n• Süre: 10 Saniye\n• Çözünürlük: 1280x720 HD\n• FPS: 24 (Theora OGV)\n• Konu: 2050 yılı Akdeniz dip suları, batık metropol kalıntıları ve deniz kaplumbağamız Caretta'nın kâşifleri arayışı.\n• İpucu: Sunum sırasında istediğiniz an [V] tuşuna basarak videoyu ekrana getirebilirsiniz."
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_pnl.add_child(info_lbl)
	
	var stream_intro = preload("res://assets/video/intro_cinematic.ogv")
	var stream_final = preload("res://assets/video/final_cinematic.ogv")
	
	var v1_btn = Button.new()
	v1_btn.text = "▶ 01. Giriş Sinematiği\n(Batık Şehir & Caretta)"
	v1_btn.custom_minimum_size = Vector2(0, 52)
	v1_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v1_btn.pressed.connect(func():
		video_theater_player.stream = stream_intro
		video_theater_player.stop()
		video_theater_player.paused = false
		video_theater_player.play()
		video_theater_play_btn.text = "⏸ Duraklat"
		info_lbl.text = "📌 Gösterim Detayları:\n• Süre: 10 Saniye\n• Çözünürlük: 1280x720 HD\n• FPS: 24 (Theora OGV)\n• Konu: 2050 yılı Akdeniz dip suları, batık metropol kalıntıları ve deniz kaplumbağamız Caretta'nın kâşifleri arayışı.\n• İpucu: Sunum sırasında istediğiniz an [V] tuşuna basarak videoyu ekrana getirebilirsiniz."
	)
	side_vbox.add_child(v1_btn)

	var v2_btn = Button.new()
	v2_btn.text = "▶ 02. Final Sinematiği\n(Son Resif & Kurtuluş)"
	v2_btn.custom_minimum_size = Vector2(0, 52)
	v2_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v2_btn.pressed.connect(func():
		video_theater_player.stream = stream_final
		video_theater_player.stop()
		video_theater_player.paused = false
		video_theater_player.play()
		video_theater_play_btn.text = "⏸ Duraklat"
		info_lbl.text = "📌 Gösterim Detayları:\n• Süre: 10 Saniye\n• Çözünürlük: 1280x720 HD\n• FPS: 24 (Theora OGV)\n• Konu: Okyanus Kâşifleri ile buluşma, Son Resif 2050 kutsal alanına varış ve COP31 iklim koruma zaferi.\n• İpucu: Sunum sırasında istediğiniz an [V] tuşuna basarak videoyu ekrana getirebilirsiniz."
	)
	side_vbox.add_child(v2_btn)
	side_vbox.add_child(info_pnl)
	
	body_hbox.add_child(side_vbox)
	vbox.add_child(body_hbox)
	
	panel.add_child(vbox)
	center.add_child(panel)
	video_theater_panel.add_child(center)
	add_child(video_theater_panel)

func toggle_video_theater():
	if is_video_theater_open:
		close_video_theater()
	else:
		open_video_theater()

func open_video_theater():
	var dbox = find_child("DialogueBox", true, false)
	if dbox and dbox.is_active:
		return
	is_video_theater_open = true
	if pause_panel:
		pause_panel.visible = false
	if video_theater_panel:
		video_theater_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if video_theater_player:
		video_theater_player.paused = false
		video_theater_player.play()
	if video_theater_play_btn:
		video_theater_play_btn.text = "⏸ Duraklat"

func _toggle_video_theater_fullscreen():
	is_video_theater_fullscreen = not is_video_theater_fullscreen
	_apply_video_theater_fullscreen_layout()

func _apply_video_theater_fullscreen_layout():
	if not video_theater_panel:
		return
	var panel = video_theater_panel.find_child("Panel", true, false)
	var center = video_theater_panel.find_child("Center", true, false)
	var side_vbox = video_theater_panel.find_child("SideVBox", true, false)
	var hbox_hdr = video_theater_panel.find_child("HBoxHdr", true, false)
	var sep1 = video_theater_panel.find_child("Sep1", true, false)
	
	if is_video_theater_fullscreen:
		if side_vbox: side_vbox.visible = false
		if hbox_hdr: hbox_hdr.visible = false
		if sep1: sep1.visible = false
		if center: center.set_anchors_preset(Control.PRESET_FULL_RECT)
		if panel: panel.custom_minimum_size = Vector2(1240, 680)
		if btn_fs_theater: btn_fs_theater.text = "🗗 Normal Boyut"
	else:
		if side_vbox: side_vbox.visible = true
		if hbox_hdr: hbox_hdr.visible = true
		if sep1: sep1.visible = true
		if panel: panel.custom_minimum_size = Vector2(920, 560)
		if btn_fs_theater: btn_fs_theater.text = "⛶ Tam Ekran Video"

func close_video_theater():
	is_video_theater_open = false
	is_video_theater_fullscreen = false
	_apply_video_theater_fullscreen_layout()
	if video_theater_player:
		video_theater_player.stop()
	if video_theater_panel:
		video_theater_panel.visible = false
	if is_game_paused and pause_panel:
		pause_panel.visible = true
	else:
		get_tree().paused = false
		if not is_inventory_open and not is_badges_open and not is_map_open and not is_journal_open and not is_settings_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
