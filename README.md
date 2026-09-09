<div align="center">

# iTerm2

### macOS Terminal Replacement

![Version](https://img.shields.io/badge/version-3.6-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

**[Website](https://iterm2.com)** • **[Downloads](https://iterm2.com/downloads.html)** • **[Documentation](https://iterm2.com/documentation.html)** • **[Features](https://iterm2.com/features.html)**

</div>

---

## About

iTerm2 is a powerful terminal emulator for macOS that brings the terminal into the modern age with features you never knew you always wanted.

### Key Features

- **tmux Integration** - Native iTerm2 windows/tabs replace tmux's text-based interface. Run tmux -CC and tmux windows become real macOS windows. Sessions persist through crashes, SSH disconnects, and even app upgrades. Collaborate by having two people attach to the same session.
- **Shell Integration** - Deep shell awareness that tracks commands, directories, hostnames, and usernames. Enables click-to-download files via SCP, drag-and-drop uploads, command history per host, recent directories by "frecency," and marks at each prompt.
- **AI Chat** - Built-in LLM chat window that can optionally interact with terminal contents. Link sessions to get context-aware help, run commands on your behalf, or explain output with annotations.
- **Inline Images** - Display images (including animated GIFs) directly in the terminal. Use imgcat to view photos, charts, or visual output without leaving your workflow.
- **Automatic Profile Switching** - Terminal appearance changes automatically based on hostname, username, directory, or running command. SSH to production? Background turns red. Different environments get different visual contexts.
- **Dedicated Hotkey Windows** - System-wide hotkey summons a terminal that slides down from the top of the screen (or any edge), even over fullscreen apps. Pin it or let it auto-hide.
- **Session Restoration** - Sessions run in long-lived server processes. If iTerm2 crashes or upgrades, your shells keep running. When iTerm2 restarts, it reconnects to your sessions exactly where you left off.
- **Built-in Web Browser** - Browser profiles integrate web browsing into iTerm2's window/tab/pane hierarchy. Copy mode, triggers, AI chat, and other terminal features work in browser sessions.
- **Configurable Status Bar** - Per-session status bar showing git branch, CPU/memory graphs, current directory, hostname, custom interpolated strings, or Python API components.
- **Triggers** - Regex patterns that fire actions when matched: highlight text, run commands, send notifications, open password manager, set marks, or invoke Python scripts.
- **Smart Selection** - Quad-click selects semantic objects (URLs, file paths, email addresses, quoted strings). Right-click for context actions. Cmd-click to open.
- **Copy Mode** - Vim-like keyboard selection. Navigate and select text without touching the mouse. Works with marks to jump between command prompts.
- **Instant Replay** - Scrub backward through terminal history to see exactly what was on screen at any moment, with timestamps. Perfect for catching fleeting errors.
- **Python Scripting API** - Full automation and customization via Python. Create custom status bar components, triggers, menu items, or entirely new features.
- **Open Quickly** - Cmd-Shift-O opens a search across all sessions by tab title, command, hostname, directory, or badge. Navigate large session collections instantly.

---

## Installation

### iTerm2-CN community fork

iTerm2-CN is an unofficial Simplified Chinese localization. Its main application
uses `com.kun686.iterm2-cn`; the executable and internal target names remain
unchanged. Select Simplified Chinese, English, or Follow System in General
settings, then relaunch to apply the selection. CN builds disable automatic
updates; Check for Updates opens [Fork Releases](https://github.com/Kun686/iTerm2-CN/releases).

Legacy title-only menu shortcuts recognize bundled menu translations. Opening
or reloading the shortcut editor preserves the original complete parameter;
only choosing a different action produces a new parameter. Stable menu IDs and
action selectors are unchanged.
Built-in Toolbelt menu and panel headings are translated only for display.
Their original English titles remain the names used by existing actions,
title-only shortcuts, automation, notifications, and saved configuration.
Dynamic tool names and the Codecierge product name are not translated.
Cockpit keeps its original no-status grouping/filter key in both languages.
Only its fallback display name is translated; session-reported status text is
preserved, including text identical to that legacy key.
Forked chat titles retain the original `(Forked at …)` marker because it also
identifies the suffix to replace on later forks. Switching UI language does not
add another suffix or reinterpret Chinese user text as that marker. Existing
titles are not migrated or rewritten.

Raw diagnostics remain untranslated. In particular, the fork-failure message
is shared by logs, terminal output, and the notification body, so it stays in
English; the notification title is localized.
The installer's two built-in plugin names remain English in its diagnostic logs
and verification-error arguments. Error descriptions translate their display
copies; download addresses, bundle identities and installation are unchanged.
Unknown AI provider names stay English in shared request errors and diagnostic
events; the attachment-rejection alert uses a localized display name instead.
The settings exporter's serialization failure keeps its original diagnostic
reason; only the error shown to the user is translated. Exported data is unchanged.
Remote-settings manual-upload help names the active app or test-suite preferences
file instead of always pointing to the official app's file. This changes only the
displayed instruction, not settings synchronization or file operations.
Semantic History mode help and its Learn More popover are translated. Literal
backreferences, interpolation variable names, link targets, and saved commands
remain unchanged; these translations are used only in explanatory UI text.
Close-confirmation job lists localize their conjunction and duplicate-count
description without translating process names or changing job grouping, sorting,
or closing decisions. The generic list joiner used by diagnostics stays unchanged.
The third-party tab bar's close-button accessibility name remains `Close Tab`:
its private getter is hard-coded and does not honor the inherited label setter.
This is a known third-party translation limitation, not a completed VoiceOver
or close-button interaction acceptance check.
Status Bar Advanced help text is localized from the existing XIB tooltips.
The upstream reuse of tight-packing help on the empty-component option is
preserved; localization does not change either setting's behavior.
Trigger-editor row identifiers retain their original values. Only the visible
labels are translated, preserving regex, name, and job input bindings and the
existing save expressions in both UI languages.
The in-memory transfer path marker also retains its upstream value because
file actions consume it as a path, not just a display label.
The background Run Command Trigger, Smart Selection Action, and URL Handler
titles remain in English because the runner shares them with diagnostic
descriptions and script history. Their independent failure-notification titles
remain localized.
Terminal button tooltips retain their original stored and diagnostic values;
their AppKit display copy is localized. Unknown tooltip values pass through
unchanged, without altering button actions or rendering state.
Python download phase titles and status messages are also localized only at
their display boundary. Shared script-import error callbacks remain in English
because they also feed diagnostic logs; independent prompts remain localized.
The uv runtime also preserves original shared NSError descriptions, fields,
and background-upgrade diagnostics. Manual upgrade results also stay in English
because their callback writes script history. Shared callback text remains in
English when shown in alerts; download labels and independent prompts are localized.
Intel-only script launch errors retain their original Script Console history.
Their alert body and recovery hints are translated only for display, leaving
unknown recovery hints, script names, and launch decisions unchanged.
SSH Integration transfer diagnostics shared with logs, completion handlers, and
browser stream failures also retain their original text. Transfer summaries and
independent UI labels remain localized.
The same boundary applies to SCP/terminal-download NSError descriptions and the
transfer manager's fallback and cancellation callback. Independent SCP error
display wrappers, authentication prompts, and security warnings are localized;
the underlying shared diagnostics are not.
The SSH file panel keeps the original default folder name, `untitled folder`,
because Create uses it as a filesystem path. Its prompts and file-kind labels
remain localized; sorting by kind uses the displayed labels without changing
file metadata or paths.
SSH connection-closed and file-not-found descriptions remain in English because
remote file creation includes them in AI tool responses as well as user notices.
Other independent endpoint error descriptions remain localized.
Shared alert, annotation, bell, capture, command, send-text, directory, host,
hyperlink, script-function, and title trigger descriptions retain their original
log text, including when used in import summaries or unnamed-trigger fallbacks.
Their independent action titles and parameter prompts remain localized.
Stop-processing and prompt-detected trigger descriptions likewise keep their
original log text while their action titles remain localized.
The same diagnostic boundary covers bounce, mark, color-highlight, password,
and notification triggers, including the legacy Growl trigger name. Popup labels
remain localized while stored numeric options, color data, and the password
unlock sentinel retain their original meanings.
The password-trigger popup keeps its original account-name ordering even when
the unlock label is translated, so each displayed row saves the matching key.
Workgroup trigger menus retain `Untitled` for unnamed workgroups: that label's
sort position determines the implicit target when no workgroup ID is stored.
Both terminal and browser triggers preserve the upstream default-selection
algorithm and stored IDs. Their independent action titles remain localized.
SGR-style, named-mark, fold, injected-data, user-variable, buffered-input, and
workgroup-exit trigger descriptions also retain the original diagnostic text.
Their action titles and independent prompts remain localized; buffered-input
menu labels still map to the original numeric options.
The terminal workgroup-entry description and its shared parameter-row fallbacks
also keep their original diagnostic text; user-defined workgroup names are unchanged.
Set Profile Setting diagnostics retain their English format and On/Off values.
Only the setting name may follow the UI language when its existing label cache
has been populated; the uncached background path retains the raw setting key.

Build with `make cn-dev` or `UNIVERSAL=1 make cn-release`. These commands set the
main-target-only `ITERM2_MAIN_BUNDLE_IDENTIFIER` without assigning the same ID to
helpers. For a direct Xcode build, set both `ITERM2_EDITION=cn` and
`ITERM2_MAIN_BUNDLE_IDENTIFIER=com.kun686.iterm2-cn`. Ordinary upstream builds
keep the original identity and update policy. Builds are unsigned by default;
building successfully does not mean an artifact has been signed or notarized.

The main preferences domain changes with the Bundle ID. Back up settings and
Profiles before using the existing import/export tools; this fork does not
automatically copy preferences or protected Keychain items from the official
app. Developer ID signing must use a profile matching the new App ID and the
actual signing team's Keychain access group. A different team cannot access the
official team's protected Keychain items merely by keeping their service names.

This is not a fully isolated parallel-install edition: helper IDs, URL schemes,
the private preferences domain, and Application Support paths remain unchanged.
Do not run both editions concurrently or erase shared data to uninstall one.
Keep backups when switching editions; automation that explicitly selects the
official Bundle ID must explicitly target `com.kun686.iterm2-cn` for this fork.

### Download

Get the latest version from [iterm2.com/downloads](https://iterm2.com/downloads.html)

For the bleeding edge without building, try the [nightly build](https://iterm2.com/nightly/latest).

### Build from Source

> **Note:** Development builds may be less stable than official releases.

#### Prerequisites

- No manual prerequisites. `make setup` will install [Homebrew](https://brew.sh/), Xcode,
  Rust, and all other dependencies, prompting for confirmation before each privileged step.

#### Clone

```bash
git clone https://github.com/gnachman/iTerm2.git
```

#### Setup (first time)

```bash
make setup
```

`make setup` is interactive and will prompt for confirmation before any privileged or
security-sensitive operation. It performs the following steps:

- **Homebrew** -- Installs [Homebrew](https://brew.sh/) via its official install script
  if not already present. Prompts before running the installer (which requires sudo).
- **Xcode** -- If no Xcode is selected via `xcode-select`, installs
  [xcodes](https://github.com/XcodesOrg/xcodes) (via Homebrew) and
  [aria2](https://aria2.github.io/) (for faster downloads), then either selects an
  existing `/Applications/Xcode*.app` or downloads the latest Xcode automatically.
  Prompts before running `sudo xcode-select` and before accepting the Xcode license.
- **Rust** -- Installs [rustup](https://rustup.rs) via the official `curl | sh`
  installer if not already present. Prompts before executing the script.
- **Homebrew packages** -- Installs cmake, pkg-config, automake, perl, and python3 if
  missing. If `brew link python@3` would overwrite existing symlinks, prompts for
  confirmation before proceeding.
- **SF Symbols** -- Installs the SF Symbols cask (a `.pkg` installer that requires
  sudo). Prompts before attempting the install; continues without it if declined.
- **Python/Rust packages** -- Installs pyobjc (via pip) and cbindgen (via cargo) if not
  already present.
- **Submodules and toolchains** -- Initializes git submodules, adds the x86_64 Rust
  target, and downloads the Metal toolchain.

To skip all confirmation prompts, use `make dangerous-setup` instead.

After setup, compile native dependencies and build:

```bash
make paranoid-deps   # compile OpenSSL, libsixel, libgit2, Sparkle, etc. (sandboxed)
make                 # build iTerm2
```

Re-run `make paranoid-deps` whenever your active Xcode version changes -- the file `last-xcode-version` tracks which version was last used.

If your Xcode version differs from the one committed in `last-xcode-version` (e.g. you're on an older machine), suppress the noise without committing your local version:

```bash
git update-index --skip-worktree last-xcode-version
```

To undo: `git update-index --no-skip-worktree last-xcode-version`

#### Build

```bash
make Development
```

#### Run

```bash
make run
```

#### Architecture

Builds target your native architecture by default. To produce a universal (arm64 + x86_64) binary:

```bash
UNIVERSAL=1 make Development
```

#### Code signing

Code signing is disabled by default to keep contributor builds simple. To enable it with the project's signing identity:

```bash
SIGNED=1 make Development
```

#### Building in Xcode

If you prefer building from Xcode instead of the command line:

1. Complete the **Clone** and **Setup** steps above.
2. Configure code signing with your team ID:

   ```bash
   tools/set_team_id.sh YOUR_TEAM_ID
   ```

   This script updates `DEVELOPMENT_TEAM` in all Xcode project files (iTerm2 and its dependencies like Sparkle, SwiftyMarkdown, etc.) so code signing works with your identity.

   **To find your team ID:** Open Keychain Access, find your "Apple Development" or "Developer ID" certificate, and look for the 10-character string in parentheses (e.g., "H7V7XYVQ7D").

   **No Developer account?** Skip this step and select "Sign to Run Locally" in Xcode's Signing & Capabilities tab.

3. Open `iTerm2.xcodeproj` in Xcode.
4. Edit Scheme (Cmd-<) and set Build Configuration to **Development**.
5. Press Cmd-R to build and run.

---

## Development

### Contributing

We welcome contributions! Please read our [contribution guide](https://gitlab.com/gnachman/iterm2/-/wikis/How-to-Contribute) before submitting pull requests.

---

## Bug Reports & Issues

- **File bugs:** [iterm2.com/bugs](https://iterm2.com/bugs)
- **Issue tracker:** [GitLab Issues](https://gitlab.com/gnachman/iterm2/issues)

> **Note:** We use GitLab for issues because it provides better support for attachments.

---

## Resources

| Resource         | Link                                                              |
| ---------------- | ----------------------------------------------------------------- |
| Official Website | [iterm2.com](https://iterm2.com)                                  |
| Documentation    | [iterm2.com/documentation](https://iterm2.com/documentation.html) |
| Community        | [iTerm2 Discussions](https://gitlab.com/gnachman/iterm2/-/issues) |
| Downloads        | [iterm2.com/downloads](https://iterm2.com/downloads.html)         |

---

## License

iTerm2 is distributed under the [GPLv3](LICENSE) license.

---

## Support

If you love iTerm2, consider:

- Starring this repository
- Spreading the word
- [Sponsoring development](https://iterm2.com/donate.html)

---

<div align="center">

**Made by [George Nachman](https://github.com/gnachman) and [contributors](https://github.com/gnachman/iTerm2/graphs/contributors)**

</div>
