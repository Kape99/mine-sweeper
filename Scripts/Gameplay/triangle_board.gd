extends Node

@export var cols: int = 10
@export var rows: int = 10
@export var mines: int = 10

@onready var board_grid: GridContainer = $CenterContainer/Board

@export var cells: Array[PackedScene]

signal on_defuse_changed(defuse_value: int)
signal on_game_started(mines_number: int)

var board_state

var _defused_count: int = 0:
	set(value):
		_defused_count = value
		emit_signal("on_defuse_changed", _defused_count)

var _is_game_started: bool = false


func _ready():
	var up_triangle: PackedScene = load("res://Cells/up_triangle_cell.tscn")
	var down_triangle: PackedScene = load("res://Cells/down_triangle_cell.tscn")


func get_board_size():
	return board_grid.get_size()


func clear():
	_is_game_started = false
	board_grid.columns = cols
	for cell in board_grid.get_children():
		cell.free()


func start_game(cols: int, rows: int, mines: int):
	self.cols = cols
	self.rows = rows
	self.mines = mines
	reset()


func reset():
	clear()
	var board = []
	for row in rows:
		board.append([])
		for col in cols:
			var cell_istance: CellBase = cells[(col + row * cols) % cells.size()].instantiate()
			board_grid.add_child(cell_istance)
			cell_istance.coord = Vector2i(col, row)
			cell_istance.connect("cell_explored", _on_cell_explored)
			cell_istance.connect("cell_defused", _on_cell_defused)
			board[row].append(cell_istance)
	board_state = board


func first_move(starting_cell):
	_is_game_started = true
	_place_mines(starting_cell)
	emit_signal("on_game_started", mines)


func _on_cell_explored(cell: CellBase, should_propagate: bool):
	if not _is_game_started:
		first_move(cell)
		_is_game_started = true
	if should_propagate:
		_explore_nearby(cell)


func _on_cell_defused(cell: CellBase, is_defused):
	if is_defused:
		_defused_count += 1
		# TODO check victory
	else:
		_defused_count -= 1


func _explore_nearby(cell: CellBase):
	for nearby_cell in _get_nearby_cells(cell):
		nearby_cell.explore()


func _place_mines(cell: CellBase):
	var invalid_cells = _get_nearby_cells(cell)
	invalid_cells.append(cell)
	var max_position = rows * cols - 1
	var placed_mine = 0
	while placed_mine < mines:
		var position = randi_range(0, max_position)
		var possible_cell = board_grid.get_child(position)
		if not invalid_cells.has(possible_cell):
			possible_cell.nearby = -1
			invalid_cells.append(possible_cell)
			placed_mine += 1

			for cell_to_update in _get_nearby_cells(possible_cell):
				cell_to_update.nearby = 1


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
			if col < target_coord.x - 1 or col > target_coord.x + 1:
				if row < target_coord.y and not target_index % 2:
					continue
				elif row > target_coord.y and target_index % 2:
					continue
			nearby_cells.append(board_state[row][col])
	return nearby_cells


func _is_valid(col: int, row: int):
	return col >= 0 and col < cols and row >= 0 and row < rows
