extends Area3D

# Sıcak Su / Termal Şok Bölgesi (Termal Ağartma Tehlikesi)
# Küresel ısınma nedeniyle aşırı ısınan dip suları Caretta'nın kabuğuna ve enerjisine zarar verir.

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and "in_hot_zone" in body:
		body.in_hot_zone = true
		print("DİKKAT: Aşırı sıcak su dalgasına girdin! Hızlıca uzaklaş.")

func _on_body_exited(body: Node3D):
	if body.is_in_group("player") and "in_hot_zone" in body:
		body.in_hot_zone = false
		print("Güvenli soğuk akıntıya döndün.")
