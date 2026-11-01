extends Node

func _ready():
	print("--- TEST LOADING FISH GLTFS ---")
	var paths = [
		"res://assets/fish/perch_mediterranean/scene.gltf",
		"res://assets/fish/wrasse_thalassoma/scene.gltf",
		"res://assets/fish/wrasse_symphodus/scene.gltf",
		"res://assets/fish/sargos_striped/scene.gltf"
	]
	for p in paths:
		var res = load(p)
		if not res:
			print("FAILED TO LOAD:", p)
			continue
		var inst = res.instantiate()
		print("\nLoaded:", p)
		print_tree_recurse(inst, "  ")
	
	print("\n--- TEST LOADING school_fish.tscn ---")
	var sf = load("res://scenes/school_fish.tscn").instantiate()
	add_child(sf)
	print("Instantiated school_fish.tscn successfully")
	print_tree_recurse(sf, "  ")
	
	get_tree().quit(0)

func print_tree_recurse(node: Node, indent: String):
	var extra = ""
	if node is MeshInstance3D:
		extra = " [MeshInstance3D mesh=" + str(node.mesh != null) + " mat_override=" + str(node.material_override != null) + "]"
		if node.mesh:
			extra += " AABB=" + str(node.mesh.get_aabb())
	elif node is AnimationPlayer:
		extra = " [AnimationPlayer anims=" + str(node.get_animation_list()) + "]"
	print(indent + node.name + " (" + node.get_class() + ")" + extra + " pos=" + str(node.position) + " scale=" + str(node.scale) + " vis=" + str(node.visible if "visible" in node else "N/A"))
	for c in node.get_children():
		print_tree_recurse(c, indent + "  ")

