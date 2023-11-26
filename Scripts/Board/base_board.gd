class_name BaseBoard
extends Control

@export var cols: int = 10
@export var rows: int = 10
@export var mines: int = 10

var _explored: int = 0

var _defused_count: int = 0

@onready var board_grid: GridContainer = $CenterContainer/Board

@export var cells: Array[PackedScene]

signal on_defuse_changed(defuse_value: int)
signal on_game_started(mines_number: int)
signal on_game_finished(is_win: bool, time: float)

var board_state

var _is_game_started: bool = false
var _is_game_over: bool = false

var to_be_explored: int = 0


func get_board_size():
	return board_grid.get_size()


func get_board_position():
	return board_grid.position


func clear():
	_explored = 0
	_defused_count = 0
	_is_game_started = false
	_is_game_over = false
	board_grid.columns = cols
	for cell in board_grid.get_children():
		cell.free()


func start_game(cols: int, rows: int, mines: int):
	self.cols = cols
	self.rows = rows
	self.mines = mines

	to_be_explored = rows * cols - mines

	print_debug("Game starting")
	print_debug("Cols: ", cols, " Rows: ", rows)
	print_debug("Number of cells: ", cols * rows, " Mines: ", mines)

	reset()


func _connect_signals(cell: CellBase):
	cell.connect("cell_pressed", _on_cell_pressed)
	cell.connect("cell_explored", _handle_explored)
	cell.connect("cell_defused", _handle_defuse)
	cell.connect("cell_exploded", _handle_explosion)


func reset():
	pass


func _handle_explored(cell: CellBase):
	print_debug("cell : ", cell.coord, " has been explored!")
	_explored += 1
	print_debug("explored count: ", _explored)

	if to_be_explored == _explored:
		emit_signal("on_game_finished", true, 0)


func _handle_defuse(cell: CellBase, is_defused: bool):
	if is_defused:
		_defused_count += 1
	else:
		_defused_count -= 1
	emit_signal("on_defuse_changed", _defused_count)


func _handle_explosion(cell: CellBase):
	if not _is_game_over:
		_is_game_over = true
		print_debug("cell :", cell.coord, " is exploded! GameOver")
		emit_signal("on_game_finished", false, 0.0)
		for cel in board_grid.get_children():
			if cel.nearby == -1:
				cel.explore_delayed((cel.coord - cell.coord).length() * .1)
		Input.vibrate_handheld(500)


func first_move(starting_cell):
	_is_game_started = true
	_place_mines(starting_cell)
	emit_signal("on_game_started", mines)


func _on_cell_pressed(cell: CellBase, nearby: int):
	if GlobaState._defusing:
		cell.defuse()
	else:
		if not _is_game_started:
			first_move(cell)
		cell.explore()
		if nearby == 0:
			_explore_nearby(cell)


func _explore_nearby(cell: CellBase):
	var to_explore = []
	var new_cells: Dictionary = _get_nearby_cells(cell)
	var size = 0
	while new_cells.size() > size:
		size = new_cells.size()
		for nearby in new_cells.keys():
			if nearby.nearby == 0:
				new_cells.merge(_get_nearby_cells(nearby))
	for nearby_cell in new_cells.keys():
		nearby_cell.explore_delayed((nearby_cell.coord - cell.coord).length() * .1)


func _place_mines(cell: CellBase):
	var invalid_cells = _get_nearby_cells(cell, 2)
	invalid_cells.merge({cell: false})
	var max_position = rows * cols - 1
	var placed_mine = 0
	while placed_mine < mines:
		var position = randi_range(0, max_position)
		var possible_cell = board_grid.get_child(position)
		if not invalid_cells.has(possible_cell):
			possible_cell.nearby = -1
			invalid_cells.merge({possible_cell: false})
			placed_mine += 1
			for cell_to_update in _get_nearby_cells(possible_cell):
				cell_to_update.nearby = 1


func _get_nearby_cells(cell: CellBase, distance: int = 1) -> Dictionary:
	return {}


func _is_valid(col: int, row: int):
	return col >= 0 and col < cols and row >= 0 and row < rows
