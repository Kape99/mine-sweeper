class_name SquareBoard
extends BaseBoard


func _get_nearby_cells(cell: CellBase, distance: int = 1) -> Dictionary:
	var result: Dictionary = {}
	var origin: Vector2i = cell.coord
	for col: int in range(origin.x - distance, origin.x + distance + 1):
		for row: int in range(origin.y - distance, origin.y + distance + 1):
			if col == origin.x and row == origin.y:
				continue
			if _wrap_mode:
				var wcol: int = posmod(col, cols)
				var wrow: int = posmod(row, rows)
				if board_state.is_empty():
					continue
				result[board_state[wrow][wcol]] = false
			else:
				if col < 0 or col >= cols or row < 0 or row >= rows:
					continue
				if board_state.is_empty():
					continue
				result[board_state[row][col]] = false
	return result
