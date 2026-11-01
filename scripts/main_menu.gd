extends Control

# CARETTA: SON RESİF 2050 - Ana Menü ve Giriş Ekranı (Main Menu UI)
# Standartlar:
# 1. Yeni Oyun (Slot seçimi veya anında başlatma)
# 2. Devam Et (En son kaydedilen slotu otomatik yükler)
# 3. Kayıt Alanları (3 Ayrı Slot + 1 Otomatik Kayıt Slotu)
# 4. Ayarlar (Ses Seviyesi, Fare Hassasiyeti, Tam Ekran, Biyolüminesans Kalitesi)
# 5. Krediler & Telif Hakları (GAMICO Caretta CC-BY-4.0, Sketchfab atıfları, cop31.tr)
# 6. Çıkış (Oyunu kapatma)

@onready var menu_buttons_container = $CenterContainer/VBoxMenu/MenuButtons
@onready var slots_modal = $SlotsModal
@onready var settings_modal = $SettingsModal
@onready var credits_modal = $CreditsModal
@onready var videos_modal = get_node_or_null("VideosModal")
var is_video_fullscreen: bool = false

var save_mgr = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# SaveManager'ı yükle veya dinamik olarak bağla
	var existing = get_node_or_null("/root/SaveManager")
	if existing:
		save_mgr = existing
	else:
		var script = load("res://scripts/save_manager.gd")
		if script:
			save_mgr = Node.new()
			save_mgr.set_script(script)
			save_mgr.name = "SaveManager"
			if get_tree() and get_tree().root:
				get_tree().root.add_child.call_deferred(save_mgr)
	
	_setup_button_connections()
	_update_continue_button_state()
	
	# Sualtı arka planına yavaş, yaşayan okyanus dalgalanması (Ken Burns efekti)
	var bg = find_child("UnderseaBackground", true, false)
	if bg:
		bg.scale = Vector2(1.0, 1.0)
		var t = create_tween().set_loops()
		t.tween_property(bg, "scale", Vector2(1.05, 1.05), 16.0).set_trans(Tween.TRANS_SINE)
		t.tween_property(bg, "scale", Vector2(1.0, 1.0), 16.0).set_trans(Tween.TRANS_SINE)

