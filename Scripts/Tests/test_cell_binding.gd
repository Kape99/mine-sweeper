## Verifies CellBase._bind_collision_shape(): the collision polygon is
## derived from the visible fill polygon (same vertex count, strictly
## larger area, non-empty) for every cell scene in the project.
extends TestCase

const CELL_SCENES: PackedStringArray = [
	"res://Scenes/Cells/square_cell.tscn",
	"res://Scenes/Cells/hexagonal_cell.tscn",
	"res://Scenes/Cells/hexagonal_cell_variant.tscn",
	"res://Scenes/Cells/up_triangle_cell.tscn",
	"res://Scenes/Cells/down_triangle_cell.tscn",
]


func run() -> void:
	for path: String in CELL_SCENES:
		_test_cell(path)


func _test_cell(path: String) -> void:
	var name: String = path.get_file().get_basename()
	var cell: CellBase = load(path).instantiate()
	add_child(cell)

	var fill: Polygon2D = cell.get_node("Area2D/Polygon2D")
	var collision: CollisionPolygon2D = cell.get_node("Area2D/CollisionPolygon2D")

	assert_false(collision.polygon.is_empty(), "%s: collision polygon is non-empty" % name)
	assert_eq(collision.polygon.size(), fill.polygon.size(),
		"%s: collision has same vertex count as fill" % name)

	var fill_area: float = _polygon_area(fill.polygon)
	var collision_area: float = _polygon_area(collision.polygon)
	assert_gt(collision_area, fill_area, "%s: collision area is larger than fill area" % name)

	cell.free()


## Shoelace formula for polygon area.
func _polygon_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	var n: int = points.size()
	for i: int in n:
		var j: int = (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	return absf(area) / 2.0
