## Draws the wrap-mode copies of the logical board without creating a node
## per copied cell.
##
## The copies used to be 8 full tiles of display-only Control nodes (4
## nodes per cell, ~80k nodes on a 50×50 board), which dominated build,
## first-frame and teardown time. Instead, each copy is split into
## [constant CHUNK_SIZE]² chunks; every chunk is one Node2D whose
## [method CanvasItem._draw] paints its cells straight from the logical
## cells' current visuals. A cell change only redraws the chunk containing
## it (in each copy), and per-chunk bounds keep viewport culling effective.
##
## Because every copy reads the real cell's colors, text and icon at draw
## time, copies can't drift out of sync with the center tile.
class_name BoardCopyRenderer
extends Node2D

## Cells per chunk side. Smaller = cheaper redraw per change, more nodes.
const CHUNK_SIZE: int = 8

var _board: BaseBoard
var _offsets: Array[Vector2] = []

## Chunk nodes, indexed [copy][chunk_row * _chunk_cols + chunk_col].
var _chunks: Array = []
var _chunk_cols: int = 0

## Per-cell-scene layout (see [method CellBase.get_render_layout]), keyed
## by scene path. Filled lazily on first draw, when cells are laid out.
var _layouts: Dictionary = {}


## Creates one set of chunks per offset. [param offsets] are the copies'
## positions relative to the logical tile.
func setup(board: BaseBoard, offsets: Array[Vector2]) -> void:
	_board = board
	_offsets = offsets
	_chunk_cols = ceili(board.cols / float(CHUNK_SIZE))
	var chunk_rows: int = ceili(board.rows / float(CHUNK_SIZE))
	for offset: Vector2 in offsets:
		var copy_chunks: Array[CopyChunk] = []
		for chunk_row: int in chunk_rows:
			for chunk_col: int in _chunk_cols:
				var origin: Vector2i = Vector2i(chunk_col, chunk_row) * CHUNK_SIZE
				var cell_range: Rect2i = Rect2i(origin, Vector2i(
					mini(CHUNK_SIZE, board.cols - origin.x),
					mini(CHUNK_SIZE, board.rows - origin.y)
				))
				var chunk: CopyChunk = CopyChunk.new(self, cell_range)
				chunk.position = offset
				add_child(chunk)
				copy_chunks.append(chunk)
		_chunks.append(copy_chunks)


## Positions of the copies relative to the logical tile.
func get_offsets() -> Array[Vector2]:
	return _offsets


## Schedules a redraw of every copy of the cell at [param coord].
func mark_dirty(coord: Vector2i) -> void:
	var idx: int = _chunk_index(coord)
	for copy_chunks: Array[CopyChunk] in _chunks:
		copy_chunks[idx].request_redraw()


## True while any copy of [param coord] has a redraw scheduled but not yet
## performed. Mainly for tests.
func is_redraw_pending(coord: Vector2i) -> bool:
	var idx: int = _chunk_index(coord)
	for copy_chunks: Array[CopyChunk] in _chunks:
		if copy_chunks[idx].redraw_pending:
			return true
	return false


## What a copy of [param cell] looks like — exactly what gets drawn.
func get_cell_visual(cell: CellBase) -> Dictionary:
	return {
		"fill": cell.get_fill_color(),
		"text": cell.get_text(),
		"text_modulate": cell.get_text_modulate(),
		"icon": cell.get_icon(),
		"icon_modulate": cell.get_icon_modulate(),
	}


func _chunk_index(coord: Vector2i) -> int:
	return (coord.y / CHUNK_SIZE) * _chunk_cols + coord.x / CHUNK_SIZE


