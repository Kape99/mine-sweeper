extends Node

var _defusing: bool = false

var background_color: Color = Color("734f9a")
var base_color: Color = Color("965fd4")
var accent_color: Color = Color("8bd450")

#var background_color: Color = Color.DIM_GRAY
#var base_color: Color = Color.WEB_GRAY
#var accent_color: Color = Color.DARK_ORANGE

enum difficulty { Easy, Medium, Hard }


func _ready():
	RenderingServer.set_default_clear_color(background_color)
