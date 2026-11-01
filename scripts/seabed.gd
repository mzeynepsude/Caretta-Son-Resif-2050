extends StaticBody3D

# Akdeniz Dalgalı Kum Tabanı ve Fiziksel Çarpışma Sınırları (World Boundaries)
# 1. Dalgalı ve jeolojik kum tepelerine uyan trimesh çarpışma gövdesi oluşturur.
# 2. Sınırı kumun dalgalı halinin en alt seviyesinin hemen altına kaydırarak
#    oyuncunun ve nesnelerin kuma tam oturmasını ve kumun görünürlüğünün engellenmemesini sağlar.
# 3. Çevre sınırlarıyla oyuncunun harita dışına çıkmasını önler.

@export var create_boundary_walls: bool = true

func _ready():
	# Dalgalı kum zeminine uyan çarpışma gövdesi oluştur
	var col = get_node_or_null("CollisionShape3D")
	var mi = get_node_or_null("MeshInstance3D")
	if mi and mi.mesh and col and not col.shape:
		col.shape = mi.mesh.create_trimesh_shape()
		# Çarpışma sınırını dalgalı kumun en alt taban seviyesine (hafifçe altına) indiriyoruz
		col.position.y = -0.2

	# Harita dışına çıkmayı engelleyen görünmez sınırlar
	if create_boundary_walls:
		_create_invisible_barriers()

func _create_invisible_barriers():
	# Tavan (Su yüzeyi sınırı - Y: 41.5, su seviyesi +20-25m yükseltildi)
	_add_box_wall(Vector3(0, 41.5, 0), Vector3(350, 4, 350))
	# Taban güvenlik tabakası (Kumun alt noktası - Y: -8.5)
	_add_box_wall(Vector3(0, -8.5, 0), Vector3(350, 3, 350))
	# Doğu sınırı (+X: 110, Y: 18'de 100m yükseklik koruması)
	_add_box_wall(Vector3(110, 18, 0), Vector3(4, 100, 350))
	# Batı sınırı (-X: -140) -> Son Resif için batı koridoru genişletildi
	_add_box_wall(Vector3(-140, 18, 0), Vector3(4, 100, 350))
	# Güney sınırı (+Z: 110)
	_add_box_wall(Vector3(0, 18, 110), Vector3(350, 100, 4))
	# Kuzey sınırı (-Z: -110)
	_add_box_wall(Vector3(0, 18, -110), Vector3(350, 100, 4))

func _add_box_wall(pos: Vector3, size: Vector3):
	var wall_col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	wall_col.shape = box_shape
	wall_col.position = to_local(pos)
	add_child(wall_col)
