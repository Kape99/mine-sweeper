## Infinite scrolling board with toroidal (wrap-around) topology.
## A single logical board (cols × rows) is the source of truth. It is
## surrounded by a fixed [constant TILE_GRID_SIZE] × [constant TILE_GRID_SIZE]
## grid of visual copies (mirroring its state), so the camera always has
## buffer content around it. When the camera drifts past a single board's
## edge, the whole tile block + camera offset are shifted by one board
## dimension — giving seamless infinite scrolling without ever spawning or
## freeing nodes during gameplay.
class_name BaseBoard
extends Control

const REVEAL_DELAY_FACTOR: float = 0.02
const EXPLOSION_VIBRATION_MS: int = 500

const FLAG_ICON: Texture2D = preload("res://Asset/Icons/flag.svg")
const MINE_ICON: Texture2D = preload("res://Asset/Icons/mine.svg")

const GRID_H_SEPARATION: int = 4
const GRID_V_SEPARATION: int = 4

## Number of tile copies per axis surrounding (and including) the logical
## board. 3 means a 3×3 block — one ring of buffer tiles around the center.
const TILE_GRID_SIZE: int = 3

## Index (row-major) of the tile that holds the real, interactive cells.
const CENTER_TILE_INDEX: int = TILE_GRID_SIZE * TILE_GRID_SIZE / 2

## Fraction of a single board's size that triggers a recenter.
const RECENTER_THRESHOLD: float = 0.5

@export var cols: int = 10
@export var rows: int = 10
@export var mines: int = 10

@export var cells: Array[PackedScene]

@onready var _board_node: Node2D = $Container

signal on_defuse_changed(defuse_value: int)
signal on_game_started(mines_number: int)
signal on_game_finished(is_win: bool, time: float)

## The logical board — 2D array [row][col] of the real, interactive cells.
var board_state: Array = []

## All tile GridContainers, including the center (logical) one.
var _tiles: Array[GridContainer] = []

var _cell_size: Vector2 = Vector2.ZERO
var _explored: int = 0
var _defused_count: int = 0
var _is_game_started: bool = false
var _is_game_over: bool = false
var _to_be_explored: int = 0
var _active_tween: Tween = null


func _ready() -> void:
	_measure_cell_size()


## Instantiates a sample cell to determine pixel dimensions.
func _measure_cell_size() -> void:
	if cells.is_empty():
		_cell_size = Vector2(40, 40)
		return
	var sample: CellBase = cells[0].instantiate()
	_board_node.add_child(sample)
	_cell_size = sample.get_combined_minimum_size()
	if _cell_size.x <= 0:
		_cell_size.x = 40
	if _cell_size.y <= 0:
		_cell_size.y = 40
	sample.free()


## Returns the spacing between one tile's origin and the next — i.e. cell
## size plus separation, repeated per column/row. Using this (rather than
## the raw cell size) for tile placement keeps the gap between the last
## cell of one board and the first cell of the next identical to the gap
## between cells within a single board.
func get_board_size() -> Vector2:
	return Vector2(
		cols * (_cell_size.x + GRID_H_SEPARATION),
		rows * (_cell_size.y + GRID_V_SEPARATION)
	)


func get_board_position() -> Vector2:
	return _board_node.position if _board_node else Vector2.ZERO


func clear() -> void:
	_kill_active_tween()
	_explored = 0
	_defused_count = 0
	_is_game_started = false
	_is_game_over = false
	for tile: GridContainer in _tiles:
		for cell in tile.get_children():
			cell.free()
		tile.free()
	_tiles.clear()
	board_state = []
	_board_node.position = Vector2.ZERO


func start_game(p_cols: int, p_rows: int, p_mines: int) -> void:
	cols = p_cols
	rows = p_rows
	mines = p_mines
	_to_be_explored = rows * cols - mines
	reset()


func reset() -> void:
	clear()
	_build_tiles()


func _connect_signals(cell: CellBase) -> void:
	cell.cell_pressed.connect(_on_cell_pressed)
	cell.cell_explored.connect(_handle_explored)
	cell.cell_defused.connect(_handle_defuse)
	cell.cell_exploded.connect(_handle_explosion)


