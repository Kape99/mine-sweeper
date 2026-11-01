extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://Scenes/Board/square_board.tscn")
	BaseBoard.warm_pool(scene, 2500)

	var board: BaseBoard = scene.instantiate()
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
	push_warning("pool sizes after clear: %s" % str(BaseBoard._cell_pools))

	# second build - fully pooled
	var t2: int = Time.get_ticks_msec()
	board.start_game(50, 50, 500, true)
	var t3: int = Time.get_ticks_msec()
	push_warning("second build: %d ms" % (t3 - t2))

	get_tree().quit()
