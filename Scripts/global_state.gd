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
	0: [GameData.new(9, 12, 5), GameData.new(9, 12, 5), GameData.new(9, 12, 5)],
	1: [GameData.new(9, 12, 5), GameData.new(9, 12, 5), GameData.new(9, 12, 5)],
	2: [GameData.new(9, 12, 5), GameData.new(9, 12, 5), GameData.new(9, 12, 5)]
}

var selected_board: int = 1

#var background_color: Color = Color.DIM_GRAY
#var base_color: Color = Color.WEB_GRAY
#var accent_color: Color = Color.DARK_ORANGE

# silvia
var background_color: Color = Color("C1D8C3")
var base_color: Color = Color("6A9C89")
var accent_color: Color = Color("F5E8B7")


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
