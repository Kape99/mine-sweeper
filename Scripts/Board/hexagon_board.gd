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


func _get_nearby_cells(cell: CellBase, distance: int = 1, _cell_list: Dictionary = {}) -> Dictionary:
	# Iterative BFS ring expansion for hex grid
	var result: Dictionary = {}
	var visited: Dictionary = {cell.coord: true}
	var current_ring: Array = [cell.coord]

	for _d in distance:
		var next_ring: Array = []
		for coord in current_ring:
			for neighbor_coord in _hex_neighbors(coord):
				if visited.has(neighbor_coord):
					continue
				if not _is_valid(neighbor_coord.x, neighbor_coord.y):
					continue
				visited[neighbor_coord] = true
				next_ring.append(neighbor_coord)
				result[board_state[neighbor_coord.y][neighbor_coord.x]] = false
		current_ring = next_ring
	return result


func _hex_neighbors(coord: Vector2i) -> Array:
	# Offset coordinates: even rows shift left, odd rows shift right
	if coord.y % 2 == 0:
		return [
			Vector2i(coord.x - 1, coord.y - 1), Vector2i(coord.x, coord.y - 1),
			Vector2i(coord.x - 1, coord.y),     Vector2i(coord.x + 1, coord.y),
			Vector2i(coord.x - 1, coord.y + 1), Vector2i(coord.x, coord.y + 1),
		]
	else:
		return [
			Vector2i(coord.x, coord.y - 1),     Vector2i(coord.x + 1, coord.y - 1),
			Vector2i(coord.x - 1, coord.y),     Vector2i(coord.x + 1, coord.y),
			Vector2i(coord.x, coord.y + 1),     Vector2i(coord.x + 1, coord.y + 1),
		]
