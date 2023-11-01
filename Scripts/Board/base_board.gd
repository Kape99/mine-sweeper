class_name BaseBoard
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
	pass


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
	var found_new_cell = true
	var checked = []
	var to_be_explored = _get_nearby_cells(cell)
	var new_cycle = []
	while found_new_cell:
		found_new_cell = false
		for nearby_cell in to_be_explored:
			if nearby_cell.nearby == 0 and checked.find(nearby_cell) == -1:
				new_cycle.append(nearby_cell)
				found_new_cell = true
			checked.append(nearby_cell)
		to_be_explored.clear()
		for cicle in new_cycle:
			to_be_explored.append_array(_get_nearby_cells(cicle))
		new_cycle.clear()

	for nearby_cell in checked:
		nearby_cell.explore_delayed((nearby_cell.coord - cell.coord).length() * .1)


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
