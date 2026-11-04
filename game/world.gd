extends RefCounted
## Pure host-owned simulation: no networking, Nodes, clocks, or filesystem access.
## Commands are the only external mutations; the whole state is JSON-compatible.
const Catalog = preload("res://game/catalog.gd")
const BuildRules = preload("res://game/build_rules.gd")
const RoomPlan = preload("res://game/room_plan.gd")
const Wishes = preload("res://game/wishes.gd")
const Hobbies = preload("res://game/hobbies.gd")
const Friendships = preload("res://game/friendships.gd")
const HomeNews = preload("res://game/home_news.gd")
const Mailbox = preload("res://game/mailbox.gd")
const Wellbeing = preload("res://game/wellbeing.gd")
const Finishes = preload("res://game/finishes.gd")
const Windows = preload("res://game/windows.gd")
const Pastimes = preload("res://game/pastimes.gd")
const Appearance = preload("res://game/appearance.gd")
const Tabletop = preload("res://game/tabletop.gd")
const BuildAccess = preload("res://game/build_access.gd")
const Routines = preload("res://game/routines.gd")
const HouseholdProfile = preload("res://game/household_profile.gd")
const GRID_SIZE := 16
const SCHEMA := 1
const MAX_FAMILIES := 4
const MAX_QUEUE := 8
const MAX_BUILD_HISTORY := 32
const MINUTES_PER_SECOND := 3.0
const MIN_ACTIVITY_TIME := 4.0
const BUILD_FIELDS := ["floors", "walls", "doors", "objects", "funds", "finishes", "windows"]
const NEEDS := ["hunger", "energy", "hygiene", "bladder", "fun", "social", "comfort"]
const DECAY := {"hunger":0.13, "energy":0.08, "hygiene":0.10, "bladder":0.15, "fun":0.12, "social":0.09, "comfort":0.07}
const ACTION_NAMES := {"bed":"Sleeping", "fridge":"Making a meal", "shower":"Showering", "toilet":"Using the bathroom", "sofa":"Relaxing", "tv":"Watching television", "bookshelf":"Reading", "plant":"Tending plants", "table":"Having tea", "game_table":"Playing a tabletop puzzle"}
const DIRECTIONS := [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
var state: Dictionary = {}
var _build_backups: Dictionary = {}
var _build_history: Dictionary = {}

func initialize() -> void:
	state = {"schema":SCHEMA, "tick":0, "day":1, "day_minutes":480.0, "lots":{}, "families":{}, "friendships":{}, "events":[], "next_object":1}
	_build_backups.clear()
	_build_history.clear()
	var names := ["Clover Cottage", "Willow House", "Juniper Place", "Maple Corner"]
	for index in range(MAX_FAMILIES):
		var id := "lot_%d" % (index + 1)
		var lot := {"id":id, "name":names[index], "owner":"", "funds":12000, "building":false, "revision":0, "build_undo":0, "build_redo":0, "floors":[], "walls":[], "doors":[], "objects":[]}
		for y in range(3, 12):
			for x in range(3, 13):
				lot.floors.append([x,y])
				if x == 3 or x == 12 or y == 3 or y == 11:
					if x == 8 and y == 11:
						lot.doors.append([x,y])
					else:
						lot.walls.append([x,y])
		for item in [["bed",4,4], ["bed",6,4], ["fridge",10,4], ["shower",11,6], ["toilet",11,8], ["sofa",4,8], ["tv",4,10], ["bookshelf",10,10], ["plant",10,6], ["table",7,8]]:
			lot.objects.append(_new_object(str(item[0]), int(item[1]), int(item[2]), 0))
		state.lots[id] = lot
		lot.finishes=Finishes.create()
		lot.windows={"5,3":"cottage","10,3":"cottage","3,7":"cottage"}

func ensure_family(profile_id: String, display_name: String) -> String:
	if profile_id.is_empty() or profile_id.length() > 128:
		return ""
	if state.families.has(profile_id):
		return str(state.families[profile_id].home_lot)
	for lot_id: String in state.lots:
		var lot: Dictionary = state.lots[lot_id]
		if not str(lot.owner).is_empty():
			continue
		var clean_name := display_name.strip_edges().left(24)
		if clean_name.is_empty():
			clean_name = "Neighbor"
		lot.owner = profile_id
		var members: Array = []
		for index in range(2):
			var needs := {}
			for need: String in NEEDS:
				needs[need] = 70.0 + index * 8.0
			members.append({"id":profile_id + "_" + str(index + 1), "name":clean_name if index == 0 else "Robin", "lot_id":lot_id, "x":7 + index, "y":7, "needs":needs, "action":"Taking it easy", "queue":[], "task":{}, "walk_clock":0.0, "idle_clock":float(index) * 2.0, "autonomy":true, "next_action":1})
		for member: Dictionary in members:
			member.wishes=Wishes.create(str(member.id),int(state.day))
			member.hobbies=Hobbies.create(int(state.day))
			member.appearance=Appearance.defaults(member)
			member.favorite=Pastimes.initial(member)
		state.families[profile_id] = {"id":profile_id, "name":clean_name + " household", "home_lot":lot_id, "online":false, "identity_revision":0, "members":members}
		Friendships.ensure_housemates(state,state.families[profile_id])
		state.families[profile_id].mailbox=Mailbox.create(int(state.day))
		state.families[profile_id].home_news=HomeNews.create()
		state.families[profile_id].routines=Routines.create()
		_event(clean_name + " moved into " + str(lot.name) + ".")
		return lot_id
	return ""

func set_online(profile_id: String, online: bool) -> void:
	if not state.families.has(profile_id):
		return
	var family: Dictionary = state.families[profile_id]
	if online: HomeNews.arrival(family)
	else: HomeNews.departure(family,bool(state.lots[family.home_lot].building))
	family.online = online
	if not online:
		var lot: Dictionary = state.lots[family.home_lot]
		if lot.building:
			if _build_backups.has(str(lot.id)):
				_restore_build(lot)
			lot.building = false
			lot.revision += 1
			_event(str(lot.name) + " left construction mode while its owner was away.")
		for member: Dictionary in family.members:
			_send_home(family, member)

func apply_command(profile_id: String, command: Dictionary) -> Dictionary:
	if not state.families.has(profile_id):
		return _result(false, "Join a household first.")
	var type: Variant = command.get("type")
	if not type is String:
		return _result(false, "Unknown action.")
	var family: Dictionary = state.families[profile_id]
	if type == "news_read": return HomeNews.read(family,command.get("revision"))
	if type == "household_edit": return HouseholdProfile.edit(family,command)
	if type in ["routine_save","routine_delete"]: return Routines.edit(family,command)
	if type in ["mail_send","mail_read","mail_claim","mail_archive"]:
		return Mailbox.apply(state,profile_id,command,_adjust_funds)
	if type == "rename_family":
		var value: Variant = command.get("name")
		if not value is String or value.strip_edges().is_empty() or value.length() > 24:
			return _result(false, "Choose a name between 1 and 24 characters.")
		var clean_name: String = value.strip_edges()
		if family.name==str(family.members[0].name)+" household": family.name = clean_name + " household"
		family.identity_revision=int(family.get("identity_revision",0))+1
		family.members[0].name = clean_name
		return _result(true, "Welcome home, " + clean_name + ".")
	var lot_id: Variant = command.get("lot_id", family.home_lot)
	if not lot_id is String or not state.lots.has(lot_id):
		return _result(false, "That lot does not exist.")
	var lot: Dictionary = state.lots[lot_id]
	if type in ["build_begin", "build_end", "build_cancel", "build_undo", "build_redo", "place", "erase", "move_object", "build_room", "paint", "set_window"]:
		if lot.owner != profile_id:
			return _result(false, "Only the owner can build on this lot.")
		if type == "build_begin":
			if lot.building:
				return _result(true, "Already in construction mode.")
			_build_backups[lot_id] = lot.duplicate(true)
			_build_history[lot_id] = {"undo":[],"redo":[]}
			_update_history_counts(lot)
			lot.building = true
			lot.revision += 1
			for other: Dictionary in state.families.values():
				for member: Dictionary in other.members:
					if member.lot_id == lot_id:
						if other.id != profile_id:
							_send_home(other, member)
						else:
							_clear_member(member, "Waiting for construction")
			_event(str(lot.name) + " is under construction. Visitors have gone home.")
			return _result(true, "Construction started. Your family is paused; neighbors keep living.")
		if not lot.building:
			return _result(false, "Enter construction mode first.")
		if type in ["build_undo", "build_redo", "build_room", "paint", "set_window"]:
			if not _integer(command.get("revision")) or int(command.revision) != int(lot.revision):
				return _result(false, "The building draft changed. Review the preview and try again.")
			if type in ["build_undo","build_redo"]: return _history_step(lot,type == "build_redo")
		if type == "build_cancel":
			if _build_backups.has(lot_id):
				_restore_build(lot)
			lot.building = false
			lot.revision += 1
			return _result(true, "Construction canceled. Your previous home and funds are restored.")
		if type == "build_end":
			var issue := _layout_issue(lot)
			if not issue.is_empty():
				return _result(false, issue)
			lot.building = false
			lot.revision += 1
			_build_backups.erase(lot_id)
			_clear_build_history(lot)
			_event(str(lot.name) + " is open for visitors again.")
			return _result(true, "Welcome home. Your family is living again.")
		var previous := _capture_build(lot)
		var result := _build(lot, command)
		if result.ok:
			var history: Dictionary = _build_history.get(lot_id,{"undo":[],"redo":[]})
			history.undo.append(previous)
			if history.undo.size() > MAX_BUILD_HISTORY: history.undo.pop_front()
			history.redo.clear()
			_build_history[lot_id] = history
			_update_history_counts(lot)
		return result
	var member_id: Variant = command.get("member_id", "")
	if not member_id is String:
		return _result(false, "Choose a household member.")
	var member := _member(family, member_id)
	if member.is_empty():
		return _result(false, "You can only direct your own family.")
	if type == "renew_wishes":
		if not Wishes.can_renew(member.wishes,int(state.day)):
			return _result(false,"Finish these wishes first. A fresh set is available on the following day.")
		member.wishes=Wishes.create(str(member.id),int(state.day),int(member.wishes.round)+1,member.wishes.journal)
		return _result(true,"A few new things to look forward to.")
	if type == "pursue_wish":
		var wish_id: Variant=command.get("wish_id")
		if not wish_id is String: return _result(false,"Choose a wish.")
		var activity := ""
		for wish: Dictionary in member.wishes.wishes:
			if wish.id==wish_id and not wish.done: activity=str(Wishes.CATALOG[wish_id].activity)
		if activity.is_empty(): return _result(false,"That wish is already complete or unavailable.")
		if not wish_status(member,activity).is_empty(): return _result(false,"That activity is already in this resident’s plan.")
		var destination: Dictionary=state.lots[member.lot_id]
		var target := ""
		var best_score := 100000.0
		if activity=="chat":
			for other: Dictionary in state.families.values():
				for companion: Dictionary in other.members:
					if companion.id==member.id or companion.lot_id!=member.lot_id: continue
					var goals := _social_cells(destination,companion)
					if goals.has(_position(member)) or not _path(destination,_position(member),goals).is_empty():
						target=str(companion.id); break
		else:
			for object: Dictionary in destination.objects:
				if object.kind!=activity or not _can_reach_object(destination,_position(member),object): continue
				var score := _position(member).distance_to(Vector2i(int(object.x),int(object.y)))
				if not _object_user(str(destination.id),object,str(member.id)).is_empty(): score+=1000.0
				if score<best_score: target=str(object.id); best_score=score
		if target.is_empty():
			return _result(false,"Find another resident to chat with." if activity=="chat" else "There is no reachable " + str(Catalog.ITEMS[activity].name) + " here. Build one or visit a neighbor.")
		return apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":target})
	if type == "autonomy":
		if not command.get("enabled") is bool:
			return _result(false, "Choose whether this resident acts on their own.")
		member.autonomy = command.enabled
		if not member.autonomy and bool(member.task.get("automatic", false)):
			member.task = {}
			member.action = "Taking it easy"
		return _result(true, "Autonomy " + ("on." if member.autonomy else "off. Your queued actions still continue."))
	if type == "remove_action":
		var action_id: Variant = command.get("action_id")
		if not action_id is String or action_id.is_empty():
			return _result(false, "Choose an action to cancel.")
		if member.task.get("id", "") == action_id:
			member.task = {}
			member.action = "Taking it easy"
			member.idle_clock = 0.0
			_start_next(member, state.lots[member.lot_id])
			return _result(true, "Current action canceled. The rest of the plan continues.")
		for queued: Dictionary in member.queue:
			if queued.get("id", "") == action_id:
				member.queue.erase(queued)
				return _result(true, "Action removed from the plan.")
		return _result(false, "That action has already finished.")
	if type == "reorder_action":
		var first: Variant=command.get("first_id")
		var second: Variant=command.get("second_id")
		if not first is String or not second is String or first.is_empty() or second.is_empty() or first==second:
			return _result(false,"Choose two neighboring actions in the upcoming plan.")
		# Ordered stable IDs describe exactly the pair the player saw. A delayed
		# repeat or an action that has started cannot swap an unintended pair.
		for index in range(member.queue.size()-1):
			if member.queue[index].get("id")==first and member.queue[index+1].get("id")==second:
				var earlier: Dictionary=member.queue[index]
				member.queue[index]=member.queue[index+1]
				member.queue[index+1]=earlier
				return _result(true,"Upcoming plan updated. The current activity continues.")
		return _result(false,"The plan has changed. Choose from the current upcoming actions.")
	if type == "cancel":
		_clear_member(member)
		return _result(true, "Action queue cleared.")
	if bool(state.lots[family.home_lot].building):
		return _result(false, "Finish construction before directing your family.")
	if type=="run_routine":
		if not Routines.revision_matches(family.routines,command.get("revision")): return _result(false,"Routines changed. Choose from the current library.")
		var id: Variant=command.get("routine_id")
		if not id is String: return _result(false,"Choose a household routine.")
		var option := routine_option(profile_id,str(member.id),id)
		if not option.available: return _result(false,str(option.detail))
		# Resolve every step and queue limit before changing any task or counter.
		for action: Dictionary in option.actions: _queue_action(member,action.duplicate(true))
		if member.task.get("automatic",false): member.task={}
		if member.task.is_empty(): _start_next(member,state.lots[member.lot_id])
		return _result(true,str(option.name)+" added to "+str(member.name)+"'s plan.")
	if type=="practice_hobby":
		var hobby: Variant=command.get("hobby")
		if not hobby is String or not Hobbies.CATALOG.has(hobby): return _result(false,"Choose reading, gardening, or cooking.")
		var option := hobby_option(member,hobby)
		if not option.available: return _result(false,str(option.detail))
		return apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":option.target_id})
	if type=="care":
		var need: Variant=command.get("need")
		if not need is String or not NEEDS.has(need): return _result(false,"Choose one of this resident’s needs.")
		var option := care_option(member,need)
		if not option.available: return _result(false,str(option.detail))
		var result := apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":option.target_id})
		if result.ok: result.message="Added to plan · "+str(option.label)+(" · Wait until it is free" if option.busy else "")
		return result
	if type in ["visit", "go_home"]:
		var destination: Dictionary = state.lots[family.home_lot] if type == "go_home" else lot
		if destination.building:
			return _result(false, "This home is under construction. Visit again soon.")
		if type == "visit" and str(destination.owner).is_empty():
			return _result(false, "Nobody lives here yet.")
		_clear_member(member)
		member.lot_id = destination.id
		var entry := _free_entry(destination)
		member.x = entry.x
		member.y = entry.y
		_event(str(member.name) + " arrived at " + str(destination.name) + ".")
		return _result(true, "Arrived at " + str(destination.name) + ".")
	if member.lot_id != lot_id:
		return _result(false, "Visit this lot before using it.")
	if lot.building:
		return _result(false, "This lot is under construction.")
	if member.queue.size() >= MAX_QUEUE:
		return _result(false, "The action queue is full (8 actions).")
	if type=="join_game":
		var companion_id: Variant=command.get("companion_id")
		var activity_id: Variant=command.get("activity_id")
		if not companion_id is String or not activity_id is String or activity_id.is_empty():
			return _result(false,"Choose a resident's current game from People.")
		var option := tabletop_option(member,companion_id)
		if option.is_empty() or option.activity_id!=activity_id:
			return _result(false,"That game has changed. Choose a current game from People.")
		if not option.available: return _result(false,str(option.detail))
		var result := apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":lot_id,"target_id":option.target_id})
		if result.ok: result.message="Tabletop game added to your plan."
		return result
	if type == "move":
		if not _valid_coord(command.get("x")) or not _valid_coord(command.get("y")):
			return _result(false, "Choose a tile inside the lot.")
		var goal := Vector2i(int(command.x), int(command.y))
		var option := move_option(profile_id,str(member.id),str(lot_id),goal)
		if not option.ok: return _result(false,str(option.message))
		_queue_action(member, {"type":"move", "x":goal.x, "y":goal.y})
	elif type == "interact":
		var target_id: Variant = command.get("target_id", "")
		if not target_id is String:
			return _result(false, "Choose a furnishing.")
		var object := _object(lot, target_id)
		if object.is_empty():
			var neighbor := _find_member(target_id)
			if neighbor.is_empty() or neighbor.id == member.id or neighbor.lot_id != member.lot_id:
				return _result(false, "Choose another resident on this lot or a furnishing.")
			if not chat_status(member,str(neighbor.id)).is_empty(): return _result(false,"That conversation is already in this resident’s plan.")
			var goals := _social_cells(lot, neighbor)
			if not goals.has(_position(member)) and _path(lot, _position(member), goals).is_empty():
				return _result(false, "There is no path to chat with that resident.")
			_queue_action(member, {"type":"interact", "target_id":target_id, "target_kind":"member"})
		else:
			if not _can_reach_object(lot, _position(member), object):
				return _result(false, "There is no path to use that furnishing.")
			_queue_action(member, {"type":"interact", "target_id":target_id})
	else:
		return _result(false, "Unknown action.")
	# A direct order interrupts an autonomous task, but preserves player-queued work.
	if bool(member.task.get("automatic", false)):
		member.task = {}
	if member.task.is_empty():
		_start_next(member, lot)
	return _result(true, "Action queued.")

func move_option(profile_id: String,member_id: String,lot_id: String,goal: Vector2i) -> Dictionary:
	# Shared, read-only reachability for ground previews and accepted commands.
	if not state.get("families",{}).has(profile_id): return _result(false,"Join a household first.")
	if not state.get("lots",{}).has(lot_id): return _result(false,"That lot does not exist.")
	var family: Dictionary=state.families[profile_id]
	var member := _member(family,member_id)
	if member.is_empty(): return _result(false,"You can only direct your own family.")
	if state.lots[family.home_lot].building: return _result(false,"Finish construction before directing your family.")
	if member.lot_id!=lot_id: return _result(false,"Visit this lot before walking here.")
	var lot: Dictionary=state.lots[lot_id]
	if lot.building: return _result(false,"This lot is under construction.")
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The action queue is full (8 actions).")
	if not _inside(goal): return _result(false,"Choose a tile inside the lot.")
	if not _walkable(lot,goal): return _result(false,"That tile is occupied.")
	var route := _path(lot,_position(member),[goal])
	if route.is_empty() and _position(member)!=goal: return _result(false,"There is no path to that tile.")
	var ahead: int=member.queue.size()+(0 if member.task.is_empty() or member.task.get("automatic",false) else 1)
	return {"ok":true,"message":"Walk here" if ahead==0 else "Queue walk · %d %s first" % [ahead,"activity" if ahead==1 else "activities"],"path":route,"ahead":ahead,"cell":goal,"here":_position(member)==goal}

func _build(lot: Dictionary, command: Dictionary) -> Dictionary:
	if not _valid_coord(command.get("x")) or not _valid_coord(command.get("y")):
		return _result(false, "Choose a tile inside the lot.")
	var cell := Vector2i(int(command.x), int(command.y))
	if command.type=="set_window":
		var plan := Windows.inspect(lot,command)
		if not plan.ok: return plan
		Windows.apply(lot,plan)
		return _result(true,str(plan.message)+". Undo restores this edit.")
	if command.type == "erase":
		if not Windows.at(lot,cell.x,cell.y).is_empty():
			var plan := Windows.inspect(lot,{"style":"","x":cell.x,"y":cell.y})
			if not plan.ok: return plan
			Windows.apply(lot,plan)
			return _result(true,str(plan.message)+".")
		for object: Dictionary in lot.objects:
			if _object_cells(object).has(cell):
				lot.objects.erase(object)
				lot.funds += int(Catalog.ITEMS[object.kind].cost * 0.6)
				lot.revision += 1
				return _result(true, "Furnishing sold for 60% of its price.")
		for kind: String in ["wall", "door", "floor"]:
			var list: Array = lot[_tile_key(kind)]
			if list.has([cell.x, cell.y]):
				list.erase([cell.x, cell.y])
				if kind in ["floor","wall"]: Finishes.remove(lot,kind,cell.x,cell.y)
				lot.funds += int(Catalog.ITEMS[kind].cost * 0.6)
				lot.revision += 1
				return _result(true, "Tile removed.")
		return _result(false, "There is nothing to remove here.")
	if command.type=="paint":
		var plan := Finishes.inspect(lot,command)
		if not plan.ok: return plan
		Finishes.apply(lot,plan)
		return _result(true,"Finished %d tiles for § %d. One Undo restores the area." % [plan.cells.size(),plan.cost])
	var residents: Array=[]
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot.id: residents.append(_position(member))
	if command.type=="build_room":
		var plan := RoomPlan.inspect(lot,command,residents)
		if not plan.ok: return plan
		RoomPlan.apply(lot,plan)
		return _result(true,"Room built for § %d. Undo restores the whole room." % int(plan.cost))
	var preview := BuildRules.inspect(lot,command,residents)
	if not preview.ok: return preview
	var kind: String=preview.kind
	var rotation: int=preview.rotation
	if command.type=="move_object":
		var object := _object(lot,str(command.object_id))
		object.x=cell.x; object.y=cell.y; object.rotation=rotation
		lot.revision+=1
		return _result(true,str(Catalog.ITEMS[kind].name)+" moved. No charge.")
	var existing := [cell.x,cell.y]
	if kind in ["floor","wall","door"]:
		if kind=="wall": lot.doors.erase(existing)
		elif kind=="door":
			lot.walls.erase(existing); Finishes.remove(lot,"wall",cell.x,cell.y); Windows.remove(lot,cell.x,cell.y)
		lot[_tile_key(kind)].append(existing)
	else:
		lot.objects.append(_new_object(kind,cell.x,cell.y,rotation))
	lot.funds -= int(preview.cost)
	lot.revision += 1
	return _result(true,str(Catalog.ITEMS[kind].name)+" placed.")

func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or state.is_empty():
		return
	delta = minf(delta, 1.0)
	state.tick += 1
	state.day_minutes += delta * MINUTES_PER_SECOND
	if state.day_minutes >= 1440.0:
		state.day_minutes -= 1440.0
		state.day += 1
		for family: Dictionary in state.families.values():
			var home: Dictionary = state.lots[family.home_lot]
			var allowance := 600
			for balance: Dictionary in _fund_balances(str(home.id)): allowance=mini(allowance,1000000000-int(balance.funds))
			_adjust_funds(str(home.id),allowance)
			if HomeNews.away(family): family.home_news.allowance+=allowance
		_event("A new day. Households received their living allowance.")
	for family: Dictionary in state.families.values():
		if HomeNews.away(family): family.home_news.minutes+=delta*MINUTES_PER_SECOND
		if state.lots[family.home_lot].building:
			continue
		for member: Dictionary in family.members:
			var lot: Dictionary = state.lots[member.lot_id]
			for need: String in NEEDS:
				var floor_value := 0.0 if family.online else 55.0
				member.needs[need] = clampf(float(member.needs[need]) - float(DECAY[need]) * delta, floor_value, 100.0)
			_tick_member(member, lot, delta)

func _tick_member(member: Dictionary, lot: Dictionary, delta: float) -> void:
	if member.task.is_empty():
		if not member.queue.is_empty():
			_start_next(member, lot)
		else:
			var partner := _conversation_partner(member)
			if not partner.is_empty():
				member.action="Chatting with "+str(partner.name)
				return
			member.idle_clock = minf(2.0, float(member.idle_clock) + delta)
			if member.idle_clock >= 2.0 and bool(member.get("autonomy", true)):
				member.idle_clock = 0.0
				_choose_autonomy(member, lot)
	if member.task.is_empty():
		if not member.queue.is_empty(): return # A busy furnishing keeps its queued order.
		member.action = "Taking it easy"
		return
	var task: Dictionary = member.task
	if not task.path.is_empty():
		member.action = "Walking" + (" · " + str(task.get("label", "")) if task.type == "interact" else "")
		member.walk_clock += delta
		if member.walk_clock >= 0.22:
			member.walk_clock = 0.0
			var next: Array = task.path.pop_front()
			if not _walkable(lot, Vector2i(int(next[0]), int(next[1]))):
				_clear_member(member, "Path changed")
				return
			member.x = int(next[0])
			member.y = int(next[1])
		return
	if task.type == "move":
		member.task = {}
		return
	if task.get("target_kind", "object") == "member":
		var neighbor := _find_member(str(task.target_id))
		if neighbor.is_empty() or neighbor.lot_id != member.lot_id or _position(member).distance_to(_position(neighbor)) > 2.0:
			member.task = {}
			member.action = "They moved away"
			return
		if _chat_busy(neighbor,member):
			if float(task.get("elapsed",0))>0:
				member.task={}; member.action="They have something to do"
			else: member.action="Waiting for "+str(neighbor.name)+" · A chat"
			return
		if not task.has("social_started"): task.social_started=int(state.tick)
		task.elapsed=float(task.get("elapsed",0.0))+delta
		member.action = "Chatting with " + str(neighbor.name)
		member.needs.social = minf(100.0, float(member.needs.social) + 7.0 * delta)
		neighbor.needs.social = minf(100.0, float(neighbor.needs.social) + 7.0 * delta)
		task.remaining -= delta
		if task.remaining <= 0.0:
			_finish_wish(member,task,"chat")
			_finish_conversation(member,neighbor,task)
			member.task = {}
			member.action = "Taking it easy"
		return
	task.elapsed = float(task.get("elapsed",0.0)) + delta
	var object := _object(lot, str(task.get("target_id", "")))
	if object.is_empty():
		member.task = {}
		return
	var definition: Dictionary = Catalog.ITEMS[object.kind]
	member.action = ACTION_NAMES.get(object.kind, "Enjoying home")
	var need: String = definition.need
	var rates := personal_activity_rates(member,str(object.kind))
	for restored: String in rates:
		member.needs[restored]=minf(100.0,float(member.needs[restored])+float(rates[restored])*delta)
	if object.kind=="game_table" and Tabletop.players(state,str(lot.id),str(object.id)).size()>1:
		member.needs.social=minf(100.0,float(member.needs.social)+Tabletop.SOCIAL_RATE*delta)
		member.action="Playing together"
	if object.kind == "table":
		for family: Dictionary in state.families.values():
			for companion: Dictionary in family.members:
				if companion.id != member.id and companion.lot_id == member.lot_id and _position(companion).distance_to(_position(member)) <= 4.0:
					companion.needs.social = minf(100.0, float(companion.needs.social) + 2.0 * delta)
	task.remaining -= delta
	var minimum_time := 0.0 if task.get("automatic",false) else MIN_ACTIVITY_TIME
	if task.remaining <= 0.0 or (float(member.needs[need]) >= 99.0 and float(task.elapsed)>=minimum_time):
		_finish_wish(member,task,str(object.kind))
		_finish_hobby(member,task,str(object.kind))
		member.task = {}
		member.action = "Taking it easy"

func task_activity(task: Dictionary, lot_id: String) -> String:
	if task.get("type")!="interact": return ""
	if task.get("target_kind")=="member": return "chat"
	return str(_object(state.lots[lot_id],str(task.get("target_id",""))).get("kind",""))

static func personal_activity_rates(member: Dictionary, kind: String) -> Dictionary:
	# The actor's restoration, shared by simulation and completion estimates.
	# Tea's effect on nearby companions is applied separately by the simulation.
	var definition: Dictionary=Catalog.ITEMS.get(kind,{})
	if str(definition.get("need","")).is_empty(): return {}
	var hobbies: Dictionary=member.get("hobbies",{})
	var rates := {str(definition.need):float(definition.rate)*Hobbies.multiplier(hobbies,kind)}
	var hobby := Hobbies.for_activity(kind)
	if not hobby.is_empty():
		var secondary: String=Hobbies.CATALOG[hobby].secondary
		rates[secondary]=float(rates.get(secondary,0.0))+Hobbies.rank(hobbies.get(hobby,{}))-1
	if kind in ["bed","sofa"]: rates.comfort=float(rates.get("comfort",0.0))+2.0
	return rates

func care_status(member: Dictionary, need: String) -> String:
	if need=="social" and Tabletop.is_shared(state,member): return "In progress"
	if Wellbeing.restores(task_activity(member.task,str(member.lot_id)),need): return "In progress"
	for task: Dictionary in member.queue:
		if Wellbeing.restores(task_activity(task,str(member.lot_id)),need): return "In your plan"
	return ""

func tabletop_option(member: Dictionary, companion_id: String) -> Dictionary:
	var companion := _find_member(companion_id)
	if companion.is_empty() or companion.id==member.id: return {}
	var object := Tabletop.activity(state,companion)
	if object.is_empty(): return {}
	var count := Tabletop.players(state,str(companion.lot_id),str(object.id),false).size()
	var option := {"available":false,"label":"Join game","detail":"Adds a game after your planned activities. Companions may finish before you arrive.","summary":"Tabletop game · %d/%d places" % [count,Tabletop.CAPACITY],"target_id":str(object.id),"activity_id":str(companion.task.id),"lot_id":str(companion.lot_id)}
	if member.lot_id!=companion.lot_id:
		option.label="Visit to join"; option.detail="Visit this home, then choose Join game."
		return option
	for family: Dictionary in state.families.values():
		if state.lots[family.home_lot].building and not _member(family,str(member.id)).is_empty():
			option.label="Under construction"; option.detail="Finish construction before directing your family."
			return option
	var tasks: Array=member.queue.duplicate()
	if not member.task.is_empty(): tasks.push_front(member.task)
	for task: Dictionary in tasks:
		if task.get("type")=="interact" and task.get("target_kind","object")=="object" and task.get("target_id")==object.id:
			option.label="In your plan"; option.detail="This game is already in your plan."
			if task==member.task and task.get("path",[]).is_empty() and float(task.get("elapsed",0.0))>0.0:
				option.label="Playing here"; option.detail="You are already playing at this table."
			return option
	if member.queue.size()>=MAX_QUEUE:
		option.label="Plan full"; option.detail="Make room in your plan before joining."
		return option
	if not _can_reach_object(state.lots[member.lot_id],_position(member),object):
		option.label="No path to game"; option.detail="There is no path to reach this table."
		return option
	option.available=true
	if count>=Tabletop.CAPACITY:
		option.label="Queue game"; option.detail="All four places are reserved. Wait for a place after your current plans."
	return option

func care_option(member: Dictionary, need: String) -> Dictionary:
	var status := care_status(member,need)
	if not status.is_empty(): return {"available":false,"status":status,"label":status,"detail":str(member.name)+" is already taking care of "+need+"."}
	var lot: Dictionary=state.lots[member.lot_id]
	var best: Dictionary={}
	var best_score := 100000.0
	for object: Dictionary in lot.objects:
		# Secondary comfort from sleeping is recognized in the plan, but a care
		# shortcut for comfort should choose a short break, not send someone to bed.
		if Catalog.ITEMS[object.kind].need!=need: continue
		var goals := _interaction_cells(lot,object)
		var path := _path(lot,_position(member),goals)
		if path.is_empty() and not goals.has(_position(member)): continue
		var busy := not _object_user(str(lot.id),object,str(member.id)).is_empty()
		if object.kind=="game_table":
			var places := _game_places(member,lot,object)
			busy=places.is_empty() or (not places.has(_position(member)) and _path(lot,_position(member),places).is_empty())
		var score := float(path.size())+(1000.0 if busy else 0.0)
		if score<best_score:
			best_score=score
			best={"available":true,"status":"","label":Wellbeing.ACTIONS.get(object.kind,str(Catalog.ITEMS[object.kind].name)),"detail":str(Catalog.ITEMS[object.kind].name)+(" · In use, wait your turn" if busy else " · Here on this lot"),"target_id":object.id,"busy":busy}
	if need=="social":
		for family: Dictionary in state.families.values():
			for other: Dictionary in family.members:
				if other.id==member.id or other.lot_id!=member.lot_id: continue
				var goals := _social_cells(lot,other)
				var path := _path(lot,_position(member),goals)
				if path.is_empty() and not goals.has(_position(member)): continue
				var busy: bool = _chat_busy(other,member) or not other.queue.is_empty()
				var score := float(path.size())-4.0+(1000.0 if busy else 0.0)
				if score<best_score:
					best_score=score
					best={"available":true,"status":"","label":"Chat with "+str(other.name),"detail":"A little company"+(" · They have a plan first" if busy else " · Here on this lot"),"target_id":other.id,"busy":busy}
	if best.is_empty(): return {"available":false,"status":"Unavailable here","label":"No reachable activity","detail":"No reachable "+str(Wellbeing.FURNISHINGS.get(need,"activity"))+" here. Build one or visit a neighbor."}
	return best

func wish_status(member: Dictionary, activity: String) -> String:
	if not member.task.get("automatic",false) and task_activity(member.task,str(member.lot_id))==activity: return "In progress"
	for task: Dictionary in member.queue:
		if not task.get("automatic",false) and task_activity(task,str(member.lot_id))==activity: return "In your plan"
	return ""

func routine_option(profile_id: String,member_id: String,routine_id: String) -> Dictionary:
	var family: Dictionary=state.get("families",{}).get(profile_id,{})
	if family.is_empty(): return {"available":false,"detail":"Join a household first."}
	var member := _member(family,member_id)
	if member.is_empty(): return {"available":false,"detail":"Choose one of your own residents."}
	var entry := Routines.find(family.routines,routine_id)
	if entry.is_empty(): return {"available":false,"detail":"That routine is no longer saved."}
	var result := {"available":false,"name":str(entry.name),"detail":"","actions":[],"steps":[]}
	if state.lots[family.home_lot].building or state.lots[member.lot_id].building:
		result.detail="Finish construction before directing your family."; return result
	var tasks: Array=member.queue.duplicate()
	if not member.task.is_empty(): tasks.append(member.task)
	for task: Dictionary in tasks:
		if task.get("routine_id")==routine_id: result.detail="Already in this resident's plan."; return result
	if member.queue.size()+entry.steps.size()>MAX_QUEUE:
		result.detail="Needs %d free places in the plan; %d available." % [entry.steps.size(),MAX_QUEUE-member.queue.size()]; return result
	var lot: Dictionary=state.lots[member.lot_id]
	var waits := 0
	for kind: String in entry.steps:
		var best: Dictionary={}; var best_score := 100000.0
		for object: Dictionary in lot.objects:
			if object.kind!=kind: continue
			var goals := _interaction_cells(lot,object)
			var path := _path(lot,_position(member),goals)
			if path.is_empty() and not goals.has(_position(member)): continue
			var busy := not _object_user(str(lot.id),object,str(member.id)).is_empty()
			if kind=="game_table":
				var places := _game_places(member,lot,object)
				busy=places.is_empty() or (not places.has(_position(member)) and _path(lot,_position(member),places).is_empty())
			var score := float(path.size())+(1000.0 if busy else 0.0)
			if score<best_score: best_score=score; best={"object":object,"busy":busy}
		if best.is_empty():
			result.detail="No reachable "+str(Catalog.ITEMS[kind].name)+" here. Add one or visit a home with one."; result.actions=[]; return result
		if best.busy: waits+=1
		result.actions.append({"type":"interact","target_kind":"object","target_id":str(best.object.id),"routine_id":routine_id,"routine_name":str(entry.name)})
		result.steps.append({"activity":kind,"target_id":str(best.object.id),"name":str(Catalog.ITEMS[kind].name),"busy":bool(best.busy)})
	result.available=true
	result.detail="Adds %d activities after your existing orders." % entry.steps.size()
	if waits>0: result.detail+=" %d %s currently in use; wait your turn." % [waits,"is" if waits==1 else "are"]
	return result

func hobby_option(member: Dictionary, hobby: String) -> Dictionary:
	var activity: String=Hobbies.CATALOG[hobby].activity
	var status := wish_status(member,activity)
	if not status.is_empty(): return {"available":false,"status":status,"detail":status}
	var lot: Dictionary=state.lots[member.lot_id]
	var best: Dictionary={}
	var best_score := 100000.0
	for object: Dictionary in lot.objects:
		if object.kind!=activity: continue
		var goals := _interaction_cells(lot,object)
		var path := _path(lot,_position(member),goals)
		if path.is_empty() and not goals.has(_position(member)): continue
		var busy := not _object_user(str(lot.id),object,str(member.id)).is_empty()
		var score := float(path.size())+(1000.0 if busy else 0.0)
		if score<best_score:
			best_score=score
			best={"available":true,"status":"","target_id":object.id,"detail":"Wait until it is free" if busy else "Here on this lot"}
	if best.is_empty(): return {"available":false,"status":"Unavailable here","detail":"No reachable "+str(Catalog.ITEMS[activity].name)+" here. Build one or visit a neighbor."}
	return best

func _finish_hobby(member: Dictionary, task: Dictionary, activity: String) -> void:
	if bool(task.get("automatic",false)) or float(task.get("elapsed",0.0))<4.0: return
	for family: Dictionary in state.families.values():
		if not family.online or not family.members.has(member): continue
		var result := Hobbies.record(member.hobbies,activity,int(state.day))
		if not result.is_empty() and result.rank_up:
			var memory := str(result.title)+" · "+str(Hobbies.CATALOG[result.hobby].name)+" rank %d" % int(result.rank)
			member.wishes.journal.push_front({"day":int(state.day),"text":memory})
			if member.wishes.journal.size()>Wishes.MAX_JOURNAL: member.wishes.journal.resize(Wishes.MAX_JOURNAL)
			_event(str(member.name)+" became a "+str(result.title).to_lower()+".")
		return

func _conversation_partner(member: Dictionary) -> Dictionary:
	for family: Dictionary in state.families.values():
		for other: Dictionary in family.members:
			if other.id==member.id or other.lot_id!=member.lot_id: continue
			if other.task.get("target_kind")=="member" and other.task.get("target_id")==member.id and other.task.get("path",[]).is_empty() and float(other.task.get("elapsed",0))>0 and _position(other).distance_to(_position(member))<=2.0: return other
	return {}

func _finish_wish(member: Dictionary, task: Dictionary, activity: String) -> void:
	if bool(task.get("automatic",false)): return
	for family: Dictionary in state.families.values():
		if not family.online: continue
		if not family.members.has(member): continue
		var result := Wishes.record(member.wishes,activity,int(state.day))
		if int(result.reward)>0:
			var home: Dictionary=state.lots[family.home_lot]
			home.funds=mini(1000000000,int(home.funds)+int(result.reward))
			_event(str(member.name)+" fulfilled a wish: "+str(result.title)+". § %d earned." % int(result.reward))
		return

func _choose_autonomy(member: Dictionary, lot: Dictionary) -> void:
	# A missing bathroom must not prevent eating or sleeping. Score every useful,
	# reachable affordance instead of repeatedly retrying one unsatisfiable need.
	var best: Dictionary = {}
	var best_score := 100000.0
	var candidates: Array[Dictionary]=[]
	var urgent := false
	for object: Dictionary in lot.objects:
		if not _object_user(str(lot.id),object,str(member.id)).is_empty(): continue
		if object.kind=="game_table":
			var places := _game_places(member,lot,object)
			if places.is_empty() or (not places.has(_position(member)) and _path(lot,_position(member),places).is_empty()): continue
		var need: String = Catalog.ITEMS[object.kind].need
		var value := float(member.needs[need])
		if value >= 78.0 or not _can_reach_object(lot, _position(member), object):
			continue
		candidates.append({"object":object,"need":value})
		urgent=urgent or value<=Pastimes.URGENT
	for candidate: Dictionary in candidates:
		var object: Dictionary=candidate.object
		var value: float=candidate.need
		if urgent and value>Pastimes.URGENT: continue
		var distance := _position(member).distance_to(Vector2i(int(object.x), int(object.y)))
		var score := value + distance * 0.2
		if not urgent and Pastimes.matches(member,str(object.kind)): score-=Pastimes.PREFERENCE
		if score < best_score:
			best = object
			best_score = score
	if not best.is_empty():
		_queue_action(member, {"type":"interact", "target_id":best.id, "automatic":true})
		_start_next(member, lot)

func _queue_action(member: Dictionary, action: Dictionary) -> void:
	action.id = str(member.id) + ":" + str(int(member.get("next_action", 1)))
	member.next_action = int(member.get("next_action", 1)) + 1
	member.queue.append(action)

func _start_next(member: Dictionary, lot: Dictionary) -> void:
	if member.queue.is_empty():
		return
	var pending: Dictionary = member.queue[0]
	var game_places: Array=[]
	if pending.type == "interact" and pending.get("target_kind", "object") == "object":
		var furnishing := _object(lot,str(pending.target_id))
		var user := _object_user(str(lot.id),furnishing,str(member.id))
		if not user.is_empty():
			member.action = "Waiting for " + str(user.name) + " · " + str(Catalog.ITEMS[furnishing.kind].name)
			return
		if furnishing.get("kind")=="game_table":
			game_places=_game_places(member,lot,furnishing)
			if game_places.is_empty() or (not game_places.has(_position(member)) and _path(lot,_position(member),game_places).is_empty()):
				member.action="Waiting for a place · Game table"
				return
	if pending.type=="interact" and pending.get("target_kind")=="member":
		var companion := _find_member(str(pending.target_id))
		if not companion.is_empty() and companion.lot_id==member.lot_id and _chat_busy(companion,member):
			member.action="Waiting for "+str(companion.name)+" · A chat"
			return
	var task: Dictionary = member.queue.pop_front()
	var goals: Array = []
	if task.type == "move":
		goals = [Vector2i(int(task.x), int(task.y))]
	elif task.get("target_kind", "object") == "member":
		var neighbor := _find_member(str(task.target_id))
		if neighbor.is_empty() or neighbor.lot_id != member.lot_id:
			return
		goals = _social_cells(lot, neighbor)
		task.remaining = 10.0
		task.label = "Chat with " + str(neighbor.name)
	else:
		var object := _object(lot, str(task.target_id))
		if object.is_empty():
			return
		goals = game_places if object.kind=="game_table" else _interaction_cells(lot, object)
		task.remaining = float(Catalog.ITEMS[object.kind].duration)
		task.label = str(Catalog.ITEMS[object.kind].name)
	var route := _path(lot, _position(member), goals)
	if route.is_empty() and not goals.has(_position(member)):
		member.action = "Cannot reach destination"
		return
	task.path = route
	if task.type=="interact": task.elapsed=0.0
	member.task = task
	member.walk_clock = 0.0
	member.action = "Walking" + (" · " + str(task.get("label", "")) if task.type == "interact" else "") if not route.is_empty() else "Starting activity"

func _game_places(member: Dictionary, lot: Dictionary, object: Dictionary) -> Array:
	var players := Tabletop.players(state,str(lot.id),str(object.id),false)
	var reserved: Array=[]
	for player: Dictionary in players:
		if player.id!=member.id: reserved.append(Tabletop.place(player))
	if reserved.size()>=Tabletop.CAPACITY: return []
	for family: Dictionary in state.families.values():
		for other: Dictionary in family.members:
			if other.lot_id==member.lot_id and other.id!=member.id: reserved.append(_position(other))
	var available: Array=[]
	for cell: Vector2i in _interaction_cells(lot,object):
		if not cell in reserved: available.append(cell)
	return available

func _object_user(lot_id: String, object: Dictionary, except_member: String = "") -> Dictionary:
	# Ownership is derived from accepted active tasks, so there are no stale locks
	# to persist or release after cancel, travel, construction, or disconnect.
	if object.is_empty() or not bool(Catalog.ITEMS[object.kind].get("exclusive", false)):
		return {}
	for family: Dictionary in state.families.values():
		for resident: Dictionary in family.members:
			if resident.id != except_member and resident.lot_id == lot_id and resident.task.get("type") == "interact" and resident.task.get("target_id") == object.id:
				return resident
	return {}

func _layout_issue(lot: Dictionary) -> String:
	return str(build_access(lot).message)

func build_access(lot: Dictionary) -> Dictionary:
	var residents: Array=[]
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot.id: residents.append(member)
	return BuildAccess.inspect(lot,residents)

func _capture_build(lot: Dictionary) -> Dictionary:
	var edit := {}
	for key: String in BUILD_FIELDS:
		edit[key] = lot[key].duplicate(true) if lot[key] is Array or lot[key] is Dictionary else lot[key]
	return edit

func _apply_build_edit(lot: Dictionary, edit: Dictionary) -> void:
	for key: String in BUILD_FIELDS:
		lot[key] = edit[key].duplicate(true) if edit[key] is Array or edit[key] is Dictionary else edit[key]

func _update_history_counts(lot: Dictionary) -> void:
	var history: Dictionary = _build_history.get(lot.id,{"undo":[],"redo":[]})
	lot.build_undo = history.undo.size()
	lot.build_redo = history.redo.size()

func _clear_build_history(lot: Dictionary) -> void:
	_build_history.erase(lot.id)
	lot.build_undo = 0
	lot.build_redo = 0

func _history_step(lot: Dictionary, redo: bool) -> Dictionary:
	var history: Dictionary = _build_history.get(lot.id,{"undo":[],"redo":[]})
	var source: String = "redo" if redo else "undo"
	var destination: String = "undo" if redo else "redo"
	if history[source].is_empty(): return _result(false,"Nothing to " + source + ".")
	history[destination].append(_capture_build(lot))
	_apply_build_edit(lot,history[source].pop_back())
	lot.revision += 1
	_update_history_counts(lot)
	return _result(true,"Building edit " + ("redone." if redo else "undone. Funds restored."))

func _restore_build(lot: Dictionary) -> void:
	_apply_build_edit(lot,_build_backups[lot.id])
	_build_backups.erase(lot.id)
	_clear_build_history(lot)

func _send_home(family: Dictionary, member: Dictionary) -> void:
	var lot: Dictionary = state.lots[family.home_lot]
	member.lot_id = family.home_lot
	var entry := _free_entry(lot)
	member.x = entry.x
	member.y = entry.y
	_clear_member(member)

func _free_entry(lot: Dictionary) -> Vector2i:
	if _walkable(lot, Vector2i(8,14)):
		return Vector2i(8,14)
	for y in range(GRID_SIZE - 1, -1, -1):
		for x in range(GRID_SIZE):
			if _walkable(lot, Vector2i(x,y)):
				return Vector2i(x,y)
	return Vector2i(8,14)

func _clear_member(member: Dictionary, label: String = "Taking it easy") -> void:
	member.queue = []
	member.task = {}
	member.action = label
	member.walk_clock = 0.0
	member.idle_clock = 0.0

func _new_object(kind: String, x: int, y: int, rotation: int) -> Dictionary:
	var id := "object_%d" % int(state.next_object)
	state.next_object += 1
	return {"id":id, "kind":kind, "x":x, "y":y, "rotation":rotation}

func _tile_key(kind: String) -> String:
	return {"floor":"floors", "wall":"walls", "door":"doors"}.get(kind, "")

func _member(family: Dictionary, id: String) -> Dictionary:
	for member: Dictionary in family.members:
		if member.id == id:
			return member
	return {}

func _find_member(id: String) -> Dictionary:
	for family: Dictionary in state.families.values():
		var member := _member(family, id)
		if not member.is_empty():
			return member
	return {}

func _social_cells(lot: Dictionary, neighbor: Dictionary) -> Array:
	var cells: Array = []
	for direction: Vector2i in DIRECTIONS:
		var position := _position(neighbor) + direction
		if _walkable(lot, position):
			cells.append(position)
	return cells

func _object(lot: Dictionary, id: String) -> Dictionary:
	for object: Dictionary in lot.objects:
		if object.id == id:
			return object
	return {}

func _object_at(lot: Dictionary, cell: Vector2i) -> Dictionary:
	for object: Dictionary in lot.objects:
		if _object_cells(object).has(cell):
			return object
	return {}

func _resident_at(lot_id: String, cell: Vector2i) -> bool:
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id == lot_id and _position(member) == cell:
				return true
	return false

func _position(member: Dictionary) -> Vector2i:
	return Vector2i(int(member.x), int(member.y))

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

func _walkable(lot: Dictionary, cell: Vector2i) -> bool:
	return _inside(cell) and not lot.walls.has([cell.x,cell.y]) and _object_at(lot, cell).is_empty()

func _object_cells(object: Dictionary) -> Array:
	var result: Array = []
	var size := Catalog.footprint(str(object.kind), int(object.rotation))
	for y in range(int(object.y), int(object.y) + size.y):
		for x in range(int(object.x), int(object.x) + size.x):
			result.append(Vector2i(x,y))
	return result

func _interaction_cells(lot: Dictionary, object: Dictionary) -> Array:
	var result: Array = []
	for tile: Vector2i in _object_cells(object):
		for direction: Vector2i in DIRECTIONS:
			var neighbor := tile + direction
			if _walkable(lot, neighbor) and not result.has(neighbor):
				result.append(neighbor)
	return result

func _can_reach_object(lot: Dictionary, start: Vector2i, object: Dictionary) -> bool:
	var goals := _interaction_cells(lot, object)
	return goals.has(start) or not _path(lot, start, goals).is_empty()

func _path(lot: Dictionary, start: Vector2i, goals: Array) -> Array:
	if goals.is_empty() or goals.has(start):
		return []
	# Construct the occupancy set once; BFS does not rescan furniture on each tile.
	var blocked := {}
	for tile: Array in lot.walls:
		blocked[Vector2i(int(tile[0]), int(tile[1]))] = true
	for object: Dictionary in lot.objects:
		for cell: Vector2i in _object_cells(object):
			blocked[cell] = true
	var previous := {start:start}
	var frontier: Array = [start]
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if not _inside(next) or blocked.has(next) or previous.has(next):
				continue
			previous[next] = current
			if goals.has(next):
				var result: Array = []
				while next != start:
					result.push_front([next.x,next.y])
					next = previous[next]
				return result
			frontier.append(next)
	return []

func snapshot() -> Dictionary:
	return state.duplicate(true)

func snapshot_for_save() -> Dictionary:
	# Save only committed buildings. A crash must not strand residents in a draft.
	var saved := snapshot()
	for lot_id: String in _build_backups:
		var source: Dictionary = _build_backups[lot_id]
		for key: String in BUILD_FIELDS:
			saved.lots[lot_id][key] = source[key].duplicate(true) if source[key] is Array or source[key] is Dictionary else source[key]
	for lot: Dictionary in saved.lots.values():
		lot.building = false
		lot.build_undo = 0
		lot.build_redo = 0
	return saved

func restore(data: Dictionary, preserve_runtime: bool = false) -> bool:
	# Reject foreign/future/corrupt worlds atomically; never partially adopt a save.
	if not _valid_state(data):
		return false
	state = data.duplicate(true)
	_normalize_numbers()
	_build_backups.clear()
	_build_history.clear()
	if preserve_runtime:
		return true
	for lot: Dictionary in state.lots.values():
		lot.building = false
		_clear_build_history(lot)
	for family: Dictionary in state.families.values():
		HomeNews.departure(family,false)
		family.online = false
		for member: Dictionary in family.members:
			_clear_member(member)
			if not _walkable(state.lots[member.lot_id], _position(member)):
				_send_home(family, member)
	return true

func _normalize_numbers() -> void:
	# JSON has one numeric type. Tile-array equality in Godot distinguishes floats
	# from ints, so restore the canonical integer representation before simulation.
	for key: String in ["tick", "day", "next_object"]:
		state[key] = int(state[key])
	for lot: Dictionary in state.lots.values():
		lot.build_undo = int(lot.get("build_undo",0))
		if not lot.has("finishes"): lot.finishes=Finishes.create()
		if not lot.has("windows"): lot.windows={}
		lot.build_redo = int(lot.get("build_redo",0))
		lot.funds = int(lot.funds)
		lot.revision = int(lot.revision)
		for key: String in ["floors", "walls", "doors"]:
			for tile: Array in lot[key]:
				tile[0] = int(tile[0])
				tile[1] = int(tile[1])
		for object: Dictionary in lot.objects:
			for key: String in ["x", "y", "rotation"]:
				object[key] = int(object[key])
	for family: Dictionary in state.families.values():
		HomeNews.normalize(family)
		if not family.has("routines"): family.routines=Routines.create()
		Routines.normalize(family.routines)
		family.identity_revision=int(family.get("identity_revision",0))
		for member: Dictionary in family.members:
			if not member.has("favorite"): member.favorite="variety"
			if not member.has("appearance"): member.appearance=Appearance.defaults(member)
			for key: String in member.appearance: member.appearance[key]=int(member.appearance[key])
			if not member.has("wishes"): member.wishes=Wishes.create(str(member.id),int(state.day))
			Wishes.normalize(member.wishes)
			if not member.has("hobbies"): member.hobbies=Hobbies.create(int(state.day))
			Hobbies.normalize(member.hobbies)
			member.autonomy = member.get("autonomy", true)
			member.next_action = int(member.get("next_action", 1))
			member.x = int(member.x)
			member.y = int(member.y)
			var tasks: Array = member.queue.duplicate()
			if not member.task.is_empty():
				tasks.append(member.task)
			for task: Dictionary in tasks:
				if not task.has("id"):
					task.id = str(member.id) + ":" + str(member.next_action)
					member.next_action += 1
				if task.type == "move":
					task.x = int(task.x)
					task.y = int(task.y)
				for tile: Array in task.get("path", []):
					tile[0] = int(tile[0])
					tile[1] = int(tile[1])
	Friendships.normalize(state)
	Mailbox.normalize(state)

func _valid_state(data: Dictionary) -> bool:
	if data.get("schema") != SCHEMA or not data.get("lots") is Dictionary or data.lots.size() != MAX_FAMILIES or not data.get("families") is Dictionary or data.families.size() > MAX_FAMILIES:
		return false
	if not _integer(data.get("tick")) or not _integer(data.get("day")) or not _number(data.get("day_minutes")) or float(data.day_minutes) < 0.0 or float(data.day_minutes) >= 1440.0 or not _integer(data.get("next_object")):
		return false
	if float(data.tick) < 0 or float(data.tick) > 9007199254740991 or float(data.day) < 1 or float(data.day) > 1000000000 or float(data.next_object) < 1 or float(data.next_object) > 9007199254740991:
		return false
	if not data.get("events") is Array or data.events.size() > 24:
		return false
	for event: Variant in data.events:
		if not event is String or event.length() > 200:
			return false
	var object_ids := {}
	for index in range(MAX_FAMILIES):
		var id := "lot_%d" % (index + 1)
		if not data.lots.get(id) is Dictionary:
			return false
		var lot: Dictionary = data.lots[id]
		if lot.get("id") != id or not lot.get("name") is String or str(lot.name).length() > 64 or not lot.get("owner") is String or str(lot.owner).length() > 128 or not _integer(lot.get("funds")) or float(lot.funds) < 0 or float(lot.funds) > 1000000000 or not lot.get("building") is bool or not _integer(lot.get("revision")):
			return false
		for key: String in ["floors", "walls", "doors"]:
			if not lot.get(key) is Array or lot[key].size() > GRID_SIZE * GRID_SIZE:
				return false
			var seen := {}
			for cell: Variant in lot[key]:
				if not cell is Array or cell.size() != 2 or not _valid_coord(cell[0]) or not _valid_coord(cell[1]):
					return false
				var position := Vector2i(int(cell[0]), int(cell[1]))
				if seen.has(position):
					return false
				seen[position] = true
		for key: String in ["build_undo","build_redo"]:
			if not _integer(lot.get(key,0)) or float(lot.get(key,0)) < 0 or float(lot.get(key,0)) > MAX_BUILD_HISTORY: return false
		if float(lot.revision) < 0 or float(lot.revision) > 9007199254740991:
			return false
		if not lot.get("objects") is Array or lot.objects.size() > GRID_SIZE * GRID_SIZE:
			return false
		var occupied := {}
		var floor_cells := {}
		for cell: Array in lot.floors:
			floor_cells[Vector2i(int(cell[0]), int(cell[1]))] = true
		for cell: Array in lot.walls:
			occupied[Vector2i(int(cell[0]), int(cell[1]))] = true
		for cell: Array in lot.doors:
			var position := Vector2i(int(cell[0]), int(cell[1]))
			if occupied.has(position):
				return false
			occupied[position] = true
		for object: Variant in lot.objects:
			if not object is Dictionary or not object.get("id") is String or str(object.id).length() > 64 or object_ids.has(object.id) or not Catalog.ITEMS.has(object.get("kind")) or object.kind in ["floor", "wall", "door"] or not _valid_coord(object.get("x")) or not _valid_coord(object.get("y")) or not _integer(object.get("rotation")) or int(object.rotation) < 0 or int(object.rotation) > 3:
				return false
			if not str(object.id).begins_with("object_") or not str(object.id).trim_prefix("object_").is_valid_int() or int(str(object.id).trim_prefix("object_")) >= int(data.next_object):
				return false
			object_ids[object.id] = true
			for cell: Vector2i in _object_cells(object):
				if not _inside(cell) or occupied.has(cell) or not floor_cells.has(cell):
					return false
				occupied[cell] = true
		if not Finishes.valid(lot) or not Windows.valid(lot): return false
	var members_seen := {}
	for profile_id: Variant in data.families:
		if not profile_id is String or profile_id.is_empty() or profile_id.length() > 128 or not data.families[profile_id] is Dictionary:
			return false
		var family: Dictionary = data.families[profile_id]
		if family.get("id") != profile_id or not family.get("name") is String or str(family.name).length() > 64 or not data.lots.has(family.get("home_lot")) or data.lots[family.home_lot].owner != profile_id or not family.get("online") is bool or not family.get("members") is Array or family.members.size() != 2:
			return false
		if family.has("home_news") and not HomeNews.valid(family.home_news): return false
		if family.has("routines") and not Routines.valid(family.routines): return false
		if not _integer(family.get("identity_revision",0)) or float(family.get("identity_revision",0))<0 or float(family.get("identity_revision",0))>9007199254740000: return false
		for member: Variant in family.members:
			if not member is Dictionary or not member.get("id") is String or str(member.id).length() > 160 or members_seen.has(member.id) or not member.get("name") is String or str(member.name).length() > 32 or not data.lots.has(member.get("lot_id")) or not _valid_coord(member.get("x")) or not _valid_coord(member.get("y")) or not member.get("needs") is Dictionary:
				return false
			if not member.get("autonomy", true) is bool or not _integer(member.get("next_action", 1)) or float(member.get("next_action", 1)) < 1 or float(member.get("next_action", 1)) > 9007199254740000:
				return false
			if member.has("favorite") and not Pastimes.valid(member.favorite): return false
			if member.has("appearance") and not Appearance.valid(member.appearance): return false
			if member.has("wishes") and not Wishes.valid(member.wishes,int(data.day)): return false
			if member.has("hobbies") and not Hobbies.valid(member.hobbies,int(data.day)): return false
			members_seen[member.id] = true
			if not member.get("action") is String or str(member.action).length() > 100 or not member.get("queue") is Array or member.queue.size() > MAX_QUEUE or not member.get("task") is Dictionary or not _number(member.get("walk_clock")) or not _number(member.get("idle_clock")):
				return false
			if float(member.walk_clock) < 0 or float(member.walk_clock) > 60 or float(member.idle_clock) < 0 or float(member.idle_clock) > 60:
				return false
			for task: Variant in member.queue:
				if not _valid_task(task, false):
					return false
			if not member.task.is_empty() and not _valid_task(member.task, true):
				return false
			for need: String in NEEDS:
				if not _number(member.needs.get(need)) or float(member.needs[need]) < 0 or float(member.needs[need]) > 100:
					return false
	if data.has("friendships") and not Friendships.valid(data.friendships,members_seen,int(data.day),int(data.tick)): return false
	if not Mailbox.valid(data): return false
	for lot: Dictionary in data.lots.values():
		if not str(lot.owner).is_empty() and not data.families.has(lot.owner):
			return false
	return true

func _fund_balances(lot_id: String) -> Array:
	var balances: Array=[state.lots[lot_id]]
	if _build_backups.has(lot_id): balances.append(_build_backups[lot_id])
	if _build_history.has(lot_id):
		for branch: String in ["undo","redo"]: balances.append_array(_build_history[lot_id][branch])
	return balances

func _adjust_funds(lot_id: String, amount: int) -> bool:
	# External income belongs to the household, not its construction draft.
	# Check every reversible balance before changing any of them.
	var balances := _fund_balances(lot_id)
	for balance: Dictionary in balances:
		if int(balance.funds)+amount<0 or int(balance.funds)+amount>1000000000: return false
	for balance: Dictionary in balances: balance.funds=int(balance.funds)+amount
	return true

func _valid_task(value: Variant, active: bool) -> bool:
	if not value is Dictionary or not value.get("type") in ["move", "interact"]:
		return false
	if value.has("routine_id") or value.has("routine_name"):
		if value.type!="interact" or not Routines.valid_id(value.get("routine_id")) or not HouseholdProfile.valid_name(value.get("routine_name"),32): return false
	if value.has("social_started") and (not _integer(value.social_started) or float(value.social_started)<0 or float(value.social_started)>9007199254740991): return false
	if value.has("elapsed") and (not _number(value.elapsed) or float(value.elapsed)<0 or float(value.elapsed)>120): return false
	if value.has("id") and (not value.id is String or str(value.id).is_empty() or str(value.id).length() > 180):
		return false
	if value.has("automatic") and not value.automatic is bool:
		return false
	if value.has("target_kind") and not value.target_kind in ["member", "object"]:
		return false
	if value.type == "move":
		if not _valid_coord(value.get("x")) or not _valid_coord(value.get("y")):
			return false
	else:
		if not value.get("target_id") is String or str(value.target_id).length() > 160:
			return false
		if active and (not _number(value.get("remaining")) or not value.get("label") is String or str(value.label).length() > 100):
			return false
	if active:
		if value.type == "interact" and (float(value.remaining) <= 0 or float(value.remaining) > 120):
			return false
		if not value.get("path") is Array or value.path.size() > GRID_SIZE * GRID_SIZE:
			return false
		for tile: Variant in value.path:
			if not tile is Array or tile.size() != 2 or not _valid_coord(tile[0]) or not _valid_coord(tile[1]):
				return false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))

