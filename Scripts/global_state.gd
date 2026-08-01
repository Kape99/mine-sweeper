## Global singleton managing game configuration, board type, and color schemes.
## Registered as an autoload named "GlobalState".
extends Node


## Whether the player is currently in defuse (flag) mode.
var is_defusing: bool = false

## Index of the currently selected board shape (0 = Triangle, 1 = Square, 2 = Hexagon).
var selected_board: int = 1

## Custom board dimensions, bomb density, and random seed.
var board_rows: int = 18
var board_cols: int = 18
var bomb_percentage: float = 0.15  # 0.0 - 1.0
var board_seed: int = 0  # 0 = random, non-zero = repeatable

## Whether the board wraps on itself (toroidal) or has hard edges (classic).
var board_wrap: bool = true

## Whether board cells should render without a visible border.
var no_border: bool = false

## Available color schemes. Each value is [background, main, secondary, accent].
var color_schemes: Dictionary = {
	"silvia": [Color("C1D8C3"), Color("CD5C08"), Color("F5E8B7"), Color("6A9C89")],
	"silvia_alt": [Color("C1D8C3"), Color("6A9C89"), Color("F5E8B7"), Color("F5E8B7")],
	"big_bubble": [Color("FFDFDF"), Color("FFF6F6"), Color("F875AA"), Color("AEDEFC")],
	"green_orange": [Color("A6CF98"), Color("F2FFE9"), Color("557C55"), Color("FA7070")],
	"rosa": [Color("F4BF96"), Color("CE5A67"), Color("1F1717"), Color("FCF5ED")],
	"browns": [Color("EBE3D5"), Color("B0A695"), Color("F3EEEA"), Color("776B5D")],
	"ukraine": [Color("0C356A"), Color("0174BE"), Color("FFC436"), Color("FFF0CE")],
}

## Key into [member color_schemes] for the active theme.
var selected_scheme: String = "silvia":
	set(value):
		selected_scheme = value
		RenderingServer.set_default_clear_color(background_color)

## Background color of the active scheme.
var background_color: Color:
	get: return color_schemes[selected_scheme][0]

## Primary color of the active scheme.
var main_color: Color:
	get: return color_schemes[selected_scheme][1]

## Secondary color of the active scheme.
var secondary_color: Color:
	get: return color_schemes[selected_scheme][2]

## Accent color of the active scheme.
var accent_color: Color:
	get: return color_schemes[selected_scheme][3]


func _ready() -> void:
	RenderingServer.set_default_clear_color(background_color)


## Returns mine count computed from board dimensions and bomb percentage.
func get_mine_count() -> int:
	return maxi(1, roundi(board_rows * board_cols * bomb_percentage))