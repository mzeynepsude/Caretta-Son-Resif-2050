extends Control

# Caretta: Son Resif 2050 — Sinematik Video Giriş Ara Sahnesi (Video Cutscene Director)
# Kullanıcının eklediği 10 saniyelik 4 sahneli sinematik video (Sea_turtle_discovers_sunken_city-giriş)
# 4 Sahneye tam senkronize, otomatik akan dinamik altyazı ve 2.39:1 Sinemaskop Letterbox

@onready var video_player = find_child("VideoStreamPlayer", true, false)
@onready var letterbox_top = find_child("LetterboxTop", true, false)
@onready var letterbox_bottom = find_child("LetterboxBottom", true, false)
@onready var subtitle_panel = find_child("SubtitlePanel", true, false)
@onready var speaker_label = find_child("SpeakerLabel", true, false)
@onready var text_label = find_child("TextLabel", true, false)
@onready var prompt_label = find_child("PromptLabel", true, false)
@onready var skip_label = find_child("SkipLabel", true, false)
@onready var fade_overlay = find_child("FadeOverlay", true, false)

# Videodaki 4 sahneye denk gelen 4 altyazı repliği
var dialogue_lines: Array = [
	{
		"speaker": "Caretta (1. Sahne: Hortum & Kopuş)",
		"text": "\"Okyanus Kâşifleri ekibimle Akdeniz'i korumaya ant içmiştik... Ama dev sualtı hortumu ve sıcak akıntı beni ekibimden kopardı!\""
	},
	{
		"speaker": "Caretta (2. Sahne: 2050 +2°C Distopyası)",
		"text": "\"Yıl 2050... İklim hedefleri tutmadı ve dünya +2°C ısındı! Akdeniz kaynıyor, asit ve atıklar canlı çeşitliliğini yok ediyor.\""
	},
	{
		"speaker": "Caretta (3. Sahne: Biyo-Örnekler & Kâşifler)",
		"text": "\"Kâşiflerle buluşmalı, Son Resif'ten topladığım canlı çeşitliliği örneklerini istasyona ulaştırmalıyım!\""
	},
	{
		"speaker": "Caretta (4. Sahne: Küresel İletişim & Kurtuluş)",
		"text": "\"İstasyonun iletişim vericilerini açıp bu verileri insanlara haykıracağız; dünyayı kurtarmak için hala umut var!\""
	}
]

# 10 saniyelik videoda her sahnenin başlangıç zamanı (saniye)
var shot_timestamps: Array = [0.0, 2.5, 5.0, 7.5]

var current_line_index: int = 0
var is_transitioning: bool = false
var elapsed_time: float = 0.0

func _ready():
	if fade_overlay:
		fade_overlay.modulate.a = 1.0
		fade_overlay.visible = true
		var t = create_tween()
		t.tween_property(fade_overlay, "modulate:a", 0.0, 0.6)
		
	if video_player:
		video_player.finished.connect(_on_video_finished)
		video_player.play()
		
	_show_line(0)

func _process(delta: float):
	if is_transitioning:
		return
		
	elapsed_time += delta
	
	# Video oynatıcının kesin zaman damgası veya iç zamanlayıcıyı kullan
	var current_pos = elapsed_time
	if video_player and video_player.is_playing() and video_player.has_method("get_stream_position"):
		var stream_pos = video_player.get_stream_position()
		if stream_pos > 0.0:
			current_pos = stream_pos
			
	# Videonun 4 sahnesi boyunca altyazıları otomatik ilerlet
	var target_index = 0
	for i in range(shot_timestamps.size() - 1, -1, -1):
		if current_pos >= shot_timestamps[i]:
			target_index = i
			break
			
	if target_index != current_line_index and target_index < dialogue_lines.size():
		current_line_index = target_index
		_show_line(current_line_index)
		
	# Alt bilgi göstergesi parıltısı
	if prompt_label:
		var pulse = (sin(Time.get_ticks_msec() * 0.007) + 1.0) * 0.5
		prompt_label.modulate = Color(1.0, 0.88, 0.52, lerp(0.7, 1.0, pulse))

func _show_line(index: int):
	if index < 0 or index >= dialogue_lines.size():
		return
	var data = dialogue_lines[index]
	if speaker_label:
		speaker_label.text = "◆ %s ◆" % data["speaker"]
	if text_label:
		text_label.text = data["text"]
		# Yumuşak sahne geçişi (alttan akan pürüzsüz geçiş efekti)
		text_label.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(text_label, "modulate:a", 1.0, 0.22)
		
	if prompt_label:
		if index >= dialogue_lines.size() - 1:
			prompt_label.text = "✦ Sahne 4 / 4 • Akdeniz'e Dalınıyor... ✦"
		else:
			prompt_label.text = "✦ Sahne %d / 4 ✦" % (index + 1)

func _unhandled_input(event: InputEvent):
	if is_transitioning:
		return
		
	# ESC ile doğrudan sahneyi atla ve oyuna başla
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_finish_cutscene()
		return
		
	# Oyuncu isterse Boşluk / E / Tık ile bir sonraki sahneye hızlandırabilir
	var manual_skip = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER, KEY_F]:
			manual_skip = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		manual_skip = true
		
	if manual_skip:
		get_viewport().set_input_as_handled()
		current_line_index += 1
		if current_line_index < dialogue_lines.size():
			elapsed_time = shot_timestamps[current_line_index]
			_show_line(current_line_index)
		else:
			_finish_cutscene()

func _on_video_finished():
	# Video 10 saniye sonunda bittiğinde otomatik olarak oyuna geç
	_finish_cutscene()

func _finish_cutscene():
	if is_transitioning:
		return
	is_transitioning = true
	
	if video_player:
		video_player.stop()
		
	if fade_overlay:
		fade_overlay.visible = true
		var t = create_tween()
		t.tween_property(fade_overlay, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD)
		await t.finished
		
	get_tree().change_scene_to_file("res://scenes/main.tscn")
