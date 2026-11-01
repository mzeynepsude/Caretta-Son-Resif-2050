extends Node

# CARETTA: SON RESİF 2050 - Merkezi Ses Yöneticisi (Audio Manager)
# Sualtı uğultusu, su kabarcıkları, plastik boğulma/hasar, şifa ve atık toplama sesleri

var music_player: AudioStreamPlayer = null
var sfx_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 6
var next_pool_idx: int = 0

var sound_streams = {
	"ambiance": preload("res://assets/audio/underwater_ambiance.wav"),
	"bubble": preload("res://assets/audio/bubble.wav"),
	"damage": preload("res://assets/audio/damage.wav"),
	"heal": preload("res://assets/audio/heal.wav"),
	"pickup": preload("res://assets/audio/pickup.wav")
}

var master_volume: float = 1.0 # 0.0 - 1.0
var ambiance_volume: float = 0.55 # 0.0 - 1.0 (Yumuşak, dinlendirici sualtı uğultusu)
var sfx_volume: float = 0.65 # 0.0 - 1.0
var bubble_timer: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Sürekli dönen sualtı atmosfer sesi (Ambiance)
	music_player = AudioStreamPlayer.new()
	music_player.name = "UnderwaterAmbiancePlayer"
	music_player.stream = sound_streams["ambiance"]
	add_child(music_player)
	_update_volumes()
	music_player.finished.connect(func():
		if music_player:
			music_player.play()
	)
	music_player.play()
	
	# Polifonik SFX oynatıcı havuzu (aynı anda birden fazla ses çıkabilmesi için)
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		add_child(p)
		sfx_pool.append(p)

func set_master_volume(val: float):
	master_volume = clampf(val, 0.0, 1.0)
	_update_volumes()

func set_ambiance_volume(val: float):
	ambiance_volume = clampf(val, 0.0, 1.0)
	_update_volumes()

func set_sfx_volume(val: float):
	sfx_volume = clampf(val, 0.0, 1.0)

func _update_volumes():
	if music_player:
		var effective = master_volume * ambiance_volume
		if effective <= 0.001:
			music_player.volume_db = -80.0
		else:
			# Kulağı tırmalamayan, dinlendirici dip seviye (-20.0 dB taban)
			music_player.volume_db = -20.0 + linear_to_db(effective)

func _process(delta: float):
	# Oyuncu depar attığında periyodik su kabarcığı efekti
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_sprinting" in player and player.is_sprinting:
		bubble_timer += delta
		if bubble_timer >= 0.75:
			bubble_timer = 0.0
			play_sfx("bubble", 0.15)
	else:
		bubble_timer = 0.0

func play_sfx(sound_name: String, pitch_range: float = 0.0):
	if not sound_streams.has(sound_name):
		return
		
	var stream = sound_streams[sound_name]
	var player = sfx_pool[next_pool_idx]
	next_pool_idx = (next_pool_idx + 1) % pool_size
	
	player.stream = stream
	if pitch_range > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	else:
		player.pitch_scale = 1.0
		
	var base_db = -8.0
	if sound_name == "damage":
		base_db = -3.0
	elif sound_name == "heal":
		base_db = -6.0
	elif sound_name == "pickup":
		base_db = -6.0
	elif sound_name == "bubble":
		base_db = -12.0

	var effective_sfx = master_volume * sfx_volume
	if effective_sfx <= 0.001:
		player.volume_db = -80.0
	else:
		player.volume_db = base_db + linear_to_db(effective_sfx)
		
	player.play()

# =========================================================================
# GLOBAL EKRAN & TAM EKRAN YÖNETİMİ (F11 / ALT+ENTER)
# =========================================================================

signal fullscreen_toggled(is_fullscreen: bool)

func is_fullscreen() -> bool:
	var mode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func set_fullscreen(enabled: bool):
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		var screen_rect = DisplayServer.screen_get_usable_rect()
		var win_size = Vector2i(1280, 720)
		var center_pos = screen_rect.position + (screen_rect.size - win_size) / 2
		DisplayServer.window_set_position(center_pos)
	fullscreen_toggled.emit(enabled)

func toggle_fullscreen() -> bool:
	var new_state = not is_fullscreen()
	set_fullscreen(new_state)
	return new_state

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or event.physical_keycode == KEY_F11 or ((event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER) and event.alt_pressed):
			get_viewport().set_input_as_handled()
			toggle_fullscreen()


