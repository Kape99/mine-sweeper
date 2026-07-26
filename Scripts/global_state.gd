## Global singleton managing game configuration, difficulty, board type, and color schemes.
## Registered as an autoload named "GlobalState".
extends Node


## Stores column, row, and mine counts for a single difficulty level.
class GameData:
	var cols: int
	var rows: int
	var mines: int
	

	func _init(p_cols: int, p_rows: int, p_mines: int) -> void:
		cols = p_cols
		rows = p_rows
		mines = p_mines


## Whether the player is currently in defuse (flag) mode.
var is_defusing: bool = false

## Index of the currently selected difficulty (0 = Easy, 1 = Medium, 2 = Hard).
var selected_difficulty: int = 1

## Index of the currently selected board shape (0 = Triangle, 1 = Square, 2 = Hexagon).
var selected_board: int = 1

var no_border: bool = false

## Game configurations per board type. Key: board index, Value: array of [GameData]
## ordered by difficulty (Easy, Medium, Hard).
var board_configs: Dictionary = {
	0: [GameData.new(11, 12, 15), GameData.new(15, 16, 35), GameData.new(19, 20, 80)],
	1: [GameData.new(9, 12, 15), GameData.new(10, 18, 35), GameData.new(13, 22, 80)],
	2: [GameData.new(9, 13, 15), GameData.new(10, 18, 35), GameData.new(13, 22, 80)],
}

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
var selected_scheme: String = "silvia"

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


## Returns the [GameData] for the currently selected board and difficulty.
func get_game_data() -> GameData:
	return board_configs.get(selected_board)[selected_difficulty]
