extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	$CanvasLayer/GameGUI/OptionPanel/OpenMenu.connect("toggled", open_menu)


func open_menu(toggle):
	if toggle:
		$CanvasLayer/GameGUI/OptionPanel/AnimationPlayer.play("open_menu")
	else:
		$CanvasLayer/GameGUI/OptionPanel/AnimationPlayer.play_backwards("open_menu")
