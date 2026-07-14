extends Node

var _defusing: bool = false


class GameData:
	var cols: int
	var rows: int
	var mines: int

	func _init(cols, rows, mines):
		self.cols = cols
		self.rows = rows
		self.mines = mines


var selected_difficulty = 1
var board: Dictionary = {
	0: [GameData.new(11, 12, 15), GameData.new(15, 16, 35), GameData.new(19, 20, 80)],
	1: [GameData.new(9, 12, 15), GameData.new(10, 18, 35), GameData.new(13, 22, 80)],
	2: [GameData.new(9, 13, 15), GameData.new(10, 18, 35), GameData.new(13, 22, 80)]
}


var selected_board: int = 1

var color_schemes: Dictionary = {
	"silvia": [Color("C1D8C3"), Color("CD5C08"), Color("F5E8B7"), Color("6A9C89")],
	"silvia_alt": [Color("C1D8C3"), Color("6A9C89"), Color("F5E8B7"), Color("F5E8B7")],
	"big_bubble": [Color("FFDFDF"), Color("FFF6F6"), Color("F875AA"), Color("AEDEFC")],
	"green_orange": [Color("A6CF98"), Color("F2FFE9"), Color("557C55"), Color("FA7070")],
	"rosa": [Color("F4BF96"), Color("CE5A67"), Color("1F1717"), Color("FCF5ED")],
	"browns": [Color("EBE3D5"), Color("B0A695"), Color("F3EEEA"), Color("776B5D")],
	"ukraine": [Color("0C356A"), Color("0174BE"), Color("FFC436"), Color("FFF0CE")],
}

var selected_scheme: String = "silvia"

var background_color: Color:
	get: return color_schemes[selected_scheme][0]
var main_color: Color:
	get: return color_schemes[selected_scheme][1]
var secondary_color: Color:
	get: return color_schemes[selected_scheme][2]
var accent_color: Color:
	get: return color_schemes[selected_scheme][3]


func _ready():
	RenderingServer.set_default_clear_color(background_color)


func get_game_data() -> GameData:
	return board.get(selected_board)[selected_difficulty]
