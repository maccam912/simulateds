extends Control
## A development console, not an evaluator. All commands cross the Session boundary.
signal closed

const Style = preload("res://game/style.gd")
const MAX_HISTORY := 50
const MAX_LOG_ENTRIES := 180
const MAX_COMMAND_LENGTH := 256
const COMMANDS: Array[String] = ["help", "rosebud", "motherlode", "money", "needs", "time", "speed", "teleport", "cancel", "save", "stats", "construction cancel", "clear", "history"]

var output: RichTextLabel
var command_input: LineEdit
var context_label: Label
var panel: PanelContainer
var history: Array[String] = []
var entries: Array[Dictionary] = []
var _opened := false
var _member_id := ""
var _history_index := 0
var _draft := ""
var _animation: Tween
var _completion_seed := ""
var _completion_candidates: Array[String] = []
var _completion_index := -1
var _changing_input := false

func _ready() -> void:
	name = "DeveloperConsole"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Style.make_theme()
	_build()
	_append("Simulateds development console\nType help for commands. rosebud adds §1,000 to your household.\nShared-world changes require the host. Commands are literal, never evaluated as code.", "info")
	hide()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.035, 0.04, 0.35)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	add_child(panel)
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.055
	panel.anchor_bottom = 0.64
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Style.box(Color(0.035, 0.058, 0.075, 0.98), 5, Style.EDGE))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "Developer console"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(clear_output)
	heading.add_child(clear_button)
	var close_button := Button.new()
	close_button.text = "Close  ×"
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	context_label = Label.new()
	context_label.add_theme_font_size_override("font_size", 12)
	context_label.add_theme_color_override("font_color", Style.MUTED)
	column.add_child(context_label)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	output = RichTextLabel.new()
	output.name = "CommandOutput"
	output.bbcode_enabled = false
	output.selection_enabled = true
	output.scroll_following = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.custom_minimum_size.y = 120
	output.add_theme_font_override("normal_font", font)
	output.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(output)
	var input_row := HBoxContainer.new()
	column.add_child(input_row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_color_override("font_color", Style.GREEN)
	prompt.add_theme_font_override("font", font)
	input_row.add_child(prompt)
	command_input = LineEdit.new()
	command_input.name = "CommandInput"
	command_input.placeholder_text = "help"
	command_input.max_length = MAX_COMMAND_LENGTH
	command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_input.add_theme_font_override("font", font)
	command_input.text_submitted.connect(submit_command)
	command_input.gui_input.connect(_input_key)
	command_input.text_changed.connect(_text_changed)
	input_row.add_child(command_input)
	var run_button := Button.new()
	run_button.text = "Run"
	run_button.pressed.connect(func(): submit_command(command_input.text))
	input_row.add_child(run_button)
	var hint := Label.new()
	hint.text = "Enter: run  ·  ↑ / ↓: history  ·  Tab: complete  ·  Escape: close  ·  Select output to copy"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Style.MUTED)
	column.add_child(hint)
	var soundscape := get_node_or_null("/root/Soundscape")
	if soundscape != null and soundscape.has_method("attach_controls"):
		soundscape.call("attach_controls", self)

func open(member_id: String = "") -> void:
	_member_id = member_id
	_opened = true
	show()
	move_to_front()
	var session := get_node_or_null("/root/Session")
	var role := str(session.get("role")) if session != null else "offline"
	context_label.text = "READ ONLY · Host controls simulation changes" if role in ["client", "joining"] else ("HOST · Changes affect the shared neighborhood" if role == "host" else "LOCAL · Changes affect this neighborhood")
	_history_index = history.size()
	_draft = ""
	_set_input("")
	command_input.call_deferred("grab_focus")
	if _animation != null and _animation.is_valid():
		_animation.kill()
	if _reduced_motion():
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		_animation = create_tween()
		_animation.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not _opened:
		return
	_opened = false
	if _animation != null and _animation.is_valid():
		_animation.kill()
	modulate.a = 1.0
	command_input.release_focus()
	hide()
	closed.emit()

func toggle(member_id: String = "") -> void:
	if is_open():
		close()
	else:
		open(member_id)

func is_open() -> bool:
	return _opened

