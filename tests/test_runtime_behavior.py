import pathlib
import platform
import shutil
import subprocess
import tempfile
import unittest


class RuntimeBehaviorTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required")
    def test_compiled_refresh_freshness_and_discovery_behavior(self):
        with tempfile.TemporaryDirectory(prefix="codex-gauge-runtime-tests-") as directory:
            executable = str(pathlib.Path(directory) / "runtime-tests")
            command = [shutil.which("swiftc")]
            if platform.system() == "Darwin":
                command += ["-target", f"{platform.machine()}-apple-macosx13.0"]
            command += ["native/CodexGaugeRuntime.swift", "tests/RuntimeBehaviorTests.swift", "-o", executable]
            build = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([executable], capture_output=True, text=True, timeout=15)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("runtime checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
