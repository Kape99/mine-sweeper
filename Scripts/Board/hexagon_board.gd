class_name HexagonBoard
extends BaseBoard


## The hex honeycomb stagger is an X-axis offset baked into alternating
## cell variants, keyed by row parity. Using the *global* row (continuing
## across tile boundaries, via posmod for negative rows) keeps the zigzag
## unbroken at tile seams.
func _get_cell_type_idx(_col: int, row: int) -> int:
	return posmod(row, 2)


## Neighbor offsets depend on row parity, so wrapping needs an even row count.
func _get_wrap_dimension_multiple() -> Vector2i:
	return Vector2i(1, 2)


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
