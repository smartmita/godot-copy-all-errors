@tool
extends EditorPlugin

class Observer extends EditorDebuggerPlugin:
	pass

var _observer: Observer
var _plugin: EditorPlugin
var _clients: Array[int] = []
var _failed := false


func _enter_tree() -> void:
	_observer = Observer.new()
	add_debugger_plugin(_observer)
	get_tree().create_timer(60.0).timeout.connect(_fail.bind("test deadline exceeded"))
	_run.call_deferred()


func _exit_tree() -> void:
	for pid in _clients:
		if OS.is_process_running(pid):
			OS.kill(pid)
	if _observer != null:
		remove_debugger_plugin(_observer)
		_observer = null


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_plugin = _find_plugin(get_tree().root)
	_clients.append(_launch_client())
	await _wait_for(func(): return _active_count() == 1 and _panels().size() == 1, "first session")
	if _failed:
		return
	# The second and third processes connect after initial plugin setup has ended.
	_clients.append(_launch_client())
	await _wait_for(func(): return _active_count() == 2 and _panels().size() == 2, "second session")
	if _failed:
		return
	_clients.append(_launch_client())
	await _wait_for(func(): return _active_count() == 3 and _panels().size() == 3, "third session")
	await get_tree().create_timer(0.8).timeout
	if not await _verify_copying():
		return
	print("MULTI_SESSION: late sessions and isolated copy output PASS")

	OS.kill(_clients[0])
	await _wait_for(func(): return _active_count() == 2, "stopped session")
	# Stopped sessions still expose their retained error lists for copying.
	if not await _verify_copying():
		return
	_clients[0] = _launch_client()
	await _wait_for(func(): return _active_count() == 3 and _has_pid(_clients[0]), "reconnected session")
	if not await _verify_copying():
		return
	print("MULTI_SESSION: stop and reconnect PASS")

	for _cycle in 2:
		var old_buttons: Array[Button] = []
		for panel in _panels():
			old_buttons.append_array(_buttons(panel))
		# Disable during flash feedback to cover outstanding timer callbacks.
		old_buttons[0].pressed.emit()
		EditorInterface.set_plugin_enabled("copy_all_errors", false)
		_plugin = null
		await get_tree().process_frame
		await get_tree().process_frame
		for button in old_buttons:
			if is_instance_valid(button):
				_fail("plugin disable left an injected button")
				return
		EditorInterface.set_plugin_enabled("copy_all_errors", true)
		await get_tree().create_timer(0.8).timeout
		_plugin = _find_plugin(get_tree().root)
		if not await _verify_copying():
			return
	print("MULTI_SESSION: re-enable with existing sessions and cleanup PASS")
	var panel: Dictionary = _panels()[0]
	var button: Button = _buttons(panel)[0]
	var original_text := button.text
	panel["tree"].clear()
	_plugin.set_meta("last_copied_text", "UNCHANGED")
	button.pressed.emit()
	if _plugin.get_meta("last_copied_text") != "UNCHANGED":
		_fail("empty session overwrote clipboard")
		return
	await get_tree().create_timer(1.7).timeout
	if button.text != original_text:
		_fail("empty-session feedback did not reset")
		return
	print("MULTI_SESSION_PASS")
	EditorInterface.stop_playing_scene()
	get_tree().quit()


func _launch_client() -> int:
	var log_path := ProjectSettings.globalize_path("res://client_%d.log" % Time.get_ticks_msec())
	var pid := OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", log_path,
		"--remote-debug", OS.get_cmdline_user_args()[0],
	])
	return pid


func _active_count() -> int:
	var count := 0
	for session in _observer.get_sessions():
		if session.is_active():
			count += 1
	return count


func _wait_for(predicate: Callable, description: String) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while not predicate.call() and not _failed:
		if Time.get_ticks_msec() > deadline:
			_fail("timed out waiting for " + description)
			return
		await get_tree().create_timer(0.1).timeout


func _verify_copying() -> bool:
	if _failed:
		return false
	var panels := _panels()
	var originals: Array[String] = []
	for panel in panels:
		var buttons := _buttons(panel)
		if buttons.size() != 1:
			_fail("session %s has %d copy buttons" % [panel["marker"], buttons.size()])
			return false
		originals.append(buttons[0].text)
	for index in panels.size():
		var panel: Dictionary = panels[index]
		var button: Button = _buttons(panel)[0]
		_plugin.set_meta("last_copied_text", "")
		button.pressed.emit()
		button.pressed.emit()
		var output: String = _plugin.get_meta("last_copied_text")
		if not output.contains(panel["marker"]) or not output.contains(panel["marker"].replace("SESSION_SENTINEL_", "SESSION_ERROR_")):
			_fail("copy omitted this session's warning or error")
			return false
		for other in panels:
			if other != panel and output.contains(other["marker"]):
				_fail("copy mixed messages from different sessions")
				return false
		for other_index in range(index + 1, panels.size()):
			if _buttons(panels[other_index])[0].text != originals[other_index]:
				_fail("copy feedback changed another session's button")
				return false
	await get_tree().create_timer(1.7).timeout
	for index in panels.size():
		if _buttons(panels[index])[0].text != originals[index]:
			_fail("copy feedback did not reset")
			return false
	return true


func _buttons(panel: Dictionary) -> Array[Button]:
	var buttons: Array[Button] = []
	for node in panel["tree"].get_parent().find_children("*", "Button", true, false):
		for connection in node.pressed.get_connections():
			if connection["callable"].get_object() == _plugin:
				buttons.append(node)
	return buttons


func _panels() -> Array[Dictionary]:
	var panels: Array[Dictionary] = []
	for node in EditorInterface.get_base_control().find_children("*", "Tree", true, false):
		var root: TreeItem = node.get_root()
		if root == null or node.columns < 2:
			continue
		for item in root.get_children():
			var message := item.get_text(1)
			var start := message.find("SESSION_SENTINEL_")
			if start >= 0:
				panels.append({"tree": node, "marker": message.substr(start).strip_edges()})
				break
	return panels


func _has_pid(pid: int) -> bool:
	for panel in _panels():
		if panel["marker"] == "SESSION_SENTINEL_%d" % pid:
			return true
	return false


func _find_plugin(node: Node) -> EditorPlugin:
	var script = node.get_script()
	if script is Script and script.resource_path.ends_with("/recording_plugin.gd"):
		return node as EditorPlugin
	for child in node.get_children():
		var found := _find_plugin(child)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	_failed = true
	print("MULTI_SESSION diagnostic active=", _active_count(), " panels=", _panels().size())
	push_error("MULTI_SESSION_FAIL: " + message)
	EditorInterface.stop_playing_scene()
	get_tree().quit(1)
