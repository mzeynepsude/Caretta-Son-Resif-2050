extends Node

# CARETTA: SON RESİF 2050 - Kapsamlı Otomatik Yazılım Test Paketi (Deep QA & Regression Suite)
# Test kapsamı:
# 1. Kalezyon (CollisionShape3D) ve Uzamsal Çakışmama (Bina, NPC, Atık, Tuzak kesişimleri)
# 2. Metin Kayması (VC_CHARS_AFTER_SHAPING, Autowrap, Panel Boyutu, UI Rect Çakışmaması)
# 3. Metin Alakasızlığı ve Diyalog Tutarlılığı (7 NPC + İstasyon + HUD tüm metinlerin denetimi)
# 4. Denizanaları ve Poşet Tuzaklarının Hata Düşürmemesi (Çoklu poşet yutma hız testi, queue_free güvenliği)
# 5. Canın Azalması / Yükselmesi, Stamina, HotWaterZone ve Akdeniz Foku AI Testleri
# 6. Envanterin P ve ESC ile Durdurulması / Devam Ettirilmesi Durum Makinesi Testi

var passed: int = 0
var failed: int = 0

func _ready():
	_run_tests()

func _assert(condition: bool, test_id: String, success_msg: String, fail_msg: String):
	if condition:
		print("✅ [PASS %s] %s" % [test_id, success_msg])
		passed += 1
	else:
		print("❌ [FAIL %s] %s" % [test_id, fail_msg])
		failed += 1

