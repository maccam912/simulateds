extends Control
## Application flow. Menus pause only offline simulation, never network polling.
const Style = preload("res://game/style.gd")
const Icons = preload("res://game/ui_icons.gd")
const SaveLibrary = preload("res://game/save_library.gd")
var navigation_hint: Label
const GameScene = preload("res://game/main.tscn")
const Console = preload("res://game/debug_console.gd")
const HouseholdEditor = preload("res://game/household_editor.gd")
const MailPanel = preload("res://game/mail_panel.gd")
const GuidePanel = preload("res://game/guide_panel.gd")
var game: Control
var console: Control
var menu_root: Control
var menu_panel: PanelContainer
var menu_content: VBoxContainer
var shade: ColorRect
var page := "splash"
var previous_page := "main"
var return_page := "main"
var message_label: Label
var slot_name: LineEdit
var selected_slot := ""
var _slot_rows: Dictionary = {}
var _overwrite_return: Dictionary = {}
var _recovery: Dictionary = {}
var binding_action := ""
var binding_buttons: Dictionary = {}
var binding_hint: Label
var _transition: Tween
var _confirm_action: Callable
var _booted := false
var household_editor: Control
var household_apply: Button
var household_cancel: Button
var _pending_household: Dictionary = {}
var household_discard: HBoxContainer
var household_actions: HBoxContainer
var household_dirty: Label
var mail_panel: Control
var guide_panel: Control
var _guide_return := "main"
var _guide_tab := 0
var _guide_welcome := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	if "--server" in OS.get_cmdline_user_args() or "--native-smoke" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		game = GameScene.instantiate()
		add_child(game)
		return
	Session.menu_paused = true
	game = GameScene.instantiate()
	add_child(game)
	game.pause_requested.connect(open_pause)
	game.save_menu_requested.connect(func(): open_saves("save"))
	game.recovery_requested.connect(func():
		if _has_recovery(): open_saves("load",str(_recovery.id)))
	game.household_requested.connect(open_household)
	game.mail_requested.connect(open_mail)
	Session.command_completed.connect(_household_result)
	Session.world_changed.connect(_household_changed)
	Session.world_changed.connect(_refresh_guide_context)
	menu_root = Control.new()
	add_child(menu_root)
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	shade = ColorRect.new()
	menu_root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025,0.045,0.055,0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	console = Console.new()
	add_child(console)
	console.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	console.closed.connect(_update_pause)
	Preferences.changed.connect(_preferences_changed)
	Session.status_changed.connect(_session_status)
	if "--play" in OS.get_cmdline_user_args():
		_booted = true
		show_game()
	else:
		_boot()

func _boot() -> void:
	_show_page("splash")
	var logo := TextureRect.new()
	logo.texture = preload("res://icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(96,96)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_content.add_child(logo)
	var brand := _label("Simulateds",38)
	brand.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	menu_content.add_child(brand)
	var hint := _label("Preparing your neighborhood",13,Style.MUTED)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	menu_content.add_child(hint)
	game.hud.hide()
	await get_tree().process_frame
	_booted = true
	if not "--skip-splash" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.7).timeout
	if page == "splash": show_main()

