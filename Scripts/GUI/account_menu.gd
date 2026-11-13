## Account screen: log in, create an account, or log out, with Talo Player
## Auth. Opened from the main menu and from the daily challenge's end
## screen (to log in before sending a score); closes itself after a
## successful login.
##
## Talo keeps the session on the device and restores it at startup
## (auto_start_session in addons/talo/settings.cfg), so players log in once.
class_name AccountMenu
extends Control

const PANEL_PADDING: int = 24
const PANEL_WIDTH: int = 340
const ROW_SPACING: int = 12
const CONTROL_MIN_HEIGHT: int = 48
const BACK_BUTTON_TEXT: String = "← Back"

## Same limit as the old name field on the end screen, so names fit the
## leaderboard rows.
const USERNAME_MAX_LENGTH: int = 20

const ERROR_COLOR: Color = Color(0.78, 0.16, 0.16)

enum Mode { LOGIN, REGISTER, VERIFY, LOGGED_IN }

var _mode: Mode = Mode.LOGIN
var _busy: bool = false

var _title: Label
var _info: Label
var _username_edit: LineEdit
var _password_edit: LineEdit
var _email_edit: LineEdit
var _code_edit: LineEdit
var _error_label: Label
var _primary_button: Button
var _switch_button: Button
var _back_button: Button


## Whether a player is logged in with a Talo account (not just identified
## by a typed name, as older builds did).
static func is_logged_in() -> bool:
	return Talo.has_identity() and Talo.current_alias.service == "talo"


## Name of the logged-in player, or "" when logged out.
static func player_name() -> String:
	return Talo.current_alias.identifier if is_logged_in() else ""


func _ready() -> void:
	_build_ui()
	_set_mode(Mode.LOGGED_IN if is_logged_in() else Mode.LOGIN)


# --- Actions -----------------------------------------------------------------

func _on_primary_pressed() -> void:
	if _busy:
		return
	match _mode:
		Mode.LOGIN:
			await _login()
		Mode.REGISTER:
			await _register()
		Mode.VERIFY:
			await _verify()
		Mode.LOGGED_IN:
			await _logout()


func _login() -> void:
	var username: String = _username_edit.text.strip_edges()
	var password: String = _password_edit.text
	if username.is_empty() or password.is_empty():
		_show_error("Enter your username and password.")
		return
	_set_busy(true)
	var res: PlayerAuthAPI.PlayerAuthLoginResult = await Talo.player_auth.login(username, password)
	_set_busy(false)
	if res.error:
		_show_error(_error_text(res.error))
	elif res.verification_required:
		_set_mode(Mode.VERIFY)
	else:
		_close()


func _register() -> void:
	var username: String = _username_edit.text.strip_edges()
	var password: String = _password_edit.text
	var email: String = _email_edit.text.strip_edges()
	if username.is_empty() or password.is_empty():
		_show_error("Choose a username and a password.")
		return
	_set_busy(true)
	var res: PlayerAuthAPI.PlayerAuthResult = await Talo.player_auth.register(username, password, email)
	_set_busy(false)
	if res.success:
		_close()
	else:
		_show_error(_error_text(res.error))


func _verify() -> void:
	var code: String = _code_edit.text.strip_edges()
	if code.is_empty():
		_show_error("Enter the code from the email.")
		return
	_set_busy(true)
	var res: PlayerAuthAPI.PlayerAuthResult = await Talo.player_auth.verify(code)
	_set_busy(false)
	if res.success:
		_close()
	else:
		_show_error(_error_text(res.error))


func _logout() -> void:
	_set_busy(true)
	await Talo.player_auth.logout()
	_set_busy(false)
	_password_edit.text = ""
	_set_mode(Mode.LOGIN)


func _on_switch_pressed() -> void:
	match _mode:
		Mode.LOGIN:
			_set_mode(Mode.REGISTER)
		Mode.REGISTER, Mode.VERIFY:
			_set_mode(Mode.LOGIN)


func _close() -> void:
	var sm: ScreenManager = get_tree().root.find_child("ScreenManager", true, false)
	if sm:
		sm.pop()


