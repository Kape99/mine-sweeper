extends MarginContainer


func _ready():
	var safe_area = DisplayServer.get_display_safe_area()
	var window_size = DisplayServer.window_get_size()

	var scale_factor_x = float(window_size.x) / 480
	var scale_factor_y = float(window_size.y) / 800

	var top = 10 + safe_area.position.y / scale_factor_y
	var left = 10 + safe_area.position.x / scale_factor_x
	var bottom = 10 + (window_size.y - safe_area.end.y) / scale_factor_y
	var right = 10 + (window_size.x - safe_area.end.x) / scale_factor_x

	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