func _show_page(value: String, title: String = "", subtitle: String = "") -> void:
	binding_action=""
	binding_buttons.clear()
	page=value
	menu_root.show()
	game.hud.hide()
	if is_instance_valid(menu_panel):
		menu_root.remove_child(menu_panel)
		menu_panel.queue_free()
	menu_panel = PanelContainer.new()
	menu_root.add_child(menu_panel)
	menu_panel.anchor_left=0.5; menu_panel.anchor_right=0.5
	menu_panel.anchor_top=0.5; menu_panel.anchor_bottom=0.5
	var width := 720.0 if value in ["settings","save","load","household","mail","guide"] else 440.0
	var height := 600.0 if value in ["settings","save","load","household","mail","guide"] else 490.0
	if value in ["save","load"]:
		width=minf(width,size.x-24.0)
		height=minf(height,size.y-24.0)
	if value=="splash": height=230
	menu_panel.offset_left=-width/2; menu_panel.offset_right=width/2
	menu_panel.offset_top=-height/2; menu_panel.offset_bottom=height/2
	if value=="main":
		menu_panel.anchor_left=0; menu_panel.anchor_right=0
		menu_panel.offset_left=48; menu_panel.offset_right=488
	if value=="household":
		menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		menu_panel.offset_left=12; menu_panel.offset_right=-12; menu_panel.offset_top=12; menu_panel.offset_bottom=-12
	menu_panel.add_theme_stylebox_override("panel",Style.box(Color(0.065,0.105,0.13,0.96),7,Color("637b83")))
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	menu_panel.add_child(margin)
	menu_content=VBoxContainer.new(); menu_content.add_theme_constant_override("separation",12); margin.add_child(menu_content)
	if not title.is_empty(): menu_content.add_child(_label(title,30))
	if not subtitle.is_empty():
		var text:=_label(subtitle,14,Style.MUTED)
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		menu_content.add_child(text)
	message_label=null
	_update_pause()
	call_deferred("_focus_menu")
	Soundscape.set_context("menu")
	if _transition: _transition.kill()
	if not bool(Preferences.values.get("reduced_motion",false)):
		menu_panel.modulate.a=0
		_transition=create_tween()
		_transition.tween_property(menu_panel,"modulate:a",1.0,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _navigation_grid(choices: Array) -> void:
	var grid := GridContainer.new(); grid.columns=2 if Preferences.values.navigation_labels else 3
	grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",8)
	menu_content.add_child(grid)
	for choice: Array in choices:
		var button := _button(str(choice[0]),choice[1],bool(choice[2]) if choice.size()>2 else false)
		Icons.navigation(button,str(choice[0]),bool(Preferences.values.navigation_labels))
		button.add_theme_font_size_override("font_size",13)
		button.custom_minimum_size=Vector2(180,48) if Preferences.values.navigation_labels else Vector2(96,72); button.add_theme_constant_override("icon_max_width",32); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	navigation_hint=_label("",14,Style.MUTED); navigation_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; menu_content.add_child(navigation_hint)

func show_main() -> void:
	_show_page("main","Simulateds",str(Session.state.get("neighborhood_name","Linden Grove")))
	_navigation_grid([
		["Play starter household" if Session.started_fresh else "Continue",show_game,true], ["New neighborhood",_new_game_menu], ["Load neighborhood",func(): open_saves("load")],
		["Play together",func(): show_game(); game._open_connection()], ["Settings",func(): open_settings()], ["Guide & controls",func(): open_guide()],
		["Customize household" if Session.started_fresh else "Edit household",open_household], ["Quit",_request_quit]
	])
	if not Session.saving_enabled:
		var warning:=_label("The current save could not be loaded. Its files are protected. Save a new copy to preserve this temporary neighborhood.",13,Style.GOLD)
		warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		menu_content.add_child(warning)

func show_game() -> void:
	Session.started_fresh=false
	page="game"
	menu_root.hide()
	game.hud.show()
	game._refresh()
	_update_pause()
	Soundscape.set_context("build" if game._last_build_mode else "live")
	get_viewport().gui_release_focus()
	if not Session.startup_continuation.is_empty():
		var report: Dictionary=Session.startup_continuation
		Session.startup_continuation={}
		if report.has("message") or int(report.interrupted)>0 or not report.relocated.is_empty():
			_show_load_notice(str(report.get("message","Neighborhood continued.")),report)

func open_pause() -> void:
	if console.is_open(): return
	var shared:=Session.role in ["host","client","joining"]
	_show_page("pause","Game menu" if shared else "Paused","The shared neighborhood keeps running." if shared else "Your household can wait a moment.")
	_navigation_grid([
		["Resume",show_game,true], ["Save neighborhood",func(): open_saves("save")], ["Load neighborhood",func(): open_saves("load")],
		["Edit household",open_household], ["Settings",func(): open_settings()], ["Guide & controls",func(): open_guide()],
		["Developer console",_open_console], ["Main menu",_request_main], ["Quit to desktop",_request_quit]
	])

func _request_main() -> void:
	if Session.role in ["host","client","joining"]:
		_confirm("Leave this session?","Hosting will stop and connected players will be disconnected. Your host saves the shared neighborhood; unfinished construction is discarded.",func(): Session.leave(); show_main())
	else:
		show_main()

func _request_quit() -> void:
	_confirm("Quit Simulateds?","The current neighborhood will be saved. Unfinished construction is discarded. If you are hosting, other players will disconnect.",func():
		if Session.is_authority() and not Session.save_world():
			_feedback("Could not save. Stay in the game and check your save location.",false)
			return
		await Session.quit_application(Session.role=="offline"))

func _confirm(title: String, detail: String, action: Callable) -> void:
	previous_page=page
	_confirm_action=action
	_show_page("confirm",title,detail)
	menu_content.add_child(_button("Confirm",func(): _confirm_action.call(),true))
	menu_content.add_child(_button("Cancel",_back))
	_message_area()

func _new_game_menu() -> void:
	previous_page=page
	_show_page("new","New neighborhood","Start with a furnished home and two residents. Your current neighborhood is preserved in a recovery save.")
	var name:=LineEdit.new(); name.placeholder_text="Neighborhood name"; name.text="Linden Grove"; name.max_length=40; menu_content.add_child(name)
	var offer_guide := CheckButton.new(); offer_guide.text="Show the first-day guide"; offer_guide.button_pressed=bool(Preferences.values.first_day_guide); menu_content.add_child(offer_guide)
	var create:=_button("Create neighborhood",func():
		var result:Dictionary=Session.new_world(name.text)
		if result.ok:
			_finish_replacement(result)
			var guide_saved := Preferences.set_value("first_day_guide",offer_guide.button_pressed)
			if offer_guide.button_pressed: open_guide(true)
			if not guide_saved:
				if page=="guide": _feedback(Preferences.last_error,false)
				else: game._notice(Preferences.last_error)
		else: _feedback(result.message,false),true)
	create.disabled=Session.role!="offline"
	menu_content.add_child(create)
	if create.disabled: menu_content.add_child(_label("Leave the multiplayer session before creating a world.",12,Style.GOLD))
	menu_content.add_child(_button("Back",_back))
	_message_area()

func open_saves(mode: String, selection: String = "", draft: Variant = null, previous_row: Dictionary = {}) -> void:
	if page in ["main","pause","game"]: return_page="pause" if page=="game" else page
	var title:="Save neighborhood" if mode=="save" else "Load neighborhood"
	_show_page(mode,title,"World saves include every household in this neighborhood.")
	selected_slot=""
	_slot_rows.clear()
	if mode=="save":
		slot_name=LineEdit.new(); slot_name.max_length=48
		slot_name.placeholder_text="Save name"
		slot_name.text=("%s · Day %d" % [str(Session.state.get("neighborhood_name","Linden Grove")),int(Session.state.get("day",1))]).left(48) if draft==null else str(draft)
		menu_content.add_child(slot_name)
	elif _has_recovery():
		var recovery := _button("Previous neighborhood · Select recovery save",func(): open_saves("load",str(_recovery.id)))
		recovery.tooltip_text=str(_recovery.name)
		menu_content.add_child(recovery)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; menu_content.add_child(scroll)
	var list:=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	var rows:Array=Session.list_saves()
	if not previous_row.is_empty() and not rows.any(func(row): return row.id==selection):
		rows.push_front({"id":selection,"name":previous_row.name,"modified":previous_row.modified,"valid":false,"message":"This save is no longer available."})
	var group := ButtonGroup.new()
	var offset := int(Time.get_time_zone_from_system().bias)
	if rows.is_empty(): list.add_child(_label("No saved neighborhoods yet.",15,Style.MUTED))
	for row in rows:
		var minutes:=int(row.get("minutes",0))
		var timestamp:=SaveLibrary.display_time(int(row.get("modified",0)),offset)
		var identity := str(row.get("neighborhood",""))
		if row.has("household"):
			identity="%s · %d %s · §%d · %s" % [row.home,row.residents,"resident" if row.residents==1 else "residents",row.funds,row.household]
		var label:="%s\nDay %d · %02d:%02d · %s\n%s" % [row.name,int(row.day),minutes/60,minutes%60,timestamp.local,identity] if row.valid else str(row.name)+"\nUnavailable"
		_slot_rows[str(row.id)]=row
		var button:=_button(label,func():
			selected_slot=str(row.id)
			if mode=="save": slot_name.text=str(row.get("name","Neighborhood"))
			_feedback("Selected: "+str(row.get("name","Neighborhood")),true))
		button.toggle_mode=true; button.button_group=group
		button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.y=78 if row.valid else 54
		button.add_theme_stylebox_override("pressed",Style.box(Style.GOLD,4))
		button.add_theme_color_override("font_pressed_color",Style.INK)
		if not row.valid and str(row.id)==selection:
			button.add_theme_stylebox_override("disabled",Style.box(Style.INK,4,Style.GOLD))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.disabled=not bool(row.get("valid",false))
		button.tooltip_text="%s\n%s\nSaved %s\n%s" % [row.name,str(row.get("neighborhood",""))+" · "+identity if row.has("household") else identity,timestamp.utc,row.message]
		list.add_child(button)
		if str(row.id)==selection:
			selected_slot=selection
			button.set_pressed_no_signal(true)
			_focus_slot.call_deferred(scroll,button)
	var actions:=HBoxContainer.new(); menu_content.add_child(actions)
	if mode=="save":
		actions.add_child(_button("Save new copy",func(): _perform_save(""),true))
		actions.add_child(_button("Overwrite selected",_confirm_overwrite))
	else:
		actions.add_child(_button("Load selected",_perform_load,true))
	actions.add_child(_button("Back",_back_from_saves))
	_message_area()
	if (mode=="load" and Session.role!="offline") or (mode=="save" and not Session.is_authority()):
		_feedback("The host owns shared saves. Leave the session before loading another neighborhood." if mode=="load" else "Only the host can save this shared neighborhood.",false)

func _focus_slot(scroll: ScrollContainer, button: Button) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree(): return
	scroll.ensure_control_visible(button)
	if not button.disabled: button.grab_focus()

func _confirm_overwrite() -> void:
	if selected_slot.is_empty(): _feedback("Select a save to overwrite.",false); return
	if selected_slot=="autosave": _feedback("Use Save new copy; the current autosave is managed automatically.",false); return
	var id:=selected_slot
	var name:=slot_name.text
	var row: Dictionary=_slot_rows[id]
	var target:=str(row.name)
	_overwrite_return={"id":id,"name":name}
	_confirm("Overwrite this save?","Replace “%s” with the current neighborhood. Its previous version is kept as a backup." % target,func():
		_overwrite_return.clear()
		var result: Dictionary=Session.save_slot(name,id)
		open_saves("save",id,result.get("name",name),{} if result.ok else row)
		if result.ok: Soundscape.play_ui("save")
		_feedback(result.message,result.ok))

func _perform_save(id: String) -> void:
	var result:Dictionary=Session.save_slot(slot_name.text,id)
	if result.ok:
		Soundscape.play_ui("save")
		open_saves("save",str(result.id),result.name)
	_feedback(result.message,result.ok)

func _perform_load() -> void:
	if selected_slot.is_empty(): _feedback("Select a neighborhood first.",false); return
	var result:Dictionary=Session.load_slot(selected_slot)
	if result.ok:
		_finish_replacement(result)
	else: _feedback(result.message,false)

func _has_recovery() -> bool:
	return Session.role=="offline" and _recovery.get("generation")==Session.world_generation

func _finish_replacement(result: Dictionary) -> void:
	_recovery={"id":result.recovery_id,"name":result.recovery_name,"generation":Session.world_generation}
	show_game()
	_show_load_notice(str(result.message),result.report)

func _show_load_notice(message: String, report: Dictionary) -> void:
	var relocated: int=report.relocated.size()
	var interrupted: int=report.interrupted
	if relocated==1: message+=" %s returned home because their saved spot was blocked." % report.relocated[0]
	elif relocated>1: message+=" %d residents returned home from blocked spots." % relocated
	if interrupted>0: message+=" %d unfinished %s stopped." % [interrupted,"activity" if interrupted==1 else "activities"]
	game._show_notice(message)
	game.notice_label.tooltip_text="\n".join(report.details)
	game.notice_label.mouse_filter=Control.MOUSE_FILTER_PASS if not report.details.is_empty() else Control.MOUSE_FILTER_IGNORE
	game.notice_recovery_button.visible=_has_recovery()
	if _has_recovery(): game.notice_recovery_button.tooltip_text=str(_recovery.name)

func open_settings(selected_tab: String = "") -> void:
	if page!="settings": previous_page=page
	_show_page("settings","Settings","Changes apply immediately and are saved on this device.")
	var tabs:=TabContainer.new(); tabs.name="SettingsTabs"; tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; menu_content.add_child(tabs)
	var audio_page:=_settings_tab(tabs,"Audio")
	for entry in [["master_volume","Master"],["music_volume","Background music"],["stereo_volume","Household stereos"],["effects_volume","Effects"],["ambience_volume","Ambience"]]:
		_volume_row(audio_page,str(entry[0]),str(entry[1]))
	audio_page.add_child(_button("Preview sound",func(): Soundscape.play_ui("confirm")))
	var display:=_settings_tab(tabs,"Display")
	_check_setting(display,"fullscreen","Fullscreen")
	_check_setting(display,"vsync","Vertical sync")
	_option_setting(display,"fps_limit","Frame limit",[30,60,120,0],["30 FPS","60 FPS","120 FPS","Unlimited"])
	_option_setting(display,"quality","Scenery detail",["high","low"],["High","Low"])
	_check_setting(display,"navigation_labels","Show navigation labels")
	_option_setting(display,"ui_scale","Interface scale",[0.9,1.0,1.1,1.25],["90%","100%","110%","125%"])
	var access:=_settings_tab(tabs,"Comfort")
	_check_setting(access,"reduced_motion","Reduced motion")
	var motion_note:=_label("Stops menu fades and decorative resident motion. Camera focus, resident movement and turns update immediately. Game timing and activity cues are unchanged. Sounds stay on, with shorter music fades.",14,Style.MUTED)
	motion_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; access.add_child(motion_note)
	_check_setting(access,"first_day_guide","Offer the guide in new neighborhoods")
	var note:=_label("Need bars also show numbers. Sound is never the only indication of success or failure.",14,Style.MUTED); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; access.add_child(note)
	var controls:=_settings_tab(tabs,"Controls")
	binding_hint=_label("Choose a binding, then press a key. Escape cancels.",13,Style.MUTED); controls.add_child(binding_hint)
	var grid:=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",18); controls.add_child(grid)
	for action in Preferences.values.get("bindings",{}):
		grid.add_child(_label(str(Preferences.ACTION_NAMES[action]),14))
		var button:=_button(Preferences.action_label(action),func():
			binding_action=str(action); binding_hint.text="Press a key for "+str(Preferences.ACTION_NAMES[action])+". Escape cancels.")
		button.accessibility_name=str(Preferences.ACTION_NAMES[action])
		button.accessibility_description="Current key: "+Preferences.action_label(action)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_child(button); binding_buttons[action]=button
	for index in range(tabs.get_tab_count()):
		if tabs.get_tab_title(index)==selected_tab: tabs.current_tab=index
	var row:=HBoxContainer.new(); menu_content.add_child(row)
	row.add_child(_button("Restore defaults",func():
		if Preferences.reset_defaults(): open_settings()
		else: _feedback(Preferences.last_error,false)))
	row.add_child(_button("Back",_back))
	_message_area()

func _settings_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new(); scroll.name=title; scroll.follow_focus=true; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; tabs.add_child(scroll)
	var margin:=MarginContainer.new(); margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	scroll.add_child(margin)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",16); margin.add_child(box)
	return box

func _volume_row(parent: Node,key: String,title: String) -> void:
	var box:=VBoxContainer.new(); parent.add_child(box)
	var row:=HBoxContainer.new(); box.add_child(row)
	var label:=_label(title,15); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
	var value:=_label("%d%%" % roundi(float(Preferences.values.get(key,1.0))*100),14,Style.MUTED); row.add_child(value)
	var slider:=HSlider.new(); slider.min_value=0; slider.max_value=100; slider.step=1; slider.value=float(Preferences.values.get(key,1.0))*100; box.add_child(slider)
	slider.accessibility_name=title
	slider.accessibility_description="Volume in percent. Zero mutes this channel."
	slider.value_changed.connect(func(number):
		if not Preferences.set_value(key,float(number)/100.0):
			slider.set_value_no_signal(float(Preferences.values[key])*100)
			_feedback(Preferences.last_error,false)
		value.text="%d%%" % roundi(float(Preferences.values[key])*100))

func _check_setting(parent: Node,key: String,title: String) -> void:
	var check:=CheckButton.new(); check.text=title; check.button_pressed=bool(Preferences.values.get(key,false)); parent.add_child(check)
	check.toggled.connect(func(value):
		if not Preferences.set_value(key,value):
			check.set_pressed_no_signal(bool(Preferences.values[key]))
			_feedback(Preferences.last_error,false))

func _option_setting(parent: Node,key: String,title: String,values: Array,labels: Array) -> void:
	var row:=HBoxContainer.new(); parent.add_child(row)
	var label:=_label(title,15); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
	var option:=OptionButton.new(); option.custom_minimum_size.x=180; option.accessibility_name=title
	for i in range(labels.size()):
		option.add_item(labels[i])
		if str(Preferences.values.get(key))==str(values[i]): option.select(i)
	row.add_child(option)
	option.item_selected.connect(func(index):
		if not Preferences.set_value(key,values[index]):
			for i in range(values.size()):
				if str(Preferences.values[key])==str(values[i]): option.select(i)
			_feedback(Preferences.last_error,false))

func _input(event: InputEvent) -> void:
	# LineEdit consumes its cancel key before unhandled input. Household Escape
	# closes the preview even while a name field has keyboard focus.
	if page in ["household","mail"] and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and (console==null or not console.is_open()):
		_back(); get_viewport().set_input_as_handled(); return
	if page=="splash" and _booted and event is InputEventMouseButton and event.pressed:
		show_main(); get_viewport().set_input_as_handled(); return
	if not binding_action.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode==KEY_ESCAPE:
			binding_action=""; binding_hint.text="Binding cancelled."; return
		var result:Dictionary=Preferences.bind_action(binding_action,int(event.physical_keycode if event.physical_keycode!=0 else event.keycode))
		if result.ok:
			binding_buttons[binding_action].text=Preferences.action_label(binding_action)
			binding_buttons[binding_action].accessibility_description="Current key: "+Preferences.action_label(binding_action)
			binding_action=""
		binding_hint.text=result.message

func _unhandled_key_input(event: InputEvent) -> void:
	if not _booted or console==null: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if page=="splash": show_main(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("console") or event.keycode==KEY_F1:
		_open_console(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fullscreen"):
		Preferences.set_value("fullscreen",not bool(Preferences.values.fullscreen)); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save") and page=="game":
		if game._save(): Soundscape.play_ui("save")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.keycode==KEY_ESCAPE:
		if page=="game": open_pause()
		elif page=="pause": show_game()
		elif page in ["save","load"]: _back_from_saves()
		elif page=="main": pass
		else: _back()
		get_viewport().set_input_as_handled()

func _open_console() -> void:
	console.toggle(game.selected_member)
	_update_pause()

func _update_pause() -> void:
	Session.menu_paused = page!="game" or (console!=null and console.is_open())

func _preferences_changed() -> void:
	if game!=null: game.lot_view.queue_redraw()
	if page=="guide" and is_instance_valid(guide_panel): guide_panel.refresh_bindings()

func _session_status(_message: String) -> void:
	if page=="household" and is_instance_valid(household_editor) and household_editor.context_key!=_household_context():
		_pending_household.clear(); household_editor.set_pending(household_discard.visible); household_apply.disabled=true; household_cancel.disabled=false
		_feedback("The session changed. Reopen the creator to edit the current household.",false)
	if page=="game" and game!=null: game._refresh()
	_refresh_guide_context()

func _back() -> void:
	if page=="household" and not _pending_household.is_empty():
		_feedback("Waiting for the host to finish saving this household…",true); return
	if page=="household":
		if household_discard.visible:
			_keep_household(); return
		if household_editor.is_dirty():
			household_actions.hide(); household_discard.show()
			household_editor.set_pending(true)
			household_discard.get_child(1).grab_focus()
			return
	_leave_page()

func _leave_page() -> void:
	match previous_page:
		"game": show_game()
		"pause": open_pause()
		"guide": open_guide()
		"save","load":
			var draft := _overwrite_return.duplicate()
			_overwrite_return.clear()
			open_saves(previous_page,str(draft.get("id","")),draft.get("name"))
		_: show_main()

func _back_from_saves() -> void:
	if return_page in ["pause","game"]: open_pause()
	else: show_main()

func _feedback(text: String, ok: bool) -> void:
	if message_label!=null:
		message_label.text=text
		message_label.add_theme_color_override("font_color",Style.GREEN if ok else Color("e9a28b"))
	Soundscape.play_ui("confirm" if ok else "error")

func _message_area() -> void:
	message_label=_label("",13)
	message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	menu_content.add_child(message_label)

func _button(text: String,callback: Callable,primary: bool=false) -> Button:
	var button:=Button.new(); button.text=text; button.custom_minimum_size.y=44
	Icons.action(button,text)
	button.focus_entered.connect(func():
		if page in ["main","pause"] and is_instance_valid(navigation_hint): navigation_hint.text=button.accessibility_name)
	button.mouse_entered.connect(func():
		if page in ["main","pause"] and is_instance_valid(navigation_hint): navigation_hint.text=button.accessibility_name)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	if primary:
		button.add_theme_color_override("icon_normal_color",Style.INK)
		button.add_theme_color_override("icon_hover_color",Style.INK)
		button.add_theme_color_override("icon_focus_color",Style.INK)
		button.add_theme_stylebox_override("normal",Style.box(Style.GREEN,4))
		button.add_theme_color_override("font_color",Style.INK)
		button.add_theme_color_override("font_focus_color",Style.INK)
		button.add_theme_color_override("font_hover_color",Style.INK)
		button.add_theme_stylebox_override("hover",Style.box(Style.GREEN.lightened(0.08),4))
	Soundscape.attach_controls(button)
	return button

func _label(text: String,size_value: int=15,color: Color=Style.TEXT) -> Label:
	var label:=Label.new(); label.text=text
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	return label

func _space(parent: Node,height: float) -> void:
	var spacer:=Control.new(); spacer.custom_minimum_size.y=height; parent.add_child(spacer)

func _focus_menu() -> void:
	if page=="game" or not is_instance_valid(menu_content): return
	if page=="settings":
		var tabs:=menu_content.get_node_or_null("SettingsTabs") as TabContainer
		if tabs!=null:
			tabs.get_tab_bar().grab_focus()
			return
	for child: Button in menu_content.find_children("*","Button",true,false):
		if child.is_visible_in_tree() and not child.disabled:
			child.grab_focus()
			return

func _household_context() -> String:
	return str(Session.role)+":"+str(Session.profile_id)+":"+str(game._family().get("home_lot",""))+":"+str(Session.world_generation)

func open_mail() -> void:
	if game._family().is_empty(): return
	previous_page="game"
	_show_page("mail","Mailbox","Little things to come home to.")
	mail_panel=MailPanel.new(); menu_content.add_child(mail_panel)
	mail_panel.arrange_requested.connect(func(source: String):
		show_game(); game._select_lot(Session.home_lot()); game._open_art(source))
	menu_content.add_child(_button("Back to neighborhood",_back))

func open_household() -> void:
	var family: Dictionary=game._family()
	if family.is_empty() or Session.role=="joining": return
	previous_page=page if page in ["pause","main"] else "game"
	_pending_household.clear()
	_show_page("household")
	household_editor=HouseholdEditor.new(); menu_content.add_child(household_editor)
	household_editor.setup(family,_household_context())
	household_editor.title_label.text="Customize household" if Session.started_fresh else "Edit household"
	household_actions=HBoxContainer.new(); menu_content.add_child(household_actions)
	household_apply=_button("Save household",_apply_household,true); household_actions.add_child(household_apply)
	household_cancel=_button("Cancel",_back); household_actions.add_child(household_cancel)
	# Keep destructive choices labeled even when compact navigation icons are enabled.
	household_cancel.text="Cancel"; household_cancel.icon=null
	household_dirty=_label("No unsaved changes",13,Style.GOLD); household_actions.add_child(household_dirty)
	household_editor.dirty_changed.connect(func(dirty: bool): household_dirty.text="Unsaved changes" if dirty else "No unsaved changes")
	household_discard=HBoxContainer.new(); household_discard.hide(); menu_content.add_child(household_discard)
	household_discard.add_child(_label("Discard household changes?",15))
	household_discard.add_child(_button("Keep editing",_keep_household,true))
	household_discard.add_child(_button("Discard changes",_discard_household))
	_message_area()
	household_editor.family_name.grab_focus()

func _keep_household() -> void:
	household_discard.hide(); household_actions.show()
	household_editor.set_pending(false)
	household_apply.disabled=household_editor.context_key!=_household_context()
	household_cancel.grab_focus()

func _discard_household() -> void:
	if page!="household" or not household_discard.visible or not _pending_household.is_empty(): return
	_leave_page()

func _apply_household() -> void:
	if page!="household" or household_discard.visible or not _pending_household.is_empty(): return
	if household_editor.context_key!=_household_context():
		_feedback("The session changed. Reopen the household editor.",false); return
	_pending_household=household_editor.payload()
	household_editor.set_pending(true); household_apply.disabled=true; household_cancel.disabled=true
	message_label.text="Applying changes…"
	Session.command(_pending_household.duplicate(true))
	_household_changed()

func _household_result(intent: Dictionary, ok: bool, message: String) -> void:
	if page!="household" or _pending_household.is_empty() or intent!=_pending_household: return
	if not ok:
		_pending_household.clear(); household_editor.set_pending(false); household_apply.disabled=false; household_cancel.disabled=false
		_feedback(message,false)

func _household_changed() -> void:
	if page!="household" or _pending_household.is_empty(): return
	var family: Dictionary=game._family()
	if household_editor.context_key!=_household_context(): return
	if int(family.get("identity_revision",0))<=int(_pending_household.revision) or str(family.get("name",""))!=str(_pending_household.name).strip_edges(): return
	if family.get("relations",[])!=_pending_household.get("relations",[]): return
	for expected: Dictionary in _pending_household.members:
		var found := false
		for member: Dictionary in family.get("members",[]):
			if member.id==expected.id and member.name==str(expected.name).strip_edges() and member.get("appearance",{})==expected.appearance and member.get("favorite","variety")==expected.favorite and member.get("character",{})==expected.get("character",{}): found=true
		if not found: return
	_pending_household.clear()
	Soundscape.play_ui("confirm")
	_leave_page()
	game._refresh()
	game._notice("Household updated.")

func _settings_help_row() -> void:
	var row := HBoxContainer.new(); menu_content.add_child(row)
	for button: Button in [_button("Settings",func(): open_settings()),_button("Guide & controls",func(): open_guide())]:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(button)

func open_guide(welcome: bool=false) -> void:
	if page in ["main","pause","game"]:
		_guide_return=page; _guide_welcome=welcome; _guide_tab=0
	previous_page=_guide_return
	_show_page("guide","Welcome home" if _guide_welcome else "Guide & controls","A few ways to make this place your own. Explore in any order.")
	guide_panel=GuidePanel.new(); menu_content.add_child(guide_panel)
	guide_panel.action_requested.connect(_guide_action)
	guide_panel.tabs.current_tab=_guide_tab
	_refresh_guide_context()
	menu_content.add_child(_button("Start your day" if _guide_welcome else "Back",_back,true))
	_message_area()

func _refresh_guide_context() -> void:
	if page!="guide" or not is_instance_valid(guide_panel): return
	var family: Dictionary=game._family()
	var building := bool(Session.state.lots.get(family.get("home_lot",""),{}).get("building",false))
	guide_panel.refresh_context(not family.is_empty(),building,Session.role=="joining",Session.is_authority())

func _guide_action(action: String) -> void:
	if page!="guide": return
	_guide_tab=guide_panel.tabs.current_tab
	_refresh_guide_context()
	if not guide_panel.action_buttons.has(action) or guide_panel.action_buttons[action][0].disabled: return
	if action=="bindings": open_settings("Controls"); return
	show_game()
	match action:
		"household": open_household()
		"care": game._context_page="care"; game._refresh(); game._show_tray(game.context_panel,true)
		"wishes": game._open_wishes()
		"hobbies": game._open_hobbies()
		"people": game._open_people()
		"mail": open_mail()
		"connect": game._open_connection()
		"save": open_saves("save")
		"build","catalog","move","decorate","garden":
			var family: Dictionary=game._family()
			if family.is_empty(): return
			game._select_lot(str(family.home_lot))
			if action=="decorate":
				game._clear_catalog_filters(); game._catalog_category="finishes"; game.catalog_category.select(game.BuildCatalog.CATEGORIES.keys().find("finishes"))
			else: game._clear_catalog_filters()
			game._select_build_tool("garden_bed" if action=="garden" else "move" if action=="move" else "room" if action=="build" else "floor")
			if not Session.state.lots[family.home_lot].building: game._toggle_build()
			else: game._refresh(); game._show_tray(game.context_panel,true)
