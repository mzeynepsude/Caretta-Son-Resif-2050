extends Control

# Caretta: Son Resif 2050 — Sinematik Final Ara Sahnesi (Final Cutscene Director)
# Kullanıcının eklediği 10 saniyelik final videosu (Turtle_swimming_toward_-_final)
# 2.39:1 Sinemaskop Letterbox, Genshin tarzı dinamik altyazı ve oyuncu kontrollü geçiş

@onready var video_player = find_child("VideoStreamPlayer", true, false)
@onready var letterbox_top = find_child("LetterboxTop", true, false)
@onready var letterbox_bottom = find_child("LetterboxBottom", true, false)
@onready var subtitle_panel = find_child("SubtitlePanel", true, false)
@onready var speaker_label = find_child("SpeakerLabel", true, false)
@onready var text_label = find_child("TextLabel", true, false)
@onready var prompt_label = find_child("PromptLabel", true, false)
@onready var skip_label = find_child("SkipLabel", true, false)
@onready var fade_overlay = find_child("FadeOverlay", true, false)

var dialogue_lines: Array = [
	{
		"speaker": "Caretta (1. Sahne: Biyo-Çeşitlilik Zaferi)",
		"text": "\"Son Resif'ten topladığımız canlı çeşitliliği örneklerini ve tohumları başarıyla istasyona ulaştırdık!\""
	},
	{
		"speaker": "Caretta (2. Sahne: İstasyon Antenleri Devrede)",
		"text": "\"Okyanus Kâşifleri ile istasyonun uç iletişim antenlerini sarıp küresel uydu hattını açtık!\""
	},
	{
		"speaker": "Caretta (3. Sahne: İnsanlığın Kurtuluş Çağrısı)",
		"text": "\"Bu biyo-veriler tüm dünyadaki insanlara ulaştı; 2050'nin +2°C distopyasını durdurmak için insanlık el ele veriyor!\""
	},
	{
		"speaker": "Caretta (4. Sahne: Geleceğe Umutla Dalış)",
		"text": "\"Ben Caretta... 100 milyon yıldır Antalya kıyılarında doğdum; temiz ve yaşayan bir Akdeniz için yüzmeye devam edeceğim!\""
	}
]

var current_line_index: int = 0
var is_transitioning: bool = false
var input_cooldown: float = 0.25

func _ready():
	if fade_overlay:
		fade_overlay.modulate.a = 1.0
		fade_overlay.visible = true
		var t = create_tween()
		t.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)
		
	if video_player:
		video_player.finished.connect(_on_video_finished)
		video_player.play()
		
	_show_line(0)

func _process(delta: float):
	if is_transitioning:
		return
		
	if input_cooldown > 0.0:
		input_cooldown -= delta
		
	if prompt_label:
		var pulse = (sin(Time.get_ticks_msec() * 0.007) + 1.0) * 0.5
		prompt_label.modulate = Color(1.0, 0.88, 0.52, lerp(0.65, 1.0, pulse))

func _show_line(index: int):
	if index < 0 or index >= dialogue_lines.size():
		return
	var data = dialogue_lines[index]
	if speaker_label:
		speaker_label.text = "◆ %s ◆" % data["speaker"]
	if text_label:
		text_label.text = data["text"]
	if prompt_label:
		if index >= dialogue_lines.size() - 1:
			prompt_label.text = "Ana Menüye Dön [ Boşluk / E ] ▶"
		else:
			prompt_label.text = "✦ [ Boşluk / E ] ile İlerle  ▼"

func _unhandled_input(event: InputEvent):
	if is_transitioning or input_cooldown > 0.0:
		return
		
	# ESC ile doğrudan ana menüye dön
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_finish_cutscene()
		return
		
	# Boşluk, Enter, E, F veya Sol Fare Tıklaması ile kontrollü ilerle
	var should_advance = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER, KEY_F]:
			should_advance = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		should_advance = true
		
	if should_advance:
		get_viewport().set_input_as_handled()
		input_cooldown = 0.25
		current_line_index += 1
		if current_line_index < dialogue_lines.size():
			_show_line(current_line_index)
		else:
			_finish_cutscene()

func _on_video_finished():
	# Video tamamlandığında oyuncu replikleri okuyana kadar döngüde akıcı kalsın
	if current_line_index < dialogue_lines.size() - 1:
		if video_player:
			video_player.play()
	else:
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
		t.tween_property(fade_overlay, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_QUAD)
		await t.finished
		
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

