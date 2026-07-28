class_name TriangleBoard
extends BaseBoard


## The triangle up/down stagger is a Y-axis offset baked into alternating
## cell variants, keyed by column parity. Using the *global* column
## (continuing across tile boundaries, via posmod for negative columns)
## keeps the zigzag unbroken at tile seams.
func _get_cell_type_idx(col: int, row: int) -> int:
	return posmod(col + row, cells.size())


func _is_upward_triangle(col: int, row: int) -> bool:
	return posmod(col + row, 2) == 0


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
				if _wrap_mode:
					neighbor_coord.x = posmod(neighbor_coord.x, cols)
					neighbor_coord.y = posmod(neighbor_coord.y, rows)
				else:
					if neighbor_coord.x < 0 or neighbor_coord.x >= cols or neighbor_coord.y < 0 or neighbor_coord.y >= rows:
						continue
				visited[neighbor_coord] = true
				next_ring.append(neighbor_coord)
				if not board_state.is_empty():
					result[board_state[neighbor_coord.y][neighbor_coord.x]] = false
		current_ring = next_ring
	return result


func _tri_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var c: int = coord.x
	var r: int = coord.y
	var neighbors: Array[Vector2i] = [
		Vector2i(c - 2, r),
		Vector2i(c - 1, r),
		Vector2i(c + 1, r),
		Vector2i(c + 2, r),
	]
	if _is_upward_triangle(c, r):
		neighbors.append(Vector2i(c - 1, r - 1))
		neighbors.append(Vector2i(c, r - 1))
		neighbors.append(Vector2i(c + 1, r - 1))
		neighbors.append(Vector2i(c - 2, r + 1))
		neighbors.append(Vector2i(c - 1, r + 1))
		neighbors.append(Vector2i(c, r + 1))
		neighbors.append(Vector2i(c + 1, r + 1))
		neighbors.append(Vector2i(c + 2, r + 1))
	else:
		neighbors.append(Vector2i(c - 2, r - 1))
		neighbors.append(Vector2i(c - 1, r - 1))
		neighbors.append(Vector2i(c, r - 1))
		neighbors.append(Vector2i(c + 1, r - 1))
		neighbors.append(Vector2i(c + 2, r - 1))
		neighbors.append(Vector2i(c - 1, r + 1))
		neighbors.append(Vector2i(c, r + 1))
		neighbors.append(Vector2i(c + 1, r + 1))
	return neighbors
