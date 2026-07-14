class_name TriangleBoard extends BaseBoard


func reset():
	clear()
	var board = []
	for row in rows:
		board.append([])
		for col in cols:
			var cell_instance: CellBase = cells[(col + row * cols) % cells.size()].instantiate()
			board_grid.add_child(cell_instance)
			cell_instance.coord = Vector2i(col, row)
			_connect_signals(cell_instance)
			board[row].append(cell_instance)
	board_state = board


func _is_upward_triangle(col: int, row: int) -> bool:
	return (col + row * cols) % 2 == 0


func _get_nearby_cells(cell: CellBase, distance: int = 1, _cell_list: Dictionary = {}) -> Dictionary:
	# Iterative BFS ring expansion for triangle grid
	var result: Dictionary = {}
	var visited: Dictionary = {cell.coord: true}
	var current_ring: Array = [cell.coord]

	for _d in distance:
		var next_ring: Array = []
		for coord in current_ring:
			for neighbor_coord in _tri_neighbors(coord):
				if visited.has(neighbor_coord):
					continue
				if not _is_valid(neighbor_coord.x, neighbor_coord.y):
					continue
				visited[neighbor_coord] = true
				next_ring.append(neighbor_coord)
				result[board_state[neighbor_coord.y][neighbor_coord.x]] = false
		current_ring = next_ring
	return result


func _tri_neighbors(coord: Vector2i) -> Array:
	var neighbors: Array = [
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x + 1, coord.y),
	]
	# Upward triangles connect to row below, downward to row above
	if _is_upward_triangle(coord.x, coord.y):
		neighbors.append(Vector2i(coord.x, coord.y + 1))
	else:
		neighbors.append(Vector2i(coord.x, coord.y - 1))
	return neighbors
