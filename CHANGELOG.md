# Changelog

## 1.0.1 - 2026-10-26

This patch includes the fixes merged since the original Asset Library submission.

### Fixed

- Add an independent Copy All button to every debugger session, including sessions connected after plugin initialization (PR #4, issue #3).
- Copy only the selected session's errors and warnings, with independent button feedback.
- Discover late debugger panels reliably and clean up buttons and feedback timers when panels are removed or the plugin is disabled and re-enabled.
- Detect the editor language on Godot 4.5 without calling an unavailable API, and use the English or Chinese string table for button text and feedback (PR #2).

### Distribution

- Set the plugin version to 1.0.1.
- Include the MIT license and installation/release notes inside `addons/copy_all_errors`, so they remain in Asset Library archives and installed projects.
- Correct the documented minimum Godot version to 4.2, which provides the `EditorInterface` singleton used by the existing implementation.

### Validation

- The merged multi-session integration test covers three real game processes, isolated errors and warnings, late connections, stop/reconnect, repeated copy, plugin disable/re-enable, cleanup, and empty-list feedback.
- PR #4 records passing runs on Godot 4.5 and 4.7.2 with English and Simplified Chinese editor settings.
- Release preparation reran the integration test successfully on official Godot 4.2.2 and 4.7.2.

## 1.0.0 - 2026-03-08

- Initial Asset Library release: copy debugger errors and warnings, including child details, to the clipboard.
