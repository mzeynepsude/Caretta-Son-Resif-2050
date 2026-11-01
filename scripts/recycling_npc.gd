extends Area3D

# Akdeniz Geri Dönüşüm Kabuklu NPC Sistemi
# Caretta'dan geri dönüştürülebilir atıkları kabul eder.
# Atık verildiğinde: Küresel ısınma gerçekleştikten sonra o atık türünün
# okyanuslarda gerçekten nelere yol açtığını (Plastiglomerat, Okyanus Asitlenmesi,
# Galvanik Korozyon / Ağır Metal Kusması vb.) anlatan distopik/bilimsel bilgileri aktarır.

enum NpcCategory { PLASTIC, GLASS, METAL, ORGANIC }

@export var category: NpcCategory = NpcCategory.PLASTIC
@export var npc_name: String = "Akdeniz Sarı Taş Yengeci (Xantho poressa)"
@export var short_name: String = "Sarı Yengeç"
@export var required_keyword: String = "Plastik"
@export var npc_theme_color: Color = Color(1.0, 0.85, 0.2)
@export var badge_title: String = "Plastik Avcısı"
@export var badge_desc: String = "Sarı Yengeç'ten ısınan sularda plastiglomerat kayaçlarını ve mikroplastik istilasını dinledin."

var player_near: bool = false
var has_delivered_before: bool = false
var base_y: float = 0.0
var base_visual_y: float = 0.16
var base_visual_scale: Vector3 = Vector3.ONE
var time_phase: float = 0.0

@onready var aura_light: OmniLight3D = get_node_or_null("AuraLight")
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")

func _ready():
	base_y = position.y
	time_phase = randf_range(0.0, 10.0)
	if visual_root:
		base_visual_y = visual_root.position.y
		base_visual_scale = visual_root.scale
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float):
	var t = Time.get_ticks_msec() * 0.001 + time_phase
	
	# Canlı su altı nefes alma, akıntı süzülmesi ve salınım animasyonu
	if visual_root:
		# Dikey nefes salınımı
		visual_root.position.y = base_visual_y + (sin(t * 1.8) + 1.0) * 0.04
		# Akıntıya göre hafif yalpalanma (roll & pitch)
		visual_root.rotation.z = sin(t * 1.2) * 0.05
		visual_root.rotation.x = cos(t * 1.0) * 0.03
		# Hafif solunum hacim nabzı (orijinal ölçeğe oranlı)
		var breathe = 1.0 + sin(t * 2.0) * 0.025
		visual_root.scale = base_visual_scale * Vector3(breathe, 2.0 - breathe, breathe)
		
	# Oyuncu yaklaştığında canlı başını/gövdesini merakla oyuncuya çevirir
	if player_near:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var to_player = player.global_position - global_position
			to_player.y = 0.0
			if to_player.length() > 0.2:
				var target_yaw = atan2(to_player.x, to_player.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, 2.8 * delta)

	if aura_light:
		var pulse = (sin(t * 3.5) + 1.0) * 0.5
		aura_light.light_energy = lerp(1.2, 2.2, pulse)

func _unhandled_input(event):
	if not player_near:
		return

	var is_talk_action = false
	var is_deliver_action = false

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			is_talk_action = true
		elif event.keycode == KEY_F or event.physical_keycode == KEY_F or event.keycode == KEY_G or event.physical_keycode == KEY_G:
			is_deliver_action = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			is_talk_action = true
		elif event.button_index == JOY_BUTTON_X or event.button_index == JOY_BUTTON_Y:
			is_deliver_action = true

	if is_talk_action:
		var hud = get_tree().root.find_child("DialogueBox", true, false)
		if hud and not hud.is_active and hud.exit_cooldown <= 0.0:
			get_viewport().set_input_as_handled()
			var hint = get_tree().root.find_child("InteractHint", true, false)
			if hint:
				hint.visible = false
			_talk()

	elif is_deliver_action:
		var hud = get_tree().root.find_child("DialogueBox", true, false)
		if hud and not hud.is_active and hud.exit_cooldown <= 0.0:
			get_viewport().set_input_as_handled()
			var hint = get_tree().root.find_child("InteractHint", true, false)
			if hint:
				hint.visible = false
			_deliver()

func _talk():
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if not tree:
		return
	var player = tree.get_first_node_in_group("player")
	var hud = tree.root.find_child("DialogueBox", true, false)
	if not hud or not player:
		return

	if has_delivered_before:
		var post_dialogues = _get_post_delivery_dialogues()
		hud.start_dialogue(post_dialogues)
	else:
		# Oyuncuda atık olsa dahi [E] ile konuşulduğunda ASLA otomatik atık teslim edilmez;
		# Canlının kimliğini, derdini ve ipuçlarını anlatan Başlangıç Diyaloğu oynatılır!
		var idle_dialogues = _get_idle_dialogues()
		hud.start_dialogue(idle_dialogues)