## Turns a Talo error into something a player can act on.
func _error_text(error: TaloPlayerAuthError) -> String:
	match error.code:
		TaloPlayerAuthError.ErrorCode.INVALID_CREDENTIALS:
			return "Wrong username or password."
		TaloPlayerAuthError.ErrorCode.IDENTIFIER_TAKEN:
			return "That username is taken."
		TaloPlayerAuthError.ErrorCode.IDENTIFIER_PROFANITY:
			return "Please choose another username."
		TaloPlayerAuthError.ErrorCode.EMAIL_TAKEN:
			return "That email is already used by another account."
		TaloPlayerAuthError.ErrorCode.INVALID_EMAIL:
			return "That email doesn't look right."
		TaloPlayerAuthError.ErrorCode.VERIFICATION_CODE_INVALID:
			return "Wrong or expired code."
		TaloPlayerAuthError.ErrorCode.VERIFICATION_EMAIL_REQUIRED:
			return "An email is required to create an account."
		_:
			# API_ERROR covers no connection as well as server-side messages.
			if error.message.begins_with("API error"):
				return "Couldn't reach the server. Check your connection."
			return error.message


# --- State -----------------------------------------------------------------------

func _set_mode(mode: Mode) -> void:
	_mode = mode
	_error_label.visible = false
	var logged_out: bool = mode == Mode.LOGIN or mode == Mode.REGISTER
	_username_edit.visible = logged_out
	_password_edit.visible = logged_out
	_email_edit.visible = mode == Mode.REGISTER
	_code_edit.visible = mode == Mode.VERIFY
	_switch_button.visible = mode != Mode.LOGGED_IN
	match mode:
		Mode.LOGIN:
			_title.text = "LOG IN"
			_info.text = "Log in to send your daily challenge times."
			_primary_button.text = "LOG IN"
			_switch_button.text = "No account? Create one"
		Mode.REGISTER:
			_title.text = "CREATE ACCOUNT"
			_info.text = "Your username is shown on the leaderboard."
			_primary_button.text = "CREATE ACCOUNT"
			_switch_button.text = "Have an account? Log in"
		Mode.VERIFY:
			_title.text = "CHECK YOUR EMAIL"
			_info.text = "Enter the code we sent to your email."
			_primary_button.text = "VERIFY"
			_switch_button.text = "Back to log in"
		Mode.LOGGED_IN:
			_title.text = "ACCOUNT"
			_info.text = "Logged in as %s" % player_name()
			_primary_button.text = "LOG OUT"


func _set_busy(busy: bool) -> void:
	_busy = busy
	_primary_button.disabled = busy
	_switch_button.disabled = busy
	_back_button.disabled = busy
	if busy:
		_error_label.visible = false


func _show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = true


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = &"CardPanel"
	center.add_child(card)

	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_constant_override("separation", ROW_SPACING)
	card.add_child(panel)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_title)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_info)

	_username_edit = _make_edit(panel, "Username", "Username")
	_username_edit.max_length = USERNAME_MAX_LENGTH
	_password_edit = _make_edit(panel, "Password", "Password")
	_password_edit.secret = true
	_email_edit = _make_edit(panel, "Email (optional, for password resets)", "Email (optional)")
	_email_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_code_edit = _make_edit(panel, "Verification code", "Code")

	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", ERROR_COLOR)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_error_label)

	_primary_button = _make_button(panel, "", _on_primary_pressed)
	_primary_button.theme_type_variation = &"PrimaryButton"
	_switch_button = _make_button(panel, "", _on_switch_pressed)
	_switch_button.theme_type_variation = &"GhostButton"
	_back_button = _make_button(panel, BACK_BUTTON_TEXT, _close)
	_back_button.theme_type_variation = &"GhostButton"


func _make_edit(parent: Control, prompt_title: String, placeholder: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
	# Enter in any field submits the form.
	edit.text_submitted.connect(func(_text: String) -> void: _on_primary_pressed())
	parent.add_child(edit)
	WebTextInput.attach(edit, prompt_title)
	return edit


func _make_button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
