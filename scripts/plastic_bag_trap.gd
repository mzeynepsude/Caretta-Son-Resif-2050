extends Area3D

# Naylon Market Poşeti (Ölümcül Biyolojik Taklit / Plastik Tuzağı)
# Suda dalgalandığında tıpkı şeffaf bir denizanası gibi görünür.
# Caretta poşeti denizanası sanıp yuttuğunda yemek borusundaki kıkırdak dikenlere takılır;
# geri kusamaz, boğulma ve sindirim tıkanması yaşar (-20 HP & Yavaşlama).

@export var damage: float = 20.0
@export var slow_duration: float = 4.5

var base_y: float = 0.0
var time_offset: float = 0.0
var is_ingested: bool = false

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")

func _ready():
	base_y = position.y
	time_offset = randf() * 10.0
	body_entered.connect(_on_body_entered)

func _process(_delta: float):
	if is_ingested:
		return
	var t = Time.get_ticks_msec() * 0.001 + time_offset
	# Akıntıyla dalgalanıp denizanasını taklit etme
	if visual_root:
		visual_root.position.y = sin(t * 1.5) * 0.2
		visual_root.rotation.z = sin(t * 1.1) * 0.15
		visual_root.rotation.x = cos(t * 0.9) * 0.12

func _on_body_entered(body: Node3D):
	if is_ingested:
		return
	if body.is_in_group("player"):
		is_ingested = true
		set_deferred("monitoring", false)
		if body.has_method("apply_plastic_ingestion"):
			body.apply_plastic_ingestion(damage, slow_duration)
		queue_free()

