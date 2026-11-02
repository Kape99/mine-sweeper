## Infinite scrolling board with toroidal (wrap-around) topology.
## A single logical board (cols × rows) of interactive cells is the source
## of truth. In wrap mode it is surrounded by the 8 other tiles of a
## [constant TILE_GRID_SIZE] × [constant TILE_GRID_SIZE] block of visual
## copies, drawn by a [BoardCopyRenderer] straight from the logical cells
## (no node per copied cell), so the camera always has buffer content
## around it. When the camera drifts past a single board's edge, the whole
## block is shifted by one board dimension — giving seamless infinite
## scrolling without ever spawning or freeing nodes during gameplay.
class_name BaseBoard
extends Control

const REVEAL_DELAY_FACTOR: float = 0.02
const EXPLOSION_VIBRATION_MS: int = 500

const GRID_H_SEPARATION: int = 4
const GRID_V_SEPARATION: int = 4

## Number of tile copies per axis surrounding (and including) the logical
## board. 3 means a 3×3 block — one ring of buffer tiles around the center.
const TILE_GRID_SIZE: int = 3

## Fraction of a single board's size that triggers a recenter.
const RECENTER_THRESHOLD: float = 0.5

## Extra padding (pixels) added around the board bounds in classic mode,
## matching CameraController's own margin so panning feels consistent.
const PAN_MARGIN: float = 100.0

## Number of interactive cells to pre-create per variant at startup.
const POOL_PREWARM: int = 200

## Preferred radius of the mine-free zone around the first tapped cell.
## Shrinks automatically (down to just the tapped cell) when the board is
## too small to fit the requested mines outside it.
const SAFE_ZONE_DISTANCE: int = 2

@export var cols: int = 10
@export var rows: int = 10
@export var mines: int = 10

@export var cells: Array[PackedScene]

@onready var _board_node: Node2D = $Container

signal on_defuse_changed(defuse_value: int)
signal on_game_started(mines_number: int)
signal on_game_finished(is_win: bool, time: float)

## Static pool of reusable interactive cells, keyed by scene path.
static var _cell_pools: Dictionary = {}

## Whether the static pools have been pre-warmed for this board's variants.
static var _pools_warmed: bool = false

## The logical board — 2D array [row][col] of the real, interactive cells.
var board_state: Array = []

## The Control holding the interactive (logical) cells, or null. Cells
## are positioned directly rather than by a GridContainer: they're all the
## same size, and a GridContainer would re-lay out every cell each time one
## is added, which made building the board in steps quadratic.
var _tile: Control = null

## Draws the wrap-mode copies around [member _tile]; null in classic mode.
var _copy_renderer: BoardCopyRenderer = null

var _cell_size: Vector2 = Vector2.ZERO
var _explored: int = 0
var _defused_count: int = 0
var _is_game_started: bool = false
var _is_game_over: bool = false
var _to_be_explored: int = 0

## Reveal animations currently running. Several waves may overlap (e.g. a
## second tap during a long flood fill) and must not cancel each other.
var _active_tweens: Array[Tween] = []

## When true (default), the board is toroidal — neighbors wrap, camera
## recenter is active, and there are no camera bounds. When false, the
## board has hard edges, the camera is clamped to the board bounds, and
## neighbor lookups stop at the edge.
var _wrap_mode: bool = true

## Long-press tracking for taps on wrap-mode display copies.
var _display_touch_active: bool = false
var _display_touch_start_time: int = 0
var _display_touch_position: Vector2 = Vector2.ZERO
var _display_long_press_triggered: bool = false
var _display_logical_cell: CellBase = null

## Currently highlighted neighbors (from a long-press on a revealed cell).
var _highlighted_neighbors: Array[CellBase] = []

## Incremental build progress (see [method prepare] / [method build_step]):
## row-major index of the next cell to create, and how many there are.
var _build_next: int = 0
var _build_total: int = 0


func _ready() -> void:
	_measure_cell_size()
	_warm_pools()


