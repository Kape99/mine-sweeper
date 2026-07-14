## Square-grid minesweeper board.
## Each cell has up to 8 neighbors (Chebyshev distance).
class_name SquareBoard
extends BaseBoard


## Clears the board and instantiates a [param cols] × [param rows] grid of square cells.
func reset() -> void:
	clear()
	var board: Array = []
	for row: int in rows:
		board.append([])
		for col: int in cols:
			var cell_instance: CellBase = cells[0].instantiate()
			board_grid.add_child(cell_instance)
			cell_instance.coord = Vector2i(col, row)
			_connect_signals(cell_instance)
			board[row].append(cell_instance)
	board_state = board


## Returns all cells within Chebyshev [param distance] of [param cell].
## For distance=1 this gives the classic 8-neighbor square adjacency.
## For distance=2 (used by safe-zone), returns a 5×5 box minus center.
func _get_nearby_cells(cell: CellBase, distance: int = 1) -> Dictionary:
	var result: Dictionary = {}
	var origin: Vector2i = cell.coord
	for col: int in range(origin.x - distance, origin.x + distance + 1):
		for row: int in range(origin.y - distance, origin.y + distance + 1):
			if not _is_valid(col, row):
				continue
			if col == origin.x and row == origin.y:
				continue
			result[board_state[row][col]] = false
	return result
