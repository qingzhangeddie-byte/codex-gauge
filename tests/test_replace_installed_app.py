import pathlib
import unittest


class ReplaceInstalledAppScriptTests(unittest.TestCase):
    def test_replacement_script_removes_old_app_copies_new_app_and_launches_target(self):
        script = pathlib.Path("script/replace_installed_app.sh").read_text()

        self.assertIn('pkill -x "$APP_NAME"', script)
        self.assertIn('rm -rf "$TARGET_APP"', script)
        self.assertIn('ditto --norsrc --noextattr "$SOURCE_APP" "$TARGET_APP"', script)
        self.assertIn('launch_app_binary "$TARGET_APP"', script)
        self.assertIn('USER_TARGET_APP="$HOME/Applications/$APP_NAME.app"', script)
        self.assertIn('TMP_TARGET_APP="/private/tmp/$APP_NAME.app"', script)
        self.assertIn("install_user_app", script)
        self.assertIn("install_tmp_app", script)
        self.assertIn("install_launch_agent", script)
        self.assertIn('install_launch_agent "$USER_TARGET_APP"', script)
        self.assertIn("temporary non-persistent app", script)
        self.assertIn("app.codexgauge.menubar.plist", script)
        self.assertIn("<key>KeepAlive</key>", script)
        self.assertIn("launchctl bootstrap", script)
        self.assertIn("launchctl kickstart -k", script)
        self.assertNotIn("remove_watchdog", script)
        self.assertNotIn("WATCHDOG", script)
        self.assertIn('launch_app_binary "$USER_TARGET_APP"', script)
        self.assertIn('launch_app_binary "$TMP_TARGET_APP"', script)
        self.assertIn('nohup "$app_path/Contents/MacOS/$APP_BINARY_NAME"', script)
        self.assertIn('Contents/MacOS/$APP_NAME"', script)
        self.assertIn('APP_NAME="CodexGauge"', script)
        self.assertIn('LEGACY_APP_NAME="AiLimitStatus"', script)
        self.assertIn('APP_BINARY_NAME="${APP_NAME}-bin"', pathlib.Path("script/build_and_run.sh").read_text())
        self.assertIn("verify_app_bundle", script)
        self.assertIn('codesign --verify --deep --strict "$app_path"', script)
        self.assertIn("codex_status.py", script)
        self.assertIn('Contents/Resources/ssd_temperature', script)
        self.assertIn("CodexGaugeUsagePath", script)
        self.assertIn("CFBundleShortVersionString", script)
        self.assertIn("CodexGaugeReleaseURL", script)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases", script)

    def test_double_click_command_runs_replacement_script(self):
        command = pathlib.Path("Replace Codex Gauge.command").read_text()

        self.assertIn('script/replace_installed_app.sh', command)
        self.assertIn('Press Return to close', command)

    def test_codex_action_can_run_replacement_script(self):
        environment = pathlib.Path(".codex/environments/environment.toml").read_text()

        self.assertIn('name = "Replace Codex Gauge"', environment)
        self.assertIn('command = "./script/replace_installed_app.sh"', environment)

    def test_replacer_app_builder_creates_app_bundle_that_runs_replacement_script(self):
        script = pathlib.Path("script/build_replacer_app.sh").read_text()

        self.assertIn('APP_NAME="ReplaceCodexGauge"', script)
        self.assertIn('$APP_NAME.app', script)
        self.assertIn('SOURCE_FILE="$ROOT_DIR/native/ReplaceCodexGauge.swift"', script)
        self.assertIn('swiftc "$SOURCE_FILE"', script)
        self.assertIn("ReplaceRootDir", script)
        self.assertIn("com.apple.provenance", script)
        self.assertIn("codesign --force --sign -", script)
        self.assertIn("codesign --verify --deep --strict", script)
        self.assertNotIn("continuing with unsigned", script)

    def test_replacer_swift_helper_runs_replacement_script(self):
        source = pathlib.Path("native/ReplaceCodexGauge.swift").read_text()

        self.assertIn('infoString("ReplaceRootDir"', source)
        self.assertIn('script/replace_installed_app.sh', source)
        self.assertIn("CodexGauge-replace.log", source)
        self.assertIn('appendingPathComponent("native")', source)
        self.assertIn("Process()", source)

    def test_main_build_script_strips_macos_metadata_before_codesign(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn("com.apple.provenance", script)
        self.assertIn("com.apple.FinderInfo", script)
        self.assertIn("com.apple.fileprovider.fpfs#P", script)
        self.assertIn('xattr -cr "$target"', script)
        self.assertIn('find "$target" -depth -print0', script)
        self.assertIn('xattr -c "$item"', script)
        self.assertIn("--noextattr", script)
        self.assertIn("--norsrc", script)
        self.assertIn("strip_macos_metadata", script)
        self.assertIn("sign_app_bundle", script)
        self.assertIn("codesign --verify --deep --strict", script)
        self.assertNotIn("continuing with unsigned", script)
        self.assertIn('stage_bundle="$stage_parent/$APP_NAME.app"', script)
        self.assertIn('SSD_TEMPERATURE_HELPER="$stage_resources/ssd_temperature"', script)
        self.assertIn('clang "$SSD_TEMPERATURE_SOURCE"', script)
        self.assertIn('sign_app_bundle "$stage_bundle"', script)
        self.assertIn('ditto --norsrc --noextattr "$stage_bundle" "$APP_BUNDLE"', script)
        self.assertIn('strip_macos_metadata "$APP_BUNDLE"', script)
        self.assertIn('verify_signed_bundle "$APP_BUNDLE"', script)
        self.assertIn('user_target="$HOME/Applications/$APP_NAME.app"', script)
        self.assertIn('tmp_target="/private/tmp/$APP_NAME.app"', script)
        self.assertIn('copy_verified_app "$user_target"', script)
        self.assertIn('copy_verified_app "$tmp_target"', script)
        self.assertIn('install_launch_agent "$user_target"', script)
        self.assertIn("temporary non-persistent app", script)
        self.assertLess(script.index('swiftc "$SOURCE_FILE"'), script.index('sign_app_bundle "$stage_bundle"'))
        self.assertLess(script.index('sign_app_bundle "$stage_bundle"'), script.index('ditto --norsrc --noextattr "$stage_bundle" "$APP_BUNDLE"'))
        self.assertLess(script.index('ditto --norsrc --noextattr "$stage_bundle" "$APP_BUNDLE"'), script.index('strip_macos_metadata "$APP_BUNDLE"'))
        self.assertLess(script.index('strip_macos_metadata "$APP_BUNDLE"'), script.index('verify_signed_bundle "$APP_BUNDLE"'))
        self.assertLess(script.index('strip_macos_metadata "$target"'), script.index('codesign --force --sign - "$target"'))
        self.assertLess(script.index('codesign --force --sign - "$target"'), script.rindex('strip_macos_metadata "$target"'))


if __name__ == "__main__":
    unittest.main()
