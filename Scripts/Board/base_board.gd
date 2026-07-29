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

## Extra padding (pixels) added around the board bounds in classic mode,
## matching CameraController's own margin so panning feels consistent.
const PAN_MARGIN: float = 100.0

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

## When true (default), the board is toroidal — neighbors wrap, camera
## recenter is active, and there are no camera bounds. When false, the
## board has hard edges, the camera is clamped to the board bounds, and
## neighbor lookups stop at the edge.
var _wrap_mode: bool = true


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


## Returns the camera bounds for this board. In wrap mode the rect is
## empty (no bounds — camera recenter handles scrolling). In classic mode
## the rect covers the board with a small margin.
func get_bounds() -> Rect2:
	if _wrap_mode:
		return Rect2()
	var board_size: Vector2 = get_board_size()
	return Rect2(
		_board_node.position - Vector2(PAN_MARGIN, PAN_MARGIN),
		board_size + Vector2(PAN_MARGIN * 2.0, PAN_MARGIN * 2.0)
	)


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


func start_game(p_cols: int, p_rows: int, p_mines: int, p_wrap: bool = true) -> void:
	cols = p_cols
	rows = p_rows
	mines = p_mines
	_wrap_mode = p_wrap
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


## Creates the tile block. In wrap mode this is a TILE_GRID_SIZE² grid
## (one interactive center tile + visual copies). In classic mode only a
## single tile is built — no copies, no wrapping offsets.
func _build_tiles() -> void:
	var board_size: Vector2 = get_board_size()
	var total: int = TILE_GRID_SIZE * TILE_GRID_SIZE if _wrap_mode else 1

	for i: int in total:
		var grid: GridContainer = GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
		grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
		_board_node.add_child(grid)

		var dx: int = 0
		var dy: int = 0
		if _wrap_mode:
			dx = (i % TILE_GRID_SIZE) - TILE_GRID_SIZE / 2
			dy = (i / TILE_GRID_SIZE) - TILE_GRID_SIZE / 2
			grid.position = Vector2(dx * board_size.x, dy * board_size.y)
		_tiles.append(grid)

		# Global row/col offset of this tile, so alternating patterns (hex
		# X-offset rows, triangle Y-offset columns) continue seamlessly
		# across tile boundaries in wrap mode. Zero in classic mode.
		var col_offset: int = dx * cols
		var row_offset: int = dy * rows

		var is_center: bool = not _wrap_mode or (i == CENTER_TILE_INDEX)
		if is_center:
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
					grid.add_child(_create_display_cell())

	if _wrap_mode:
		# Sync all display cells to match center tile initial state
		for row: int in rows:
			for col: int in cols:
				_sync_display_to_copies(board_state[row][col])


## Returns the index into the `cells` array for a given global (col, row).
## [param col] and [param row] may be negative or exceed [member cols] /
## [member rows] when called for a tile other than the center one —
## implementations must wrap/modulo as needed to keep the pattern
## continuous across tile boundaries.
## Override in subclasses that use multiple cell types.
func _get_cell_type_idx(_col: int, _row: int) -> int:
	return 0


## Creates a lightweight display-only cell for non-center tiles.
## No Area2D, no FSM, no collision — just visuals.
func _create_display_cell() -> Control:
	var cell: Control = Control.new()
	cell.custom_minimum_size = _cell_size
	cell.mouse_filter = MOUSE_FILTER_IGNORE

	var poly: Polygon2D = Polygon2D.new()
	var half: Vector2 = _cell_size / 2.0
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	poly.position = half
	poly.modulate = GlobalState.secondary_color
	cell.add_child(poly)

	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = _cell_size
	label.position = Vector2.ZERO
	label.modulate = GlobalState.main_color
	label.mouse_filter = MOUSE_FILTER_IGNORE
	cell.add_child(label)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = _cell_size * 0.6
	icon.size = icon.custom_minimum_size
	icon.position = (_cell_size - icon.size) / 2.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = GlobalState.main_color
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	return cell


## Maps any clicked cell (copy or the real one) back to the logical cell.
func _get_center_cell(cell: CellBase) -> CellBase:
	if board_state.is_empty():
		return cell
	return board_state[cell.coord.y][cell.coord.x]


## Handles taps on non-center tiles via unhandled input. Computes which
## tile was hit from the click position, then maps to the logical cell.
func _unhandled_input(event: InputEvent) -> void:
	if not _wrap_mode or _tiles.is_empty() or board_state.is_empty():
		return
	var is_tap: bool = (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
		or (event is InputEventScreenTouch and not event.pressed)
	)
	if not is_tap:
		return
	_handle_tile_tap(event.position)


