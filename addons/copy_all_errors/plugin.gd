@tool
extends EditorPlugin

## 在调试器的「错误」面板中注入一个「复制全部」按钮，
## 点击后将所有错误/警告信息格式化并复制到系统剪贴板。

# gdlint: disable=max-line-length
const _STRINGS = {
    "en": {
        "button_text": "Copy All",
        "button_tooltip": "Copy all errors/warnings to clipboard",
        "warn_panel_not_found": "[CopyAllErrors] Could not find debugger error panel, plugin initialization failed.",
        "msg_plugin_ready": "[CopyAllErrors] Plugin ready, 'Copy All' button injected into error panel.",
        "warn_tree_invalid": "[CopyAllErrors] Error list control invalid.",
        "msg_no_content": "Nothing to copy",
        "msg_copied_log": "[CopyAllErrors] Copied %d messages to clipboard.",
        "msg_copied_button": "Copied %d items!"
    },
    "zh": {
        "button_text": "复制全部",
        "button_tooltip": "复制所有错误/警告信息到剪贴板",
        "warn_panel_not_found": "[CopyAllErrors] 未找到调试器错误面板，插件初始化失败。",
        "msg_plugin_ready": "[CopyAllErrors] 插件已就绪，「复制全部」按钮已注入错误面板。",
        "warn_tree_invalid": "[CopyAllErrors] 错误列表控件无效。",
        "msg_no_content": "没有内容",
        "msg_copied_log": "[CopyAllErrors] 已复制 %d 条消息到剪贴板。",
        "msg_copied_button": "已复制 %d 条!"
    }
}
# gdlint: enable=max-line-length

const _MAX_RETRIES := 20


class SessionWatcher extends EditorDebuggerPlugin:
	signal session_added

	func _setup_session(_session_id: int) -> void:
		session_added.emit()


var _panels: Dictionary = {}
var _session_watcher: SessionWatcher = null
var _setup_timer: Timer = null
var _retry_count := 0

var _cached_locale: String = ""
var _detected_ui_is_english := true


func _enter_tree() -> void:
	# 编辑器 UI 可能还没完全就绪，用 Timer 延迟查找
	_setup_timer = Timer.new()
	_setup_timer.wait_time = 0.5
	_setup_timer.one_shot = true
	_setup_timer.timeout.connect(_try_setup)
	add_child(_setup_timer)
	_session_watcher = SessionWatcher.new()
	_session_watcher.session_added.connect(_schedule_setup)
	add_debugger_plugin(_session_watcher)
	_schedule_setup()


func _exit_tree() -> void:
	_cached_locale = ""
	if _session_watcher != null:
		_session_watcher.session_added.disconnect(_schedule_setup)
		remove_debugger_plugin(_session_watcher)
		_session_watcher = null
	_cleanup_timer()
	for id in _panels.keys():
		_remove_panel(id)


# ────────────────── 国际化 ──────────────────


func _get_locale() -> String:
	# 已缓存则直接返回
	if not _cached_locale.is_empty():
		return _cached_locale

	# 获取可用翻译键
	var available_locales := _STRINGS.keys()

	# Godot 4.6+ 提供此方法；动态调用避免旧版在解析时失败。
	var editor_lang := ""
	if EditorInterface.has_method("get_editor_language"):
		editor_lang = EditorInterface.call("get_editor_language")

	if not editor_lang.is_empty():
		# 精确匹配
		if editor_lang in available_locales:
			_cached_locale = editor_lang
		else:
			# 前缀匹配 (如 "zh_CN" 匹配 "zh")
			for loc in available_locales:
				if editor_lang.begins_with(loc + "_"):
					_cached_locale = loc
					break
			# 无匹配则默认英语
			if _cached_locale.is_empty():
				_cached_locale = "en"
	else:
		# 回退：基于按钮文本检测
		_cached_locale = "en" if _detected_ui_is_english else "zh"

	return _cached_locale


func _tr(key: String) -> String:
	var locale := _get_locale()
	if _STRINGS.has(locale) and _STRINGS[locale].has(key):
		return _STRINGS[locale][key]
	return _STRINGS["en"].get(key, key)


# ────────────────── 初始化 ──────────────────


func _schedule_setup() -> void:
	_retry_count = 0
	if is_instance_valid(_setup_timer):
		_setup_timer.start()


func _try_setup() -> void:
	var base := EditorInterface.get_base_control()
	if not base:
		_schedule_retry()
		return

	var results: Array[Dictionary] = []
	_find_error_panels(base, results)
	if results.is_empty():
		_schedule_retry()
		return

	for result in results:
		var tree: Tree = result["tree"]
		if not _panels.has(tree.get_instance_id()):
			_inject_copy_button(result["hbox"], tree)
	# 已找到旧面板并不代表刚通知的新会话面板也已就绪。
	if results.size() < _session_watcher.get_sessions().size():
		_schedule_retry()


func _schedule_retry() -> void:
	_retry_count += 1
	if _retry_count < _MAX_RETRIES and is_instance_valid(_setup_timer):
		_setup_timer.start()
	else:
		push_warning(_tr("warn_panel_not_found"))
		# 保留单次定时器，后续新会话仍可触发查找；不持续轮询。


func _cleanup_timer() -> void:
	if is_instance_valid(_setup_timer):
		_setup_timer.queue_free()
		_setup_timer = null


# ────────────────── 查找错误面板 ──────────────────


