## Abstract base class for all board types (square, triangle, hexagon).
## Handles mine placement, game state, flood-fill reveal, and win/lose detection.
## Subclasses must override [method reset] and [method _get_nearby_cells].
class_name BaseBoard
extends Control

## Delay multiplier (seconds per unit of grid distance) for the reveal wave animation.
const REVEAL_DELAY_FACTOR: float = 0.02

## Haptic feedback duration (ms) when a mine explodes.
const EXPLOSION_VIBRATION_MS: int = 500

@export var cols: int = 10
@export var rows: int = 10
@export var mines: int = 10

## Cell scenes to instantiate. Subclasses index into this array based on cell variant.
@export var cells: Array[PackedScene]

@onready var board_grid: GridContainer = $CenterContainer/Board

## Emitted when the defused-mine count changes.
signal on_defuse_changed(defuse_value: int)

## Emitted after the first move, once mines have been placed.
signal on_game_started(mines_number: int)

## Emitted when the game ends. [param is_win] indicates victory or defeat.
signal on_game_finished(is_win: bool, time: float)

## 2D array of [CellBase] references, indexed as [code]board_state[row][col][/code].
## Untyped because GDScript doesn't support [code]Array[Array[CellBase]][/code].
var board_state: Array = []

var _explored: int = 0
var _defused_count: int = 0
var _is_game_started: bool = false
var _is_game_over: bool = false
var _to_be_explored: int = 0

## Active animation tween. Tracked so it can be killed when a new animation starts
## (e.g. flood-fill interrupted by explosion).
var _active_tween: Tween = null


## Returns the pixel size of the board grid container.
func get_board_size() -> Vector2:
	return board_grid.get_size()


## Returns the position of the board grid container.
func get_board_position() -> Vector2:
	return board_grid.position


## Resets internal state and frees all child cells from the grid.
func clear() -> void:
	_kill_active_tween()
	_explored = 0
	_defused_count = 0
	_is_game_started = false
	_is_game_over = false
	board_grid.columns = cols
	for cell in board_grid.get_children():
		cell.free()


## Configures board dimensions and mine count then calls [method reset].
func start_game(p_cols: int, p_rows: int, p_mines: int) -> void:
	cols = p_cols
	rows = p_rows
	mines = p_mines
	_to_be_explored = rows * cols - mines
	reset()


## Connects all gameplay signals from a cell to board handlers.
func _connect_signals(cell: CellBase) -> void:
	cell.cell_pressed.connect(_on_cell_pressed)
	cell.cell_explored.connect(_handle_explored)
	cell.cell_defused.connect(_handle_defuse)
	cell.cell_exploded.connect(_handle_explosion)


## Override in subclasses to instantiate cells and populate [member board_state].
func reset() -> void:
	pass


# -- Signal handlers ----------------------------------------------------------

func _handle_explored(_cell: CellBase) -> void:
	_explored += 1
	if _to_be_explored == _explored:
		on_game_finished.emit(true, 0)


func _handle_defuse(_cell: CellBase, is_defused: bool) -> void:
	if is_defused:
		_defused_count += 1
	else:
		_defused_count -= 1
	on_defuse_changed.emit(_defused_count)


func _handle_explosion(cell: CellBase) -> void:
	if not _is_game_over:
		_is_game_over = true
		on_game_finished.emit(false, 0.0)
		_reveal_mines_from(cell)
		Input.vibrate_handheld(EXPLOSION_VIBRATION_MS)


# -- Core gameplay logic -------------------------------------------------------

## Kills the currently running animation tween, if any.
func _kill_active_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


## Creates a new animation tween, killing any active one first.
func _create_tween() -> Tween:
	_kill_active_tween()
	_active_tween = create_tween()
	return _active_tween


## Animates the reveal of all remaining mines in a distance-sorted wave
## originating from [param origin].
func _reveal_mines_from(origin: CellBase) -> void:
	var mine_cells: Array[CellBase] = []
	for cel in board_grid.get_children():
		if cel.is_mine() and not cel.is_explored():
			mine_cells.append(cel)
	if mine_cells.is_empty():
		return
	mine_cells.sort_custom(
		func(a: CellBase, b: CellBase) -> bool:
			return a.coord.distance_to(origin.coord) < b.coord.distance_to(origin.coord)
	)
	var tween: Tween = _create_tween()
	for cel in mine_cells:
		tween.tween_callback(cel.explore).set_delay(REVEAL_DELAY_FACTOR)


## Called on the very first click: places mines, then signals game start.
func _first_move(starting_cell: CellBase) -> void:
	_is_game_started = true
	_place_mines(starting_cell)
	on_game_started.emit(mines)


## Handles a cell press: delegates to defuse or explore depending on mode.
func _on_cell_pressed(cell: CellBase, p_nearby: int) -> void:
	if _is_game_over:
		return
	if GlobalState.is_defusing:
		cell.defuse()
	else:
		if not _is_game_started:
			_first_move(cell)
		cell.explore()
		if p_nearby == 0:
			_explore_nearby(cell)


## BFS flood fill starting from [param cell]. Expands through cells with
## [code]nearby == 0[/code] and reveals all reachable neighbors.
## Uses a single [Tween] for the wave animation.
func _explore_nearby(cell: CellBase) -> void:
	var visited: Dictionary = {cell: true}
	var queue: Array[CellBase] = [cell]
	var to_reveal: Array[CellBase] = []
	var head: int = 0

	while head < queue.size():
		var current: CellBase = queue[head]
		head += 1
		for neighbor: CellBase in _get_nearby_cells(current).keys():
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			to_reveal.append(neighbor)
			if neighbor.nearby == 0:
				queue.append(neighbor)

	if to_reveal.is_empty():
		return

	to_reveal.sort_custom(
		func(a: CellBase, b: CellBase) -> bool:
			return a.coord.distance_to(cell.coord) < b.coord.distance_to(cell.coord)
	)
	var tween: Tween = _create_tween()
	for neighbor_cell: CellBase in to_reveal:
		tween.tween_callback(neighbor_cell.explore).set_delay(REVEAL_DELAY_FACTOR)


## Places mines using Fisher-Yates shuffle over valid positions — O(n) guaranteed.
## Cells within distance 2 of [param cell] are excluded to ensure a safe first click.
func _place_mines(cell: CellBase) -> void:
	var invalid_cells: Dictionary = _get_nearby_cells(cell, 2)
	invalid_cells[cell] = false

	var valid_indices: Array[int] = []
	var child_count: int = board_grid.get_child_count()
	for i: int in child_count:
		if not invalid_cells.has(board_grid.get_child(i)):
			valid_indices.append(i)
	valid_indices.shuffle()

	var actual_mines: int = mini(mines, valid_indices.size())
	for i: int in actual_mines:
		var mine_cell: CellBase = board_grid.get_child(valid_indices[i])
		mine_cell.mark_as_mine()
		for cell_to_update: CellBase in _get_nearby_cells(mine_cell):
			cell_to_update.increment_nearby()


## Returns a [Dictionary] of neighboring [CellBase] nodes within [param distance].
## Keys are [CellBase], values are unused ([code]false[/code]).
## Used as a set — GDScript lacks a native Set type.[br]
## Must be overridden by each board subclass.
func _get_nearby_cells(_cell: CellBase, _distance: int = 1) -> Dictionary:
	return {}


## Returns [code]true[/code] if [param col] and [param row] are within bounds.
func _is_valid(col: int, row: int) -> bool:
	return col >= 0 and col < cols and row >= 0 and row < rows