## Pre-creates a pool of reusable interactive cells for each cell variant.
## Called once per board instance; static flag keeps it from repeating.
func _warm_pools() -> void:
	if _pools_warmed:
		return
	_pools_warmed = true
	for scene: PackedScene in cells:
		warm_pool(scene, POOL_PREWARM)


## Static helper to pre-warm a pool for any board cell scene.
static func warm_pool(scene: PackedScene, count: int) -> void:
	if not scene or _cell_pools.has(scene.resource_path):
		return
	var pool: Array = []
	pool.resize(count)
	for i: int in count:
		pool[i] = scene.instantiate()
	_cell_pools[scene.resource_path] = pool


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
	_kill_active_tweens()
	_explored = 0
	_defused_count = 0
	_is_game_started = false
	_is_game_over = false
	if _copy_renderer:
		_copy_renderer.free()
		_copy_renderer = null
	if _tile:
		for cell: Node in _tile.get_children():
			if cell is CellBase:
				_release_cell(cell)
			else:
				cell.free()
		_tile.free()
		_tile = null
	board_state = []
	_build_next = 0
	_build_total = 0
	_board_node.position = Vector2.ZERO


## Starts a game. If the board was already built for these dimensions with
## [method prepare] (e.g. in the background while the menu was open), that
## build is reused; otherwise the board is built now, in one go.
func start_game(p_cols: int, p_rows: int, p_mines: int, p_wrap: bool = true) -> void:
	if not is_prepared_for(p_cols, p_rows, p_wrap):
		prepare(p_cols, p_rows, p_wrap)
	build_step(-1)
	var requested: Vector2i = Vector2i(p_cols, p_rows)
	mines = p_mines
	if Vector2i(cols, rows) != requested:
		# Keep the requested mine density on the enlarged board.
		mines = roundi(p_mines * float(cols * rows) / float(p_cols * p_rows))
	_to_be_explored = rows * cols - mines


## Clears the board and sets it up for a [param p_cols] × [param p_rows]
## game without creating any cells yet; [method build_step] creates them.
func prepare(p_cols: int, p_rows: int, p_wrap: bool) -> void:
	clear()
	_wrap_mode = p_wrap
	var dims: Vector2i = _get_dimensions(p_cols, p_rows, p_wrap)
	cols = dims.x
	rows = dims.y
	_begin_build()


## Creates cells for at most [param budget_usec] microseconds (all remaining
## cells if negative). Returns true once the board is fully built.
func build_step(budget_usec: int) -> bool:
	if _tile == null:
		return false
	var start: int = Time.get_ticks_usec()
	while _build_next < _build_total:
		_add_cell(_build_next)
		_build_next += 1
		# Checking the clock every few cells keeps its cost negligible.
		if budget_usec >= 0 and _build_next % 4 == 0 and Time.get_ticks_usec() - start >= budget_usec:
			return false
	if not _wrap_mode:
		return true
	if _copy_renderer == null:
		# Built in one go: draw every copy right away. Built in steps: let
		# the copies appear a few chunks per frame (their first draw is the
		# single most expensive part of the build).
		_add_copy_renderer(budget_usec >= 0)
	var remaining: int = budget_usec - (Time.get_ticks_usec() - start) if budget_usec >= 0 else -1
	return _copy_renderer.show_step(maxi(remaining, 0) if budget_usec >= 0 else -1)


## True once every cell exists (and, in wrap mode, every copy is shown).
func is_built() -> bool:
	if _tile == null or _build_next < _build_total:
		return false
	return not _wrap_mode or (_copy_renderer != null and _copy_renderer.is_fully_shown())


## True if this board was prepared for exactly these settings and no game
## has been played on it yet, so [method start_game] can reuse it.
func is_prepared_for(p_cols: int, p_rows: int, p_wrap: bool) -> bool:
	return (
		_tile != null
		and not _is_game_started
		and not _is_game_over
		and p_wrap == _wrap_mode
		and _get_dimensions(p_cols, p_rows, p_wrap) == Vector2i(cols, rows)
	)


