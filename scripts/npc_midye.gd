extends Area3D

# Kadim Pina (Pinna nobilis) - Akdeniz'in Yerel Kök Salmış Hafızası
# Yalnızca oyuncu yakındayken ve E tuşuna BASTIĞINDA diyaloğu başlatır.

var player_near: bool = false
@onready var shell_top = get_node_or_null("ShellTop")
var base_top_rot_x: float = 0.0

var dialogues = [
	{
		"speaker": "Kadim Pina (Pinna nobilis)",
		"text": "(Kabuğunu hafifçe aralar, derin ve kederli bir nefes alır)\n\"Hoş geldin küçük Caretta... Görüyorsun ya, köklerim bu kumların derinliklerine bağlı. Biz yer değiştiremeyiz. Akdeniz hiç bu kadar kaynamamıştı...\"",
		"color": Color(0.4, 0.85, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Sular gerçekten çok sıcak ve etraf plastiklerle dolu kadim dostum. Neden bu kadar acı çekiyorsun?\"",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"speaker": "Kadim Pina (Pinna nobilis)",
		"text": "\"Deniz suyu sıcaklığı 30 dereceyi aştı. Aşırı sıcak dalgaları ve salgın hastalıklar Akdeniz'deki koca pina kolonilerimizi yok etti. Kaçacak hiçbir yerimiz yok... Eğer bu batık caddelerdeki atıkları temizlersen, deniz tabanı yeniden nefes alabilir.\"",
		"color": Color(0.4, 0.85, 1.0)
	},
	{
		"speaker": "🐢 Caretta",
		"text": "\"Dayan Kadim Pina! Okyanus Kâşifleri ekibimle 'Son Resif'i kurtarmak için buradayız. ÖÇK Sualtı Gözlem ve İzleme İstasyonu'na ulaşıp Akdeniz'i yeniden serin ve temiz sulara kavuşturacağım!\"",
		"color": Color(0.3, 1.0, 0.5)
	}
]

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if shell_top:
		base_top_rot_x = shell_top.rotation.x

func _process(_delta: float):
	# Kadim Midye'nin canlı gibi hafifçe nefes alıp vermesi (kabuk salınımı & deniz suyu filtrasyonu)
	var t = Time.get_ticks_msec() * 0.001
	if shell_top:
		shell_top.rotation.x = base_top_rot_x + (sin(t * 1.5) + 0.3) * 0.08
	# Dip akıntısıyla hafif organik salınım
	rotation.z = sin(t * 1.0) * 0.03

func _unhandled_input(event):
	# Sadece oyuncu yakındayken ve E tuşuna veya Gamepad (A) tuşuna basıldığında tetiklenir
	if not player_near:
		return
		
	var is_interact_action = false
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		is_interact_action = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		is_interact_action = true

	if is_interact_action:
		var hud = get_tree().root.find_child("DialogueBox", true, false)
		if hud and not hud.is_active and hud.exit_cooldown <= 0.0:
			get_viewport().set_input_as_handled()
			var hint = get_tree().root.find_child("InteractHint", true, false)
			if hint:
				hint.visible = false
			hud.start_dialogue(dialogues, "Akdeniz'in Hafızası", "Kadim Pina'dan yerel Akdeniz sıcak dalgasını ve kolonilerin yok oluşunu dinledin.")

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_near = true
		update_hint()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_near = false
		var hint = get_tree().root.find_child("InteractHint", true, false)
		if hint and hint.text.find("Pina") != -1:
			hint.visible = false

func update_hint():
	var hint = get_tree().root.find_child("InteractHint", true, false)
	var hud = get_tree().root.find_child("DialogueBox", true, false)
	if hint:
		var dialog_open = hud and hud.is_active
		if player_near and not dialog_open:
			hint.text = "💬 [E / F / (A)] Kadim Pina ile Konuş"
			hint.visible = true
		else:
			hint.visible = false