func _setup_button_connections():
	var btn_new = find_child("BtnNewGame", true, false)
	var btn_continue = find_child("BtnContinue", true, false)
	var btn_slots = find_child("BtnSlots", true, false)
	var btn_settings = find_child("BtnSettings", true, false)
	var btn_credits = find_child("BtnCredits", true, false)
	var btn_quit = find_child("BtnQuit", true, false)
	
	if btn_new: btn_new.pressed.connect(_on_new_game_pressed)
	if btn_continue: btn_continue.pressed.connect(_on_continue_pressed)
	if btn_slots: btn_slots.pressed.connect(_on_slots_pressed)
	if btn_settings: btn_settings.pressed.connect(_on_settings_pressed)
	var btn_videos = find_child("BtnVideos", true, false)
	if btn_videos: btn_videos.pressed.connect(_on_videos_pressed)
	if btn_credits: btn_credits.pressed.connect(_on_credits_pressed)
	if btn_quit: btn_quit.pressed.connect(func(): get_tree().quit())
	
	# Modal kapatma butonları
	var close_slots = find_child("BtnCloseSlots", true, false)
	var close_settings = find_child("BtnCloseSettings", true, false)
	var close_credits = find_child("BtnCloseCredits", true, false)
	var close_videos = find_child("BtnCloseVideos", true, false)
	
	if close_slots: close_slots.pressed.connect(func(): slots_modal.visible = false)
	if close_settings: close_settings.pressed.connect(func(): settings_modal.visible = false)
	if close_credits: close_credits.pressed.connect(func(): credits_modal.visible = false)
	if close_videos: close_videos.pressed.connect(_close_videos_modal)
	
	# Video Oynatıcı Kontrolleri
	var v_player = find_child("VideoStreamPlayer", true, false)
	var btn_play_pause = find_child("BtnPlayPause", true, false)
	var btn_restart = find_child("BtnRestart", true, false)
	var chk_loop = find_child("CheckLoop", true, false)
	var btn_v1 = find_child("BtnPlayVideo1", true, false)
	var btn_v2 = find_child("BtnPlayVideo2", true, false)
	var stream_v1 = preload("res://assets/video/intro_cinematic.ogv")
	var stream_v2 = preload("res://assets/video/final_cinematic.ogv")
	var info_lbl = find_child("InfoLabel", true, false)
	var btn_fs_video = find_child("BtnFullscreenVideo", true, false)
	if btn_fs_video:
		btn_fs_video.pressed.connect(_toggle_video_fullscreen)
	
	if v_player and btn_play_pause:
		btn_play_pause.pressed.connect(func():
			if v_player.is_playing() and not v_player.paused:
				v_player.paused = true
				btn_play_pause.text = "▶ Oynat"
			else:
				v_player.paused = false
				if not v_player.is_playing():
					v_player.play()
				btn_play_pause.text = "⏸ Duraklat"
		)
	
	if v_player and btn_restart:
		btn_restart.pressed.connect(func():
			v_player.stop()
			v_player.paused = false
			v_player.play()
			if btn_play_pause: btn_play_pause.text = "⏸ Duraklat"
		)
	
	if v_player and btn_v1:
		btn_v1.pressed.connect(func():
			v_player.stream = stream_v1
			v_player.stop()
			v_player.paused = false
			v_player.play()
			if btn_play_pause: btn_play_pause.text = "⏸ Duraklat"
			if info_lbl:
				info_lbl.text = "📌 Video Detayları:\n• Süre: 10 Saniye\n• Çözünürlük: 1280x720 HD\n• Format: Theora OGV / Vorbis\n• Konu: 2050 yılı Akdeniz dip suları, batık metropol kalıntıları ve deniz kaplumbağamız Caretta'nın kâşifleri arayışı.\n• Kullanım: Canlı sunum ve tanıtım."
		)

	if v_player and btn_v2:
		btn_v2.pressed.connect(func():
			v_player.stream = stream_v2
			v_player.stop()
			v_player.paused = false
			v_player.play()
			if btn_play_pause: btn_play_pause.text = "⏸ Duraklat"
			if info_lbl:
				info_lbl.text = "📌 Video Detayları:\n• Süre: 10 Saniye\n• Çözünürlük: 1280x720 HD\n• Format: Theora OGV / Vorbis\n• Konu: Okyanus Kâşifleri ile buluşma, Son Resif 2050 kutsal alanına varış ve COP31 iklim koruma zaferi.\n• Kullanım: Canlı sunum ve tanıtım."
		)
	
	if v_player:
		v_player.finished.connect(func():
			if chk_loop and chk_loop.button_pressed and videos_modal and videos_modal.visible:
				v_player.play()
			elif btn_play_pause:
				btn_play_pause.text = "▶ Oynat"
		)
	
	# Ayarlar Slider'ları
	var sld_sens = find_child("SliderSensitivity", true, false)
	var chk_fullscreen = find_child("CheckFullscreen", true, false)
	if chk_fullscreen:
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("is_fullscreen"):
			chk_fullscreen.button_pressed = audio.is_fullscreen()
			audio.fullscreen_toggled.connect(func(is_fs):
				chk_fullscreen.button_pressed = is_fs
			)
		else:
			var mode = DisplayServer.window_get_mode()
			chk_fullscreen.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		
		chk_fullscreen.toggled.connect(func(toggled):
			if audio and audio.has_method("set_fullscreen"):
				if audio.is_fullscreen() != toggled:
					audio.set_fullscreen(toggled)
			else:
				if toggled:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_size(Vector2i(1280, 720))
		)

func _update_continue_button_state():
	var btn_continue = find_child("BtnContinue", true, false)
	if not btn_continue:
		return
	var has_any_save = false
	var mgr = _get_save_manager()
	if mgr:
		for s in [0, 1, 2, 3]:
			if mgr.has_save(s):
				has_any_save = true
				break
	btn_continue.disabled = not has_any_save

func _get_save_manager():
	if save_mgr and is_instance_valid(save_mgr):
		return save_mgr
	save_mgr = get_node_or_null("/root/SaveManager")
	return save_mgr

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/intro_cutscene.tscn")

func _on_continue_pressed():
	var mgr = _get_save_manager()
	if not mgr:
		_on_new_game_pressed()
		return
	# En güncel slotu bul (1..3 ve 0)
	var latest_slot = -1
	for s in [1, 2, 3, 0]:
		if mgr.has_save(s):
			latest_slot = s
			break
	if latest_slot != -1:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		mgr.load_game(latest_slot)
	else:
		_on_new_game_pressed()

func _on_slots_pressed():
	_refresh_slots_ui()
	slots_modal.visible = true

func _on_settings_pressed():
	settings_modal.visible = true

func _on_credits_pressed():
	credits_modal.visible = true

