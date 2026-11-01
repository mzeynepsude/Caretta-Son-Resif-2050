extends Node

# CARETTA: SON RESİF 2050 - Kayıt & İlerleme Yöneticisi (Save/Load Manager)
# - 3 Ayrı Kayıt Alanı (Slot 1, Slot 2, Slot 3)
# - 1 Otomatik Kayıt Alanı (Slot 0 - AutoSave)
# - 10 dakikada bir otomatik kayıt döngüsü (Timer)
# - Oyun kapatılıp açılsa da `user://` dizininde kalıcı JSON formatı

const SAVE_PATH_TEMPLATE = "user://save_slot_%d.json"
const AUTOSAVE_SLOT = 0
const AUTOSAVE_INTERVAL_SEC = 600.0 # 10 dakika

var current_active_slot: int = 1
var autosave_timer: Timer = null

signal game_saved(slot_index)
signal game_loaded(slot_index)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_autosave_timer()

func _setup_autosave_timer():
	autosave_timer = Timer.new()
	autosave_timer.name = "AutoSaveTimer"
	autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	autosave_timer.autostart = true
	autosave_timer.one_shot = false
	autosave_timer.timeout.connect(func():
		var main = get_tree().root.find_child("Main", true, false)
		if main and not get_tree().paused:
			save_game(AUTOSAVE_SLOT)
			var hud = main.find_child("HUD", true, false)
			if hud and hud.has_method("show_screen_heal_alert"):
				hud.show_screen_heal_alert("💾 OYUN OTOMATİK KAYDEDİLDİ (10 dk Periyodu)")
	)
	add_child(autosave_timer)

func get_slot_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))

func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {"exists": false, "label": "Boş Kayıt Alanı"}
	var file = FileAccess.open(get_slot_path(slot), FileAccess.READ)
	if not file:
		return {"exists": false, "label": "Bozuk Dosya"}
	var content = file.get_as_text()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var d = json.data
		d["exists"] = true
		return d
	return {"exists": false, "label": "Okunamadı"}

func save_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_active_slot
	var main = get_tree().root.find_child("Main", true, false)
	if not main:
		return false
	var player = main.find_child("Player", true, false)
	var hud = main.find_child("HUD", true, false)
	var station = main.find_child("ResearchStation", true, false)
	if not player:
		return false

	var save_data = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"display_time": "%s %s" % [Time.get_date_string_from_system(), Time.get_time_string_from_system()],
		"slot_name": "Otomatik Kayıt" if slot == 0 else "Kayıt Slotu %d" % slot,
		"player": {
			"health": player.health,
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.rotation.y,
			"inventory": player.inventory.duplicate(),
			"swim_speed": player.base_swim_speed,
			"can_break_shipwrecks": player.can_break_shipwrecks
		},
		"unlocked_badges": hud.unlocked_badges.duplicate() if hud and "unlocked_badges" in hud else [],
		"station_activated": station.is_activated if station and "is_activated" in station else false
	}

	var file = FileAccess.open(get_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		current_active_slot = slot
		game_saved.emit(slot)
		return true
	return false

func load_game(slot: int) -> bool:
	if not has_save(slot):
		return false
	var file = FileAccess.open(get_slot_path(slot), FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return false
	var data: Dictionary = json.data
	current_active_slot = slot

	# Eğer Main sahnesinde değilsek önce Main sahnesine geçelim
	var main = get_tree().root.find_child("Main", true, false)
	if not main:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		main = get_tree().root.find_child("Main", true, false)

	if not main:
		return false

	var player = main.find_child("Player", true, false)
	var hud = main.find_child("HUD", true, false)
	var station = main.find_child("ResearchStation", true, false)

	if player and data.has("player"):
		var p_data = data["player"]
		player.health = p_data.get("health", 100.0)
		var pos = p_data.get("position", [0, 0, 0])
		player.global_position = Vector3(pos[0], pos[1], pos[2])
		player.rotation.y = p_data.get("rotation_y", 0.0)
		player.inventory = p_data.get("inventory", []).duplicate()
		player.base_swim_speed = p_data.get("swim_speed", 6.0)
		player.swim_speed = player.base_swim_speed
		player.can_break_shipwrecks = p_data.get("can_break_shipwrecks", false)
		player.health_changed.emit(player.health)
		player.inventory_updated.emit(player.inventory)

	if hud and data.has("unlocked_badges"):
		hud.unlocked_badges = data["unlocked_badges"].duplicate()
		if hud.has_method("_refresh_badge_collection_ui"):
			hud._refresh_badge_collection_ui()

	if station and data.get("station_activated", false):
		station.is_activated = true
		if station.station_aura:
			station.station_aura.light_color = Color(0.3, 1.0, 0.8)

	game_loaded.emit(slot)
	return true