func _handle_tile_tap(global_pos: Vector2) -> void:
	# Convert from viewport coordinates to canvas coordinates (accounts for camera)
	var canvas_pos: Vector2 = get_viewport().canvas_transform.affine_inverse() * global_pos
	var board_size: Vector2 = get_board_size()
	var board_origin: Vector2 = _board_node.global_position
	var cell_step: Vector2 = Vector2(
		_cell_size.x + GRID_H_SEPARATION,
		_cell_size.y + GRID_V_SEPARATION
	)

	for i: int in _tiles.size():
		if i == CENTER_TILE_INDEX:
			continue
		var tile: GridContainer = _tiles[i]
		var tile_origin: Vector2 = board_origin + tile.position
		var local_pos: Vector2 = canvas_pos - tile_origin
		if local_pos.x < 0 or local_pos.y < 0:
			continue
		if local_pos.x >= board_size.x or local_pos.y >= board_size.y:
			continue
		var col: int = int(local_pos.x / cell_step.x)
		var row: int = int(local_pos.y / cell_step.y)
		if col >= 0 and col < cols and row >= 0 and row < rows:
			Input.vibrate_handheld(CellBase.TAP_VIBRATION_MS)
			var logical_cell: CellBase = board_state[row][col]
			_on_cell_pressed(logical_cell, logical_cell.nearby)
		return


## Called every frame from the main controller with the camera's current
## offset. The camera itself is never touched here — instead [member
## _board_node] (and its whole tile block) is snapped by exactly one board
## dimension once the camera drifts too far from the block's center.
## Because the surrounding tiles are visual mirrors of the center board,
## snapping the block by a full board size leaves an identical-looking tile
## under the camera, so the jump is imperceptible — giving the illusion of
## infinite scrolling.
func recenter_if_needed(camera_offset: Vector2) -> void:
	if not _wrap_mode or _tiles.is_empty() or not _is_game_started:
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


func _apply_display_from_source(target: Node, source: CellBase) -> void:
	if target is CellBase:
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
	else:
		# Lightweight display cell — children: Polygon2D, Label, TextureRect
		if target.get_child_count() < 3:
			return
		var poly: Polygon2D = target.get_child(0)
		var label: Label = target.get_child(1)
		var icon: TextureRect = target.get_child(2)

		if source.is_explored():
			if source.is_mine():
				poly.modulate = GlobalState.main_color
				label.modulate = GlobalState.secondary_color
				icon.modulate = GlobalState.background_color
				icon.texture = MINE_ICON
				label.text = ""
			else:
				poly.modulate = GlobalState.main_color
				label.modulate = GlobalState.secondary_color
				icon.modulate = GlobalState.secondary_color
				icon.texture = null
				label.text = str(source.nearby) if source.nearby > 0 else ""
		elif source.is_defused():
			poly.modulate = GlobalState.secondary_color
			label.modulate = GlobalState.main_color
			icon.modulate = GlobalState.main_color
			icon.texture = FLAG_ICON
			label.text = ""
		else:
			poly.modulate = GlobalState.secondary_color
			label.modulate = GlobalState.main_color
			icon.modulate = GlobalState.main_color
			icon.texture = null
			label.text = ""


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
		if logical_cell.is_explored() and logical_cell.nearby > 0:
			_chord_reveal(logical_cell)
		else:
			logical_cell.defuse()
	elif logical_cell.is_explored() and logical_cell.nearby > 0:
		_chord_reveal(logical_cell)
	else:
		if not _is_game_started:
			_first_move(logical_cell)
		logical_cell.explore()
		if logical_cell.nearby == 0:
			_explore_nearby(logical_cell)


## Chord reveal: if number of defused neighbors equals cell's nearby count,
## reveal all remaining un-explored, un-defused neighbors.
func _chord_reveal(cell: CellBase) -> void:
	var defused: int = 0
	var to_reveal: Array[CellBase] = []
	for neighbor: CellBase in _get_nearby_cells(cell).keys():
		if neighbor.is_defused():
			defused += 1
		elif not neighbor.is_explored():
			to_reveal.append(neighbor)
	if defused != cell.nearby or to_reveal.is_empty():
		return

	to_reveal.sort_custom(
		func(a: CellBase, b: CellBase) -> bool:
			return a.coord.distance_to(cell.coord) < b.coord.distance_to(cell.coord)
	)
	var tween: Tween = _create_tween()
	for neighbor: CellBase in to_reveal:
		var nc: CellBase = neighbor
		tween.tween_callback(
			func():
				nc.explore()
				if nc.nearby == 0:
					_explore_nearby(nc)
		).set_delay(REVEAL_DELAY_FACTOR)


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

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if GlobalState.board_seed != 0:
		rng.seed = GlobalState.board_seed
	# Fisher-Yates shuffle with seeded RNG for repeatable layouts
	for i: int in range(valid_indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = valid_indices[i]
		valid_indices[i] = valid_indices[j]
		valid_indices[j] = tmp

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