## Actual board dimensions for the requested ones (wrap mode may round up).
func _get_dimensions(p_cols: int, p_rows: int, p_wrap: bool) -> Vector2i:
	var requested: Vector2i = Vector2i(p_cols, p_rows)
	return _wrap_safe_dimensions(requested) if p_wrap else requested


## In wrap mode each dimension must be a multiple of this so the cell
## parity pattern (hex row stagger, triangle up/down) stays consistent
## across the seam — otherwise the neighbor relation becomes asymmetric
## there and the displayed numbers stop matching the flood fill / chord
## logic. Override in subclasses whose topology depends on parity.
func _get_wrap_dimension_multiple() -> Vector2i:
	return Vector2i.ONE


## Rounds [param dims] up to the nearest valid wrap-mode size.
func _wrap_safe_dimensions(dims: Vector2i) -> Vector2i:
	var m: Vector2i = _get_wrap_dimension_multiple()
	return Vector2i(ceili(dims.x / float(m.x)) * m.x, ceili(dims.y / float(m.y)) * m.y)


## Rebuilds the board (same dimensions) for a new game, in one go.
func reset() -> void:
	prepare(cols, rows, _wrap_mode)
	build_step(-1)


func _connect_signals(cell: CellBase) -> void:
	if not cell.cell_pressed.is_connected(_on_cell_pressed):
		cell.cell_pressed.connect(_on_cell_pressed)
	if not cell.cell_explored.is_connected(_handle_explored):
		cell.cell_explored.connect(_handle_explored)
	if not cell.cell_defused.is_connected(_handle_defuse):
		cell.cell_defused.connect(_handle_defuse)
	if not cell.cell_exploded.is_connected(_handle_explosion):
		cell.cell_exploded.connect(_handle_explosion)
	if not cell.cell_highlight_requested.is_connected(_on_cell_highlight_requested):
		cell.cell_highlight_requested.connect(_on_cell_highlight_requested)
	if not cell.cell_highlight_cleared.is_connected(_clear_neighbor_highlight):
		cell.cell_highlight_cleared.connect(_clear_neighbor_highlight)


## Pulls a reusable cell from the static pool, or instantiates a new one.
func _acquire_cell(p_idx: int) -> CellBase:
	var scene: PackedScene = cells[p_idx]
	var pool: Array = _cell_pools.get(scene.resource_path, [])
	if not pool.is_empty():
		return pool.pop_back()
	return scene.instantiate()


## Returns an interactive cell to the static pool for reuse.
func _release_cell(cell: CellBase) -> void:
	if cell.cell_pressed.is_connected(_on_cell_pressed):
		cell.cell_pressed.disconnect(_on_cell_pressed)
	if cell.cell_explored.is_connected(_handle_explored):
		cell.cell_explored.disconnect(_handle_explored)
	if cell.cell_defused.is_connected(_handle_defuse):
		cell.cell_defused.disconnect(_handle_defuse)
	if cell.cell_exploded.is_connected(_handle_explosion):
		cell.cell_exploded.disconnect(_handle_explosion)
	if cell.cell_highlight_requested.is_connected(_on_cell_highlight_requested):
		cell.cell_highlight_requested.disconnect(_on_cell_highlight_requested)
	if cell.cell_highlight_cleared.is_connected(_clear_neighbor_highlight):
		cell.cell_highlight_cleared.disconnect(_clear_neighbor_highlight)
	var parent: Node = cell.get_parent()
	if parent:
		parent.remove_child(cell)
	cell.reset_state()
	var pool: Array = _cell_pools.get(cell.scene_file_path, [])
	pool.append(cell)
	_cell_pools[cell.scene_file_path] = pool


## Frees every pooled cell. Useful for tests that would otherwise leak
## CanvasItem RIDs held by off-tree pooled nodes.
static func clear_pools() -> void:
	for pool: Array in _cell_pools.values():
		for cell: CellBase in pool:
			cell.free()
	_cell_pools.clear()
	_pools_warmed = false