## Creates the TILE_GRID_SIZE² tile block. The center tile holds real,
## interactive cells (becomes [member board_state]); the rest are visual
## copies that mirror the center tile's appearance.
func _build_tiles() -> void:
	var board_size: Vector2 = get_board_size()
	var half: int = TILE_GRID_SIZE / 2
	var total: int = TILE_GRID_SIZE * TILE_GRID_SIZE

	for i: int in total:
		var grid: GridContainer = GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
		grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
		_board_node.add_child(grid)

		var dx: int = (i % TILE_GRID_SIZE) - half
		var dy: int = (i / TILE_GRID_SIZE) - half
		grid.position = Vector2(dx * board_size.x, dy * board_size.y)
		_tiles.append(grid)

		# Global row/col offset of this tile, so alternating patterns (hex
		# X-offset rows, triangle Y-offset columns) continue seamlessly across
		# tile boundaries instead of restarting at each tile's local (0, 0).
		var col_offset: int = dx * cols
		var row_offset: int = dy * rows

		if i == CENTER_TILE_INDEX:
			var board: Array = []
			for row: int in rows:
				board.append([])
				for col: int in cols:
					var cell_instance: CellBase = cells[
						_get_cell_type_idx(col_offset + col, row_offset + row)
					].instantiate()
					grid.add_child(cell_instance)
					cell_instance.coord = Vector2i(col, row)
					_connect_signals(cell_instance)
					board[row].append(cell_instance)
			board_state = board
		else:
			for row: int in rows:
				for col: int in cols:
					var cell_instance: CellBase = cells[
						_get_cell_type_idx(col_offset + col, row_offset + row)
					].instantiate()
					grid.add_child(cell_instance)
					cell_instance.coord = Vector2i(col, row)
					_connect_signals(cell_instance)


## Returns the index into the `cells` array for a given global (col, row).
## [param col] and [param row] may be negative or exceed [member cols] /
## [member rows] when called for a tile other than the center one —
## implementations must wrap/modulo as needed to keep the pattern
## continuous across tile boundaries.
## Override in subclasses that use multiple cell types.
func _get_cell_type_idx(_col: int, _row: int) -> int:
	return 0


## Maps any clicked cell (copy or the real one) back to the logical cell.
func _get_center_cell(cell: CellBase) -> CellBase:
	if board_state.is_empty():
		return cell
	return board_state[cell.coord.y][cell.coord.x]


## Called every frame from the main controller with the camera's current
## offset. The camera itself is never touched here — instead [member
## _board_node] (and its whole tile block) is snapped by exactly one board
## dimension once the camera drifts too far from the block's center.
## Because the surrounding tiles are visual mirrors of the center board,
## snapping the block by a full board size leaves an identical-looking tile
## under the camera, so the jump is imperceptible — giving the illusion of
## infinite scrolling.
func recenter_if_needed(camera_offset: Vector2) -> void:
	if _tiles.is_empty() or not _is_game_started:
		return

	var board_size: Vector2 = get_board_size()
	if board_size.x <= 0 or board_size.y <= 0:
		return

	# Center of the tile block, in the same space as camera_offset.
	var center: Vector2 = _board_node.position + board_size / 2.0
	var delta: Vector2 = camera_offset - center
	var threshold: Vector2 = board_size * RECENTER_THRESHOLD

	if delta.x > threshold.x:
		_board_node.position.x += board_size.x
	elif delta.x < -threshold.x:
		_board_node.position.x -= board_size.x

	if delta.y > threshold.y:
		_board_node.position.y += board_size.y
	elif delta.y < -threshold.y:
		_board_node.position.y -= board_size.y


## Updates every non-center tile's cell at [param source]'s coordinate to
## mirror its current appearance.
func _sync_display_to_copies(source: CellBase) -> void:
	if _tiles.size() <= CENTER_TILE_INDEX:
		return
	var idx: int = source.coord.y * cols + source.coord.x
	for tile_idx: int in _tiles.size():
		if tile_idx == CENTER_TILE_INDEX:
			continue
		var tile: GridContainer = _tiles[tile_idx]
		if idx < 0 or idx >= tile.get_child_count():
			continue
		_apply_display_from_source(tile.get_child(idx), source)


