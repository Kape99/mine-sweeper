## One game palette. Each scheme is saved as a .tres under
## res://Asset/ColorSchemes/ and registered in [member GlobalState.color_schemes],
## so it can be edited with color pickers in the inspector.
class_name ColorScheme
extends Resource

## Highest possible mine count around a cell (a triangle cell has 12
## neighbors). Number styling is spread over 1 to this.
const MAX_COUNT: int = 12

@export_group("Board")
## Screen clear color; also shows through the gaps between cells.
@export var background: Color = Color.WHITE
## Fill of cells not revealed yet, flagged ones included.
@export var unrevealed: Color = Color.GRAY
## Fill of revealed safe cells. Number colors must read well on it.
@export var revealed: Color = Color.WHITE
## Flag icon on flagged cells, drawn over [member unrevealed].
@export var flag: Color = Color.BLACK
## Exploded mine fill, and the flag color of wrongly placed flags at game
## over. Keep it distinct from [member flag]. The mine icon is drawn white
## on top of it.
@export var danger: Color = Color.RED
## Fill of the unrevealed neighbors of a held revealed cell.
@export var highlight: Color = Color.YELLOW
## Number color for a count of 1. Higher counts blend toward
## [member number_dark], reaching it at [constant MAX_COUNT]. Must stay
## readable on [member revealed].
@export var number_light: Color = Color.GRAY
## Number color for a count of [constant MAX_COUNT].
@export var number_dark: Color = Color.BLACK

@export_group("HUD")
## Bar behind the mine counter and timer; also tints the defuse button.
@export var accent: Color = Color.WHITE
## Text and icon color of the mine counter and timer, drawn over [member accent].
@export var hud_text: Color = Color.BLACK


## Color for a revealed cell showing [param count] nearby mines.
func get_number_color(count: int) -> Color:
	return number_light.lerp(number_dark, number_level(count))


## Where [param count] sits on the 1 → [constant MAX_COUNT] scale, from
## 0.0 to 1.0. Shared by the number color and the number size (see
## [method CellBase.number_font_size]) so both grow together.
static func number_level(count: int) -> float:
	return clampf(float(count - 1) / float(MAX_COUNT - 1), 0.0, 1.0)
