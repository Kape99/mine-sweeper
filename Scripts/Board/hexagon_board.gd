class_name HexagonBoard extends BaseBoard


func reset():
	clear()
	var board = []
	for row in rows:
		board.append([])
		for col in cols:
			var cell_instance: CellBase = cells[row % 2].instantiate()
			board_grid.add_child(cell_instance)
			cell_instance.coord = Vector2i(col, row)
			_connect_signals(cell_instance)
			board[row].append(cell_instance)
	board_state = board

func _get_nearby_cells(cell: CellBase, distance: int = 1, cell_list: Dictionary = {}):
	if distance == 0:
		return {cell: false}
	var target_coord: Vector2i = cell.coord
	var target_index: int = cell.get_index()
	for col in range(target_coord.x - 1, target_coord.x + 1 + 1):
		for row in range(target_coord.y - 1, target_coord.y + 1 + 1):
			if not _is_valid(col, row):
				continue
			if Vector2i(col, row) == target_coord:
				# Skip self
				continue
			if target_coord.y != row:
				if target_coord.y % 2 and target_coord.x > col + distance - 1:
					continue
				if not target_coord.y % 2 and target_coord.x < col + distance - 1:
					continue
			cell_list.merge(_get_nearby_cells(board_state[row][col], distance - 1, cell_list))
	return cell_list