func _valid_coord(value: Variant) -> bool:
	return _integer(value) and float(value) >= 0 and float(value) < GRID_SIZE

func _event(message: String) -> void:
	state.events.push_front(message.left(200))
	if state.events.size() > 24:
		state.events.resize(24)

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok, "message":message}

func chat_status(member: Dictionary, target_id: String) -> String:
	if member.task.get("target_kind")=="member" and member.task.get("target_id")==target_id: return "In progress"
	for task: Dictionary in member.queue:
		if task.get("target_kind")=="member" and task.get("target_id")==target_id: return "In your plan"
	return ""

func _chat_busy(target: Dictionary, initiator: Dictionary) -> bool:
	if not target.task.is_empty():
		if not (target.task.get("target_kind")=="member" and target.task.get("target_id")==initiator.id): return true
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.id==initiator.id or member.id==target.id or member.lot_id!=target.lot_id: continue
			if member.task.get("target_kind")=="member" and member.task.get("target_id")==target.id and member.task.get("path",[]).is_empty() and float(member.task.get("elapsed",0))>0: return true
	return false

func _online_member(member: Dictionary) -> bool:
	for family: Dictionary in state.families.values():
		if family.members.has(member): return bool(family.online)
	return false

func _finish_conversation(member: Dictionary, neighbor: Dictionary, task: Dictionary) -> void:
	if task.get("automatic",false) or not _online_member(member) or not _online_member(neighbor): return
	var result := Friendships.record(state,str(member.id),str(neighbor.id),int(task.get("social_started",state.tick)))
	var milestone: String=result.get("milestone","")
	if milestone.is_empty(): return
	var detail := " got to know " if milestone=="met" else " became "+milestone+" with "
	_event(str(member.name)+detail+str(neighbor.name)+".")
	for pair in [[member,neighbor],[neighbor,member]]:
		var text := ("Got to know " if milestone=="met" else "Became "+milestone+" with ")+str(pair[1].name)+"."
		pair[0].wishes.journal.push_front({"day":int(state.day),"text":text})
		if pair[0].wishes.journal.size()>Wishes.MAX_JOURNAL: pair[0].wishes.journal.resize(Wishes.MAX_JOURNAL)
