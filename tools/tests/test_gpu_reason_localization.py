"""Compile the actual GPU-reason display method and unchanged diagnostic producer.

Uses synthetic enum values and temporary resource bundles; no GPU, window,
session, rendering state, defaults or user logs are touched.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_close_job_list_localization import method


ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ("None", None, None),
    ("NoGPU", "no usable GPU found on this machine.", "此电脑上未找到可用的 GPU。"),
    ("Disabled", "GPU Renderer is disabled in Settings > General.", "GPU 渲染器已在“设置 > 通用”中停用。"),
    ("Ligatures", "ligatures are enabled. You can disable them in Settings > Profiles > Text > Use ligatures.", "已启用连字。可在“设置 > 配置文件 > 文本 > 使用连字”中停用。"),
    ("Initializing", "the GPU renderer is initializing. It should be ready soon.", "GPU 渲染器正在初始化，即将就绪。"),
    ("InvalidSize", "the session is too large or too small.", "会话尺寸过大或过小。"),
    ("SessionInitializing", "the session is initializing.", "会话正在初始化。"),
    ("Transparency", "transparent windows are not supported. They can be disabled in Settings > Profiles > Window > Transparency.", "不支持透明窗口。可在“设置 > 配置文件 > 窗口 > 透明度”中停用透明效果。"),
    ("VerticalSpacing", "the font's vertical spacing set to less than 100%. You can change it in Settings > Profiles > Text > Change Font.", "字体的垂直间距小于 100%。可在“设置 > 配置文件 > 文本 > 更改字体”中调整。"),
    ("MarginSize", "terminal window margins are too small. You can edit them in Settings > Advanced.", "终端窗口边距过小。可在“设置 > 高级”中调整。"),
    ("Annotations", "annotations or URL shortcuts are open.", "批注或 URL 快捷方式处于打开状态。"),
    ("Portholes", "this session has natively rendered items.", "此会话包含原生渲染的项目。"),
    ("FindPanel", "the find panel is open.", "查找面板处于打开状态。"),
    ("PasteIndicator", "the paste progress indicator is open.", "粘贴进度指示器处于打开状态。"),
    ("Announcement", "an announcement (yellow bar) is visible.", "通知栏（黄色横条）处于显示状态。"),
    ("URLPreview", "a URL preview is visible.", "URL 预览处于显示状态。"),
    ("WindowResizing", "the window is being resized.", "正在调整窗口大小。"),
    ("DisconnectedFromPower", "the computer is not connected to power. You can enable GPU rendering while disconnected from power in Settings > General > Advanced GPU Settings.", "电脑未连接电源。可在“设置 > 通用 > 高级 GPU 设置”中启用未连接电源时的 GPU 渲染。"),
    ("Idle", "the session is idle. You can enable Metal while idle in Settings > Advanced.", "会话处于空闲状态。可在“设置 > 高级”中启用空闲时的 Metal 渲染。"),
    ("TooManyPanesReason", "This tab has too many split panes", "此标签页的分割窗格过多"),
    ("NoFocus", "the window does not have keyboard focus.", "窗口没有键盘焦点。"),
    ("TabInactive", "this tab is not active.", "此标签页未处于活动状态。"),
    ("TabBarTemporarilyVisible", "the tab bar is temporarily visible.", "标签栏暂时处于显示状态。"),
    ("ScreensChanging", "the screen configuration has just changed.", "屏幕配置刚刚发生变化。"),
    ("ContextAllocationFailure", "of a temporary failure to allocate a graphics context.", "暂时无法分配图形上下文。"),
    ("TabDragInProgress", "a tab is being dragged.", "正在拖动标签页。"),
    ("SessionHasNoWindow", "the current session has no window (this shouldn't happen).", "当前会话没有窗口（正常情况下不应发生）。"),
    ("DropTargetsVisible", "secure copy drop targets are visible.", "安全拷贝放置目标处于显示状态。"),
    ("SwipingBetweenTabs", "swiping between tabs", "正在轻扫切换标签页"),
    ("SplitPaneBeingDragged", "a split pane is being dragged.", "正在拖动分割窗格。"),
    ("WindowObscured", "the window is mostly under another window.", "窗口大部分被其他窗口遮挡。"),
    ("LowerPowerMode", "macOS is in low power mode.", "macOS 处于低电量模式。"),
    ("NotATerminal", "the current session is not a terminal.", "当前会话不是终端。"),
    ("Unknown", "of an internal error. Please file a bug report!", "of an internal error. Please file a bug report!"),
]


class GPUReasonLocalizationTests(unittest.TestCase):
    def test_display_translates_reasons_without_changing_diagnostics(self):
        delegate = (ROOT / "sources/AppKit/iTermApplicationDelegate.m").read_text()
        display = method(delegate, "- (NSString *)gpuUnavailableStringForReason:")
        self.assertIn(
            "NSString *reason = [self gpuUnavailableStringForReason:tab.metalUnavailableReason];",
            delegate)
        header = ROOT / "sources/MetalRenderer/Infrastructure/iTermMetalUnavailableReason.h"
        declared = set(re.findall(r"^\s*(iTermMetalUnavailableReason\w+),?\s*$",
                                  header.read_text(), re.M))
        expected = {"iTermMetalUnavailableReason" + name
                    for name, _, _ in CASES if name != "Unknown"}
        self.assertEqual(declared, expected)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-gpu-display-") as directory:
            root = Path(directory)
            (root / "gpu-display-method.inc").write_text(display)
            (root / "gpu-reason-cases.inc").write_text("\n".join(
                'ADD_REASON(@"{name}", {value});'.format(
                    name=name, value="NSUIntegerMax" if name == "Unknown"
                    else "iTermMetalUnavailableReason" + name)
                for name, _, _ in CASES))
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation",
                 "-I", str(root), "-I", str(header.parent),
                 str(ROOT / "sources/MetalRenderer/iTermMetalUnavailableReason.m"),
                 str(ROOT / "tests/gpu_reason_localization_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items()
                          if key.startswith("ui.appkit.itermapplicationdelegate.")}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)],
                                     capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                snapshot = json.loads(run.stdout)
                control = "ui.appkit.itermapplicationdelegate.gpu_renderer_availability.bd16bac3"
                self.assertEqual(snapshot["control"], values[control])
                self.assertEqual(set(snapshot["rows"]), {row[0] for row in CASES})
                for name, english, chinese in CASES:
                    with self.subTest(language=language, reason=name):
                        row = snapshot["rows"][name]
                        self.assertEqual(row["diagnostic"], english)
                        self.assertEqual(row["display"], english if language == "en" else chinese)


if __name__ == "__main__":
    unittest.main()