func _deliver():
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if not tree:
		return
	var player = tree.get_first_node_in_group("player")
	var hud = tree.root.find_child("DialogueBox", true, false)
	if not hud or not player:
		return

	if has_delivered_before:
		var post_dialogues = _get_post_delivery_dialogues()
		hud.start_dialogue(post_dialogues)
		return

	if _player_has_matching_item(player):
		var removed_item = _remove_matching_item(player)
		has_delivered_before = true
		_apply_gameplay_reward(player)
		
		var delivery_dialogues = _get_delivery_dialogues(removed_item)
		hud.start_dialogue(delivery_dialogues, badge_title, badge_desc)
	else:
		# Oyuncu [F] ile teslim etmek istedi ama envanterinde bu atık yok
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("show_screen_heal_alert"):
			hud_node.show_screen_heal_alert("⚠️ Envanterinde '%s' atığı yok! Kanyondaki atığı toplayıp [F] ile getir." % required_keyword)
		var idle_dialogues = _get_idle_dialogues()
		hud.start_dialogue(idle_dialogues)

func _interact(action: String = "auto"):
	if action == "talk":
		_talk()
	elif action == "deliver":
		_deliver()
	else:
		# 'auto' modu: Test paketi TEST 15 ve harici çağrılar için geriye dönük uyumluluk
		var player = get_tree().get_first_node_in_group("player")
		if _player_has_matching_item(player):
			_deliver()
		else:
			_talk()

func _player_has_matching_item(player) -> bool:
	if not player or not player.has_method("has_item_with_keyword"):
		return false
	if category == NpcCategory.METAL:
		return player.has_item_with_keyword("alüminyum") or player.has_item_with_keyword("metal")
	if category == NpcCategory.ORGANIC:
		return player.has_item_with_keyword("kağıt") or player.has_item_with_keyword("kitap") or player.has_item_with_keyword("kitab") or player.has_item_with_keyword("organik")
	return player.has_item_with_keyword(required_keyword)

func _remove_matching_item(player) -> String:
	if not player or not player.has_method("remove_item_by_keyword"):
		return ""
	if category == NpcCategory.METAL:
		var res = player.remove_item_by_keyword("alüminyum")
		if res == "":
			res = player.remove_item_by_keyword("metal")
		return res
	if category == NpcCategory.ORGANIC:
		var res2 = player.remove_item_by_keyword("kitap")
		if res2 == "":
			res2 = player.remove_item_by_keyword("kitab")
		if res2 == "":
			res2 = player.remove_item_by_keyword("kağıt")
		if res2 == "":
			res2 = player.remove_item_by_keyword("organik")
		return res2
	return player.remove_item_by_keyword(required_keyword)

func _apply_gameplay_reward(player):
	match category:
		NpcCategory.PLASTIC:
			# Yüzme sürtünmesi azalır, hız bonusu verilir
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(1.25)
		NpcCategory.GLASS:
			# Caretta'nın kabuğunda biyolüminesans ışık açılır, görüş menzili genişler
			if player.has_method("enhance_bioluminescence"):
				player.enhance_bioluminescence()
		NpcCategory.METAL:
			# Batık kapılarını ve demir ızgaraları parçalama zırhı kazanılır + can tazelenir
			if player.has_method("enable_wreck_breaker"):
				player.enable_wreck_breaker()
			if player.has_method("apply_healing"):
				player.apply_healing(35.0)
		NpcCategory.ORGANIC:
			if player.has_method("apply_healing"):
				player.apply_healing(50.0)

