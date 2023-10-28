extends Control


func _on_defuse_toggle_toggled(toggled_on):
	GlobaState._defusing = toggled_on


func _on_triangle_board_on_defuse_changed(defuse_value):
	$MarginContainer/VBoxContainer/Label.text = str(defuse_value) + "/" + str(mine)


var mine = 0


func _on_triangle_board_on_game_started(mines_number):
	mine = mines_number


func _on_button_pressed():
	$MarginContainer/VBoxContainer/TriangleBoard.reset()
