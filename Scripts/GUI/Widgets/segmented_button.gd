@tool
class_name SegmentedButton
extends HBoxContainer

## Emitted when the selected segment changes.
signal segment_selected(index: int)

## Segment labels, left to right.
@export var segments: PackedStringArray = []:
	set(value):
		segments = value
		_rebuild()

## Index of the currently selected segment.
@export var selected_index: int = 0:
	set(value):
		selected_index = clamp(value, 0, max(0, segments.size() - 1))
		_update_styles()

## If true, the widget captures all horizontal space and each segment expands.
@export var expand: bool = true

## Optional override for the active segment background. Leave alpha negative to use the scheme accent.
@export var active_bg_override: Color = Color(-1, 0, 0, 0)
## Optional override for the active segment text color. Leave alpha negative to use the scheme hud_text.
@export var active_text_override: Color = Color(-1, 0, 0, 0)

var _buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	for i: int in segments.size():
		var btn: Button = Button.new()
		btn.text = segments[i]
		btn.toggle_mode = true
		btn.size_flags_horizontal = SIZE_EXPAND_FILL if expand else SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_button_pressed.bind(i))
		add_child(btn)
		_buttons.append(btn)
	_update_styles()


func _update_styles() -> void:
	for i: int in _buttons.size():
		var btn: Button = _buttons[i]
		var active: bool = i == selected_index
		btn.button_pressed = active
		btn.focus_mode = Control.FOCUS_NONE
		_apply_segment_style(btn, active, i == 0, i == _buttons.size() - 1)


func _apply_segment_style(btn: Button, active: bool, is_first: bool, is_last: bool) -> void:
	var accent: Color = GlobalState.scheme.accent if is_instance_valid(GlobalState) else Color.WHITE
	var text: Color = GlobalState.scheme.hud_text if is_instance_valid(GlobalState) else Color.BLACK
	var bg: Color = accent if active else accent.darkened(0.35)
	var fg: Color = text if active else text.darkened(0.35)
	if active and active_bg_override.a >= 0.0:
		bg = active_bg_override
	if active and active_text_override.a >= 0.0:
		fg = active_text_override

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 8 if is_first else 0
	style.corner_radius_bottom_left = 8 if is_first else 0
	style.corner_radius_top_right = 8 if is_last else 0
	style.corner_radius_bottom_right = 8 if is_last else 0
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", _tint_style(style, 0.05))
	btn.add_theme_stylebox_override("pressed", _tint_style(style, -0.05))
	btn.add_theme_color_override("font_color", fg)


func _tint_style(style: StyleBoxFlat, amount: float) -> StyleBoxFlat:
	var tinted: StyleBoxFlat = style.duplicate()
	tinted.bg_color = tinted.bg_color.lightened(amount)
	return tinted


func _on_button_pressed(index: int) -> void:
	if index == selected_index:
		return
	selected_index = index
	_update_styles()
	segment_selected.emit(index)


## Sets the selection without emitting the signal.
func set_selected(index: int) -> void:
	selected_index = index
	_update_styles()


## Returns the currently selected label.
func get_selected_text() -> String:
	if selected_index < 0 or selected_index >= segments.size():
		return ""
	return segments[selected_index]