## Creates the (empty) interactive tile. Cells are then added by
## [method _add_cell], all at once or spread over frames.
func _begin_build() -> void:
	_tile = Control.new()
	_tile.mouse_filter = Control.MOUSE_FILTER_PASS
	_tile.size = get_board_size() - Vector2(GRID_H_SEPARATION, GRID_V_SEPARATION)
	_board_node.add_child(_tile)
	board_state = []
	_build_next = 0
	_build_total = cols * rows


## Creates the cell at row-major [param index]. Cells are created in order,
## so a new row starts exactly when its first cell is added.
func _add_cell(index: int) -> void:
	var col: int = index % cols
	var row: int = index / cols
	if col == 0:
		board_state.append([])
	var cell_instance: CellBase = _acquire_cell(_get_cell_type_idx(col, row))
	# Same layout a GridContainer would produce: a uniform grid of
	# cell size + separation.
	cell_instance.position = Vector2(
		col * (_cell_size.x + GRID_H_SEPARATION),
		row * (_cell_size.y + GRID_V_SEPARATION)
	)
	cell_instance.size = _cell_size
	_tile.add_child(cell_instance)
	cell_instance.coord = Vector2i(col, row)
	_connect_signals(cell_instance)
	board_state[row].append(cell_instance)


## Adds the renderer that draws the 8 copies around the tile (wrap mode).
## Only done once every cell exists, since it draws from all of them.
func _add_copy_renderer(hidden: bool) -> void:
	_copy_renderer = BoardCopyRenderer.new()
	_board_node.add_child(_copy_renderer)
	# First child, so the copies draw beneath the interactive tile.
	_board_node.move_child(_copy_renderer, 0)
	_copy_renderer.setup(self, _get_copy_offsets(), hidden)


## Offsets of the 8 copies around the logical tile, in board-node space.
func _get_copy_offsets() -> Array[Vector2]:
	var board_size: Vector2 = get_board_size()
	var half: int = TILE_GRID_SIZE / 2
	var offsets: Array[Vector2] = []
	for dy: int in range(-half, half + 1):
		for dx: int in range(-half, half + 1):
			if dx != 0 or dy != 0:
				offsets.append(Vector2(dx * board_size.x, dy * board_size.y))
	return offsets


## Returns the index into the `cells` array for a given (col, row).
## Override in subclasses that use multiple cell types. Copies reuse the
## logical cell's variant, which is consistent across seams because wrap
## mode enforces even dimensions where the pattern depends on parity
## (see [method _get_wrap_dimension_multiple]).
func _get_cell_type_idx(_col: int, _row: int) -> int:
	return 0


## Maps any clicked cell (copy or the real one) back to the logical cell.
func _get_center_cell(cell: CellBase) -> CellBase:
	if board_state.is_empty():
		return cell
	return board_state[cell.coord.y][cell.coord.x]


func _process(_delta: float) -> void:
	if not _display_touch_active or _display_long_press_triggered:
		return
	var elapsed: int = Time.get_ticks_msec() - _display_touch_start_time
	if elapsed <= CellBase.LONG_PRESS_THRESHOLD_MS:
		return
	_display_long_press_triggered = true
	if Settings.vibration_enabled:
		Input.vibrate_handheld(CellBase.LONG_PRESS_VIBRATION_MS)
	if _display_logical_cell and _display_logical_cell.is_explored() and _display_logical_cell.nearby > 0:
		_highlight_neighbors(_display_logical_cell)
	elif _display_logical_cell and not _display_logical_cell.is_explored():
		_display_logical_cell.defuse()


