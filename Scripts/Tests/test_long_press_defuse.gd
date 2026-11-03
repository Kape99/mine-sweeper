## Verifies that holding a cell toggles defuse (flag) only on release,
## not during the hold, and not at all if the finger drags away.
extends TestCase

const CELL_SCENE: String = "res://Scenes/Cells/square_cell.tscn"


func _ready() -> void:
	print("\n=== test_long_press_defuse ===")
	await run()
	_report()


func run() -> void:
	var cell: CellBase = load(CELL_SCENE).instantiate()
	add_child(cell)

	var pressed_count: int = 0
	cell.cell_pressed.connect(func(_c: CellBase, _n: int) -> void: pressed_count += 1)

	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2.ZERO
	press.index = 0
	cell._on_area_2d_input_event(null, press, 0)

	await wait_wall_ms(CellBase.LONG_PRESS_THRESHOLD_MS + 150)

	# Long press must NOT defuse while still held; defuse happens on release.
	assert_false(cell.is_defused(), "Long press does not defuse while still held")
	assert_eq(pressed_count, 0, "Long press does not emit cell_pressed while held")

	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2.ZERO
	release.index = 0
	cell._on_area_2d_input_event(null, release, 0)

	assert_true(cell.is_defused(), "Long press defuses on release")
	assert_eq(pressed_count, 0, "Release after long press still does not emit cell_pressed")

	# --- Drag cancels long-press defuse ---

	var cell2: CellBase = load(CELL_SCENE).instantiate()
	add_child(cell2)

	var press2: InputEventScreenTouch = InputEventScreenTouch.new()
	press2.pressed = true
	press2.position = Vector2.ZERO
	press2.index = 0
	cell2._on_area_2d_input_event(null, press2, 0)

	# Drag beyond the tap threshold while holding.
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(CellBase.TAP_THRESHOLD + 10, 0)
	drag.index = 0
	cell2._on_area_2d_input_event(null, drag, 0)

	await wait_wall_ms(CellBase.LONG_PRESS_THRESHOLD_MS + 150)

	var release2: InputEventScreenTouch = InputEventScreenTouch.new()
	release2.pressed = false
	release2.position = drag.position
	release2.index = 0
	cell2._on_area_2d_input_event(null, release2, 0)

	assert_false(cell2.is_defused(), "Drag cancels long-press defuse")

	cell.free()
	cell2.free()
