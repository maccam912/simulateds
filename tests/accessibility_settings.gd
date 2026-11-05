extends SceneTree
var app: Control

func _initialize() -> void: call_deferred("_run")

func _key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
		root.push_input(event,true); await process_frame

func _capture(name: String) -> void:
	await process_frame; await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/accessibility-"+name+".png")==OK)

func _run() -> void:
	var prefs: Node=root.get_node("Preferences")
	var session: Node=root.get_node("Session")
	session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	assert(prefs.reset_defaults())
	root.size=Vector2i(1440,900)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout
	for compact in [false,true]:
		root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
		assert(prefs.set_value("ui_scale",1.25 if compact else 1.0))
		for night in [false,true]:
			session.state.day_minutes=60.0 if night else 720.0
			var suffix: String=("compact" if compact else "normal")+("-night" if night else "-day")
			app.open_settings("Audio"); await process_frame; await process_frame
			var tabs: TabContainer=app.menu_content.get_node("SettingsTabs")
			assert(tabs.get_tab_bar().has_focus(),"Settings starts at the tab bar, before its fields")
			var sliders: Array=app.menu_content.find_children("*","HSlider",true,false)
			var names: Array=[]
			for slider: HSlider in sliders: names.append(slider.accessibility_name)
			assert(names==["Master","Background music","Household stereos","Effects","Ambience"])
			await _key(KEY_TAB)
			assert(sliders[0].has_focus(),"Tab enters the first audio control")
			await _key(KEY_RIGHT)
			assert(is_equal_approx(prefs.values.master_volume,0.81))
			await _key(KEY_LEFT)
			for index in range(1,sliders.size()):
				await _key(KEY_TAB); assert(sliders[index].has_focus())
				await process_frame; await process_frame
				assert(root.get_visible_rect().encloses(sliders[index].get_global_rect()))
				assert(tabs.get_current_tab_control().get_global_rect().encloses(sliders[index].get_global_rect()))
			await _capture("audio-"+suffix)
			await _key(KEY_TAB); await process_frame; await process_frame
			var preview: Button=root.gui_get_focus_owner()
			assert(preview.text=="Preview sound" and root.get_visible_rect().encloses(preview.get_global_rect()))
			assert(tabs.get_current_tab_control().get_global_rect().encloses(preview.get_global_rect()))
			await _capture("audio-scrolled-"+suffix)
			app.open_settings("Display"); await process_frame; await process_frame
			var options: Array=app.menu_content.find_children("*","OptionButton",true,false)
			for option: OptionButton in options: assert(not option.accessibility_name.is_empty())
			app.open_settings("Comfort"); await process_frame; await process_frame
			await _key(KEY_TAB)
			var motion: CheckButton=root.gui_get_focus_owner()
			assert(motion.text=="Reduced motion")
			var before: Dictionary=session.world.snapshot()
			await _key(KEY_SPACE)
			assert(prefs.values.reduced_motion and session.world.snapshot()==before)
			await _capture("comfort-"+suffix)
			await _key(KEY_SPACE); assert(not prefs.values.reduced_motion)
			app.open_settings("Controls"); await process_frame; await process_frame
			var last: Button=app.binding_buttons.speed_faster
			last.grab_focus(); await process_frame; await process_frame
			assert(root.get_visible_rect().encloses(last.get_global_rect()),"Keyboard focus scrolls the final binding into view")
			var controls_tabs: TabContainer=app.menu_content.get_node("SettingsTabs")
			assert(controls_tabs.get_current_tab_control().get_global_rect().encloses(last.get_global_rect()))
			assert(last.accessibility_name==prefs.ACTION_NAMES.speed_faster)
			app.binding_action="rotate"; await _key(KEY_T)
			assert(app.binding_buttons.rotate.accessibility_description=="Current key: T")
			assert(prefs.bind_action("rotate",KEY_R).ok)
			await _capture("controls-"+suffix)
			await _key(KEY_ESCAPE); assert(app.page=="main")
	assert(prefs.reset_defaults())
	print("ACCESSIBILITY_SETTINGS_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
