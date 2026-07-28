## UI scene controller with animated push/pop transitions.
## Owned by base.tscn; manages MainMenu, SettingsMenu, PauseOverlay, and
## any future screens. Uses a Tween-based slide+fade so transitions feel
## native on mobile.
class_name ScreenManager
extends Control

## How long a push/pop transition takes (seconds).
const TRANSITION_DURATION: float = 0.25

## Easing curve for transitions.
const TRANSITION_EASE: Tween.EaseType = Tween.EASE_IN_OUT
const TRANSITION_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC

@onready var _container: Control = get_parent().get_node("GUI_ScreenManager#Container")
@onready var _tween: Tween

## Currently visible screen, or null.
var _current: Control = null

## Stack of screen paths for pop navigation.
var _history: Array[String] = []

## Screen that was hidden (not destroyed) by a push with
## [code]dismiss_current=false[/code]. Restored on the next pop() when
## the history stack is empty.
var _dismissed_screen: Control = null


func _ready() -> void:
	_tween = create_tween()
	_tween.stop()

	# Don't auto-show MainMenu here — base.gd calls show_main_menu()
	# after wiring the board, so the menu appears only when appropriate.


## Show [param screen] with a slide-in animation from the right.
## [param animated] — false for the first screen (no intro animation).
## [param dismiss_current] — when true (default), the current screen is
## animated out and queued for removal. When false, the current screen is
## hidden immediately (modulate → 0) without being destroyed, so it can
## be restored by a later pop() — used by PauseOverlay pushing Settings.
func push(screen: Control, animated: bool = true, dismiss_current: bool = true) -> void:
	if _current:
		if dismiss_current:
			_history.append(_current.scene_file_path)
			_animate_out(_current, animated)
		else:
			# Hide current in-place (no history entry, no destroy)
			_dismissed_screen = _current
			_current.modulate = Color(1, 1, 1, 0)
			_current.process_mode = Control.PROCESS_MODE_DISABLED
	_show_screen(screen, animated)


## Return to the previous screen in the history stack.
## If the stack is empty (e.g. pushed from a screen not managed by this
## manager, like the embedded main menu), simply dismiss the current
## overlay instead of trying to restore a non-existent previous screen.
func pop() -> bool:
	if _history.is_empty():
		if _current:
			_animate_out(_current, true)
			_current = null
		# Restore a screen that was hidden (not destroyed) by a
		# dismiss_current push — e.g. PauseOverlay underneath Settings.
		if _dismissed_screen and is_instance_valid(_dismissed_screen):
			var restored: Control = _dismissed_screen
			_dismissed_screen = null
			_show_screen(restored, false)
			restored.modulate = Color(1, 1, 1, 1)
			restored.process_mode = Control.PROCESS_MODE_INHERIT
		return true
	var prev_path: String = _history.pop_back()
	var prev: Control = load(prev_path).instantiate()
	if _current:
		_animate_out(_current, true)
	_show_screen(prev, true)
	return true


## Replace the current screen with [param screen] (no history entry).
func replace(screen: Control, animated: bool = true) -> void:
	if _current:
		_animate_out(_current, animated)
	_show_screen(screen, animated)


## Show [param screen] directly, replacing whatever is currently visible,
## and clearing the navigation history.
func reset_stack(screen: Control, animated: bool = true) -> void:
	_clear_history()
	if _current:
		_animate_out(_current, animated)
	_show_screen(screen, animated)


## Show the main menu screen (always-present inline node in base.tscn).
## Clears any open overlays first.
func show_main_menu(main_menu: Control) -> void:
	_clear_history()
	if _dismissed_screen and is_instance_valid(_dismissed_screen):
		_dismissed_screen.modulate = Color(1, 1, 1, 0)
		_dismissed_screen.process_mode = Control.PROCESS_MODE_DISABLED
		_dismissed_screen = null
	if _current and _current != main_menu:
		_animate_out(_current, true)
	_show_screen(main_menu, false)
	main_menu.modulate = Color(1, 1, 1, 1)
	main_menu.process_mode = Control.PROCESS_MODE_INHERIT


## Pause the game and show the pause overlay.
## [param gameplay_root] is the node to freeze (typically the board).
func show_pause(gameplay_root: Control, pause_scene_path: String = "res://Scenes/Menu/PauseOverlay.tscn") -> void:
	var pause: Control = load(pause_scene_path).instantiate()
	_container.add_child(pause)
	pause.visible = true
	pause.modulate = Color(1, 1, 1, 0)
	_current = pause

	# Dim the gameplay behind the overlay
	if gameplay_root:
		gameplay_root.modulate = Color(1, 1, 1, 0.4)

	var t: Tween = create_tween()
	t.tween_property(pause, "modulate", Color(1, 1, 1, 1), TRANSITION_DURATION) \
		.set_ease(TRANSITION_EASE) \
		.set_trans(TRANSITION_TRANS)


## Hide the pause overlay and restore gameplay visibility.
func hide_pause(gameplay_root: Control) -> void:
	if not _current:
		return
	var pause: Control = _current

	var t: Tween = create_tween()
	t.tween_property(pause, "modulate", Color(1, 1, 1, 0), TRANSITION_DURATION) \
		.set_ease(TRANSITION_EASE) \
		.set_trans(TRANSITION_TRANS)
	t.tween_callback(func(): pause.queue_free())

	if gameplay_root:
		gameplay_root.modulate = Color(1, 1, 1, 1)
	_current = null


func _show_screen(screen: Control, animated: bool) -> void:
	_container.add_child(screen)
	screen.visible = true
	_current = screen

	if animated:
		screen.modulate = Color(1, 1, 1, 0)
		var t: Tween = create_tween()
		t.tween_property(screen, "modulate", Color(1, 1, 1, 1), TRANSITION_DURATION) \
			.set_ease(TRANSITION_EASE) \
			.set_trans(TRANSITION_TRANS)
	else:
		screen.modulate = Color(1, 1, 1, 1)


func _animate_out(screen: Control, animated: bool) -> void:
	if not screen or not is_instance_valid(screen):
		return
	if animated:
		var t: Tween = create_tween()
		t.tween_property(screen, "modulate", Color(1, 1, 1, 0), TRANSITION_DURATION) \
			.set_ease(TRANSITION_EASE) \
			.set_trans(TRANSITION_TRANS)
		t.tween_callback(func(): screen.queue_free())
	else:
		screen.queue_free()


func _clear_history() -> void:
	_history.clear()