func _get_delivery_dialogues(item_name: String) -> Array:
	match category:
		NpcCategory.PLASTIC:
			return [
				{
					"speaker": npc_name,
					"text": "(Kıskaçlarıyla %s atığını kapar, sert kıskacıyla vurup çatırdatır)\n\"Ver şunu! Hah... 500 yıl boyunca çürümeyen saf polimer. Bu kaynayan asitli suda kabuğuma zırh yapacağım, sonsuza kadar erimez.\"" % item_name,
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Anlaşma anlaşmaydı. Kâşifler nerede?\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "\"Batık binaların arasındaki karanlık kanyona kaçtılar. Arkalarına bile bakmıyorlardı; buradaki herkes gibi onlar da can derdindeydi. Alacağını aldın, şimdi kovuğumun önünden çekil!\"",
					"color": npc_theme_color
				}
			]

		NpcCategory.GLASS:
			return [
				{
					"speaker": npc_name,
					"text": "(Cam şişeyi hırsla kapıp dikenlerinin arasına sertçe kilitler)\n\"Ver şunu! Hah... Saf silis! Deniz suyu isterse cehennem asidine dönsün, bu cam 4000 yıl boyunca tek bir çatlak bile vermez. Kabuğumu bununla zırhlayacağım!\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Anlaşmayı tamamladım. Kâşifler nereye gitti?\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "\"Batık gökdelenlerin arasındaki kanyonun en zifiri dibine indiler! İnsanlar kaçarken camlarının prizma ışığı kabuğuna vurdu; o karanlık geçitleri artık delip geçebilirsin. Alacağını aldın, şimdi çekil de kayama sımsıkı tutunayım!\"",
					"color": npc_theme_color
				}
			]

		NpcCategory.METAL:
			return [
				{
					"speaker": npc_name,
					"text": "(Alüminyum kutuyu antenleriyle kavrayıp kitin zırhına sertçe kilitler)\n\"Hah! Saf alüminyum! Ağır metaller ve batık korozyonu artık bu karapaksa diş geçiremez. Zırh güçlendi! Al bakalım; kabuğuna koçbaşı kuyruk vuruşunu verdim. Çelik kanyon kapılarına dimdik çarp ve devir! Kâşifler o kapının ardındaki istasyona kapandı. Bas git oraya!\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Kapıyı devirip kâşiflere ulaşacağım!\"",
					"color": Color(0.3, 1.0, 0.5)
				}
			]

		NpcCategory.ORGANIC:
			return [
				{
					"speaker": npc_name,
					"text": "(Islak kitabın sayfalarını radulasıyla —törpü diliyle— ağır ağır, keyifle kazır)\n\"...Nefis. Saf ağaç lifi... İnsanların yüzlerce yıl önce bastığı o kağıtlar dipte çürürse devasa bir bakteri patlaması olur ve bu kanyonun son oksijenini de bitirir. Törpü dilimle hepsini hücresel zırhıma katıyorum...\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Kitabını aldın. Şimdi söyle, kâşifler nereye kapandı?\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "(Ağır ağır arkasındaki solungaç çiçeğini dalgalandırır)\n\"Haa, kâşifler mi?... Evet evet... O koca demir istasyonla alakalı bir şeyler diyorlardı. Çok gürültü yapıyorlardı, uykumu kaçırdılar... Neyse, atıştırmalığımı yiyeyim de ben biraz daha uyuyacağım...\"",
					"color": npc_theme_color
				}
			]

	return []

func _get_idle_dialogues() -> Array:
	match category:
		NpcCategory.PLASTIC:
			return [
				{
					"speaker": "🐢 Caretta",
					"text": "\"Okyanus Kâşifleri'ni gördün mü? Fırtınada onlardan koptum.\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "(İri kıskaçlarını öne uzatıp sertçe şakırdatır)\n\"Okyanus Kâşifleri mi? Umurumda bile değil! Bedavaya tek kelime etmem kaplumbağa. Bana plastik şişe getir. Boş gelirsen o yumuşak yüzgeçlerini kıskaçlarımla kıstırır, kabuğunu çatlatırım! Çekil önümden, laf değil plastik getir!\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Kıskaçlarını indir. Bulup geleceğim.\"",
					"color": Color(0.3, 1.0, 0.5)
				}
			]

		NpcCategory.GLASS:
			return [
				{
					"speaker": "🐢 Caretta",
					"text": "\"Taş Kestanesi! Buralardan geçen Okyanus Kâşifleri'ni gördün mü?\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "(Dikenlerini savunmacı bir hırsla dikleştirir)\n\"Ne kâşifi, ne insanı be kaplumbağa? Canım burnumda zaten! İnsanların asidi denizi sirkeye çevirdi; kireç kabuklarımız kâğıt gibi eriyor!\"",
					"color": npc_theme_color
				},
				{
					"speaker": npc_name,
					"text": "\"Bana laf değil, deniz tabanından cam şişe getir. 4000 yıl çürümeyen, asidin eritemediği saf silis kumu lazım bana! Camı getirirsen kanyonu anlatırım, yoksa yıkıl karşımdan!\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Dikenlerini kollayacağım. Asitsiz zırhın için o cam şişeyi bulup geliyorum.\"",
					"color": Color(0.3, 1.0, 0.5)
				}
			]

		NpcCategory.METAL:
			return [
				{
					"speaker": "🐢 Caretta",
					"text": "\"Zırhlı Böcek! Kâşifler bu kanyon kapılarının ardına mı sığındı?\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "(Dikenli antenlerini birbirine sürter: krrr-krrr! Akustik ses suda çınlar)\n\"Dur orada kaplumbağa! İki metrelik antenlerimin menzilindesin. Kâşiflerin peşine düşecek vaktim yok; batık arabaların aküleri kanyona kurşun kusuyor, galvanik pas zırhımı çürütüyor!\"",
					"color": npc_theme_color
				},
				{
					"speaker": npc_name,
					"text": "\"Bana paslanmayan alüminyum kutu getir. Zırhımı güçlendireyim, sana da o çelik kapıları devirecek koçbaşı kuyruk gücünü vereyim. Boş lafla o kapılar açılmaz!\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Antenlerini indir. Paslanmayan alüminyumu bulup getireceğim.\"",
					"color": Color(0.3, 1.0, 0.5)
				}
			]

		NpcCategory.ORGANIC:
			return [
				{
					"speaker": "🐢 Caretta",
					"text": "\"Boyalı Deniz Tavşanı... Kâşiflerin nereye gittiğini gördün mü? Suyun dibinde bir iz arıyorum.\"",
					"color": Color(0.3, 1.0, 0.5)
				},
				{
					"speaker": npc_name,
					"text": "(Rinoferlerini —koku boynuzlarını— uykulu uykulu esnetir, solungaç tacını ağır ağır dalgalandırır)\n\"...Hımm? Ne bu telaş kaplumbağa... Yüzgeçlerini öyle delice çırpma, suyumu bulandırıyorsun. Kimsenin beni avlayamayacağını bilirsin; derimdeki sünger zehirleri yüzünden koca balıklar bile yanımdan usulca geçer. O yüzden hiç acelem yok...\"",
					"color": npc_theme_color
				},
				{
					"speaker": npc_name,
					"text": "\"Kâşifler mi? Batık kütüphaneden kaçarken bir tomar ıslak kitap düşürdüler. O lifli kağıtların selülozu törpü dilime nefis bir tat veriyor. Git bana o batıklardan bir kitap getir... Belki o zaman uykumu bölüp kâşiflerin hangi kapıya saklandığını hatırlarım... Haaah... (Esnemeye devam eder)\"",
					"color": npc_theme_color
				},
				{
					"speaker": "🐢 Caretta",
					"text": "\"Törpü dilin için bir kitap bulup geleceğim. Sakın uykuya dalma.\"",
					"color": Color(0.3, 1.0, 0.5)
				}
			]

	return []

