class_name BaseBoard
extends Node

@export var cols: int = 10
@export var rows: int = 10
@export var mines: int = 10

var _explored: int = 0

@onready var board_grid: GridContainer = $CenterContainer/Board

@export var cells: Array[PackedScene]

signal on_defuse_changed(defuse_value: int)
signal on_game_started(mines_number: int)
signal game_finished(is_win: bool, time: float)

var board_state

var _is_game_started: bool = false


func get_board_size():
	return board_grid.get_size()


func clear():
	_explored = 0
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
	pass


func first_move(starting_cell):
	_is_game_started = true
	_place_mines(starting_cell)


func _on_cell_pressed(cell: CellBase, nearby: int):
	if GlobaState._defusing:
		cell.defuse()
	else:
		if not _is_game_started:
			first_move(cell)
		cell.explore()
		_explored += 1
		if nearby == 0:
			_explore_nearby(cell)
	check_victory()


func check_victory():
	if _explored + mines == rows * cols:
		print("win")
		emit_signal("game_finished", true, 0)


func _explore_nearby(cell: CellBase):
	var to_explore = []
	var new_cells = _get_nearby_cells(cell)
	while new_cells.size() > 0:
		for around in new_cells:
			if not to_explore.has(around):
				to_explore.append(around)
				if around.nearby == 0:
					for appo in _get_nearby_cells(around):
						if !new_cells.has(appo):
							new_cells.append(appo)
		new_cells.clear()
	for nearby_cell in to_explore:
		nearby_cell.explore_delayed((nearby_cell.coord - cell.coord).length() * .1)
		_explored += 1


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
	pass


func _is_valid(col: int, row: int):
	return col >= 0 and col < cols and row >= 0 and row < rows
