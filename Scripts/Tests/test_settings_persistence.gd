## Settings persistence test.
## Covers the one-time migration that switches double tap on for configs
## saved before it became the default.
extends TestCase

func run() -> void:
	var prev_double_tap: bool = Settings.use_double_tap

	# A pre-v1 config (no settings_version) with double tap saved as off.
	Settings.use_double_tap = false
	Settings._config.erase_section_key(Settings.CONFIG_SECTION, "settings_version")
	Settings._migrate(0)
	assert_true(Settings.use_double_tap, "Migration from v0 turns double tap on")
	assert_eq(Settings.get_setting("settings_version", 0), Settings.SETTINGS_VERSION,
		"Migration stores the current settings version")

	# Once migrated, a later choice to turn it off sticks.
	Settings.use_double_tap = false
	Settings._migrate(Settings.get_setting("settings_version", 0))
	assert_false(Settings.use_double_tap, "Migration runs only once")

	Settings.use_double_tap = prev_double_tap
