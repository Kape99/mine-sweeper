## Text entry for touchscreen web builds.
##
## Godot draws its text fields on a canvas, and mobile browsers only open
## their on-screen keyboard for a focused HTML input, so tapping a
## [LineEdit] in a mobile browser never brings up a keyboard. (The export
## option [code]html/experimental_virtual_keyboard[/code] is unreliable:
## the keyboard may open but the typed text often never reaches the field.)
##
## On a touchscreen web build, a field passed to [method attach] asks for
## its text with the browser's own prompt dialog instead, which always gets
## the native keyboard. Everywhere else (desktop web, Android, desktop) the
## field is left untouched and works as usual.
class_name WebTextInput
extends RefCounted


## True when text fields need the prompt fallback.
static func is_needed() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


## Makes a tap on [param edit] open a browser prompt titled [param title]
## (touchscreen web only). The result is written to the field and
## [signal LineEdit.text_changed] is emitted, as if it had been typed.
static func attach(edit: LineEdit, title: String) -> void:
	if not is_needed():
		return
	edit.virtual_keyboard_enabled = false
	edit.gui_input.connect(func(event: InputEvent) -> void: _on_gui_input(event, edit, title))


static func _on_gui_input(event: InputEvent, edit: LineEdit, title: String) -> void:
	# A tap arrives as a touch and as an emulated mouse click; react to the
	# mouse release only, so the prompt opens once. Swallow the rest so the
	# field doesn't take focus and try to show Godot's own keyboard.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		edit.accept_event()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	edit.accept_event()
	if event.pressed:
		return
	edit.release_focus()
	var value: Variant = JavaScriptBridge.eval(
		"window.prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(edit.text)], true)
	if value == null:  # cancelled
		return
	var text: String = str(value).strip_edges()
	if edit.max_length > 0:
		text = text.left(edit.max_length)
	edit.text = text
	edit.text_changed.emit(text)
