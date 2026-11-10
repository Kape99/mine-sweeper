## Adjusts margins to respect the device's safe area (notches, rounded corners).
## Scales margins relative to a base resolution of 480×800.
extends MarginContainer

## Base resolution used to compute scaling factors.
const BASE_WIDTH: float = 480.0
const BASE_HEIGHT: float = 800.0

## Default padding added to each margin in logical pixels.
const BASE_PADDING: float = 10.0


func _ready() -> void:
	var window_size: Vector2i = DisplayServer.window_get_size()
	var window_rect: Rect2i = Rect2i(DisplayServer.window_get_position(), window_size)
	var insets: Dictionary = safe_area_insets(DisplayServer.get_display_safe_area(), window_rect)

	var scale_factor_x: float = float(window_size.x) / BASE_WIDTH
	var scale_factor_y: float = float(window_size.y) / BASE_HEIGHT

	var top: float = BASE_PADDING + insets.top / scale_factor_y
	var left: float = BASE_PADDING + insets.left / scale_factor_x
	var bottom: float = BASE_PADDING + insets.bottom / scale_factor_y
	var right: float = BASE_PADDING + insets.right / scale_factor_x

	add_theme_constant_override("margin_top", int(top))
	add_theme_constant_override("margin_left", int(left))
	add_theme_constant_override("margin_right", int(right))
	add_theme_constant_override("margin_bottom", int(bottom))


## How far the safe area reaches into the window from each edge, in
## physical pixels. [param safe_area] is in screen coordinates (as
## [method DisplayServer.get_display_safe_area] returns it), so it is
## clipped to [param window_rect] first. Without that, on a desktop with
## the window on a second monitor (e.g. starting at x = 1920) the monitor
## offset was taken as a ~1900 px left inset, pushing the HUD off-screen.
static func safe_area_insets(safe_area: Rect2i, window_rect: Rect2i) -> Dictionary:
	var safe: Rect2i = safe_area.intersection(window_rect)
	if not safe.has_area():
		return {"top": 0, "left": 0, "bottom": 0, "right": 0}
	return {
		"top": safe.position.y - window_rect.position.y,
		"left": safe.position.x - window_rect.position.x,
		"bottom": window_rect.end.y - safe.end.y,
		"right": window_rect.end.x - safe.end.x,
	}
