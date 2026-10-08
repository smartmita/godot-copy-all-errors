@tool
extends "res://addons/copy_all_errors/plugin.gd"

# Record the OS clipboard boundary so this regression can run headlessly without
# changing the user's clipboard. Button callbacks and error trees are real.
func _copy_to_clipboard(text: String) -> void:
	set_meta("last_copied_text", text)
