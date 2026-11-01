extends Node

func _ready() -> void:
	var cell_scene: PackedScene = load("res://Scenes/Cells/square_cell.tscn")
	var root: Node2D = Node2D.new()
	root.name = "Square50x50"

	var grid: GridContainer = GridContainer.new()
	grid.name = "GridContainer"
	grid.columns = 50
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)
	grid.owner = root

	for i: int in 2500:
		var cell: CellBase = cell_scene.instantiate()
		cell.name = "Cell_%d" % i
		grid.add_child(cell)
		cell.owner = root

	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	var err: Error = ResourceSaver.save(ps, "res://Scenes/Board/square_50x50.tscn")
	if err == OK:
		print("saved square_50x50.tscn")
	else:
		print("save failed: %d" % err)
	root.free()
	get_tree().quit()
