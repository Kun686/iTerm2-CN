# iTerm2-CN

macOS 上的 iTerm2 非官方社区简体中文版本。

[下载发行版](https://github.com/Kun686/iTerm2-CN/releases) ·
[反馈问题](https://github.com/Kun686/iTerm2-CN/issues) ·
[上游项目](https://github.com/gnachman/iTerm2) ·
[官方使用文档](https://iterm2.com/documentation.html)

> 本项目与 iTerm2 官方项目不存在隶属关系，不代表官方发布、支持或安全保证。
> 终端功能来自 George Nachman 与 iTerm2 上游贡献者；本 Fork 主要提供界面汉化。

## 提供什么

- 简体中文界面：菜单、设置、配置文件编辑器、提示、工具侧栏等应用自有文字。
- 三种界面语言：**简体中文、English、跟随系统**，更改后下次启动生效。
- CN 首次启动默认简体中文；已明确保存的语言选择会保留。
- 保留原有终端功能，包括窗口／标签页／窗格、tmux、Shell 集成、搜索、
  快捷键、触发器、状态栏、即时回放、Python API，以及原有 AI 和浏览器功能。
- CN 版本使用独立的主应用 Bundle ID：`com.kun686.iterm2-cn`。
- CN 自动更新已停用；“检查更新”打开本仓库 Releases，由用户手动更新。

汉化只处理显示层，不翻译终端输入输出、命令、用户数据、API 字段或协议。
不以汉化为理由修改终端解析、PTY、Shell 启动、渲染和数据持久化逻辑。
应用语言与 Shell 的 `LANG`、`LC_*` 是不同设置，切换界面语言不会改写它们。

## 下载与安装

运行要求：**macOS 13 或更新版本**。正式发行包为 **Universal**，
同时包含 Apple Silicon（arm64）和 Intel（x86_64）。

1. 先导出并备份现有 iTerm2 的配置文件和设置，保存正在进行的工作并退出官方版。
2. 打开 [Releases](https://github.com/Kun686/iTerm2-CN/releases)，
   下载该版本的 `iTerm2-CN-…-macOS-universal.zip` 和 `SHA256SUMS`。
   GitHub 自动生成的 “Source code” 压缩包不是安装包。
3. 将两个文件放在同一文件夹，在该目录执行：

   ```bash
   shasum -a 256 -c SHA256SUMS
   ```

4. 校验显示 `OK` 后解压，将 `iTerm2-CN.app` 拖入“应用程序”并打开。

正式发行包的 Developer ID 签名、Apple 公证和已知限制以对应 Release Notes
为准。源码自行构建默认不签名；`UNSIGNED-TEST-ONLY` 或 development 产物
不是正式发行包。不要通过关闭 Gatekeeper、删除隔离属性等方式掩盖验证失败。

如需复验已安装的发行包：

```bash
codesign --verify --deep --strict --verbose=2 /Applications/iTerm2-CN.app
spctl --assess --type execute --verbose=4 /Applications/iTerm2-CN.app
xcrun stapler validate /Applications/iTerm2-CN.app
```

## 切换语言

在“设置 → 通用”中找到“语言”，选择简体中文、English 或跟随系统。
保存后正常退出并重新打开应用；不会替你关闭当前 Shell 会话。

- **简体中文**：使用随应用打包的中文资源。
- **English**：使用英文资源。
- **跟随系统**：移除应用内显式语言覆盖，由 macOS 选择；不支持的语言回退英文。
- 无效或损坏的已保存语言值安全回退 English。

## 更新与回滚

第一版仅通过 [本 Fork 的 Releases](https://github.com/Kun686/iTerm2-CN/releases)
手动更新，不会自动安装官方英文构建，也没有伪装成 Sparkle Appcast 的更新源。
更新前备份设置、退出应用，再用新发行包替换旧的 `iTerm2-CN.app`。

回滚时先退出 CN 版，使用之前备份的 CN 发行包，或从
[官方渠道](https://iterm2.com/downloads.html) 重新安装官方 iTerm2。
按需要使用原有导入／导出功能恢复设置。**不要删除共享数据目录来卸载其中一个版本。**

## 与官方版共存的限制

独立的主 Bundle ID **不等于所有数据和组件完全隔离**。
第一版不保证与官方 iTerm2 并行安装或同时运行；请避免同时运行两个版本。

- 主应用偏好域随新 Bundle ID 改变；本 Fork 不自动迁移官方版的设置或受保护钥匙串项目。
- Helper／XPC／Service 标识、URL Scheme、私有偏好域和部分 Application Support
  路径仍沿用上游设计，不能据此承诺完整隔离。
- 部分 Keychain 服务名仍相同；受访问组保护的项目还受签名团队权限限制。
  保留服务名不会使 Fork 获得官方签名团队的钥匙串访问权。
- 依赖官方 Bundle ID 的自动化，需要明确指定 `com.kun686.iterm2-cn`。
  内部可执行文件、API 和协议名称没有全局重命名。
- 浏览器和其他可选组件仍遵循原有插件安装、签名与权限要求；不会绕过官方校验。
- 安装、切换版本和手动导入设置前均应备份；不承诺无损自动迁移或自动合并两套设置。

## 汉化边界与已知英文内容

为了保持原有行为，以下内容保留原文，不能简单全局替换：

- Shell 输出、日志、共享 `NSError`／回调诊断、Script Console 历史和 API 响应；
  独立的界面提示可以翻译，但共享诊断可能仍出现在提示窗口中。
- 命令、路径、URL、正则表达式、环境变量、快捷键参数、用户自定义名称和外部网页。
- 第三方组件的自有文字，例如标签关闭按钮的 `Close Tab` 辅助功能名称；
  不宣称第三方界面或 VoiceOver 已达到全量中文覆盖。
- 与配置、排序、文件操作或诊断共用的稳定名称，例如 `Dynamic Profile Parent Name`、
  `iTerm2 Command.rtf`、`untitled folder`、未命名工作组的 `Untitled`、
  聊天分叉标题标记 `(Forked at …)`，以及部分后台动作／触发器描述。
- Toolbelt 内置工具的菜单／标题只翻译显示副本，原名称继续用于已有配置和自动化。
  动态工具、进程、会话状态和 AI 提供商返回的内容不翻译。

旧的标题式菜单快捷键兼容随应用打包的译文。仅打开或重新加载编辑器不会
重写原参数；菜单稳定 ID、动作 selector 和配置值保持不变。
未知诊断和未知第三方名称保留原文，不凭空生成可能改变含义的中文错误。

## 从源码构建

完整 Xcode、命令行工具及依赖准备方式沿用上游工程。首次配置：

```bash
git clone --recurse-submodules https://github.com/Kun686/iTerm2-CN.git
cd iTerm2-CN
make setup
UNIVERSAL=1 make paranoid-deps
```

`make setup` 是交互式流程，可能安装 Homebrew、Xcode、Rust、构建工具与
Metal toolchain，并在特权或安全敏感操作前询问。已配置好的机器无需重复执行。
更换 Xcode 后按上游要求重新构建依赖；不要把本地依赖产物或工具链时间戳提交到 Fork。

开发与分发构建：

```bash
make cn-dev
make cn-run
UNIVERSAL=1 make cn-release
```

`cn-run` 使用仓库要求的隔离 suite。手动测试启动也必须传入
`-suite <隔离名称>`；suite 不会隔离全部 Keychain 或 Application Support 数据，
不要用真实密码库做无隔离测试。可用 `BUILD_DIR=/绝对路径` 指定构建输出目录。

直接在 Xcode 构建 CN 版本时，同时设置：

```text
ITERM2_EDITION=cn
ITERM2_MAIN_BUNDLE_IDENTIFIER=com.kun686.iterm2-cn
```

该标识设置仅用于主应用，不要给所有 Helper 批量设置相同 Bundle ID。
普通上游构建仍保留原来的应用身份和更新策略。

版本来自 `version.txt` 与工程的日期替换规则；发行修订号体现在
`v<版本>-cn.1` Tag 和压缩包名称中，不向 Apple Bundle 版本字段塞入非法后缀。
构建命令默认禁用签名；本地编译成功不等于完成正式签名或公证。
维护者发布时须从最终合并提交的全新干净副本构建，逐层签名、公证、装订，
并重新验证解压后的 App。Apple 凭据只应存入本机 Keychain 等安全存储。

常用检查：

```bash
python3 tools/check_localizations.py
python3 -m unittest discover -s tools/tests
tools/run_tests.expect ModernTests
```

真实 AI 测试是单独的 opt-in 流程，可能产生费用；凭据使用仓库已有安全临时文件
机制，不应写入源码或 README。日常检查不需要为了汉化重复调用真实供应商。

### 首次发布的静态分析例外

Xcode 26.6 的 Clang 在为未改动的 `iTermStreamingPNGWriter.m` 输出 plist
静态分析报告时崩溃。相同分析规则下，单文件文本报告可完成，但这**不代表
全项目静态分析已通过**，也不代表所有分析警告已被排除。
本次发布已明确接受这一工具故障例外，不修改官方源码来规避工具问题；
单元测试、Universal 构建、签名、公证和分发包复验不因此豁免。
具体提交、测试结果及发行包验证记录见对应 Release Notes。

## 反馈与贡献

汉化遗漏、翻译错误、布局和本 Fork 发行包问题，请提交到
[Kun686/iTerm2-CN Issues](https://github.com/Kun686/iTerm2-CN/issues)。
请附版本、macOS 版本、界面语言、复现步骤和不含敏感信息的截图；
不要上传密码、私钥、终端秘密内容或未脱敏的配置。

上游文档与贡献规则：

- [iTerm2 使用文档](https://iterm2.com/documentation.html)
- [上游贡献指南](https://gitlab.com/gnachman/iterm2/-/wikis/How-to-Contribute)
- [上游问题渠道](https://iterm2.com/bugs)

先在官方版复现后再向上游反馈功能问题，明确说明是否与 Fork 有关。
上游同步使用独立 PR，不混入本地化变更。添加语言应复用现有语言注册表和
`<locale>.lproj` 资源，并补充检查与测试，不扩展终端核心。

## 许可证与致谢

iTerm2 原作者为 [George Nachman](https://github.com/gnachman)，感谢
[上游贡献者](https://github.com/gnachman/iTerm2/graphs/contributors)。
本 Fork 保留原有版权、源码授权及第三方许可证，不主张拥有上游作品。

许可证以仓库 [LICENSE](LICENSE)、[COPYING](COPYING) 和各组件自带授权为准；
其中 LICENSE 收录 GNU GPL version 2。对应发行源码可通过相同 Tag 获取，
子模块版本由该提交固定；下载源码时请递归获取子模块。

如果希望支持终端本身的发展，可通过
[iTerm2 官方捐助渠道](https://iterm2.com/donate.html) 支持上游。
