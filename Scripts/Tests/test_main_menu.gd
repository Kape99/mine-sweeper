## Main menu layout: daily card + PLAY with a one-line summary; the board
## settings live in the New game sheet, which saves to GlobalState and can
## start a game itself.
extends TestCase

const BASE_SCENE: String = "res://Scenes/base.tscn"


func _ready() -> void:
	print("\n=== test_main_menu ===")
	await run()
	_report()


func run() -> void:
	var saved_alias: TaloPlayerAlias = Talo.current_alias
	Talo.current_alias = null
	var saved: Array = [GlobalState.selected_board, GlobalState.board_wrap, GlobalState.board_seed]

	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)
	await _frames(2)
	var sm: ScreenManager = base.get_node("ScreenManager")
	var menu: MainMenu = base._main_menu

	# Daily card describes today's board.
	var today: String = Time.get_date_string_from_system(true)
	var daily: Dictionary = MainMenu.daily_settings(today)
	assert_true(menu._daily_info.text.contains(MainMenu.BOARD_TYPE_NAMES[daily.board]), "Daily card names today's board shape")
	assert_true(menu._daily_info.text.contains("%d × %d" % [daily.cols, daily.rows]), "Daily card shows today's size")
	assert_eq(menu._daily_status.text, "Log in to join the leaderboard", "Logged out: daily card invites to log in")
	assert_false(menu.has_node("Margin/Layout/Footer/QuitButton"), "No QUIT button")
	assert_false(menu.has_node("CenterContainer/Panel/SeedRow"), "Seed row moved off the main menu")

	# Summary line follows GlobalState.
	GlobalState.selected_board = 2
	GlobalState.board_wrap = false
	GlobalState.board_seed = ""
	await _frames(1)
	assert_true(menu._game_summary.text.begins_with("Hexagon · %s · Classic" % GlobalState.get_difficulty()), "Summary shows board · difficulty · mode")

	# The summary opens the New game sheet.
	menu._game_summary.pressed.emit()
	await _frames(1)
	var sheet: Control = sm.get_current_screen()
	assert_true(sheet is NewGameMenu, "Summary opens the New game sheet")
	assert_eq(sheet._board_label.text, "Hexagon", "Sheet starts from the current settings")

	# Changes are saved as they're made and show in the summary on return.
	sheet._cycle_board(1)
	sheet._toggle_mode(1)
	sheet._seed_edit.text_changed.emit("zuru7 ")
	assert_eq(GlobalState.selected_board, 0, "Board change is saved")
	assert_true(GlobalState.board_wrap, "Mode change is saved")
	assert_eq(GlobalState.board_seed, "ZURU7", "Seed is saved normalized")
	base._handle_back_button()
	await _frames(2)
	assert_true(sm.get_current_screen() is MainMenu, "Back returns to the main menu")
	assert_true(menu._game_summary.text.begins_with("Triangle · %s · Wrap · Seed ZURU7" % GlobalState.get_difficulty()), "Summary reflects the sheet's changes")

	# PLAY in the sheet closes it and starts a normal game with its settings.
	menu._game_summary.pressed.emit()
	await _frames(1)
	sheet = sm.get_current_screen()
	sheet.play_requested.emit()
	await _frames(1)
	assert_false(sm.get_current_screen() is NewGameMenu, "Sheet's PLAY closes the sheet")
	assert_true(base._board != null and not base._is_daily, "Sheet's PLAY starts a normal game")
	assert_eq(base._board._seed, "ZURU7", "Game uses the sheet's seed")
	assert_false(menu.visible, "Main menu hides during the game")

	# The daily button still starts today's daily with its own settings.
	base._reset()
	await _frames(1)
	menu._start_daily(today)
	assert_true(base._is_daily, "Daily starts the daily")
	assert_eq(base._board._seed, daily.seed, "Daily uses the date as seed")

	base._reset()
	GlobalState.selected_board = saved[0]
	GlobalState.board_wrap = saved[1]
	GlobalState.board_seed = saved[2]
	Talo.current_alias = saved_alias


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
