extends Node

var _defusing: bool = false

var background_color: Color = Color("734f9a")
var base_color: Color = Color("965fd4")
var accent_color: Color = Color("8bd450")

var selected_difficulty = 1
var difficulties: Dictionary = {0: Vector3i(7, 8, 10), 1: Vector3i(13, 18, 40), 2: Vector3i(19, 22, 70)}

#var background_color: Color = Color.DIM_GRAY
#var base_color: Color = Color.WEB_GRAY
#var accent_color: Color = Color.DARK_ORANGE

enum difficulty { Easy, Medium, Hard }


func _ready():
	RenderingServer.set_default_clear_color(background_color)


func get_cols():
	return difficulties[selected_difficulty].x


func get_rows():
	return difficulties[selected_difficulty].y


func get_mines():
	return difficulties[selected_difficulty].z
