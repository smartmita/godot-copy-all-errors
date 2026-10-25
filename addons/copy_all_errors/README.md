# Copy All Errors 1.0.1

A Godot 4.2+ editor plugin that adds a **Copy All** button to each Debugger Errors panel.
Each button copies only that session's errors and warnings, including stack traces and other child details.
Button text and feedback support English and Chinese editor locales.

## Installation

1. Copy this `copy_all_errors` directory into your project's `addons/` directory, or install Copy All Errors from Godot's AssetLib.
2. Enable **Copy All Errors** in **Project > Project Settings > Plugins**.
3. Run your project, select a debugger session, open its **Errors** panel, and click **Copy All**.

When updating an existing installation, stop debugging and disable the plugin before replacing its files, then re-enable it.

## Changes in 1.0.1

- Independent Copy All buttons and copy feedback for multiple debugger sessions, including late connections.
- Reliable panel discovery, stop/reconnect behavior, and cleanup when disabling and re-enabling the plugin.
- Godot 4.5-compatible editor language detection and English/Chinese text.
- License and installation notes included in the distributed plugin directory.

Requires Godot 4.2 or later. Release preparation passed the multi-session regression on official Godot 4.2.2 and 4.7.2. PR #4 also records Godot 4.5 and 4.7.2 runs with English and Simplified Chinese editor settings.

Source, full changelog, and regression test instructions:
https://github.com/smartmita/godot-copy-all-errors

Report issues:
https://github.com/smartmita/godot-copy-all-errors/issues

## License

MIT; see [LICENSE](LICENSE).
