extends SceneTree

func _init():
	var scene = load("res://scenes/school_fish.tscn")
	var inst = scene.instantiate()
	root.add_child(inst)
	
	print("--- Inspecting SchoolFish Children ---")
	for child in inst.get_children():
		print("Child:", child.name, "Type:", child.get_class(), "Scale:", child.scale)
		# find mesh instances
		var meshes = child.find_children("*", "MeshInstance3D", true, false)
		for m in meshes:
			if m.mesh:
				var aabb = m.mesh.get_aabb()
				print("  Mesh:", m.name, "AABB size:", aabb.size, "Global Trans Scale:", m.global_transform.basis.get_scale())
	quit(0)

