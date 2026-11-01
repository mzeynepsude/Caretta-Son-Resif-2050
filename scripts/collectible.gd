extends Area3D

# Toplanabilir Plastik / Atık (Geri Dönüşüm Parçası)
@export var item_name: String = "Plastik Ağ Artığı"
var can_be_collected: bool = true

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta: float):
	# Su altı salınımı ve dönüş efekti
	rotate_y(1.5 * delta)
	position.y += sin(Time.get_ticks_msec() * 0.003) * 0.005

func _on_body_entered(body: Node3D):
	if not can_be_collected:
		return
	if body.is_in_group("player") and body.has_method("collect_item"):
		if body.has_method("can_collect_item") and not body.can_collect_item():
			var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
			if tree and tree.root:
				var hud = tree.root.find_child("HUD", true, false)
				if hud and hud.has_method("show_screen_heal_alert"):
					hud.show_screen_heal_alert("⚠️ Envanter Dolu! (Maksimum 15/15 Atık)")
			return
		can_be_collected = false
		set_deferred("monitoring", false)
		if get_tree().root.has_node("AudioManager"):
			get_tree().root.get_node("AudioManager").play_sfx("pickup", 0.1)
		body.collect_item(item_name)
		queue_free()
