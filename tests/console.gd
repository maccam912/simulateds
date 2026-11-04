extends SceneTree
## Development tools must keep input bounded and not leak clicks into the world.
var console: Control
var world_clicks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440,900)
	var backdrop := Control.new()
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			world_clicks += 1)
	console = load("res://game/debug_console.gd").new()
	root.add_child(console)
	await process_frame
	assert(not console.is_open())
	console.open()
	await process_frame
	assert(console.is_open() and console.visible)
	console.command_input.text = "ros"
	console._text_changed("ros")
	console._complete()
	assert(console.command_input.text == "rosebud", "Completion did not preserve a literal command")
	console.command_input.text = ""
	console._text_changed("")
	console._complete()
	assert(console.command_input.text == "help")
	console._complete()
	assert(console.command_input.text == "rosebud", "Tab should cycle candidate commands")
	console.submit_command("clear")
	assert(console.entries.is_empty())
	console.submit_command("history")
	assert(console.history == ["clear", "history"])
	console.command_input.text = "unsent draft"
	console._history_move(-1)
	assert(console.command_input.text == "history")
	console._history_move(1)
	assert(console.command_input.text == "unsent draft", "History must preserve unsent input")
	console._append("[url=https://example.test]literal[/url]", "info")
	assert(console.output.get_parsed_text().contains("[url=https://example.test]literal[/url]"), "Console interpreted output markup")
	for index in range(190):
		console._append("Line " + str(index), "info")
	assert(console.entries.size() == console.MAX_LOG_ENTRIES)
	for index in range(55):
		console.submit_command(" clear " if index % 2 == 0 else "history")
	assert(console.history.size() == console.MAX_HISTORY)
	var prior_history: int = console.history.size()
	console.submit_command("x".repeat(console.MAX_COMMAND_LENGTH + 1))
	assert(console.history.size() == prior_history, "Oversized input should not enter history")
	assert(str(console.entries.back().text).contains("too long"))
	var session := root.get_node("Session")
	session.set_physics_process(false)
	session.saving_enabled = false
	var lot_id: String = session.home_lot()
	var funds_before: int = session.state.lots[lot_id].funds
	console.submit_command("rosebud")
	assert(session.state.lots[lot_id].funds == funds_before + 1000, "Console did not dispatch rosebud")
	assert(console.entries.back().kind == "success")
	session.role = "client"
	console.submit_command("rosebud")
	assert(session.state.lots[lot_id].funds == funds_before + 1000, "Console let a client mutate the world")
	assert(console.entries.back().kind == "error")
	session.role = "offline"
	# Click below the terminal panel, still inside its modal input shield.
	await _click(Vector2(700,800))
	assert(world_clicks == 0, "Open console leaked input to gameplay")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await process_frame
	assert(not console.is_open())
	await _click(Vector2(700,800))
	assert(world_clicks == 1, "Closed console blocked gameplay")
	print("CONSOLE_PASS")
	quit()

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = point
		button.pressed = pressed
		root.push_input(button,true)
		await process_frame
