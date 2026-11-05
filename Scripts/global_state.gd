## Global singleton managing game configuration, board type, and color schemes.
## Registered as an autoload named "GlobalState".
extends Node


## Whether the player is currently in defuse (flag) mode.
var is_defusing: bool = false

## Index of the currently selected board shape (0 = Triangle, 1 = Square, 2 = Hexagon).
var selected_board: int = 1

## Difficulty presets shown in the main menu, in cycle order. Each value
## is [rows, cols, bomb percentage 0–1]. Board settings not matching any
## preset report as "Custom" (see [method get_difficulty]).
const DIFFICULTY_NAMES: PackedStringArray = ["Easy", "Medium", "Hard"]
const DIFFICULTY_PRESETS: Dictionary = {
	"Easy": [9, 9, 0.12],
	"Medium": [16, 16, 0.16],
	"Hard": [24, 24, 0.20],
}

## Custom board dimensions, bomb density, and random seed. Editable raw
## in the debug settings; defaults are the Medium preset.
var board_rows: int = 16
var board_cols: int = 16
var bomb_percentage: float = 0.16  # 0.0 - 1.0
## Seed for a shared, repeatable board, as a short alphanumeric string
## (e.g. "ZURU7"). Empty = random board each game. A non-empty seed
## gives everyone the same layout and the same center opening.
var board_seed: String = ""

## Whether the board wraps on itself (toroidal) or has hard edges (classic).
var board_wrap: bool = true

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


## Numeric seed derived from [member board_seed] for the RNG, or 0 when
## the game should be random (empty seed).
func get_seed_value() -> int:
	return absi(board_seed.hash()) if not board_seed.is_empty() else 0


## Applies a named difficulty preset to the board settings.
func apply_difficulty(difficulty: String) -> void:
	var preset: Array = DIFFICULTY_PRESETS[difficulty]
	board_rows = preset[0]
	board_cols = preset[1]
	bomb_percentage = preset[2]


## Name of the preset matching the current board settings, or "Custom".
func get_difficulty() -> String:
	for difficulty: String in DIFFICULTY_NAMES:
		var preset: Array = DIFFICULTY_PRESETS[difficulty]
		if board_rows == preset[0] and board_cols == preset[1] and is_equal_approx(bomb_percentage, preset[2]):
			return difficulty
	return "Custom"