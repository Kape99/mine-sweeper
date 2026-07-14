class_name SquareBoard extends BaseBoard


func reset():
	clear()
	var board = []
	for row in rows:
		board.append([])
		for col in cols:
			var cell_instance: CellBase = cells[0].instantiate()
			board_grid.add_child(cell_instance)
			cell_instance.coord = Vector2i(col, row)
			_connect_signals(cell_instance)
			board[row].append(cell_instance)
	board_state = board


func _get_nearby_cells(cell: CellBase, distance: int = 1, _cell_list: Dictionary = {}) -> Dictionary:
	# Iterative: collect all unique cells within Manhattan-Chebyshev distance
	var result: Dictionary = {}
	var origin: Vector2i = cell.coord
	for col in range(origin.x - distance, origin.x + distance + 1):
		for row in range(origin.y - distance, origin.y + distance + 1):
			if not _is_valid(col, row):
				continue
			if col == origin.x and row == origin.y:
				continue
			result[board_state[row][col]] = false
	return result
