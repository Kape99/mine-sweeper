## Hexagonal-grid minesweeper board using offset coordinates (odd-row shift right).
## Each cell has up to 6 neighbors.
class_name HexagonBoard
extends BaseBoard


## Clears the board and instantiates a hex grid. Alternates cell scene by row parity
## to account for the visual offset.
func reset() -> void:
	clear()
	var board: Array = []
	for row: int in rows:
		board.append([])
		for col: int in cols:
			var cell_instance: CellBase = cells[row % 2].instantiate()
			board_grid.add_child(cell_instance)
			cell_instance.coord = Vector2i(col, row)
			_connect_signals(cell_instance)
			board[row].append(cell_instance)
	board_state = board


## Returns all cells within [param distance] rings of [param cell] using
## iterative BFS ring expansion over hex neighbors.
func _get_nearby_cells(cell: CellBase, distance: int = 1) -> Dictionary:
	var result: Dictionary = {}
	var visited: Dictionary = {cell.coord: true}
	var current_ring: Array[Vector2i] = [cell.coord]

	for _d: int in distance:
		var next_ring: Array[Vector2i] = []
		for coord: Vector2i in current_ring:
			for neighbor_coord: Vector2i in _hex_neighbors(coord):
				if visited.has(neighbor_coord):
					continue
				if not _is_valid(neighbor_coord.x, neighbor_coord.y):
					continue
				visited[neighbor_coord] = true
				next_ring.append(neighbor_coord)
				result[board_state[neighbor_coord.y][neighbor_coord.x]] = false
		current_ring = next_ring
	return result


## Returns the 6 neighbor coordinates for a hex cell at [param coord].
## Uses offset coordinates: even rows shift left, odd rows shift right.
func _hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
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
