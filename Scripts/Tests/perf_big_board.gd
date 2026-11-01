extends Node

func _ready() -> void:
	var board: BaseBoard = load("res://Scenes/Board/square_board.tscn").instantiate()
	add_child(board)
	await get_tree().process_frame

	var cols: int = 50
	var rows: int = 50
	var mines: int = 500
	var t0: int = Time.get_ticks_msec()
	board.start_game(cols, rows, mines, true)
	var t1: int = Time.get_ticks_msec()
	print("build time: %d ms, total nodes: %d" % [t1 - t0, count_nodes(board)])
	get_tree().quit()

func count_nodes(node: Node) -> int:
	var n: int = 1
	for child in node.get_children():
		n += count_nodes(child)
	return n