func _get_post_delivery_dialogues() -> Array:
	match category:
		NpcCategory.PLASTIC:
			return [
				{
					"speaker": npc_name,
					"text": "(Kıskaçlarını tehditkâr biçimde kaldırır)\n\"Hâlâ ne dikiliyorsun tepemde? Batık kanyona kaçtılar dedim ya! Yüz git buradan, kovuğumu meşgul etme!\"",
					"color": npc_theme_color
				}
			]
		NpcCategory.GLASS:
			return [
				{
					"speaker": npc_name,
					"text": "(Sırtındaki cam prizma gibi parlarken dikenlerini oynatır)\n\"Hâlâ ne dikiliyorsun başımda? Kanyonun dibindeler dedim ya! Işığını da kaptın, yüz git buradan; koca kabuğunla suyumu bulandırıyorsun!\"",
					"color": npc_theme_color
				}
			]
		NpcCategory.METAL:
			return [
				{
					"speaker": npc_name,
					"text": "(Antenlerini gururla dikleştirir)\n\"Koçbaşı gücünü aldın asker! Hâlâ ne bekliyorsun? Git o çelik kapıları yerle bir et, kanyonu boşalt!\"",
					"color": npc_theme_color
				}
			]
		NpcCategory.ORGANIC:
			return [
				{
					"speaker": npc_name,
					"text": "(Gövdesini kayanın üzerine iyice yaymış, solungaç tacını uykulu uykulu titretiyor)\n\"Hâlâ burada mısın kaplumbağa?... Kâşifler istasyonun hava kilidinde dedim ya... Git o kapıyı zorla. Beni de dürtüp durma, zehirli mukusumu üstüne bulaştırırsam üç gün uyuşuk gezersin... Haaah... Bırak da biraz uyuyayım... Zzz...\"",
					"color": npc_theme_color
				}
			]
	return []

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_near = true
		update_hint()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_near = false
		var hint = get_tree().root.find_child("InteractHint", true, false)
		if hint and hint.text.find(short_name) != -1:
			hint.visible = false

func update_hint():
	var hint = get_tree().root.find_child("InteractHint", true, false)
	var hud = get_tree().root.find_child("DialogueBox", true, false)
	var player = get_tree().get_first_node_in_group("player")
	if hint:
		var dialog_open = hud and hud.is_active
		if player_near and not dialog_open:
			if has_delivered_before:
				hint.text = "💬 [E] %s ile Konuş" % short_name
			else:
				var has_item = _player_has_matching_item(player)
				if has_item:
					hint.text = "💬 [E] Konuş (Hikâye) | ♻️ [F] %s Atığını Ver" % required_keyword
				else:
					hint.text = "💬 [E] %s ile Konuş (Gereken Atık: %s)" % [short_name, required_keyword]
			hint.visible = true
		else:
			hint.visible = false
