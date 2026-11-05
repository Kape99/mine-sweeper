## Settings persistence test.
## Covers the version stamping of configs saved by older versions.
extends TestCase

func run() -> void:
	# A pre-v1 config (no settings_version) gets stamped with the current one.
	Settings._config.erase_section_key(Settings.CONFIG_SECTION, "settings_version")
	Settings._migrate(0)
	assert_eq(Settings.get_setting("settings_version", 0), Settings.SETTINGS_VERSION,
		"Migration stamps the current settings version")

	# Already-current configs are left alone.
	Settings._migrate(Settings.get_setting("settings_version", 0))
	assert_eq(Settings.get_setting("settings_version", 0), Settings.SETTINGS_VERSION,
		"Migration is a no-op on a current config")