func _input(event: InputEvent) -> void:
	if not _opened or not event is InputEventKey or not event.pressed or event.echo:
		return
	var is_console_key: bool = event.keycode == KEY_F1
	if InputMap.has_action("console"):
		is_console_key = is_console_key or event.is_action_pressed("console")
	if event.keycode == KEY_ESCAPE or is_console_key:
		close()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	# An open terminal must not rotate, save, pause, or move the game behind it.
	if _opened:
		get_viewport().set_input_as_handled()

func _input_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			_history_move(-1)
			command_input.accept_event()
		KEY_DOWN:
			_history_move(1)
			command_input.accept_event()
		KEY_TAB:
			_complete(-1 if event.shift_pressed else 1)
			command_input.accept_event()

func _text_changed(_text: String) -> void:
	if not _changing_input:
		_completion_seed = ""
		_completion_candidates.clear()
		_completion_index = -1

func _set_input(value: String) -> void:
	_changing_input = true
	command_input.text = value
	command_input.caret_column = value.length()
	_changing_input = false

func _history_move(direction: int) -> void:
	if history.is_empty():
		return
	if _history_index == history.size():
		_draft = command_input.text
	_history_index = clampi(_history_index + direction, 0, history.size())
	_set_input(_draft if _history_index == history.size() else history[_history_index])
	_completion_candidates.clear()

func _complete(direction: int = 1) -> void:
	if _completion_candidates.is_empty():
		_completion_seed = command_input.text.strip_edges().to_lower()
		for candidate in COMMANDS:
			if candidate.begins_with(_completion_seed):
				_completion_candidates.append(candidate)
		_completion_index = -1 if direction > 0 else 0
	if _completion_candidates.is_empty():
		_sound("error")
		return
	_completion_index = posmod(_completion_index + direction, _completion_candidates.size())
	_set_input(_completion_candidates[_completion_index])

func submit_command(line: String) -> void:
	line = line.strip_edges()
	if line.is_empty():
		return
	if line.length() > MAX_COMMAND_LENGTH:
		_append("Command is too long (maximum %d characters)." % MAX_COMMAND_LENGTH, "error")
		_sound("error")
		return
	if history.is_empty() or history.back() != line:
		history.append(line)
		if history.size() > MAX_HISTORY:
			history.pop_front()
	_history_index = history.size()
	_draft = ""
	_completion_candidates.clear()
	_completion_index = -1
	_set_input("")
	var command := line.to_lower()
	if command == "clear":
		clear_output()
	elif command == "history":
		_append("> " + line, "command")
		_append("\n".join(history), "info")
	else:
		_append("> " + line, "command")
		var session := get_node_or_null("/root/Session")
		if session == null or not session.has_method("execute_debug"):
			_append("Debug commands are unavailable in this session.", "error")
			_sound("error")
		else:
			var reply: Variant = session.call("execute_debug", line, _member_id)
			if not reply is Dictionary or not reply.get("message") is String or not reply.get("ok") is bool:
				_append("The command handler returned an invalid response.", "error")
				_sound("error")
			else:
				_append(str(reply.message).left(4096), "success" if reply.ok else "error")
				_sound("confirm" if reply.ok else "error")
	command_input.call_deferred("grab_focus")

func clear_output() -> void:
	entries.clear()
	output.clear()

func _append(text: String, kind: String) -> void:
	entries.append({"text": text, "kind": kind})
	while entries.size() > MAX_LOG_ENTRIES:
		entries.pop_front()
	output.clear()
	for entry in entries:
		var color := Style.TEXT
		match str(entry.kind):
			"error": color = Color("df9785")
			"success": color = Style.GREEN
			"command": color = Style.GOLD
			"info": color = Style.MUTED
		output.push_color(color)
		output.add_text(str(entry.text) + "\n")
		output.pop()

func _reduced_motion() -> bool:
	var preferences := get_node_or_null("/root/Preferences")
	return preferences != null and bool(preferences.get("values").get("reduced_motion", false))

func _sound(event: String) -> void:
	var soundscape := get_node_or_null("/root/Soundscape")
	if soundscape != null and soundscape.has_method("play_ui"):
		soundscape.call("play_ui", event)
