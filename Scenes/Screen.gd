## Adjusts margins to respect the device's safe area (notches, rounded corners).
## Scales margins relative to a base resolution of 480×800.
extends MarginContainer

## Base resolution used to compute scaling factors.
const BASE_WIDTH: float = 480.0
const BASE_HEIGHT: float = 800.0

## Default padding added to each margin in logical pixels.
const BASE_PADDING: float = 10.0


func _ready() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	var scale_factor_x: float = float(window_size.x) / BASE_WIDTH
	var scale_factor_y: float = float(window_size.y) / BASE_HEIGHT

	var top: float = BASE_PADDING + maxf(0.0, safe_area.position.y / scale_factor_y)
	var left: float = BASE_PADDING + maxf(0.0, safe_area.position.x / scale_factor_x)
	var bottom: float = BASE_PADDING + maxf(0.0, (window_size.y - safe_area.end.y) / scale_factor_y)
	var right: float = BASE_PADDING + maxf(0.0, (window_size.x - safe_area.end.x) / scale_factor_x)

	add_theme_constant_override("margin_top", int(top))
	add_theme_constant_override("margin_left", int(left))
	add_theme_constant_override("margin_right", int(right))
	add_theme_constant_override("margin_bottom", int(bottom))
