# Copy All Errors — Godot Editor Plugin

A simple Godot 4.x editor plugin that adds a **"Copy All"** button to the Debugger's **Errors** panel, allowing you to copy all errors and warnings to the clipboard with one click.

![Godot 4.x](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- Injects a **Copy All** (复制全部) button into the built-in Errors panel toolbar
- Copies all errors and warnings in a clean, formatted text
- Distinguishes between **E** (error) and **W** (warning) entries
- Includes child details (stack trace, error codes, etc.)
- Button shows a brief "Copied N items!" flash feedback
- Works with both English and Chinese editor locales
- Supports multiple debugging sessions, each with its own Copy All button

## Installation

### From GitHub

1. Download or clone this repository.
2. Copy the `addons/copy_all_errors` folder into your project's `addons/` directory.
3. In Godot, go to **Project → Project Settings → Plugins** and enable **Copy All Errors**.

### From Godot Asset Library

1. In Godot, go to **AssetLib** tab at the top of the editor.
2. Search for **"Copy All Errors"**.
3. Click **Download** → **Install**.
4. Enable the plugin in **Project → Project Settings → Plugins**.

## Usage

1. Run your project and trigger some errors / warnings.
2. Open the **Debugger → Errors** panel at the bottom of the editor.
3. Click the **复制全部** (Copy All) button next to "Collapse All".
4. Paste the copied content anywhere — issue trackers, chat, AI assistants, etc.

When running multiple instances, select the desired debugger session and click its
**Copy All** button. Each button copies only that session's errors and warnings.
Buttons are also added to sessions started after the plugin is enabled.

### Example Output

```
E 0:00:02:145   MyScript.gd:42 — Attempted to call function 'foo' on a null instance.
  <Error> Method not found
  res://scripts/MyScript.gd:42

W 0:00:03:012   AnotherScript.gd:10 — UNUSED_VARIABLE
  <GDScript Warning> The local variable 'bar' is declared but never used.
  res://scripts/AnotherScript.gd:10
```

## Compatibility

- **Godot 4.0+** (tested on 4.5 / 4.6.1)
- Works on Windows, macOS, and Linux

## Regression test

With Python 3.9+ and a Godot editor installed, run:

```sh
python tests/run_multi_session.py --godot /path/to/godot
```

This creates a temporary project and connects three real headless game processes.
It checks per-session copy output, sessions added later, stop/reconnect, plugin
disable/re-enable, and button cleanup. The test records text at the clipboard
boundary without changing the system clipboard. It uses the editor's configured
language; English and Simplified Chinese are supported.

## License

[MIT](LICENSE)
