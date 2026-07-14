## Triangular-grid minesweeper board.
## Alternates between upward and downward triangles. Each cell has up to 12 neighbors
## (3 edge-sharing + 9 vertex-sharing).
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
func _get_nearby_cells(cell: CellBase, distance: int = 1) -> Dictionary:
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


## Returns all 12 neighbor coordinates (edge + vertex) for a triangle cell at [param coord].
## Upward triangles have 5 neighbors in the row below; downward triangles have 5 above.
func _tri_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var c: int = coord.x
	var r: int = coord.y
	var neighbors: Array[Vector2i] = [
		# Same row (4 neighbors)
		Vector2i(c - 2, r),
		Vector2i(c - 1, r),
		Vector2i(c + 1, r),
		Vector2i(c + 2, r),
	]
	if _is_upward_triangle(c, r):
		# Row above (3 neighbors)
		neighbors.append(Vector2i(c - 1, r - 1))
		neighbors.append(Vector2i(c, r - 1))
		neighbors.append(Vector2i(c + 1, r - 1))
		# Row below (5 neighbors)
		neighbors.append(Vector2i(c - 2, r + 1))
		neighbors.append(Vector2i(c - 1, r + 1))
		neighbors.append(Vector2i(c, r + 1))
		neighbors.append(Vector2i(c + 1, r + 1))
		neighbors.append(Vector2i(c + 2, r + 1))
	else:
		# Row above (5 neighbors)
		neighbors.append(Vector2i(c - 2, r - 1))
		neighbors.append(Vector2i(c - 1, r - 1))
		neighbors.append(Vector2i(c, r - 1))
		neighbors.append(Vector2i(c + 1, r - 1))
		neighbors.append(Vector2i(c + 2, r - 1))
		# Row below (3 neighbors)
		neighbors.append(Vector2i(c - 1, r + 1))
		neighbors.append(Vector2i(c, r + 1))
		neighbors.append(Vector2i(c + 1, r + 1))
	return neighbors
