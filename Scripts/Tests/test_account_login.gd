## Login flow for daily scores, without touching the network: a logged-out
## player is sent to the Account screen instead of typing a name, and once
## logged in the end screen and main menu show the account's name.
extends TestCase

const BASE_SCENE: String = "res://Scenes/base.tscn"


func _ready() -> void:
	print("\n=== test_account_login ===")
	await run()
	_report()


func run() -> void:
	# The test shares user:// with the real game, so a saved session may
	# have been restored at startup: start logged out, restore at the end.
	var saved_alias: TaloPlayerAlias = Talo.current_alias
	Talo.current_alias = null

	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)
	await _frames(2)
	var sm: ScreenManager = base.get_node("ScreenManager")
	var final_screen: Control = base._final_screen
	var main_menu: MainMenu = base._main_menu

	assert_eq(main_menu._account_button.text, "LOG IN", "Logged out: main menu offers LOG IN")

	# Win a daily while logged out.
	base._load_game(GlobalState.selected_board, GlobalState.board_cols, GlobalState.board_rows, GlobalState.bomb_percentage, true, "2026-01-01", true)
	base._game_finished(true, 0.0)
	assert_true(final_screen._leaderboard_box.visible, "Daily win shows the score row")
	assert_eq(final_screen._score_button.text, "Log in to send score", "Logged out: button asks to log in")
	assert_false(final_screen.has_node("BlurPanel/CenterContainer/VBoxContainer/LeaderBoard/Username"), "No free-text name field anymore")

	# Pressing it opens the Account screen instead of submitting.
	final_screen._score_button.pressed.emit()
	await _frames(1)
	var account: Control = sm.get_current_screen()
	assert_true(account is AccountMenu, "Logged out: score button opens the Account screen")
	assert_eq(account._mode, AccountMenu.Mode.LOGIN, "Account screen starts on log in")
	assert_false(account._email_edit.visible, "Log in form has no email field")
	account._switch_button.pressed.emit()
	assert_eq(account._mode, AccountMenu.Mode.REGISTER, "Switch goes to create account")
	assert_true(account._email_edit.visible, "Create account form has the email field")

	# Empty form: rejected locally, nothing sent.
	account._username_edit.text = ""
	await account._on_primary_pressed()
	assert_true(account._error_label.visible, "Empty form shows an error")

	# Simulate a successful login (what Talo does on login/register).
	Talo.current_alias = _fake_alias("talo", "Tester")
	Talo.players.identified.emit(Talo.current_alias)
	assert_eq(final_screen._score_button.text, "Send score as Tester", "Logged in: end screen sends as the account")

	# Back closes the Account screen and returns to the end screen.
	base._handle_back_button()
	await _frames(1)
	assert_false(sm.get_current_screen() is AccountMenu, "Back closes the Account screen")
	assert_true(final_screen.visible, "End screen is still there after closing it")
	assert_false(main_menu.visible, "Closing it doesn't bring the main menu up behind the end screen")

	# An alias from the old typed-name flow doesn't count as logged in.
	Talo.current_alias = _fake_alias("username", "Someone")
	assert_false(AccountMenu.is_logged_in(), "A typed-name alias isn't a login")

	# Main menu shows the account's name.
	Talo.current_alias = _fake_alias("talo", "Tester")
	base._reset()
	await _frames(2)
	assert_eq(main_menu._account_button.text, "TESTER", "Logged in: main menu shows the account name")

	# Opened while logged in, the Account screen offers log out.
	main_menu._account_button.pressed.emit()
	await _frames(1)
	account = sm.get_current_screen()
	assert_true(account is AccountMenu, "Main menu button opens the Account screen")
	assert_eq(account._mode, AccountMenu.Mode.LOGGED_IN, "Logged in: Account screen shows the account")
	assert_eq(account._primary_button.text, "LOG OUT", "Logged in: offers log out")

	Talo.current_alias = saved_alias


func _fake_alias(service: String, identifier: String) -> TaloPlayerAlias:
	return TaloPlayerAlias.new({
		id = 1,
		service = service,
		identifier = identifier,
		displayName = identifier,
		player = { id = "test", props = [], groups = [] },
		lastSeenAt = "",
		createdAt = "",
		updatedAt = "",
	})


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
