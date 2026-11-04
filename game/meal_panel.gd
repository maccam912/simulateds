extends VBoxContainer
signal command_requested(command: Dictionary)
const Meals=preload("res://game/meals.gd")
const Wishes=preload("res://game/wishes.gd")
const Style=preload("res://game/style.gd")
var summary: Label
var credit: Label
var preview: Control
var status: Label
var note: Label
var feedback: Label
var buttons := {}
var pending := {}
var _ack := false
var _next := 0
var _context := ""
var _lot := ""
var _object := ""
var _member := ""
var _options := {}
var _error := ""
var _preview_recipe := "salad"
func _ready() -> void:
	add_theme_constant_override("separation",6)
	summary=_label(14,Style.GOLD); credit=_label(12,Style.MUTED)
	preview=preload("res://game/meal_preview.gd").new(); preview.custom_minimum_size=Vector2(200,66); preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(preview)
	status=_label(12,Style.GREEN)
	for key: String in ["salad","sandwiches","eat","clear"]:
		var button:=Button.new(); button.custom_minimum_size.y=32; button.add_theme_font_size_override("font_size",12); button.pressed.connect(func(): _request(key)); add_child(button); buttons[key]=button
		if Meals.RECIPES.has(key):
			button.mouse_entered.connect(func(): _preview_recipe=key; refresh(_lot,_object,_member))
			button.focus_entered.connect(func(): _preview_recipe=key; refresh(_lot,_object,_member))
	note=_label(12,Style.MUTED); feedback=_label(12,Style.GOLD)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)
func _label(font_size: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label
func refresh(lot_id: String,object_id: String,member_id: String) -> void:
	_lot=lot_id; _object=object_id; _member=member_id
	var context:=str([Session.role,Session.profile_id,lot_id,object_id,member_id])
	if context!=_context: _context=context; pending={}; _ack=false; _error=""
	var lot: Dictionary=Session.state.lots.get(lot_id,{})
	var table: Dictionary=Session.world._object(lot,object_id) if not lot.is_empty() else {}
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	var member: Dictionary=Session.world._member(family,member_id) if not family.is_empty() else {}
	if _ack and not pending.is_empty():
		if (pending.action=="clear" and int(table.get("meal",{}).get("batch",0))>int(pending.batch)) or (pending.action!="clear" and int(member.get("next_action",0))>_next): pending={}; _ack=false
	var exists: bool=table.get("kind")=="dining_table"
	for control: Control in [preview,status,credit,note,feedback]: control.visible=exists
	for button: Button in buttons.values(): button.visible=exists
	if not exists: summary.text="This dining table is no longer here."; return
	var meal: Dictionary=table.meal; var ready: bool=meal.recipe!="" and int(meal.servings)>0
	var owner: bool=lot.owner==Session.profile_id
	summary.text=Meals.summary(meal)
	credit.visible=meal.recipe!=""; credit.text="By "+str(meal.cook_name)+" · Day %d" % int(meal.day)
	preview.recipe=str(meal.recipe) if meal.recipe!="" else _preview_recipe; preview.portions=int(meal.servings) if meal.recipe!="" else 4; preview.queue_redraw()
	preview.custom_minimum_size.y=48 if get_viewport_rect().size.y<800 else 66
	var free := Meals.available(Session.state,lot,table)
	status.text="%d available · %d reserved" % [free,int(meal.servings)-free] if ready else "Four portions · Prepare at your fridge"
	var plans:=Meals.plans(Session.state,lot_id,object_id)
	var dining: bool=plans.any(func(plan): return plan.task.meal_action=="eat" and plan.task.meal_batch==meal.batch and plan.task.meal_recipe==meal.recipe)
	var choice: Dictionary=Session.world.meal_option(Session.profile_id,member_id,lot_id,object_id,"choose")
	if not ready and dining:
		summary.text=str(Meals.RECIPES[meal.recipe].name)+" · Last portions at the table"
		status.text="0 available · Diners have their portions"
	for plan: Dictionary in plans:
		if plan.task.meal_action=="prepare":
			summary.text="Preparing "+str(Meals.RECIPES[plan.task.meal_recipe].name).to_lower(); credit.visible=false
			status.text=str(plan.member.name)+" · Four portions when served"
			preview.recipe=str(plan.task.meal_recipe); preview.portions=4; preview.queue_redraw(); break
	note.text="Ingredients paid when served.\nLeftovers keep while you are away." if not ready else "One chosen portion · Hunger + comfort\nSocial when eating together."
	if owner and ready: note.text="Autonomy: hungry housemates can eat.\nHunger + comfort · Social together."
	if choice.ok: note.text="Keep your portion and remaining time.\nChosen company starts now."
	elif dining and not ready: note.text="Diners keep their current portions.\nWait for them to finish before preparing more."
	elif not owner and not ready: note.text="This household prepares its meals. Visit again when food is served."
	var wishes: Array=member.get("wishes",{}).get("wishes",[])
	if wishes.any(func(wish): return wish.id=="homemade" and not wish.done) and not ready and not dining and owner:
		note.text="Wish: serve a meal · Reward §%d.\nIngredients paid when served." % Wishes.REWARD
	if wishes.any(func(wish): return wish.id=="meal_together" and not wish.done) and (ready or dining):
		note.text="Keep this portion and time.\nBoth diners choose 12 min together." if choice.ok else "Both diners choose 12 min together.\nPeople → Join meal · Reward §%d." % Wishes.REWARD
	_options.clear(); var unavailable := ""
	for key: String in buttons:
		var action := "prepare" if Meals.RECIPES.has(key) else key
		var option: Dictionary=choice if action=="eat" and choice.ok else Session.world.meal_option(Session.profile_id,member_id,lot_id,object_id,action,key if action=="prepare" else "")
		_options[key]=option
		var button: Button=buttons[key]
		button.visible=owner and not ready and not dining if action=="prepare" else ready and owner if action=="clear" else ready or dining
		button.text="Prepare "+str(Meals.RECIPES[key].name).to_lower()+" · §%d" % int(Meals.RECIPES[key].cost) if action=="prepare" else ("Choose this meal" if choice.ok else "Eat a portion") if action=="eat" else "Clear leftovers"
		button.disabled=not option.ok or not pending.is_empty() or Session.role=="joining"
		button.tooltip_text=str(option.message)+(". A portion is taken when eating begins." if action=="eat" and option.ok and not choice.ok else "")
		if button.visible and not option.ok and (action!="clear" or (unavailable.is_empty() and not choice.ok)): unavailable=str(option.message)
	feedback.text="Waiting for the neighborhood…" if not pending.is_empty() else _error if not _error.is_empty() else unavailable
	feedback.visible=not feedback.text.is_empty()
func _request(key: String) -> void:
	if not pending.is_empty() or not _options.get(key,{}).get("ok",false): return
	var action: String="prepare" if Meals.RECIPES.has(key) else "choose" if key=="eat" and _options[key].has("activity_id") else key
	pending={"type":"meal","lot_id":_lot,"target_id":_object,"member_id":_member,"action":action,"recipe":key if action=="prepare" else "","batch":int(_options[key].batch)}
	if action=="choose": pending.activity_id=str(_options[key].activity_id)
	_next=int(Session.world._member(Session.state.families[Session.profile_id],_member).next_action); _ack=false; _error=""
	refresh(_lot,_object,_member); command_requested.emit(pending.duplicate(true))
func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or intent!=pending: return
	if ok: _ack=true
	else: pending={}; _ack=false; _error=message
	refresh(_lot,_object,_member)
