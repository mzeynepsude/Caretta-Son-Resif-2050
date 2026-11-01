extends Node3D

# CARETTA: SON RESİF 2050 - Mercan Renk ve Biyolojik Çeşitlilik Yöneticisi (Coral Tint & Variety)
# Akdeniz mercan türlerinin doğal renk çeşitliliğini (altın, mor, zümrüt, kızıl, lavanta) dinamik uygular.

@export var tint_color: Color = Color.WHITE
@export var emission_color: Color = Color.BLACK
@export var emission_energy: float = 0.0

func _ready():
	if tint_color == Color.WHITE and emission_color == Color.BLACK:
		return
		
	_apply_tint_to_children(self)

func _apply_tint_to_children(node: Node):
	if node is MeshInstance3D:
		var count = node.get_surface_override_material_count()
		# Eğer override yoksa mesh'in kendi materyallerini çoğaltıp renklendir
		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var orig_mat = node.get_active_material(i)
			if orig_mat is StandardMaterial3D:
				var new_mat = orig_mat.duplicate()
				new_mat.albedo_color = orig_mat.albedo_color * tint_color
				if emission_energy > 0.0 or emission_color != Color.BLACK:
					new_mat.emission_enabled = true
					new_mat.emission = emission_color
					new_mat.emission_energy_multiplier = emission_energy
				node.set_surface_override_material(i, new_mat)
				
	for child in node.get_children():
		_apply_tint_to_children(child)

