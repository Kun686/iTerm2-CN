"""Real installer text assembly, with synthetic controls and command preview.

No App, shell discovery, download, command dispatch, dotfile or preferences access.
Font/color objects are stand-ins; this checks attributed text, not UI rendering.
"""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools.tests.test_close_job_list_localization import method


ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "sources/ShellIntegrationInstaller"
PREVIEW = "printf '用户 %@\\n'"


def case(stage, shell, busy, utilities, lines, bold=None, preview=PREVIEW):
    return dict(stage=stage, shell=shell, busy=busy, utilities=utilities,
                lines=lines.split(), bold=bold, preview=preview)


# Literal line snapshots below are independent of the production resource keys.
CASES = [
    case(-1, 5, False, True, "initial write_future utils_future dot4"),
    case(0, 5, False, True, "discover write_future utils_future dot4", 0),
    case(0, 5, True, True, "wait write_future utils_future dot4", 0),
    case(1, 5, False, True, "unsupported"),
    case(1, 0, False, True, "bash write_next utils_future dot4", 1),
    case(1, 0, True, True, "bash wait utils_future dot4", 1),
    case(2, 0, False, True, "bash wrote utils_next dot4", 2),
    case(2, 0, True, True, "bash wrote wait dot4", 2),
    case(3, 0, False, True, "bash wrote installed dot_next", 3),
    case(3, 0, True, True, "bash wrote installed wait", 3),
    case(4, 0, False, True, "bash wrote installed updated blank done", 5),
    case(1, 3, False, False, "fish write_next dot3", 1),
    case(2, 1, False, False, "tcsh wrote dot_next", 2),
    case(2, 2, True, False, "zsh wrote wait", 2),
    case(3, 2, False, False, "zsh wrote updated blank done", 4),
    case(1, 4, False, False, "xonsh write_next xonsh3", 1),
    case(2, 4, False, False, "xonsh wrote xonsh_done blank done", 4),
    case(2, 4, True, True, "xonsh wrote wait xonsh4", 2),
    case(3, 4, False, True, "xonsh wrote installed xonsh_done blank done", 5),
    case(1, 0, False, True, "bash write_next utils_future dot4", 1, preview=None),
]
LINES = {
    "initial": ("1. Discover.", "1. 检测。"),
    "discover": ("➡ Select “Continue” to discover.", "➡ 选择“继续”以检测。"),
    "wait": ("⏳ Waiting for command to complete…", "⏳ 等待命令完成…"),
    "unsupported": (
        "🛑 Your shell is not supported.\n\nOnly bash, fish, tcsh, xonsh, and zsh work with shell integration",
        "🛑 不支持你的 Shell。\n\nShell 集成仅支持 bash、fish、tcsh、xonsh 和 zsh"),
    "write_future": ("Step 2. Write the shell integration script.", "第 2 步：写入 Shell 集成脚本。"),
    "write_next": ("➡ Select “Continue” to write the shell integration script.", "➡ 选择“继续”以写入 Shell 集成脚本。"),
    "wrote": ("✅ Wrote the shell integration script.", "✅ 已写入 Shell 集成脚本。"),
    "utils_future": ("Step 3. Install iTerm2 utility scripts.", "第 3 步：安装 iTerm2 实用工具脚本。"),
    "utils_next": ("➡ Select “Continue” to install iTerm2 utility scripts.", "➡ 选择“继续”以安装 iTerm2 实用工具脚本。"),
    "installed": ("✅ Installed iTerm2 utility scripts.", "✅ 已安装 iTerm2 实用工具脚本。"),
    "dot_next": ("➡ Select “Continue” to update your shell's dotfile.", "➡ 选择“继续”以更新你的 Shell 配置文件。"),
    "updated": ("✅ Updated your shell's dotfile.", "✅ 已更新你的 Shell 配置文件。"),
    "xonsh_done": ("✅ Xonsh auto-loads scripts from rc.d (no dotfile update needed).",
                   "✅ Xonsh 会从 rc.d 自动加载脚本（无需更新配置文件）。"),
    "blank": ("", ""),
    "done": ("Done! Select “Continue” to proceed.", "完成！选择“继续”以进行下一步。"),
}
for shell in ("bash", "fish", "tcsh", "zsh", "xonsh"):
    LINES[shell] = (f"✅ Discovered your shell: you use “{shell}”.",
                    f"✅ 已识别你的 Shell：使用的是“{shell}”。")
for step in (3, 4):
    LINES[f"dot{step}"] = (f"Step {step}. Update your shell's dotfile.",
                           f"第 {step} 步：更新你的 Shell 配置文件。")
    LINES[f"xonsh{step}"] = (
        f"Step {step}. Xonsh auto-loads scripts from rc.d (no dotfile update needed).",
        f"第 {step} 步：Xonsh 会从 rc.d 自动加载脚本（无需更新配置文件）。")


class ShellIntegrationStepsLocalizationTests(unittest.TestCase):
    def test_steps_controls_and_raw_preview_in_both_languages(self):
        source = (DIRECTORY / "iTermShellIntegrationPasteShellCommandsViewController.m").read_text()
        window = (DIRECTORY / "iTermShellIntegrationWindowController.m").read_text()
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-shell-steps-") as temporary:
            root = Path(temporary)
            (root / "steps-methods.inc").write_text("\n".join(method(source, signature) for signature in (
                "- (void)setShell:", "- (NSString *)waitingText", "- (void)update")))
            (root / "shell-name.inc").write_text(method(window, "NSString *iTermShellIntegrationShellString("))
            payload = root / "cases.json"
            payload.write_text(json.dumps(CASES))
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation",
                 "-I", str(DIRECTORY), "-I", str(root),
                 str(ROOT / "tests/shell_integration_steps_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language_index, language in enumerate(("en", "zh-Hans")):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith((
                              "ui.shell_integration.steps.",
                              "ui.shellintegrationinstaller.itermshellintegrationpasteshellcommandsviewcontroller."))}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                result = subprocess.run([str(probe), str(resources), str(payload)],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                rows = json.loads(result.stdout)
                self.assertEqual(len(rows), len(CASES))
                for index, (item, row) in enumerate(zip(CASES, rows)):
                    lines = [LINES[key][language_index] for key in item["lines"]]
                    unavailable = item["stage"] == 1 and item["shell"] == 5
                    titles = (("Preview Command", "Send Again") if language == "en"
                              else ("预览命令", "再次发送"))
                    expected = {
                        "text": "".join(line + "\n" for line in lines),
                        "bold": [] if item["bold"] is None else [lines[item["bold"]] + "\n"],
                        "preview": item["preview"] or "", "requests": 1,
                        "shell": item["shell"],
                        "continue": not (unavailable or item["busy"]),
                        "skip": not (unavailable or item["busy"] or "done" in item["lines"]),
                        "buttons": [{"hidden": unavailable or button != item["stage"] or item["preview"] is None,
                                     "title": titles[int(item["busy"] and button == item["stage"])]}
                                    for button in range(4)],
                    }
                    with self.subTest(language=language, state=index):
                        self.assertEqual(row, expected)


if __name__ == "__main__":
    unittest.main()