func _apply_display_from_source(target: CellBase, source: CellBase) -> void:
	if source.is_explored():
		if source.is_mine():
			target.set_display(GlobalState.main_color, GlobalState.secondary_color)
			target.set_icon(MINE_ICON, GlobalState.background_color)
		else:
			var text: String = str(source.nearby) if source.nearby > 0 else ""
			target.set_display(GlobalState.main_color, GlobalState.secondary_color, null, text)
	elif source.is_defused():
		target.set_display(GlobalState.secondary_color, GlobalState.main_color, FLAG_ICON)
	else:
		target.set_display(GlobalState.secondary_color, GlobalState.main_color)


func _handle_explored(_cell: CellBase) -> void:
	_explored += 1
	_sync_display_to_copies(_cell)
	if _to_be_explored == _explored:
		on_game_finished.emit(true, 0)


func _handle_defuse(_cell: CellBase, is_defused: bool) -> void:
	if is_defused:
		_defused_count += 1
	else:
		_defused_count -= 1
	_sync_display_to_copies(_cell)
	on_defuse_changed.emit(_defused_count)


func _handle_explosion(_cell: CellBase) -> void:
	if not _is_game_over:
		_is_game_over = true
		on_game_finished.emit(false, 0.0)
		_reveal_mines_from(_cell)
		Input.vibrate_handheld(EXPLOSION_VIBRATION_MS)


func _kill_active_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _create_tween() -> Tween:
	_kill_active_tween()
	_active_tween = create_tween()
	return _active_tween


func _reveal_mines_from(origin: CellBase) -> void:
	var origin_coord: Vector2i = origin.coord
	var mine_cells: Array[CellBase] = []
	for row: int in rows:
		for col: int in cols:
			var cel: CellBase = board_state[row][col]
			if cel.is_mine() and not cel.is_explored():
				mine_cells.append(cel)
	if mine_cells.is_empty():
		return
	mine_cells.sort_custom(
		func(a: CellBase, b: CellBase) -> bool:
			return a.coord.distance_to(origin_coord) < b.coord.distance_to(origin_coord)
	)
	var tween: Tween = _create_tween()
	for cel: CellBase in mine_cells:
		var cell: CellBase = cel
		tween.tween_callback(
			func():
				cell.explore()
				_sync_display_to_copies(cell)
		).set_delay(REVEAL_DELAY_FACTOR)


func _first_move(starting_cell: CellBase) -> void:
	_is_game_started = true
	_place_mines(starting_cell)
	on_game_started.emit(mines)


func _on_cell_pressed(cell: CellBase, _p_nearby: int) -> void:
	if _is_game_over:
		return
	var logical_cell: CellBase = _get_center_cell(cell)
	if GlobalState.is_defusing:
		logical_cell.defuse()
	else:
		if not _is_game_started:
			_first_move(logical_cell)
		logical_cell.explore()
		if logical_cell.nearby == 0:
			_explore_nearby(logical_cell)


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
		var nc: CellBase = neighbor_cell
		tween.tween_callback(
			func():
				nc.explore()
		).set_delay(REVEAL_DELAY_FACTOR)


func _place_mines(cell: CellBase) -> void:
	var invalid_cells: Dictionary = _get_nearby_cells(cell, 2)
	invalid_cells[cell] = false

	var valid_indices: Array[int] = []
	var child_count: int = cols * rows
	for i: int in child_count:
		var r: int = i / cols
		var c: int = i % cols
		if not invalid_cells.has(board_state[r][c]):
			valid_indices.append(i)
	valid_indices.shuffle()

	var actual_mines: int = mini(mines, valid_indices.size())
	for i: int in actual_mines:
		var idx: int = valid_indices[i]
		var r: int = idx / cols
		var c: int = idx % cols
		var mine_cell: CellBase = board_state[r][c]
		mine_cell.mark_as_mine()
		for cell_to_update: CellBase in _get_nearby_cells(board_state[r][c]):
			var neighbor_coord: Vector2i = cell_to_update.coord
			board_state[neighbor_coord.y][neighbor_coord.x].increment_nearby()


func _get_nearby_cells(_cell: CellBase, _distance: int = 1) -> Dictionary:
	return {}
