## Settings menu screen: timer tuning plus the raw board (debug) settings.
class_name SettingsMenu
extends Control

@onready var _rows_spin: SpinBox = $CenterContainer/Panel/RowsRow/RowsSpin
@onready var _cols_spin: SpinBox = $CenterContainer/Panel/ColsRow/ColsSpin
@onready var _bombs_spin: SpinBox = $CenterContainer/Panel/BombsRow/BombsSpin
@onready var _seed_edit: LineEdit = $CenterContainer/Panel/SeedRow/SeedEdit
@onready var _tap_slider: HSlider = $CenterContainer/Panel/TapRow/TapSlider
@onready var _long_press_slider: HSlider = $CenterContainer/Panel/LongPressRow/LongPressSlider
@onready var _double_tap_slider: HSlider = $CenterContainer/Panel/DoubleTapRow/DoubleTapSlider
@onready var _back_button: Button = $CenterContainer/Panel/BackButton


func _ready() -> void:
	_sync_from_settings()
	_connect_signals()


func _sync_from_settings() -> void:
	_tap_slider.value = Settings.tap_threshold
	_long_press_slider.value = Settings.long_press_threshold_ms
	_double_tap_slider.value = Settings.double_tap_window_ms

	_rows_spin.value = GlobalState.board_rows
	_cols_spin.value = GlobalState.board_cols
	_bombs_spin.value = GlobalState.bomb_percentage * 100.0
	_seed_edit.text = GlobalState.board_seed
	_update_bomb_max()


func _connect_signals() -> void:
	_tap_slider.value_changed.connect(func(v): Settings.tap_threshold = v)
	_long_press_slider.value_changed.connect(func(v): Settings.long_press_threshold_ms = int(v))
	_double_tap_slider.value_changed.connect(func(v): Settings.double_tap_window_ms = int(v))

	_rows_spin.value_changed.connect(_on_dimensions_changed)
	_cols_spin.value_changed.connect(_on_dimensions_changed)
	_bombs_spin.value_changed.connect(_on_bombs_changed)
	_seed_edit.text_changed.connect(_on_seed_changed)
	_back_button.pressed.connect(_on_back_pressed)


func _on_dimensions_changed(_value: float) -> void:
	GlobalState.board_rows = int(_rows_spin.value)
	GlobalState.board_cols = int(_cols_spin.value)
	_update_bomb_max()
	Settings.save_menu_state()


func _on_bombs_changed(value: float) -> void:
	GlobalState.bomb_percentage = value / 100.0
	Settings.save_menu_state()


func _on_seed_changed(text: String) -> void:
	GlobalState.board_seed = text.strip_edges().to_upper()
	Settings.save_menu_state()


func _update_bomb_max() -> void:
	var cells: int = GlobalState.board_rows * GlobalState.board_cols
	var max_mines: int = maxi(1, cells - 9)
	var max_percent: float = floorf(max_mines * 100.0 / cells)
	_bombs_spin.max_value = clampf(max_percent, 1.0, 99.0)
	_bombs_spin.value = minf(_bombs_spin.value, _bombs_spin.max_value)
	GlobalState.bomb_percentage = _bombs_spin.value / 100.0


func _on_back_pressed() -> void:
	var sm: ScreenManager = get_tree().root.find_child("ScreenManager", true, false)
	if sm:
		sm.pop()
