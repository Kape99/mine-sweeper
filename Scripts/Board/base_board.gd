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
	reset()


func _connect_signals(cell: CellBase):
	cell.cell_pressed.connect(_on_cell_pressed)
	cell.cell_explored.connect(_handle_explored)
	cell.cell_defused.connect(_handle_defuse)
	cell.cell_exploded.connect(_handle_explosion)


func reset():
	pass


func _handle_explored(cell: CellBase):
	_explored += 1
	if to_be_explored == _explored:
		on_game_finished.emit(true, 0)


func _handle_defuse(cell: CellBase, is_defused: bool):
	if is_defused:
		_defused_count += 1
	else:
		_defused_count -= 1
	on_defuse_changed.emit(_defused_count)


func _handle_explosion(cell: CellBase):
	if not _is_game_over:
		_is_game_over = true
		on_game_finished.emit(false, 0.0)
		_reveal_mines_from(cell)
		Input.vibrate_handheld(500)


func _reveal_mines_from(origin: CellBase):
	var mine_cells: Array = []
	for cel in board_grid.get_children():
		if cel.nearby == -1 and not cel.is_explored():
			mine_cells.append(cel)
	if mine_cells.is_empty():
		return
	mine_cells.sort_custom(func(a, b): return a.coord.distance_to(origin.coord) < b.coord.distance_to(origin.coord))
	var tween = create_tween()
	for cel in mine_cells:
		var delay = cel.coord.distance_to(origin.coord) * 0.1
		tween.tween_callback(cel.explore).set_delay(delay)


func first_move(starting_cell):
	_is_game_started = true
	_place_mines(starting_cell)
	on_game_started.emit(mines)


func _on_cell_pressed(cell: CellBase, nearby: int):
	if _is_game_over:
		return
	if GlobalState._defusing:
		cell.defuse()
	else:
		if not _is_game_started:
			first_move(cell)
		cell.explore()
		if nearby == 0:
			_explore_nearby(cell)


func _explore_nearby(cell: CellBase):
	# BFS flood fill — only expands through cells with nearby == 0
	var visited: Dictionary = {cell: true}
	var queue: Array[CellBase] = [cell]
	var to_reveal: Array = []
	var head: int = 0
	while head < queue.size():
		var current = queue[head]
		head += 1
		for neighbor in _get_nearby_cells(current).keys():
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			to_reveal.append(neighbor)
			if neighbor.nearby == 0:
				queue.append(neighbor)
	if to_reveal.is_empty():
		return
	# Sort by distance for wave animation, batch into single tween
	to_reveal.sort_custom(func(a, b): return a.coord.distance_to(cell.coord) < b.coord.distance_to(cell.coord))
	var tween = create_tween()
	for neighbor_cell in to_reveal:
		var delay = neighbor_cell.coord.distance_to(cell.coord) * 0.1
		tween.tween_callback(neighbor_cell.explore).set_delay(delay)


func _place_mines(cell: CellBase):
	# Collect valid positions, shuffle, pick first N — O(n) guaranteed
	var invalid_cells = _get_nearby_cells(cell, 2)
	invalid_cells[cell] = false
	var valid_indices: Array[int] = []
	var child_count = board_grid.get_child_count()
	for i in child_count:
		if not invalid_cells.has(board_grid.get_child(i)):
			valid_indices.append(i)
	valid_indices.shuffle()
	var actual_mines = mini(mines, valid_indices.size())
	for i in actual_mines:
		var mine_cell = board_grid.get_child(valid_indices[i])
		mine_cell.nearby = -1
		for cell_to_update in _get_nearby_cells(mine_cell):
			cell_to_update.nearby = 1


func _get_nearby_cells(cell: CellBase, distance: int = 1) -> Dictionary:
	return {}


func _is_valid(col: int, row: int):
	return col >= 0 and col < cols and row >= 0 and row < rows