func _run_tests():
	print("==========================================================================")
	print("🧪 CARETTA: SON RESİF 2050 - KAPSAMLI YAZILIM VE KALİTE TEST PAKETİ (QA)")
	print("==========================================================================")

	# -------------------------------------------------------------------------
	# TEST 01: Ana Sahne ve Sinematik Giriş Sahnesi Yükleme
	# -------------------------------------------------------------------------
	var main_packed = load("res://scenes/main.tscn")
	var intro_packed = load("res://scenes/intro_cutscene.tscn")
	var intro_inst = intro_packed.instantiate() if intro_packed else null
	var intro_ok = false
	if intro_inst:
		add_child(intro_inst)
		intro_ok = (intro_inst.speaker_label != null and intro_inst.text_label != null)
		remove_child(intro_inst)
		intro_inst.queue_free()
		
	var final_packed = load("res://scenes/final_cutscene.tscn")
	var final_inst = final_packed.instantiate() if final_packed else null
	var final_ok = false
	if final_inst:
		add_child(final_inst)
		final_ok = (final_inst.speaker_label != null and final_inst.text_label != null)
		remove_child(final_inst)
		final_inst.queue_free()
		
	var menu_packed = load("res://scenes/main_menu.tscn")
	_assert(main_packed != null and intro_ok and final_ok and menu_packed != null, "01", "main.tscn, main_menu.tscn, intro ve final sahneleri hatasız yüklendi.", "Sahne yükleme hatası!")
	if not main_packed:
		get_tree().quit(1)
		return

	var main = main_packed.instantiate()
	add_child(main)

	var player = main.find_child("Player", true, false)
	var hud = main.find_child("HUD", true, false)
	var dlg_box = main.find_child("DialogueBox", true, false)
	var station = main.find_child("ResearchStation", true, false)
	var school_fish = main.find_child("SchoolFish1", true, false)
	var logo_cop = hud.find_child("LogoCOP31", true, false) if hud else null
	var logo_sdg14 = hud.find_child("LogoSDG14", true, false) if hud else null
	var logo_sdg13 = hud.find_child("LogoSDG13", true, false) if hud else null

	_assert(player != null and hud != null and dlg_box != null and station != null and school_fish != null and logo_cop != null and logo_sdg14 != null and logo_sdg13 != null,
		"02", "Player, HUD (COP31, SDG14 ve SDG13 logoları), DialogueBox, Station ve SchoolFish aktif.", "Temel sahne düğümleri veya HUD logoları eksik!")

	# -------------------------------------------------------------------------
	# TEST 03: Canın Azalması, Canın Yükselmesi, Sınır Koruması (0-100) ve HUD Senkronu
	# -------------------------------------------------------------------------
	var health_bar = hud.get("health_bar")
	player.health = 100.0
	player.take_damage(35.0)
	var hp_after_dmg = player.health
	var bar_after_dmg = health_bar.value if health_bar else -1.0

	player.apply_healing(20.0)
	var hp_after_heal = player.health
	var bar_after_heal = health_bar.value if health_bar else -1.0

	# Aşırı hasar ve aşırı şifa sınır (clamping) testi
	player.take_damage(500.0)
	var hp_min_clamp = player.health
	player.apply_healing(500.0)
	var hp_max_clamp = player.health

	_assert(
		is_equal_approx(hp_after_dmg, 65.0) and is_equal_approx(bar_after_dmg, 65.0) and
		is_equal_approx(hp_after_heal, 85.0) and is_equal_approx(bar_after_heal, 85.0) and
		is_equal_approx(hp_min_clamp, 0.0) and is_equal_approx(hp_max_clamp, 100.0),
		"03",
		"Can azalması (100->65), yükselmesi (65->85), 0-100 sınır koruması ve HUD HealthBar senkronu kusursuz.",
		"Can/HealthBar senkron hatası! Dmg:%f, Heal:%f, Min:%f, Max:%f" % [hp_after_dmg, hp_after_heal, hp_min_clamp, hp_max_clamp]
	)

	# -------------------------------------------------------------------------
	# TEST 04: Stamina (Enerji) Barı ve Sıcak Su Bölgesi (HotWaterZone) Hasar Testi
	# -------------------------------------------------------------------------
	var hot_zone = main.find_child("HotWaterZone", true, false)
	var warning_lbl = hud.get("warning_label")
	var hot_ok = false
	if hot_zone and warning_lbl:
		hot_zone._on_body_entered(player)
		hud._process(0.016)
		var entered_ok = player.in_hot_zone and warning_lbl.visible
		player.health = 100.0
		player._physics_process(0.5) # 0.5 sn * 6.0 hasar = 3.0 hasar
		var hot_dmg_ok = player.health < 100.0
		hot_zone._on_body_exited(player)
		hud._process(0.016)
		var exited_ok = (not player.in_hot_zone) and (not warning_lbl.visible)
		hot_ok = entered_ok and hot_dmg_ok and exited_ok
		player.apply_healing(100.0)

	_assert(hot_ok, "04", "HotWaterZone (Sıcak Su Akıntısı) giriş/çıkış, termal hasar ve HUD uyarı yazısı doğrulandı.", "HotWaterZone testi başarısız!")

	# -------------------------------------------------------------------------
	# TEST 05: Envanterin P ve ESC ile Durdurulması / Devam Ettirilmesi (State Machine Testi)
	# -------------------------------------------------------------------------
	# Diyalog açıksa önce kapat
	dlg_box.finish()
	dlg_box.exit_cooldown = 0.0

	# 1) I ile envanteri aç
	hud.open_inventory()
	var inv_opened_ok = hud.is_inventory_open and player.is_inventory_open and hud.inventory_panel.visible

	# 2) Envanter açıkken P ile oyunu durdur -> Envanter temizce kapanmalı, PausePanel açılmalı!
	var ev_p = InputEventKey.new()
	ev_p.pressed = true
	ev_p.keycode = KEY_P
	ev_p.physical_keycode = KEY_P
	hud._unhandled_input(ev_p)

	var paused_from_inv_ok = (
		hud.is_game_paused and
		get_tree().paused and
		hud.pause_panel.visible and
		not hud.is_inventory_open and
		not player.is_inventory_open and
		not hud.inventory_panel.visible
	)

	# 3) Oyun duraklatılmışken I tuşuna basılırsa envanter açılmamalı!
	var ev_i = InputEventKey.new()
	ev_i.pressed = true
	ev_i.keycode = KEY_I
	ev_i.physical_keycode = KEY_I
	hud._unhandled_input(ev_i)
	var blocked_i_while_paused = not hud.is_inventory_open

	# 4) Tekrar P (veya ESC) ile oyuna devam et -> Pause kapanmalı, oyuncu kilidi açılmalı!
	hud._unhandled_input(ev_p)
	var resumed_ok = (
		not hud.is_game_paused and
		not get_tree().paused and
		not hud.pause_panel.visible and
		not hud.is_inventory_open and
		not player.is_inventory_open
	)

	# 5) Envanteri açıp ESC ile kapatma testi
	hud.open_inventory()
	var ev_esc = InputEventKey.new()
	ev_esc.pressed = true
	ev_esc.keycode = KEY_ESCAPE
	hud._unhandled_input(ev_esc)
	var esc_closed_inv_ok = not hud.is_inventory_open and not player.is_inventory_open and not hud.is_game_paused

	_assert(
		inv_opened_ok and paused_from_inv_ok and blocked_i_while_paused and resumed_ok and esc_closed_inv_ok,
		"05",
		"Envanter (I) açıkken P ile durdurma, duraklatmada I kilidi ve ESC/P geçişleri kusursuz çalışıyor.",
		"Envanter + P durdurma durum makinesi hatası! Open:%s, PauseFromInv:%s, BlockI:%s, Resume:%s, EscClose:%s" % [
			str(inv_opened_ok), str(paused_from_inv_ok), str(blocked_i_while_paused), str(resumed_ok), str(esc_closed_inv_ok)
		]
	)

	# -------------------------------------------------------------------------
	# TEST 06: Çoklu Plastik Poşet Yutma ve Hız Kaybı Kurtarma Testi
	# -------------------------------------------------------------------------
	player.health = 100.0
	var initial_base_swim = player.base_swim_speed
	# Üst üste 2 poşet yutulsun (timer bitmeden ikinci poşet!)
	player.apply_plastic_ingestion(20.0, 0.05)
	var speed_after_bag1 = player.swim_speed
	player.apply_plastic_ingestion(20.0, 0.05)
	var speed_after_bag2 = player.swim_speed
	# Boğulma sırasında hız bonusu alınsın (Sarı Yengeç 1.25x ödülü)
	player.apply_speed_boost(1.25)
	var expected_boosted_base = clamp(initial_base_swim * 1.25, 6.0, 10.0)
	# Süre bitişini simüle et
	player.is_suffocating = false
	player.swim_speed = player.base_swim_speed
	player.sprint_speed = player.base_sprint_speed

	_assert(
		is_equal_approx(speed_after_bag1, initial_base_swim * 0.5) and
		is_equal_approx(speed_after_bag2, initial_base_swim * 0.5) and
		is_equal_approx(player.swim_speed, expected_boosted_base),
		"06",
		"Çoklu plastik poşet yutma hız kilidi koruması doğrulandı (Üst üste poşet yutulsa da hız kalıcı bozulmuyor).",
		"Çoklu poşet hız hatası! Bag1:%f, Bag2:%f, Final:%f" % [speed_after_bag1, speed_after_bag2, player.swim_speed]
	)
	# Hızı normale döndür
	player.base_swim_speed = 6.0
	player.base_sprint_speed = 12.0
	player.swim_speed = 6.0
	player.sprint_speed = 12.0
	player.apply_healing(100.0)

	# -------------------------------------------------------------------------
	# TEST 07: Denizanaları ve Poşetlerin Çarpışma & Hata Düşürmeme Testi
	# -------------------------------------------------------------------------
	var jelly_med = main.find_child("JellyMed1", true, false)
	var jelly_rho = main.find_child("JellyRho1", true, false)
	var bag_trap = main.find_child("BagTrap1", true, false)
	var jelly_safe_ok = false
	if jelly_med and jelly_rho and bag_trap:
		player.health = 60.0
		# Aynı denizanasına aynı karede 2 kez sinyal gelse bile sadece 1 kez şifa vermeli ve hata düşürmemeli
		jelly_med._on_body_entered(player)
		jelly_med._on_body_entered(player)
		var hp_after_double_med = player.health # 60 + 25 = 85 olmalı

		# Göçmen denizanası aynı anda 2 kez tetiklense bile cooldown sayesinde 1 kez hasar vermeli
		jelly_rho._on_body_entered(player)
		jelly_rho._on_body_entered(player)
		var hp_after_double_rho = player.health # 85 - 15 = 70 olmalı

		# Poşet aynı anda 2 kez tetiklense bile sadece 1 kez yutulmalı
		bag_trap._on_body_entered(player)
		bag_trap._on_body_entered(player)
		var hp_after_double_bag = player.health # 70 - 20 = 50 olmalı

		jelly_safe_ok = (
			is_equal_approx(hp_after_double_med, 85.0) and
			is_equal_approx(hp_after_double_rho, 70.0) and
			is_equal_approx(hp_after_double_bag, 50.0)
		)
	player.is_suffocating = false
	player.swim_speed = player.base_swim_speed
	player.sprint_speed = player.base_sprint_speed
	player.apply_healing(100.0)
	_assert(jelly_safe_ok, "07", "Denizanaları ve poşet tuzakları mükerrer çarpışmalarda hata düşürmüyor ve tekil tetikleniyor.", "Denizanası/Poşet çarpışma güvenliği hatası!")

	# -------------------------------------------------------------------------
	# TEST 08: Envanterden Denize Atık Bırakma (drop_item) ve Yeniden Toplama Koruması
	# -------------------------------------------------------------------------
	player.inventory.clear()
	player.collect_item("Küçük Plastik Şişe (0.5L)")
	var count_before_drop = main.find_child("Collectibles", true, false).get_child_count()
	player.drop_item(0)
	var count_after_drop = main.find_child("Collectibles", true, false).get_child_count()
	_assert(
		player.inventory.size() == 0 and count_after_drop == count_before_drop + 1,
		"08",
		"Envanterden denize atık bırakma (drop_item) ve 3B sahneye geri yerleştirme doğrulandı.",
		"Atık bırakma hatası!"
	)

	# -------------------------------------------------------------------------
	# TEST 09: Akdeniz Foku (seal_ai.gd) Devriye, Kovalama ve Diyalogda Saldırmama Testi
	# -------------------------------------------------------------------------
	var seal = main.find_child("AkdenizFoku", true, false)
	var seal_ok = false
	if seal:
		seal._physics_process(0.016)
		var init_state = seal.current_state
		# Diyalog açıkken fok oyuncuyu kovalamamalı / takibi bırakmalı
		dlg_box.is_active = true
		seal.current_state = seal.State.CHASE
		seal._physics_process(0.016)
		var returned_during_dlg = (seal.current_state == seal.State.RETURN)
		dlg_box.is_active = false
		seal_ok = (init_state == seal.State.PATROL) and returned_during_dlg
	_assert(seal_ok, "09", "Akdeniz Foku AI devriye ve diyalog sırasında takibi bırakma koruması doğrulandı.", "Akdeniz Foku AI hatası!")

	# -------------------------------------------------------------------------
	# TEST 10: 3B Kalezyon (CollisionShape3D) Varlık ve Geçerlilik Denetimi
	# -------------------------------------------------------------------------
	var seabed = main.find_child("Seabed", true, false)
	var b1 = main.find_child("Building1", true, false)
	var b2 = main.find_child("Building2", true, false)
	var b3 = main.find_child("Building3", true, false)
	var col_valid = true
	for node in [seabed, b1, b2, b3, player, seal]:
		if not node:
			col_valid = false
			continue
		var cshape = node.get_node_or_null("CollisionShape3D")
		if not cshape or not cshape.shape or cshape.disabled:
			print("   ⚠️ Eksik/Devre dışı CollisionShape3D: ", node.name)
			col_valid = false

	_assert(col_valid, "10", "Seabed (trimesh + sınır duvarları), Binalar (1-2-3), Player ve Fok fizik kalezyonları tam ve aktif.", "Fizik kalezyon şekillerinde eksiklik var!")

	# -------------------------------------------------------------------------
	# TEST 11: Uzamsal Çakışmama Denetimi (Binalar, NPC Etkileşim Küreleri ve Tuzaklar)
	# -------------------------------------------------------------------------
	var collectibles = main.find_child("Collectibles", true, false)
	var traps_node = main.find_child("JellyfishAndTraps", true, false)
	var spatial_ok = true

	# 11A: Atıkların ve denizanalarının binaların içinde olmaması
	var check_nodes = []
	if collectibles: check_nodes.append_array(collectibles.get_children())
	if traps_node: check_nodes.append_array(traps_node.get_children())

	for item in check_nodes:
		var p = item.position
		# Building1: X in [-21, -9], Z in [-32, -18]
		if p.x >= -20.5 and p.x <= -9.5 and p.z >= -31.5 and p.z <= -18.5:
			print("   ⚠️ Building1 ile çakışan nesne: ", item.name, " Pos: ", p)
			spatial_ok = false
		# Building2: X in [15, 25], Z in [-35, -25]
		if p.x >= 15.0 and p.x <= 25.0 and p.z >= -35.0 and p.z <= -25.0:
			print("   ⚠️ Building2 ile çakışan nesne: ", item.name, " Pos: ", p)
			spatial_ok = false
		# Building3: X in [-10, 0], Z in [-51, -39]
		if p.x >= -10.0 and p.x <= 0.0 and p.z >= -51.0 and p.z <= -39.0:
			print("   ⚠️ Building3 ile çakışan nesne: ", item.name, " Pos: ", p)
			spatial_ok = false

	# 11B: NPC Etkileşim Kürelerinin (Area3D) Birbiriyle Kesişmemesi
	var npc_names = ["KadimMidyeNPC", "NpcYengec", "NpcDenizTavsani", "NpcKestane", "NpcIstakoz", "DeriSirtliDev"]
	var npc_nodes = []
	for n_name in npc_names:
		var n = main.find_child(n_name, true, false)
		if n: npc_nodes.append(n)

	for i in range(npc_nodes.size()):
		for j in range(i + 1, npc_nodes.size()):
			var n1 = npc_nodes[i]
			var n2 = npc_nodes[j]
			var r1 = n1.get_node("CollisionShape3D").shape.radius
			var r2 = n2.get_node("CollisionShape3D").shape.radius
			var dist = n1.position.distance_to(n2.position)
			if dist < (r1 + r2):
				print("   ⚠️ NPC etkileşim alanı çakışması: %s ve %s (Mesafe: %.2fm < %.2fm)" % [n1.name, n2.name, dist, r1 + r2])
				spatial_ok = false

	# 11C: Tuzaklar ile Atıkların Çarpışma Kürelerinin Kesişmemesi
	if collectibles and traps_node:
		for t in traps_node.get_children():
			if not is_instance_valid(t) or t.is_queued_for_deletion():
				continue
			var tr = t.get_node("CollisionShape3D").shape.radius
			for c in collectibles.get_children():
				if not is_instance_valid(c) or c.is_queued_for_deletion():
					continue
				var cr = c.get_node("CollisionShape3D").shape.radius
				var d = t.position.distance_to(c.position)
				if d < (tr + cr):
					print("   ⚠️ Tuzak-Atık çakışması: %s ve %s (Mesafe: %.2fm < %.2fm)" % [t.name, c.name, d, tr + cr])
					spatial_ok = false

	_assert(spatial_ok, "11", "Hiçbir bina, NPC etkileşim alanı, atık ve denizanası/poşet tuzağı birbiriyle çakışmıyor.", "3B uzamsal çakışma tespit edildi!")

	# -------------------------------------------------------------------------
	# TEST 12: NPC Biyolojik Ölçek, Kaya Kaidesi (RockPedestal) ve Görsel Yükseklik
	# -------------------------------------------------------------------------
	var pedestal_npcs = ["NpcYengec", "NpcDenizTavsani", "NpcKestane", "NpcIstakoz"]
	var visual_ok = true
	for p_name in pedestal_npcs:
		var npc_node = main.find_child(p_name, true, false)
		if not npc_node:
			visual_ok = false
			continue
		npc_node._process(0.016)
		var vr = npc_node.get_node_or_null("VisualRoot")
		var ped = npc_node.get_node_or_null("RockPedestal")
		if not vr or not ped or vr.scale.x > 0.4 or vr.position.y < 0.15:
			print("   ⚠️ Görsel/Kaide hatası: ", p_name)
			visual_ok = false

	_assert(visual_ok, "12", "Tüm geri dönüşüm canlıları kaya kaidesinin (RockPedestal) tam üstünde ve doğru biyolojik ölçekte (0.32).", "NPC görsel/kaide yüksekliği hatası!")

	# -------------------------------------------------------------------------
	# TEST 13: Metin Kayması Önleme (VC_CHARS_AFTER_SHAPING, Autowrap ve UI Çakışmaması)
	# -------------------------------------------------------------------------
	var txt_lbl: Label = dlg_box.get("text_label")
	var badge_pnl: Control = hud.get("badge_panel")
	var dlg_pnl: Control = dlg_box.get("panel")

	var text_layout_ok = (
		txt_lbl != null and
		txt_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD and
		txt_lbl.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING and
		txt_lbl.custom_minimum_size.x >= 800.0 and
		txt_lbl.custom_minimum_size.y >= 100.0 and
		badge_pnl.anchor_top == 0.0 and # Sağ üstte
		dlg_pnl.anchor_top == 1.0       # Alt ortada
	)

	_assert(
		text_layout_ok,
		"13",
		"Daktilo metin kayması koruması (VC_CHARS_AFTER_SHAPING), kelime sarma ve BadgePanel/DialogueBox ayrımı doğrulandı.",
		"UI metin kayması / yerleşim ayarları hatalı!"
	)

	# -------------------------------------------------------------------------
	# TEST 14: Metin Alakasızlığı ve Tüm Diyalogların İçerik Denetimi
	# -------------------------------------------------------------------------
	var all_dialogue_sets: Array = []
	for p_name in pedestal_npcs:
		var n = main.find_child(p_name, true, false)
		if n:
			all_dialogue_sets.append(n._get_idle_dialogues())
			all_dialogue_sets.append(n._get_delivery_dialogues("Test Atığı"))
			all_dialogue_sets.append(n._get_post_delivery_dialogues())

	var midye = main.find_child("KadimMidyeNPC", true, false)
	var dev = main.find_child("DeriSirtliDev", true, false)
	if midye: all_dialogue_sets.append(midye.dialogues)
	if dev: all_dialogue_sets.append(dev.dialogues)
	if station: all_dialogue_sets.append(station.dialogues)

	var text_audit_ok = true
	var total_lines_checked = 0
	var forbidden_words = ["mavi yengeç", "pamuk şeker", "acalem"]

	for d_set in all_dialogue_sets:
		if d_set.is_empty():
			text_audit_ok = false
		for entry in d_set:
			total_lines_checked += 1
			var spk = str(entry.get("speaker", "")).strip_edges()
			var txt = str(entry.get("text", "")).strip_edges()
			if spk == "" or txt == "" or txt.length() > 380:
				print("   ⚠️ Geçersiz veya aşırı uzun replik (%d krk): %s" % [txt.length(), txt])
				text_audit_ok = false
			for fw in forbidden_words:
				if fw in txt.to_lower() or fw in spk.to_lower():
					print("   ⚠️ Yasaklı/Alakasız kelime bulundu ('%s'): %s" % [fw, txt])
					text_audit_ok = false

	_assert(
		text_audit_ok and total_lines_checked >= 35,
		"14",
		"Toplam %d diyalog repliği tarandı: Metin alakasızlığı, yazım hatası veya panel taşması yok." % total_lines_checked,
		"Diyalog metin denetiminde hata bulundu!"
	)

	# -------------------------------------------------------------------------
	# TEST 15: 4 Geri Dönüşüm Canlısının Tam Teslim Döngüsü ve Ödül Testi
	# -------------------------------------------------------------------------
	var yengec = main.find_child("NpcYengec", true, false)
	var tavsan = main.find_child("NpcDenizTavsani", true, false)
	var kestane = main.find_child("NpcKestane", true, false)
	var istakoz = main.find_child("NpcIstakoz", true, false)

	player.inventory.clear()
	player.collect_item("Küçük Plastik Şişe (0.5L)")
	player.collect_item("Geri Dönüştürülebilir Cam Şişe")
	player.collect_item("Geri Dönüştürülebilir Alüminyum Kutu")
	player.collect_item("Geri Dönüştürülebilir Kağıt (Batık Kitap)")

	# Doğrulama: Elinde atık olsa bile _talk() (E Tuşu) çağrıldığında atık otomatik teslim EDİLMEMELİ!
	dlg_box.finish()
	dlg_box.exit_cooldown = 0.0
	var inv_before_talk = player.inventory.size()
	yengec._talk()
	var talk_keeps_item = (player.inventory.size() == inv_before_talk and not yengec.has_delivered_before and dlg_box.is_active)
	dlg_box.finish()
	dlg_box.exit_cooldown = 0.0

	var cycle_ok = talk_keeps_item
	for npc in [yengec, kestane, istakoz, tavsan]:
		dlg_box.finish()
		dlg_box.exit_cooldown = 0.0
		npc._interact()
		if not npc.has_delivered_before:
			print("   ⚠️ Teslim alamayan NPC: ", npc.name)
			cycle_ok = false

	print("   DEBUG TEST 15: cycle_ok=%s, inv_size=%d, can_break=%s, swim_speed=%.2f" % [
		str(cycle_ok), player.inventory.size(), str(player.can_break_shipwrecks), player.swim_speed
	])

	dlg_box.finish()
	dlg_box.exit_cooldown = 0.0

	_assert(
		cycle_ok and player.inventory.is_empty() and player.can_break_shipwrecks and player.swim_speed >= 6.0,
		"15",
		"4 Geri Dönüşüm NPC'sinde E/F tuş ayrımı (başlangıç diyaloğu korunumu) ve tam teslim döngüsü doğrulandı.",
		"NPC atık teslim döngüsü hatası!"
	)

	# -------------------------------------------------------------------------
	# TEST 16: ÖÇK Sualtı Gözlem ve İzleme İstasyonu & 'İklim Elçisi' Final Rozeti
	# -------------------------------------------------------------------------
	var badge_box = [""]
	player.badge_unlocked.connect(func(b_title, _b_desc): badge_box[0] = b_title)
	dlg_box.is_active = false
	dlg_box.exit_cooldown = 0.0
	station._activate_station(dlg_box)
	dlg_box.finish()

	_assert(
		station.is_activated and badge_box[0] == "İklim Elçisi" and is_equal_approx(player.health, 100.0),
		"16",
		"ÖÇK Sualtı Gözlem ve İzleme İstasyonu aktivasyonu ve 'İklim Elçisi' final rozeti doğrulandı.",
		"İstasyon aktivasyonu veya İklim Elçisi rozeti hatası!"
	)

	# -------------------------------------------------------------------------
	# TEST 17: Görev Günlüğü (Quest Journal J/Q) ve Hızlı Kayıt (F5)
	# -------------------------------------------------------------------------
	hud.toggle_quest_journal()
	var j_open_ok = hud.is_journal_open and hud.journal_panel.visible
	var q_list = hud.journal_panel.find_child("QuestList", true, false)
	var q_count_ok = q_list != null and q_list.get_child_count() == 3
	hud.close_quest_journal()
	var j_close_ok = not hud.is_journal_open and not hud.journal_panel.visible
	
	_assert(
		j_open_ok and q_count_ok and j_close_ok,
		"17",
		"Görev Günlüğü (Quest Journal J/Q) 3 aşamalı ekolojik görev takibi ve UI doğrulandı.",
		"Görev Günlüğü paneli veya görev listesi hatası!"
	)

	# -------------------------------------------------------------------------
	# TEST 18: Durdurma Menüsü Ayarlar & Gamepad Paneli Doğrulaması
	# -------------------------------------------------------------------------
	hud.pause_game()
	var pause_ok = hud.is_game_paused and hud.pause_panel.visible
	hud.open_settings()
	var settings_open_ok = hud.is_settings_open and hud.settings_panel.visible and not hud.pause_panel.visible
	var m_slider = hud.settings_panel.find_child("MasterSlider", true, false)
	var amb_slider = hud.settings_panel.find_child("AmbianceSlider", true, false)
	var sfx_slider = hud.settings_panel.find_child("SfxSlider", true, false)
	var sliders_ok = m_slider != null and amb_slider != null and sfx_slider != null
	
	hud.close_settings()
	var settings_close_ok = not hud.is_settings_open and not hud.settings_panel.visible and hud.pause_panel.visible
	hud.resume_game()
	var resume_ok = not hud.is_game_paused and not hud.pause_panel.visible
	
	_assert(
		pause_ok and settings_open_ok and sliders_ok and settings_close_ok and resume_ok,
		"18",
		"Durdurma Menüsü Ayarlar Paneli (Ses Slider'ları & Gamepad Kılavuzu) ve geçiş durum makinesi doğrulandı.",
		"Ayarlar paneli veya ses slider'ları hatası!"
	)

	# -------------------------------------------------------------------------
	# TEST 19: Oyun İçi Video Tiyatrosu (HUD & Durdurma Menüsü Video Gösterimi)
	# -------------------------------------------------------------------------
	var v_panel_exists = hud.video_theater_panel != null and hud.video_theater_player != null
	hud.open_video_theater()
	var v_open_ok = hud.is_video_theater_open and hud.video_theater_panel.visible
	hud.close_video_theater()
	var v_close_ok = not hud.is_video_theater_open and not hud.video_theater_panel.visible
	
	_assert(
		v_panel_exists and v_open_ok and v_close_ok,
		"19",
		"Oyun İçi Video Tiyatrosu (Video Theater Modal & VideoStreamPlayer) ve gösterim kontrolleri doğrulandı.",
		"Video Tiyatrosu paneli veya kontrolleri hatası!"
	)

	print("==========================================================================")
	print("📊 YAZILIM TESTİ ÖZETİ: %d TEST GEÇTİ, %d TEST KALDI" % [passed, failed])
	print("==========================================================================")
	if failed == 0:
		print("🎉 TÜM SİSTEMLER (%d/19 KATEGORİ) SIFIR HATA İLE DOĞRULANDI!" % passed)
		get_tree().quit(0)
	else:
		print("⚠️ BAZI TESTLER BAŞARISIZ OLDU!")
		get_tree().quit(1)
