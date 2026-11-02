## Verifies that holding a cell toggles defuse (flag) without emitting
## the normal cell_pressed tap signal.
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

	assert_true(cell.is_defused(), "Long press toggles defuse on unknown cell")
	assert_eq(pressed_count, 0, "Long press does not emit cell_pressed")

	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2.ZERO
	release.index = 0
	cell._on_area_2d_input_event(null, release, 0)

	assert_eq(pressed_count, 0, "Release after long press still does not emit cell_pressed")
	assert_true(cell.is_defused(), "Cell remains defused after release")

	cell.free()
