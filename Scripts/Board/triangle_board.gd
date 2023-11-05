class_name TriangleBoard extends BaseBoard


func reset():
	clear()
	var board = []
	for row in rows:
		board.append([])
		for col in cols:
			var cell_istance: CellBase = cells[(col + row * cols) % cells.size()].instantiate()
			board_grid.add_child(cell_istance)
			cell_istance.coord = Vector2i(col, row)
			cell_istance.connect("cell_pressed", _on_cell_pressed)
			board[row].append(cell_istance)
	board_state = board


func _get_nearby_cells(cell: CellBase, distance: int = 1):
	var target_coord: Vector2i = cell.coord
	var target_index: int = cell.get_index()
	var nearby_cells = []
	for col in range(target_coord.x - 2 * distance, target_coord.x + 2 * distance + 1):
		for row in range(target_coord.y - distance, target_coord.y + distance + 1):
			if not _is_valid(col, row):
				continue
			if Vector2i(col, row) == target_coord:
				# Skip self
				continue
			if col + 1 < target_coord.x or col - 1 > target_coord.x:
				if row < target_coord.y and not target_index % 2:
					continue
				elif row > target_coord.y and target_index % 2:
					continue
			nearby_cells.append(board_state[row][col])
	return nearby_cells
