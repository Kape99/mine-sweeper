extends Camera2D


func _unhandled_input(event):
	limit_smoothed
	if event is InputEventScreenDrag:
		position -= event.relative
		print(position, offset, limit_smoothed)

		print($"../TriangleBoard".get_board_size())