## Handles taps and long-presses on non-center display tiles.
func _unhandled_input(event: InputEvent) -> void:
	if not _wrap_mode or _copy_renderer == null or board_state.is_empty():
		return

	var is_press: bool = (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	var is_release: bool = (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
		or (event is InputEventScreenTouch and not event.pressed)
	)

	if is_press:
		var cell: CellBase = _find_display_logical_cell(event.position)
		if cell:
			_display_touch_active = true
			_display_touch_start_time = Time.get_ticks_msec()
			_display_touch_position = event.position
			_display_long_press_triggered = false
			_display_logical_cell = cell
		return

	if is_release and _display_touch_active:
		_display_touch_active = false
		var cell: CellBase = _display_logical_cell
		_display_logical_cell = null
		var had_long_press: bool = _display_long_press_triggered
		_display_long_press_triggered = false
		_clear_neighbor_highlight()
		if had_long_press:
			return
		if _display_touch_position.distance_to(event.position) < CellBase.TAP_THRESHOLD:
			if Settings.vibration_enabled:
				Input.vibrate_handheld(CellBase.TAP_VIBRATION_MS)
			if cell:
				_on_cell_pressed(cell, cell.nearby)


## Finds the logical cell under a position on a non-center display tile.
func _find_display_logical_cell(global_pos: Vector2) -> CellBase:
	var canvas_pos: Vector2 = get_viewport().canvas_transform.affine_inverse() * global_pos
	var board_size: Vector2 = get_board_size()
	var board_origin: Vector2 = _board_node.global_position
	var cell_step: Vector2 = Vector2(
		_cell_size.x + GRID_H_SEPARATION,
		_cell_size.y + GRID_V_SEPARATION
	)

	for offset: Vector2 in _copy_renderer.get_offsets():
		var tile_origin: Vector2 = board_origin + offset
		var local_pos: Vector2 = canvas_pos - tile_origin
		if local_pos.x < 0 or local_pos.y < 0:
			continue
		if local_pos.x >= board_size.x or local_pos.y >= board_size.y:
			continue
		var col: int = int(local_pos.x / cell_step.x)
		var row: int = int(local_pos.y / cell_step.y)
		if col >= 0 and col < cols and row >= 0 and row < rows:
			return board_state[row][col]
	return null


## Called every frame from the main controller with the camera's current
## offset. The camera itself is never touched here — instead [member
## _board_node] (and its whole tile block) is snapped by exactly one board
## dimension once the camera drifts too far from the block's center.
## Because the surrounding tiles are visual mirrors of the center board,
## snapping the block by a full board size leaves an identical-looking tile
## under the camera, so the jump is imperceptible — giving the illusion of
## infinite scrolling.
func recenter_if_needed(camera_offset: Vector2) -> void:
	if not _wrap_mode or _tile == null or not _is_game_started:
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


## Redraws every copy of [param source] (wrap mode only). Copies read the
## cell's current visuals when drawn, so this only schedules the redraw.
func _sync_display_to_copies(source: CellBase) -> void:
	if _copy_renderer:
		_copy_renderer.mark_dirty(source.coord)


## Highlights the neighbors of [param cell] and all their display copies.
func _highlight_neighbors(cell: CellBase) -> void:
	_clear_neighbor_highlight()
	for neighbor: CellBase in _get_nearby_cells(cell).keys():
		if neighbor.is_explored():
			continue
		neighbor.set_neighbor_highlight(true)
		_highlighted_neighbors.append(neighbor)
		_sync_display_to_copies(neighbor)


## Clears any active neighbor highlight.
func _clear_neighbor_highlight() -> void:
	for neighbor: CellBase in _highlighted_neighbors:
		if not is_instance_valid(neighbor):
			continue
		neighbor.set_neighbor_highlight(false)
		_sync_display_to_copies(neighbor)
	_highlighted_neighbors.clear()


func _on_cell_highlight_requested(cell: CellBase) -> void:
	_highlight_neighbors(_get_center_cell(cell))


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
		_sync_display_to_copies(_cell)
		if Settings.vibration_enabled:
			Input.vibrate_handheld(EXPLOSION_VIBRATION_MS)


func _kill_active_tweens() -> void:
	for tween: Tween in _active_tweens:
		if tween.is_valid():
			tween.kill()
	_active_tweens.clear()


## Starts a new reveal animation alongside any that are still running.
## Overlapping waves are safe: [method CellBase.explore] is a no-op on a
## cell that's already explored or flagged.
func _create_reveal_tween() -> Tween:
	var still_running: Array[Tween] = []
	for tween: Tween in _active_tweens:
		if tween.is_valid():
			still_running.append(tween)
	_active_tweens = still_running
	var new_tween: Tween = create_tween()
	_active_tweens.append(new_tween)
	return new_tween


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
	# Game over: stop any pending reveal waves before showing the mines.
	_kill_active_tweens()
	var tween: Tween = _create_reveal_tween()
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
	# A board being built in the background is paused (see base.gd); it
	# must never start a game from a stray tap.
	if _is_game_over or not can_process():
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
## reveal all remaining un-explored, un-defused neighbors, including any
## zero-cascade cells reachable from them. The whole set is animated in a
## single wave so nested tweens cannot kill each other.
func _chord_reveal(cell: CellBase) -> void:
	var defused: int = 0
	var seeds: Array[CellBase] = []
	for neighbor: CellBase in _get_nearby_cells(cell).keys():
		if neighbor.is_defused():
			defused += 1
		elif not neighbor.is_explored():
			seeds.append(neighbor)
	if defused != cell.nearby or seeds.is_empty():
		return

	var to_reveal: Array[CellBase] = []
	var visited: Dictionary = {}
	var queue: Array[CellBase] = seeds.duplicate()
	for s: CellBase in seeds:
		visited[s] = true
	var head: int = 0
	while head < queue.size():
		var current: CellBase = queue[head]
		head += 1
		to_reveal.append(current)
		if current.nearby == 0:
			for n: CellBase in _get_nearby_cells(current).keys():
				if visited.has(n) or n.is_explored() or n.is_defused():
					continue
				visited[n] = true
				queue.append(n)

	if to_reveal.is_empty():
		return

	to_reveal.sort_custom(
		func(a: CellBase, b: CellBase) -> bool:
			return a.coord.distance_to(cell.coord) < b.coord.distance_to(cell.coord)
	)
	var tween: Tween = _create_reveal_tween()
	for reveal_cell: CellBase in to_reveal:
		var rc: CellBase = reveal_cell
		tween.tween_callback(func(): rc.explore()).set_delay(REVEAL_DELAY_FACTOR)


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
	var tween: Tween = _create_reveal_tween()
	for neighbor_cell: CellBase in to_reveal:
		var nc: CellBase = neighbor_cell
		tween.tween_callback(
			func():
				nc.explore()
		).set_delay(REVEAL_DELAY_FACTOR)


func _place_mines(cell: CellBase) -> void:
	var valid_indices: Array[int] = _get_mine_candidates(cell)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if GlobalState.board_seed != 0:
		rng.seed = GlobalState.board_seed
	# Fisher-Yates shuffle with seeded RNG for repeatable layouts
	for i: int in range(valid_indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = valid_indices[i]
		valid_indices[i] = valid_indices[j]
		valid_indices[j] = tmp

	# The mine count and win target must reflect what was actually placed,
	# otherwise the HUD lies and the win check fires at the wrong time.
	mines = mini(mines, valid_indices.size())
	_to_be_explored = rows * cols - mines
	for i: int in mines:
		var idx: int = valid_indices[i]
		var mine_cell: CellBase = board_state[idx / cols][idx % cols]
		mine_cell.mark_as_mine()
		for neighbor: CellBase in _get_nearby_cells(mine_cell):
			neighbor.increment_nearby()


## Returns row-major indices of cells that may hold a mine. Uses the
## largest safe zone around [param first_cell] (up to [constant
## SAFE_ZONE_DISTANCE]) that still leaves room for every requested mine;
## on tiny or dense boards it shrinks down to excluding only the tapped cell.
func _get_mine_candidates(first_cell: CellBase) -> Array[int]:
	var candidates: Array[int] = []
	for distance: int in range(SAFE_ZONE_DISTANCE, -1, -1):
		var excluded: Dictionary = _get_nearby_cells(first_cell, distance) if distance > 0 else {}
		excluded[first_cell] = true
		candidates.clear()
		for i: int in cols * rows:
			if not excluded.has(board_state[i / cols][i % cols]):
				candidates.append(i)
		if candidates.size() >= mines:
			break
	return candidates


func _get_nearby_cells(_cell: CellBase, _distance: int = 1) -> Dictionary:
	return {}