func _find_error_panels(node: Node, results: Array[Dictionary]) -> void:
	# 目标结构（Godot 源码 script_editor_debugger.cpp）：
	# VBoxContainer ("Errors" / "错误")
	#   ├─ HBoxContainer
	#   │    ├─ Button ("Expand All" / "全部展开")
	#   │    ├─ Button ("Collapse All" / "全部折叠")
	#   │    ├─ Control (spacer)
	#   │    └─ Button ("Clear" / "清除")
	#   └─ Tree (error_tree, columns=2)
	if node is VBoxContainer:
		var tree: Tree = null
		var hbox: HBoxContainer = null
		var has_expand_btn := false

		for child in node.get_children():
			if child is HBoxContainer and not has_expand_btn:
				for btn in child.get_children():
					if btn is Button and btn.text in ["Expand All", "全部展开"]:
						has_expand_btn = true
						hbox = child
						_detected_ui_is_english = (btn.text == "Expand All")
						break
			elif child is Tree and tree == null:
				tree = child

		if has_expand_btn and tree != null and hbox != null:
			results.append({"tree": tree, "hbox": hbox})
			return

	for child in node.get_children():
		_find_error_panels(child, results)


# ────────────────── 注入按钮 ──────────────────


func _inject_copy_button(hbox: HBoxContainer, tree: Tree) -> void:
	var button := Button.new()
	button.text = _tr("button_text")
	button.tooltip_text = _tr("button_tooltip")
	button.pressed.connect(_on_copy_all_pressed.bind(tree, button))
	# 定时器随按钮销毁，避免禁用插件后仍回调已释放的按钮。
	var feedback_timer := Timer.new()
	feedback_timer.name = "CopyFeedback"
	feedback_timer.wait_time = 1.5
	feedback_timer.one_shot = true
	feedback_timer.timeout.connect(_reset_button_text.bind(button))
	button.add_child(feedback_timer)

	# 尝试加上复制图标
	var theme := EditorInterface.get_editor_theme()
	if theme:
		for icon_name in ["ActionCopy", "CopyNodePath", "Duplicate"]:
			if theme.has_icon(icon_name, "EditorIcons"):
				button.icon = theme.get_icon(icon_name, "EditorIcons")
				break

	# 插入到「全部折叠」按钮后面
	var insert_idx := hbox.get_child_count()
	for i in hbox.get_child_count():
		var child := hbox.get_child(i)
		if child is Button and child.text in ["Collapse All", "全部折叠"]:
			insert_idx = i + 1
			break

	hbox.add_child(button)
	if insert_idx < hbox.get_child_count():
		hbox.move_child(button, insert_idx)
	var id := tree.get_instance_id()
	_panels[id] = {"tree": tree, "button": button}
	tree.tree_exiting.connect(_remove_panel.bind(id))

	print(_tr("msg_plugin_ready"))


func _remove_panel(id: int) -> void:
	if not _panels.has(id):
		return
	var panel: Dictionary = _panels[id]
	_panels.erase(id)
	var tree: Tree = panel["tree"]
	var callback := _remove_panel.bind(id)
	if is_instance_valid(tree) and tree.tree_exiting.is_connected(callback):
		tree.tree_exiting.disconnect(callback)
	var button: Button = panel["button"]
	if is_instance_valid(button):
		button.queue_free()


# ────────────────── 复制逻辑 ──────────────────


func _on_copy_all_pressed(tree: Tree, button: Button) -> void:
	if not is_instance_valid(tree):
		push_warning(_tr("warn_tree_invalid"))
		return

	var root := tree.get_root()
	if not root or not root.get_first_child():
		_flash_button(button, _tr("msg_no_content"))
		return

	var entries: PackedStringArray = []
	var count := 0
	var item := root.get_first_child()

	while item:
		entries.append(_format_error_item(item))
		count += 1
		item = item.get_next()

	var output := "\n\n".join(entries).strip_edges()
	_copy_to_clipboard(output)
	print(_tr("msg_copied_log") % count)
	_flash_button(button, _tr("msg_copied_button") % count)


func _copy_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)


func _flash_button(button: Button, msg: String) -> void:
	if not is_instance_valid(button):
		return
	button.text = msg
	button.get_node("CopyFeedback").start()


func _reset_button_text(button: Button) -> void:
	if is_instance_valid(button):
		button.text = _tr("button_text")


# ────────────────── 格式化 ──────────────────


func _format_error_item(item: TreeItem) -> String:
	var parts: PackedStringArray = []

	# 判断消息类型 (W = 警告, E = 错误)
	var type_char := _get_type_char(item)

	# 主行: "W 0:00:01:633   GDScript::reload: ..."
	var time_str: String = item.get_text(0).strip_edges()
	var msg_str: String = item.get_text(1).strip_edges()
	parts.append("%s %s   %s" % [type_char, time_str, msg_str])

	# 子行: "  <GDScript 错误> UNUSED_VARIABLE" 等
	var child := item.get_first_child()
	while child:
		var c0: String = child.get_text(0).strip_edges()
		var c1: String = child.get_text(1).strip_edges()
		if c0 or c1:
			var line := "  "
			if c0 and c1:
				line += c0 + " " + c1
			elif c0:
				line += c0
			else:
				line += c1
			parts.append(line)
		child = child.get_next()

	return "\n".join(parts)


func _get_type_char(item: TreeItem) -> String:
	# 优先从 TreeItem 的 metadata 判断
	# (Godot 内部存储了 "warning" / "error" / "cycled_error")
	var meta = item.get_metadata(0)
	if meta is String:
		if meta == "warning":
			return "W"
		if meta in ["error", "cycled_error"]:
			return "E"

	# metadata 不可用时，从子项文本推断
	var child := item.get_first_child()
	while child:
		var combined := (child.get_text(0) + " " + child.get_text(1)).to_upper()
		if "WARNING" in combined or "WARN" in combined:
			return "W"
		child = child.get_next()

	# 保守默认 → 警告
	return "W"
