//
//  iTermApplicationDelegate.swift
//  iTerm2
//
//  Created by George Nachman on 3/28/25.
//

@objc
extension iTermApplicationDelegate {
    @objc
    func registerMenuTips() {
        guard let mainMenu = NSApp.mainMenu else {
            return
        }
        struct Tip {
            var identifier: String
            var imageName: String?
            var text: String
        }

        let toolbeltText = String(localized: "ui.swift.appkit.itermapplicationdelegate.the_toolbelt_provides_a_versatile_dockable_sidebar_that.14fc12e1", defaultValue: """
        The **Toolbelt** provides a versatile, dockable sidebar that offers quick access to frequently used features and information. It supports multiple panels that can be displayed simultaneously, including clipboard history, recently opened directories, command history, a scratchpad for notes, and more.
        """, bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")

        let tips = [
            Tip(identifier: "Toolbelt",
                imageName: "Toolbelt-Screenshot",
                text: toolbeltText),
            Tip(identifier: "Show Toolbelt",
                imageName: "Toolbelt-Screenshot",
                text: toolbeltText),
            Tip(identifier: "Split Vertically with Current Profile",
                imageName: "VerticalSplit",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.splits_the_current_session_vertically_placing_a_new.34e401a5", defaultValue: "Splits the current session vertically, placing a new session in the right half. The new session inherits the profile of the current session, including any changes made in `Session > Edit Session`.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Split Horizontally with Current Profile",
                imageName: "HorizontalSplit",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.splits_the_current_session_horizontally_placing_a_new.d6eac7d1", defaultValue: "Splits the current session horizontally, placing a new session in the bottom half. The new session inherits the profile of the current session, including any changes made in `Session > Edit Session`.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Split Vertically…",
                imageName: "VerticalSplit",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.prompts_you_to_select_a_profile_and_then.efe9077a", defaultValue: "Prompts you to select a profile and then splits the current session vertically, placing the new session in the right half.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Split Horizontally…",
                imageName: "HorizontalSplit",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.prompts_you_to_select_a_profile_and_then.f059e926", defaultValue: "Prompts you to select a profile and then splits the current session horizontally, placing the new session in the bottom half.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "tmux.Dashboard",
                imageName: "TmuxDashboard",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.the_tmux_dashboard_helps_you_switch_between_tmux.15e32861", defaultValue: "The **tmux Dashboard** helps you switch between tmux sessions, show and hide windows, and administer other features of tmux without needing to use tmux’s commands.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Paste Special.Advanced Paste…",
                imageName: "AdvancedPaste",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.advanced_paste_lets_you_edit_text_before_pasting.279787b7", defaultValue: "**Advanced Paste** lets you edit text before pasting, remove control characters, convert tabs, base64-encode, and perform regular expression substitutions. It also lets you fine-tune how quickly pasted text is sent.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Render Selection Natively",
                imageName: "RenderNatively",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.render_natively_shows_a_nicely_formatted_syntax_highlighted.a471a119", defaultValue: "**Render Natively** shows a nicely formatted, syntax-highlighted rendition of a document. For example, Markdown renders beautifully. It also allows for horizontal scrolling, making it a convenient way to view log files.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Paste Special.Warn Before Multi-Line Paste",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.you_ll_be_prompted_any_time_you_paste.efb25d74", defaultValue: "You’ll be prompted any time you paste text containing a newline. See also **Limit Multi-Line Paste Warning to Shell Prompt**.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Paste Special.Limit Multi-Line Paste Warning to Shell Prompt",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.this_is_effective_only_when_warn_before_multi.1f0d529f", defaultValue: "This is effective only when **Warn Before Multi-Line Paste** is enabled. It also requires Shell Integration. When enabled, it suppresses confirmation when pasting text containing a newline if you are not at a shell prompt.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Paste Special.Warn Before Pasting One Line Ending in a Newline at Shell Prompt",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.if_enabled_you_ll_be_prompted_to_confirm.3b871453", defaultValue: "If enabled, you’ll be prompted to confirm that you wish to send a newline when pasting a single line of text ending in a newline. Shell Integration is required.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Engage Artificial Intelligence",
                imageName: "AIMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_selected_at_a_shell_prompt_provided_shell.22f96f65", defaultValue: "When selected at a shell prompt (provided Shell Integration is installed) or in the Composer, it sends the current command to the configured AI system along with a prompt for it to generate a command. If no input is provided, you’ll be asked to give instructions. The generated command goes into the Composer.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Explain Output with AI",
                imageName: "AIExplainTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.this_is_meant_to_be_used_at_the.fad0fbaa", defaultValue: "This is meant to be used at the shell prompt after executing a command. It requires Shell Integration. The output of the preceding (or selected) command is sent to AI, which annotates the output and opens a chat window for further discussion.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Edit.Snippets",
                imageName: "SnippetsTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.snippets_are_pieces_of_text_that_you_save.8e6cc5bb", defaultValue: "Snippets are pieces of text that you save to reuse later. They’re great for frequently used commands, hard-to-remember directories, and much more.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Edit.Actions",
                imageName: "ActionsMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.actions_are_saved_instructions_for_iterm2_for_example.586c553f", defaultValue: "Actions are saved instructions for iTerm2. For example, you could create an action that opens a new window and then creates a split pane.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Set Default Width",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.records_the_current_width_of_the_toolbelt_for.67601c5b", defaultValue: "Records the current width of the toolbelt for use in newly created windows.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Actions",
                imageName: "ActionsMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.actions_are_saved_instructions_for_iterm2_for_example.586c553f", defaultValue: "Actions are saved instructions for iTerm2. For example, you could create an action that opens a new window and then creates a split pane.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Selection Respects Soft Boundaries",
                imageName: "SelectionRespectsSoftBoundariesMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_dividers_rendered_by_programs_like_vim.ce94148c", defaultValue: "When enabled, dividers rendered by programs like vim or emacs are detected, and text selection wraps around them.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Find.Filter",
                imageName: "FilterMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.filter_allows_you_to_hide_any_lines_that.04dbd695", defaultValue: "**Filter** allows you to hide any lines that do not match a search query, which can be a substring or regular expression. It updates live as new text arrives.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Marks and Annotations.Set Mark",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.a_mark_appears_as_a_blue_triangle_in.0e7acf1f", defaultValue: "A **Mark** appears as a blue triangle in the left margin. You can easily navigate among marks using **Jump to Mark**, **Next Mark**, and **Previous Mark**. If Shell Integration is enabled, a Mark is automatically added at each shell prompt.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Set Named Mark",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.a_named_mark_appears_as_a_blue_triangle.40bbc8d8", defaultValue: "A **Named Mark** appears as a blue triangle in the left margin. In addition to being easy to navigate with **Next Mark** and **Previous Mark**, you can also find Named Marks in the Toolbelt’s **Named Marks** tool.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Named Marks",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.a_named_mark_appears_as_a_blue_triangle.6b57d9fa", defaultValue: "A **Named Mark** appears as a blue triangle in the left margin. In addition to being easy to navigate with **Next Mark** and **Previous Mark**, you can also find Named Marks in this Toolbelt tool.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Fold Selected Lines",
                imageName: "FoldMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.fold_lets_you_collapse_multiple_lines_into_a.95ce8655", defaultValue: "**Fold** lets you collapse multiple lines into a single line to hide distracting text. You can always unfold it by clicking the arrow in the margin, selecting the text and using **Edit > Unfold in Selection**, or right-clicking and choosing **Unfold**.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Captured Output",
                imageName: "CapturedOutputMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.captured_output_works_in_conjunction_with_a_trigger.5580682f", defaultValue: "**Captured Output** works in conjunction with a Trigger to detect interesting text in the terminal and make it easy to find. The Toolbelt tool shows a list of captured text. You can click to navigate to it or double-click to enter a programmable command. This is useful for finding errors in the output of a build command, for example. It requires Shell Integration.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Codecierge",
                imageName: "CodeciergeMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.codecierge_uses_ai_to_help_you_achieve_a.d62e3dfb", defaultValue: "**Codecierge** uses AI to help you achieve a goal. Tell it what you want to do, and it can watch your terminal to interpret output and suggest commands. Shell Integration is required.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Command History",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.if_shell_integration_is_installed_command_history_shows.f2d35e5b", defaultValue: "If Shell Integration is installed, **Command History** shows a searchable list of recently run commands on the current host.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Notes",
                imageName: "NotesMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.notes_is_a_single_persistent_notepad_in_your.57130e5d", defaultValue: "**Notes** is a single, persistent notepad in your Toolbelt. It’s useful for keeping track of what you’re doing or composing messages.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Paste History",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.paste_history_shows_text_that_you_have_copied.36ce4610", defaultValue: "**Paste History** shows text that you have copied and pasted in iTerm2. You can configure it to be saved long term.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Profiles",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.shows_a_list_of_your_profiles_so_you.b119f019", defaultValue: "Shows a list of your profiles so you can create new sessions easily.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Recent Directories",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.shows_your_most_used_directories_sorted_by_a.7740bb8a", defaultValue: "Shows your most used directories, sorted by a combination of frequency and recency of use. Requires Shell Integration.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Snippets",
                imageName: "SnippetsTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.snippets_are_pieces_of_text_that_you_save.8e6cc5bb", defaultValue: "Snippets are pieces of text that you save to reuse later. They’re great for frequently used commands, hard-to-remember directories, and much more.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Zoom In on Selection",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.hides_everything_except_the_lines_of_selected_text.1414dcab", defaultValue: "Hides everything except the lines of selected text to remove distractions.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Find Cursor",
                imageName: "FindCursorMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.highlights_the_location_of_the_cursor_and_unhides.22489deb", defaultValue: "Highlights the location of the cursor and unhides it if it is currently hidden.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Show Annotations",
                imageName: "AnnotationsMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.annotations_are_inline_markup_when_closed_they_appear.f3bb3b77", defaultValue: "Annotations are inline markup. When closed, they appear as a yellow underline; when open, they look like yellow stickies where you can write memos about content in the terminal window.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Composer",
                imageName: "ComposerMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.the_composer_is_a_window_within_the_terminal.c32a11a5", defaultValue: "The Composer is a window within the terminal where you can edit text using macOS-native controls. It does syntax highlighting, command and filename completion—even over SSH (provided you use SSH Integration). If AI features are enabled, you can also get AI-powered suggestions. You can even have multiple cursors! When you're ready, you can send the whole buffer or just a line at a time to your shell.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Auto Composer",
                imageName: "AutoComposerMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.auto_composer_replaces_your_shell_prompt_with_a.da24a70b", defaultValue: "**Auto Composer** replaces your shell prompt with a macOS-native text field. It does syntax highlighting and command and filename completion. You can also enable AI-powered suggestions. Shell Integration is required.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Open Quickly",
                imageName: "OpenQuicklyMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.open_quickly_provides_quick_access_to_many_common.9f6d73a2", defaultValue: "**Open Quickly** provides quick access to many common actions. You can use it to find a session by typing its name, directory, hostname, or recent command. You can also use it to switch profiles or create a new window by typing the name of a profile. Restore an arrangement by entering its name. Press `/` to get tips for quick commands.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Start Instant Replay",
                imageName: "InstantReplayMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.instant_replay_lets_you_review_recent_terminal_history.cbfde430", defaultValue: "**Instant Replay** lets you review recent terminal history. It’s handy if something just disappeared from the screen and it isn’t in scrollback history.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Run Coprocess…",
                imageName: "CoprocessMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.a_coprocess_is_a_program_that_automates_interactions.cc083d25", defaultValue: "A **Coprocess** is a program that automates interactions in the terminal. Input to the terminal is redirected to stdin of the coprocess, and its output is sent back to the terminal as though the coprocess were typing.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Stop Coprocess",
                imageName: "CoprocessMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.stops_the_active_coprocess_input_to_the_terminal.b35ebc48", defaultValue: "Stops the active coprocess. Input to the terminal is no longer redirected to the coprocess, and its output ceases.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Triggers",
                imageName: "TriggersMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.triggers_are_actions_the_terminal_performs_automatically_when.41a13f5a", defaultValue: "**Triggers** are actions the terminal performs automatically when text matching a regular expression is received. For example, you can highlight text or display an alert.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Terminal State.Literal Mode",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_control_characters_are_displayed_visually_rather.62d2a288", defaultValue: "When enabled, control characters are displayed visually rather than being interpreted as usual.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Terminal State.Report Modifiers with CSI u",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.this_mode_is_generally_not_recommended_disambiguate_escape.b59258cd", defaultValue: "This mode is generally not recommended. **Disambiguate Escape** is a more modern approach.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Bury Session",
                imageName: "BurySessionMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.buried_sessions_are_hidden_in_the_buried_sessions.56aa64a3", defaultValue: "Buried sessions are hidden in the **Buried Sessions** menu below and do not appear in any window. These are particularly useful for the session where you initiate tmux integration by running `tmux -CC`.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Open Interactive Window",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.the_python_repl_opens_a_window_running_a.279e2422", defaultValue: "The Python REPL opens a window running a special Python interpreter that lets you experiment with iTerm2’s Python API. You can use `await` at the top level of the interpreter.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Manage Dependencies",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.opens_a_ui_where_you_can_add_update.1fc3e7a7", defaultValue: "Opens a UI where you can add, update, or remove pip dependencies of a Python API script.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Install Python Runtime",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.iterm2_s_python_runtime_is_a_large_binary.ba3e4687", defaultValue: "iTerm2’s Python Runtime is a large binary package (hundreds of MBs) that enables the Python API by installing a pre-built Python environment that scripts can use.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Import Script",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.use_import_to_install_scripts_others_have_shared.a7a61618", defaultValue: "Use **Import** to install scripts others have shared with you. These scripts have the `.its` extension.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Export Script",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.if_you_want_to_share_python_api_scripts.5792f170", defaultValue: "If you want to share Python API scripts, you can export them to an `.its` file. If you have a code signing certificate and private key in your Keychain, you can also sign the `.its` file.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Script Console",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.view_errors_and_low_level_communication_between_python.ec6905c9", defaultValue: "View errors and low-level communication between Python API scripts and iTerm2 here.\n\nThe Inspector can be accessed from the Console. It allows you to browse variables in sessions, tabs, and windows.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Arrangements",
                imageName: "ArrangementsMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.window_arrangements_are_a_saved_record_of_one.4599eb95", defaultValue: "**Window Arrangements** are a saved record of one or more windows, their tabs, and split panes, including how each pane is configured. They do not include content. They’re a quick way to create a working environment with multiple sessions in various configurations.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Password Manager",
                imageName: "PasswordManagerMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.the_password_manager_helps_you_keep_track_of.dc509649", defaultValue: "The **Password Manager** helps you keep track of your passwords securely. By default, it stores them in the macOS Keychain, but it can also use 1Password or LastPass.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "AI Chats",
                imageName: "AIChatMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.ai_chats_opens_a_chat_window_where_you.a49d5af9", defaultValue: "**AI Chats** opens a chat window where you can interact with AI. It can optionally view and control the terminal if you grant it permission.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Pin Hotkey Window",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.a_pinned_hotkey_window_does_not_close_automatically.e06ec233", defaultValue: "A **pinned** Hotkey Window does not close automatically when it loses keyboard focus.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "GPU Renderer Availability",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.checks_whether_the_gpu_renderer_is_currently_being.bc30713f", defaultValue: "Checks whether the GPU Renderer is currently being used in the active session. This is sometimes useful for debugging.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Secure Keyboard Entry",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.secure_keyboard_entry_prevents_other_programs_from_intercepting.d4ae15e8", defaultValue: "**Secure Keyboard Entry** prevents other programs from intercepting your keystrokes in the terminal. However, it also breaks some functionality: other programs cannot activate their windows while this is enabled. For example, the `open` command will still open an app, but it won’t be activated.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Install Shell Integration",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.shell_integration_consists_of_shell_scripts_that_run.853fee64", defaultValue: "**Shell Integration** consists of shell scripts that run when you log in. They inform iTerm2 of where your shell prompt is. This enables dozens of useful features such as command history, directory history, AI features, and more.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toggle Debug Logging",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.debug_logs_are_saved_in_memory_while_this.306f414a", defaultValue: "Debug logs are saved in memory while this setting is enabled and written to `/tmp/debuglog.txt` when you turn it off. Memory use is capped at about 200MB; if the log grows past that, the oldest entries are discarded so the most recent activity is always kept.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Broadcast Input.Broadcast Input to All Panes in All Tabs",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_anything_you_type_in_this_window.d9344e96", defaultValue: "When enabled, anything you type in this window is sent to all sessions in this window.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Broadcast Input.Broadcast Input to All Panes in Current Tab",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_anything_you_type_in_this_tab.b27b34c3", defaultValue: "When enabled, anything you type in this tab is sent to all sessions in this tab.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Broadcast Input.Toggle Broadcast Input to Current Session",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.adds_or_removes_this_session_from_the_set.f5218766", defaultValue: "Adds or removes this session from the set of sessions in this window that have broadcast enabled. When you type in a session with broadcast enabled, the keystrokes are sent to all other sessions in the same window that have broadcast enabled.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Broadcast Input.Show Background Pattern Indicator",
                imageName: "BroadcastStripesMenuTip",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_prominent_red_lines_are_drawn_in.af21f67d", defaultValue: "When enabled, prominent red lines are drawn in the background to indicate that text you type is being broadcast to other sessions.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Broadcast Input.Current Session is Broadcast Source",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_typing_in_this_session_is_broadcast.c9c11cad", defaultValue: "When enabled, typing in this session is broadcast to other sessions in the same broadcast domain. Typing in other sessions sends input only to those sessions.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Lock Size",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.locked_windows_resist_being_resized_this_can_be.3c9425e2", defaultValue: "Locked windows resist being resized. This can be useful when macOS screws up your windows when connecting or disconnecting displays.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Lock Layout",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_a_window_s_layout_is_locked_its.f0519c56", defaultValue: "When a window’s layout is locked, its tabs and panes can’t be added, closed, reordered, dragged, or moved to another window, so a stray click or drag can’t rearrange it. Resizing panes, opening new windows, and closing the window still work. This is an alternative to Lock Size; turning one on turns the other off.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Notify on Status Change",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.when_enabled_the_next_time_any_session_in.2cad386c", defaultValue: "When enabled, the next time any session in this window changes its status (such as waiting, idle, or busy) an alert is shown and this setting turns itself back off. This is the same toggle as the bell button in the **Session Status** toolbelt tool, which must be open for this to be available.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toggle Buffer Input", text: String(localized: "ui.swift.appkit.itermapplicationdelegate.while_buffer_input_is_turned_on_keyboard_input.5309f7d0", defaultValue: "While Buffer Input is turned on, keyboard input is stored in a buffer. It will be sent when Buffer Input is turned off. You can also configure a trigger to change the Buffer Input setting.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
            Tip(identifier: "Toolbelt.Session Status",
                imageName: "TabStatus",
                text: String(localized: "ui.swift.appkit.itermapplicationdelegate.the_session_status_tool_shows_the_status_of.bb3817e1", defaultValue: "The **Session Status** tool shows the status of sessions across all tabs. Statuses can be set by the **Set Tab Status** trigger or by programs using a control sequence. Each entry shows the session name, a colored indicator dot, status text, and a keyboard shortcut to jump to that session.", bundle: .main, comment: "User-facing text in iTermApplicationDelegate.")),
        ]
        var index = [String: NSMenuItem]()
        func makeIndex(menu: NSMenu) {
            for item in menu.items {
                if let identifier = item.identifier?.rawValue, !identifier.isEmpty {
                    index[identifier] = item
                }
                if let sub = item.submenu {
                    makeIndex(menu: sub)
                }
            }
        }
        makeIndex(menu: mainMenu)
        let controller = MenuItemTipController.instance
        for tip in tips {
            if let item = index[tip.identifier] {
                controller.registerTip(forMenuItem: item,
                                       image: tip.imageName.compactMap { NSImage.it_imageNamed($0, for: Self.self) },
                                       attributedString: NSAttributedString.attributedString(markdown: tip.text,
                                                                                             font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                                                                                             paragraphStyle: NSParagraphStyle.default)!)
            } else {
                #if(DEBUG)
                it_fatalError("Index missing \(tip.identifier)")
                #endif
            }
        }
    }
}

@objc
extension iTermApplicationDelegate {
    @IBAction func restoreArchive(_ sender: Any?) {
        ArchivesMenuBuilder.shared?.restoreArchive(nil)
    }
}

@objc
extension iTermApplicationDelegate {
    @IBAction func revealCockpit(_ sender: Any?) {
        CockpitWindowController.shared.showAndFocusCommand()
    }
}
