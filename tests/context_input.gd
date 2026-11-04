extends SceneTree

var view: Control
var contexts: Array[Dictionary]=[]
var clicks: Array=[]

func _initialize() -> void: call_deferred("_run")

func _touch(point: Vector2, pressed: bool, index: int=0, canceled: bool=false) -> void:
	var event := InputEventScreenTouch.new()
	event.position=point; event.pressed=pressed; event.index=index; event.canceled=canceled
	root.push_input(event,true)
	await process_frame

func _mouse(point: Vector2, button: int, device: int=0) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.button_index=button; event.pressed=pressed; event.device=device
		root.push_input(event,true)
		await process_frame

func _run() -> void:
	root.size=Vector2i(1440,900)
	var session: Node=root.get_node("Session")
	session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	view=load("res://game/lot_view.gd").new(); root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.world=session.state; view.selected_member=session.state.families[session.profile_id].members[0].id
	view.context_requested.connect(func(target,point): contexts.append({"target":target,"point":point}))
	view.tile_clicked.connect(func(cell): clicks.append(cell))
	view.entity_clicked.connect(func(target): clicks.append(target))
	await process_frame; await process_frame
	var point: Vector2=view.grid_point(8.5,14.5)
	assert(view.hit_target(point).is_empty())
	var before: Dictionary=session.world.snapshot()
	await _mouse(point,MOUSE_BUTTON_RIGHT)
	assert(contexts.size()==1 and contexts[0].target=={"type":"ground","x":8,"y":14} and contexts[0].point.is_equal_approx(point))
	assert(clicks.is_empty(),"Right-click opens a context menu without an ordinary order")
	await _mouse(point,MOUSE_BUTTON_LEFT)
	assert(clicks==[Vector2i(8,14)],"Ordinary mouse click still works")
	clicks.clear(); contexts.clear()
	await _touch(point,true)
	await _mouse(point,MOUSE_BUTTON_LEFT,InputEvent.DEVICE_ID_EMULATION)
	assert(clicks.is_empty(),"Touch emulation cannot issue an early mouse-down order")
	view._update_context_touch(0.51)
	assert(contexts.size()==1 and clicks.is_empty(),"Holding offers the context menu without an order")
	assert(view._touch_index==-1,"An opened menu owns the release, leaving no stale touch in the world")
	view._update_context_touch(1.0)
	await _touch(point,false)
	assert(contexts.size()==1 and clicks.is_empty(),"One hold opens once and release cannot click through")
	await _touch(point,true); view._update_context_touch(0.51); await _touch(point,false)
	assert(contexts.size()==2 and clicks.is_empty(),"A second hold works after the first menu took ownership")
	contexts.clear()
	await _touch(point,true); await _touch(point,false)
	assert(clicks==[Vector2i(8,14)],"A short touch retains normal tap behavior")
	clicks.clear()
	await _touch(point,true)
	var drag := InputEventScreenDrag.new(); drag.index=0; drag.position=point+Vector2(40,0); drag.relative=Vector2(40,0)
	root.push_input(drag,true); await process_frame
	view._update_context_touch(0.51)
	await _touch(point+Vector2(40,0),false)
	assert(contexts.is_empty() and clicks.is_empty() and view.pan==Vector2(40,0),"Dragging pans and cancels both the hold and tap")
	view.center_lot()
	await _touch(point,true); await _touch(point+Vector2(20,0),true,1)
	view._update_context_touch(0.51)
	await _touch(point+Vector2(20,0),false,1); await _touch(point,false)
	assert(contexts.is_empty() and clicks.is_empty(),"A second finger cancels the pending gesture")
	await _touch(point,true)
	view.overlay_rects.assign([Rect2(point-Vector2(20,20),Vector2(40,40))])
	view._update_context_touch(0.51); await _touch(point,false)
	assert(contexts.is_empty() and clicks.is_empty(),"An opening overlay cancels a pending gesture")
	await _mouse(point,MOUSE_BUTTON_RIGHT)
	assert(contexts.is_empty(),"Blocked world areas cannot open a radial menu")
	view.overlay_rects.clear()
	await _touch(point,true); await _touch(point,false,0,true)
	assert(clicks.is_empty(),"A cancelled touch never orders an activity")
	# A replacement world can reuse every lot and resident ID. Neither a hold nor
	# a release before the next process frame may act on that replacement.
	for hold: bool in [false,true]:
		await _touch(point,true)
		session.world_generation+=1
		if hold: view._update_context_touch(0.51)
		await _touch(point,false)
		assert(contexts.is_empty() and clicks.is_empty(),"A new world generation cancels touches even with identical target IDs")
	for field: String in ["profile_id","role"]:
		var previous: Variant=session.get(field)
		for hold: bool in [false,true]:
			await _touch(point,true)
			session.set(field,str(previous)+"-changed" if field=="profile_id" else "joining")
			if hold: view._update_context_touch(0.51)
			await _touch(point,false)
			assert(contexts.is_empty() and clicks.is_empty(),"A changed session "+field+" cancels the pending touch")
			session.set(field,previous)
	view.building=true
	await _mouse(point,MOUSE_BUTTON_RIGHT)
	await _touch(point,true); view._update_context_touch(0.51); await _touch(point,false)
	assert(contexts.is_empty() and clicks==[Vector2i(8,14)],"Construction keeps its tap tools and does not open live actions")
	assert(session.world.snapshot()==before,"Input dispatch cannot mutate authoritative state")
	print("CONTEXT_INPUT_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
