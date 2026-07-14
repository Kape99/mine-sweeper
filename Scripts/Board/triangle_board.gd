## Triangular-grid minesweeper board.
## Alternates between upward and downward triangles. Each cell has exactly 3 edge-neighbors.
class_name TriangleBoard
extends BaseBoard


## Clears the board and instantiates a triangle grid. Cell scene is selected by
## alternating index to produce the up/down triangle pattern.
func reset() -> void:
	clear()
	var board: Array = []
	for row: int in rows:
		board.append([])
		for col: int in cols:
			var cell_instance: CellBase = cells[(col + row * cols) % cells.size()].instantiate()
			board_grid.add_child(cell_instance)
			cell_instance.coord = Vector2i(col, row)
			_connect_signals(cell_instance)
			board[row].append(cell_instance)
	board_state = board


## Returns [code]true[/code] if the triangle at ([param col], [param row]) points upward.
func _is_upward_triangle(col: int, row: int) -> bool:
	return (col + row * cols) % 2 == 0


## Returns all cells within [param distance] rings of [param cell] using
## iterative BFS ring expansion over triangle edge-neighbors.
func _get_nearby_cells(cell: CellBase, distance: int = 1, _cell_list: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var visited: Dictionary = {cell.coord: true}
	var current_ring: Array[Vector2i] = [cell.coord]

	for _d: int in distance:
		var next_ring: Array[Vector2i] = []
		for coord: Vector2i in current_ring:
			for neighbor_coord: Vector2i in _tri_neighbors(coord):
				if visited.has(neighbor_coord):
					continue
				if not _is_valid(neighbor_coord.x, neighbor_coord.y):
					continue
				visited[neighbor_coord] = true
				next_ring.append(neighbor_coord)
				result[board_state[neighbor_coord.y][neighbor_coord.x]] = false
		current_ring = next_ring
	return result


## Returns the 3 edge-neighbor coordinates for a triangle cell at [param coord].
## Upward triangles connect to the row below; downward triangles to the row above.
func _tri_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = [
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x + 1, coord.y),
	]
	if _is_upward_triangle(coord.x, coord.y):
		neighbors.append(Vector2i(coord.x, coord.y + 1))
	else:
		neighbors.append(Vector2i(coord.x, coord.y - 1))
	return neighbors
