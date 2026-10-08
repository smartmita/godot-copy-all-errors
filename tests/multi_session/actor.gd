extends Node

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	push_warning("SESSION_SENTINEL_%d" % OS.get_process_id())
	push_error("SESSION_ERROR_%d" % OS.get_process_id())
	# Bound client lifetime even if the editor or fixture fails unexpectedly.
	await get_tree().create_timer(65.0).timeout
	get_tree().quit()