func _refresh_slots_ui():
	var mgr = _get_save_manager()
	if not mgr:
		return
	var slots_vbox = find_child("SlotsList", true, false)
	if not slots_vbox:
		return
	for c in slots_vbox.get_children():
		c.queue_free()

	var slot_indices = [1, 2, 3, 0]
	for s in slot_indices:
		var info = mgr.get_slot_summary(s)
		var pnl = PanelContainer.new()
		var pstyle = StyleBoxFlat.new()
		pstyle.bg_color = Color(0.05, 0.14, 0.22, 0.9)
		pstyle.border_color = Color(0.25, 0.75, 0.95, 0.7)
		pstyle.set_border_width_all(1)
		pstyle.set_corner_radius_all(6)
		pstyle.content_margin_left = 12
		pstyle.content_margin_right = 12
		pstyle.content_margin_top = 8
		pstyle.content_margin_bottom = 8
		pnl.add_theme_stylebox_override("panel", pstyle)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var vbox_info = VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var t_lbl = Label.new()
		t_lbl.text = "💾 Otomatik Kayıt (AutoSave)" if s == 0 else "💾 Kayıt Slotu %d" % s
		t_lbl.add_theme_font_size_override("font_size", 15)
		t_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if s == 0 else Color(0.35, 0.9, 1.0))
		vbox_info.add_child(t_lbl)
		
		var d_lbl = Label.new()
		if info.get("exists", false):
			var hp = int(info.get("player", {}).get("health", 100))
			var dt = info.get("display_time", "")
			d_lbl.text = "Tarih: %s | Can: %d HP | Rozetler: %d" % [dt, hp, info.get("unlocked_badges", []).size()]
			d_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
		else:
			d_lbl.text = "(Boş Kayıt Alanı)"
			d_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
		d_lbl.add_theme_font_size_override("font_size", 12)
		vbox_info.add_child(d_lbl)
		hbox.add_child(vbox_info)
		
		if info.get("exists", false):
			var load_b = Button.new()
			load_b.text = "Yükle ▶"
			load_b.custom_minimum_size = Vector2(85, 34)
			load_b.pressed.connect(func():
				slots_modal.visible = false
				get_tree().change_scene_to_file("res://scenes/main.tscn")
				await get_tree().process_frame
				await get_tree().process_frame
				mgr.load_game(s)
			)
			hbox.add_child(load_b)
		else:
			var empty_lbl = Label.new()
			empty_lbl.text = "Boş"
			empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.55))
			hbox.add_child(empty_lbl)
			
		pnl.add_child(hbox)
		slots_vbox.add_child(pnl)

func _on_videos_pressed():
	if not videos_modal:
		videos_modal = find_child("VideosModal", true, false)
	if videos_modal:
		videos_modal.visible = true
	var amb = find_child("AmbiancePlayer", true, false)
	if amb:
		amb.stream_paused = true
	var v_player = find_child("VideoStreamPlayer", true, false)
	if v_player:
		v_player.paused = false
		v_player.play()
	var btn_play_pause = find_child("BtnPlayPause", true, false)
	if btn_play_pause:
		btn_play_pause.text = "⏸ Duraklat"

func _toggle_video_fullscreen():
	is_video_fullscreen = not is_video_fullscreen
	_apply_video_fullscreen_layout()

func _apply_video_fullscreen_layout():
	if not videos_modal:
		videos_modal = find_child("VideosModal", true, false)
	if not videos_modal:
		return
	var panel = videos_modal.find_child("Panel", true, false)
	var playlist = videos_modal.find_child("PlaylistVBox", true, false)
	var hdr = videos_modal.find_child("HBoxHdr", true, false)
	var sep = videos_modal.find_child("HSeparator", true, false)
	var btn_fs = videos_modal.find_child("BtnFullscreenVideo", true, false)
	
	if is_video_fullscreen:
		if playlist: playlist.visible = false
		if hdr: hdr.visible = false
		if sep: sep.visible = false
		if panel: panel.custom_minimum_size = Vector2(1240, 680)
		if btn_fs: btn_fs.text = "🗗 Normal Boyut"
	else:
		if playlist: playlist.visible = true
		if hdr: hdr.visible = true
		if sep: sep.visible = true
		if panel: panel.custom_minimum_size = Vector2(920, 560)
		if btn_fs: btn_fs.text = "⛶ Tam Ekran Video"

func _close_videos_modal():
	is_video_fullscreen = false
	_apply_video_fullscreen_layout()
	if not videos_modal:
		videos_modal = find_child("VideosModal", true, false)
	if videos_modal:
		videos_modal.visible = false
	var v_player = find_child("VideoStreamPlayer", true, false)
	if v_player:
		v_player.stop()
	var amb = find_child("AmbiancePlayer", true, false)
	if amb:
		amb.stream_paused = false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if videos_modal and videos_modal.visible:
				get_viewport().set_input_as_handled()
				if is_video_fullscreen:
					_toggle_video_fullscreen()
				else:
					_close_videos_modal()
			elif slots_modal and slots_modal.visible:
				get_viewport().set_input_as_handled()
				slots_modal.visible = false
			elif settings_modal and settings_modal.visible:
				get_viewport().set_input_as_handled()
				settings_modal.visible = false
			elif credits_modal and credits_modal.visible:
				get_viewport().set_input_as_handled()
				credits_modal.visible = false
