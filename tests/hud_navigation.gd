extends RefCounted
## Reach optional HUD controls through the same mouse navigation as a player.

static func reveal(control: Control) -> void:
	assert(is_instance_valid(control),"The requested HUD control must exist")
	var owner: Node=control
	while owner!=null:
		if owner.has_method("_toggle_needs"):
			var more: Control=owner.more_panel
			var needs: Control=owner.needs_details
			var plan: Control=owner.plan_panel
			if more.is_ancestor_of(control) and not more.is_visible_in_tree():
				await _press(owner.more_button)
				assert(more.is_visible_in_tree(),"More opens the household and world controls")
			elif needs.is_ancestor_of(control) and not needs.is_visible_in_tree():
				await _press(owner.needs_toggle)
				assert(needs.is_visible_in_tree(),"Needs expands the care controls")
			elif plan.is_ancestor_of(control) and not plan.is_visible_in_tree():
				await _press(owner.queue_label)
				assert(plan.is_visible_in_tree(),"Plan opens the resident's activity controls")
			return
		owner=owner.get_parent()

static func _press(control: Button) -> void:
	var tree := control.get_tree()
	var root := tree.root
	await tree.process_frame; await tree.process_frame
	assert(control.is_visible_in_tree() and root.get_visible_rect().encloses(control.get_global_rect()),"Navigation must remain visible on screen")
	var point := control.get_global_rect().get_center()
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point)
		await tree.process_frame; await tree.process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true); await tree.process_frame
	var clicked := [false]
	control.pressed.connect(func(): clicked[0]=true,CONNECT_ONE_SHOT)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await tree.process_frame
	await tree.process_frame; await tree.process_frame
	assert(clicked[0],"HUD navigation must receive the mouse click")
