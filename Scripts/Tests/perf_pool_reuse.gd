extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://Scenes/Board/square_board.tscn")
	var board: BaseBoard = scene.instantiate()
	# Warm the pools with the board's *cell* scenes (not the board scene)
	# before the board's own _ready() pre-warms a smaller pool.
	for cell_scene: PackedScene in board.cells:
		BaseBoard.warm_pool(cell_scene, 2500)

	add_child(board)
	await get_tree().process_frame

	# first build - uses warmed pool
	var t0: int = Time.get_ticks_msec()
	board.start_game(50, 50, 500, true)
	var t1: int = Time.get_ticks_msec()
	push_warning("first build: %d ms" % (t1 - t0))

	# return cells to pool
	board.clear()
	await get_tree().process_frame
	var sizes: Dictionary = {}
	for path: String in BaseBoard._cell_pools:
		sizes[path] = BaseBoard._cell_pools[path].size()
	push_warning("pool sizes after clear: %s" % str(sizes))

	# second build - fully pooled
	var t2: int = Time.get_ticks_msec()
	board.start_game(50, 50, 500, true)
	var t3: int = Time.get_ticks_msec()
	push_warning("second build: %d ms" % (t3 - t2))

	board.free()
	BaseBoard.clear_pools()
	get_tree().quit()