## Draws the logical cells in [param cell_range] onto [param canvas].
func _draw_cells(canvas: CanvasItem, cell_range: Rect2i) -> void:
	if _board == null or _board.board_state.is_empty():
		return
	for row: int in range(cell_range.position.y, cell_range.end.y):
		var board_row: Array = _board.board_state[row]
		for col: int in range(cell_range.position.x, cell_range.end.x):
			_draw_cell(canvas, board_row[col])
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_cell(canvas: CanvasItem, cell: CellBase) -> void:
	var layout: Dictionary = _get_layout(cell)
	# Cells sit at the same grid position in every copy as in the center tile.
	canvas.draw_set_transform(cell.position)
	canvas.draw_colored_polygon(layout.polygon, cell.get_fill_color())

	var text: String = cell.get_text()
	if not text.is_empty():
		_draw_text(canvas, layout, cell, text)
		canvas.draw_set_transform(cell.position)

	var icon: Texture2D = cell.get_icon()
	if icon:
		canvas.draw_texture_rect(icon, _icon_draw_rect(layout, icon), false, cell.get_icon_modulate())


## Mirrors how [Label] draws a single centered line, pixel for pixel: the
## label's local position is pixel-snapped (see [method _snap]), and the
## glyph offset inside it stays integral (truncated centering, baseline at
## the font ascent), as in Label's own draw code.
func _draw_text(canvas: CanvasItem, layout: Dictionary, cell: CellBase, text: String) -> void:
	var font: Font = layout.font
	var font_size: int = layout.font_size
	var rect: Rect2 = cell.get_text_rect()
	canvas.draw_set_transform(cell.position + layout.content_xform * _snap(rect.position))
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent: float = font.get_ascent(font_size)
	var line_height: float = ascent + font.get_descent(font_size)
	var x: int = int(rect.size.x - text_width) / 2
	var y: int = int(rect.size.y - line_height) / 2
	canvas.draw_string(font, Vector2(x, y + ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		layout.font_color * cell.get_text_modulate())


## Mirrors [TextureRect]'s stretch modes for the modes the cell scenes use.
func _icon_draw_rect(layout: Dictionary, icon: Texture2D) -> Rect2:
	var rect: Rect2 = layout.icon_rect
	var tex_size: Vector2 = icon.get_size()
	match layout.icon_stretch:
		TextureRect.STRETCH_KEEP:
			return Rect2(rect.position, tex_size)
		TextureRect.STRETCH_KEEP_CENTERED:
			return Rect2(rect.position + (rect.size - tex_size) / 2.0, tex_size)
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var fitted: Vector2 = tex_size * minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
			var ofs: Vector2 = Vector2.ZERO
			if layout.icon_stretch == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				ofs = (rect.size - fitted) / 2.0
			return Rect2(rect.position + ofs, fitted)
		_:
			return rect


func _get_layout(cell: CellBase) -> Dictionary:
	var key: String = cell.scene_file_path
	if not _layouts.has(key):
		var layout: Dictionary = cell.get_render_layout()
		layout.content_xform = layout.content_parent_xform * Transform2D(0.0, _snap(layout.content_position))
		layout.icon_rect = Rect2(layout.content_xform * _snap(layout.icon_position), layout.icon_size)
		_layouts[key] = layout
	return _layouts[key]


## Applies Control pixel snapping to a Control's *local* position, as the
## engine does for every Control when "gui/common/snap_controls_to_pixels"
## is on (the default). The cell labels and icons sit at half-pixel local
## offsets, so without this the copies render blurred and half a pixel
## off. Halves round up, matching the engine (verified by pixel comparison).
func _snap(local_position: Vector2) -> Vector2:
	if not ProjectSettings.get_setting("gui/common/snap_controls_to_pixels", true):
		return local_position
	return (local_position + Vector2(0.5, 0.5)).floor()


## One chunk of one copy. Holds no cell state of its own.
class CopyChunk:
	extends Node2D

	var renderer: BoardCopyRenderer
	var cell_range: Rect2i
	var redraw_pending: bool = true

	func _init(p_renderer: BoardCopyRenderer, p_cell_range: Rect2i) -> void:
		renderer = p_renderer
		cell_range = p_cell_range

	func request_redraw() -> void:
		redraw_pending = true
		queue_redraw()

	func _draw() -> void:
		redraw_pending = false
		renderer._draw_cells(self, cell_range)
