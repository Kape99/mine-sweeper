extends Node

var _defusing: bool = false

#var background_color: Color = Color("734f9a")
#var base_color: Color = Color("965fd4")
#var accent_color: Color = Color("8bd450")


class GameData:
	var cols: int
	var rows: int
	var mines: int

	func _init(cols, rows, mines):
		self.cols = cols
		self.rows = rows
		self.mines = mines


var selected_difficulty = 1
var difficulties: Dictionary = {0: Vector3i(9, 12, 50), 1: Vector3i(13, 18, 40), 2: Vector3i(19, 22, 150)}

var board: Dictionary = {
	0: [GameData.new(11, 12, 15), GameData.new(15, 16, 35), GameData.new(19, 20, 80)],
	1: [GameData.new(9, 12, 15), GameData.new(10, 18, 35), GameData.new(13, 22, 80)],
	2: [GameData.new(9, 13, 15), GameData.new(10, 18, 35), GameData.new(13, 22, 80)]
}


class ColorScheme:
	var background: Color
	var main: Color
	var secondary: Color
	var accent: Color

	func _init(background, main, secondary, accent):
		self.back = background
		self.main = main
		self.secondary = secondary
		self.accent = accent


var color_schemes: Dictionary

var selected_board: int = 1

# silvia
var background_color: Color = Color("C1D8C3")
var main_color: Color = Color("CD5C08")
var secondary_color: Color = Color("F5E8B7")
var accent_color: Color = Color("6A9C89")

## silvia
#var background_color: Color = Color("C1D8C3")
#var main_color: Color = Color("6A9C89")
#var secondary_color: Color = Color("F5E8B7")
#var accent_color: Color = Color("F5E8B7")

## Big-Bubble
#var background_color: Color = Color("FFDFDF")
#var main_color: Color = Color("FFF6F6")
#var secondary_color: Color = Color("F875AA")
#var accent_color: Color = Color("AEDEFC")

## Green-Orange
#var background_color: Color = Color("A6CF98")
#var main_color: Color = Color("F2FFE9")
#var secondary_color: Color = Color("557C55")
#var accent_color: Color = Color("FA7070")

## rosa
#var background_color: Color = Color("F4BF96")
#var main_color: Color = Color("CE5A67")
#var secondary_color: Color = Color("1F1717")
#var accent_color: Color = Color("FCF5ED")

## browns
#var background_color: Color = Color("EBE3D5")
#var main_color: Color = Color("B0A695")
#var secondary_color: Color = Color("F3EEEA")
#var accent_color: Color = Color("776B5D")

## Ukraine
#var background_color: Color = Color("0C356A")
#var main_color: Color = Color("0174BE")
#var secondary_color: Color = Color("FFC436")
#var accent_color: Color = Color("FFF0CE")


func _ready():
	RenderingServer.set_default_clear_color(background_color)


func get_game_data() -> GameData:
	return board.get(selected_board)[selected_difficulty]


func get_cols():
	return difficulties[selected_difficulty].x


func get_rows():
	return difficulties[selected_difficulty].y


func get_mines():
	return difficulties[selected_difficulty].z
