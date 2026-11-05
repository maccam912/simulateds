extends RefCounted
## Pure host-owned simulation: no networking, Nodes, clocks, or filesystem access.
## Commands are the only external mutations; the whole state is JSON-compatible.
const Catalog = preload("res://game/catalog.gd")
const BuildRules = preload("res://game/build_rules.gd")
const RoomPlan = preload("res://game/room_plan.gd")
const RoomCopy = preload("res://game/room_copy.gd")
const ConstructionSpace = preload("res://game/construction_space.gd")
const Storeys = preload("res://game/storeys.gd")
const Landscaping = preload("res://game/landscaping.gd")
const BuildArea = preload("res://game/build_area.gd")
const ClearLot = preload("res://game/clear_lot.gd")
const RoomLibrary = preload("res://game/room_library.gd")
const FurnitureColors = preload("res://game/furniture_colors.gd")
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
const Leisure = preload("res://game/shared_leisure.gd")
const Recreation = preload("res://game/recreation.gd")
const Courtesy = preload("res://game/courtesy.gd")
const BuildAccess = preload("res://game/build_access.gd")
const Routines = preload("res://game/routines.gd")
const ArtAdmiration = preload("res://game/art_admiration.gd")
const WallArt = preload("res://game/wall_art.gd")
const Paintings = preload("res://game/paintings.gd")
const Commissions = preload("res://game/art_commissions.gd")
const Pantry = preload("res://game/pantry.gd")
const Meals = preload("res://game/meals.gd")
const HouseholdTravel = preload("res://game/household_travel.gd")
const Gardens = preload("res://game/gardens.gd")
const ActivityLog = preload("res://game/activity_log.gd")
const Character = preload("res://game/character_profile.gd")
const HouseholdProfile = preload("res://game/household_profile.gd")
const GRID_SIZE := 16
const SCHEMA := 3
const MAX_FAMILIES := 4
const MAX_QUEUE := 8
const MAX_BUILD_HISTORY := 32
const MINUTES_PER_SECOND := 3.0
const MIN_ACTIVITY_TIME := 4.0
const BUILD_FIELDS := ["floors", "walls", "doors", "objects", "funds", "finishes", "windows", "artworks", "landscape", "diagonal_walls", "storeys"]
const NEEDS := ["hunger", "energy", "hygiene", "bladder", "fun", "social", "comfort"]
const DECAY := {"hunger":0.13, "energy":0.08, "hygiene":0.10, "bladder":0.15, "fun":0.12, "social":0.09, "comfort":0.07}
const ACTION_NAMES := {"bed":"Sleeping", "fridge":"Making a meal", "shower":"Showering", "toilet":"Using the bathroom", "sofa":"Relaxing", "tv":"Watching television", "bookshelf":"Reading", "plant":"Tending plants", "table":"Having tea", "game_table":"Playing a tabletop puzzle", "stereo":"Dancing", "easel":"Painting"}
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
		var lot := {"id":id, "name":names[index], "owner":"", "funds":12000, "building":false, "revision":0, "build_undo":0, "build_redo":0, "floors":[], "walls":[], "doors":[], "objects":[],"artworks":{},"landscape":Landscaping.empty(),"diagonal_walls":{},"storeys":{}}
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
			members.append({"id":profile_id + "_" + str(index + 1), "name":clean_name if index == 0 else "Robin", "lot_id":lot_id, "x":7 + index, "y":7, "needs":needs, "action":"Taking it easy", "queue":[], "task":{}, "activity_log":[], "walk_clock":0.0, "idle_clock":float(index) * 2.0, "autonomy":true, "next_action":1})
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
		state.families[profile_id].room_library=RoomLibrary.create()
		state.families[profile_id].commissions=Commissions.create()
		state.families[profile_id].pantry=Pantry.create()
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
	if type in ["commission_accept","commission_cancel","commission_deliver"]:
		var outcome:=Commissions.apply(state,profile_id,command,_adjust_funds)
		if outcome.ok and type=="commission_deliver": _event(str(outcome.message))
		return outcome
	if type == "news_read": return HomeNews.read(family,command.get("revision"))
	if type == "household_edit":
		var edited := HouseholdProfile.edit(family,command,_create_resident)
		if edited.ok:
			Friendships.ensure_housemates(state,family)
			for resident: Dictionary in family.members:
				if Character.is_baby(resident):
					_clear_member(resident,"Resting in the bassinet")
					if resident.lot_id!=family.home_lot: _send_home(family,resident)
		return edited
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
	if type=="construction_space": return _construction_space(profile_id,command,lot)
	if type in ["blueprint_save","blueprint_rename","blueprint_delete"]:
		if not _integer(command.get("level",0)) or int(command.get("level",0))<0 or int(command.get("level",0))>Storeys.MAX_LEVEL: return _result(false,"Choose a floor from 1 to 3.")
		lot=Storeys.view(lot,int(command.get("level",0)))
		if lot.owner!=profile_id: return _result(false,"Only your own household can edit its saved rooms.")
		var captured := {}
		if type=="blueprint_save":
			if not lot.building: return _result(false,"Enter construction mode to select a room to save.")
			if not _integer(command.get("revision")) or int(command.revision)!=int(lot.revision): return _result(false,"The room changed. Select it again before saving.")
			if not BuildRules._coordinate(command.get("source_x")) or not BuildRules._coordinate(command.get("source_y")): return _result(false,"Choose floor inside a room to save.")
			captured=RoomCopy.capture(lot,Vector2i(int(command.source_x),int(command.source_y)))
			if not captured.ok: return captured
		return RoomLibrary.edit(family,command,captured)
	if type in ["build_begin", "build_end", "build_cancel", "build_undo", "build_redo", "place", "erase", "move_object", "build_room", "copy_room", "place_blueprint", "clear_lot", "erase_area", "place_area", "landscape", "paint", "set_window", "recolor", "art_hang", "art_store", "art_return"]:
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
							_send_home(other, member, "This lot entered construction; returned home.")
						else:
							_clear_member(member, "Waiting for construction", "Construction started.")
			_event(str(lot.name) + " is under construction. Visitors have gone home.")
			return _result(true, "Construction started. Your family is paused; neighbors keep living.")
		if not lot.building:
			return _result(false, "Enter construction mode first.")
		if type in ["build_undo", "build_redo", "build_room", "copy_room", "place_blueprint", "clear_lot", "erase_area", "place_area", "landscape", "paint", "set_window", "recolor", "art_hang", "art_store", "art_return"]:
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
			_relocate_build_residents(lot)
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
		var result := _build_storey(lot, command)
		if result.ok:
			_relocate_build_residents(lot)
			var stored := WallArt.reconcile(lot)
			if stored>0: result.message+=" A painting moved safely into the collection." if stored==1 else " %d paintings moved safely into the collection." % stored
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
	if type=="meal_call": return _call_meal(profile_id,command)
	if type=="recreation": return _recreation(profile_id,command,lot)
	if type=="travel_household": return _travel_household(profile_id,command)
	if Character.is_baby(member): return _result(false,"Babies rest at home in their bassinet. Choose an older resident for activities.")
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
		if wish_id in Wishes.MEALS: return _result(false,"Open this wish to find a dining table, then choose a recipe or meal. Ingredients are paid only when served.")
		if not wish_status(member,activity).is_empty(): return _result(false,"That activity is already in this resident’s plan.")
		var destination: Dictionary=_member_lot(member)
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
			_end_task(member,"cancelled","Cancelled from Plan.")
			member.idle_clock = 0.0
			_start_next(member, _member_lot(member))
			return _result(true, "Current action canceled. The rest of the plan continues.")
		for queued: Dictionary in member.queue:
			if queued.get("id", "") == action_id:
				_record_activity(member,queued,"cancelled","Cancelled from Plan.")
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
		if member.task.is_empty(): _start_next(member,_member_lot(member))
		return _result(true,str(option.name)+" added to "+str(member.name)+"'s plan.")
	if type=="practice_hobby":
		var hobby: Variant=command.get("hobby")
		if not hobby is String or not Hobbies.CATALOG.has(hobby): return _result(false,"Choose a hobby from this resident's Hobbies panel.")
		if hobby=="painting": return _result(false,"Choose a subject or continue a canvas at the easel.")
		var option := hobby_option(member,hobby)
		if not option.available: return _result(false,str(option.detail))
		return apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":option.target_id})
	if type=="care":
		var need: Variant=command.get("need")
		if not need is String or not NEEDS.has(need): return _result(false,"Choose one of this resident’s needs.")
		var option := care_option(member,need)
		if not option.available: return _result(false,str(option.detail))
		if option.has("meal_batch"): return apply_command(profile_id,{"type":"meal","member_id":member.id,"lot_id":member.lot_id,"target_id":option.target_id,"action":"eat","recipe":"","batch":option.meal_batch})
		var result := apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":option.target_id})
		return result
	if type in ["visit", "go_home"]:
		var destination: Dictionary = state.lots[family.home_lot] if type == "go_home" else lot
		if destination.building:
			return _result(false, "This home is under construction. Visit again soon.")
		if type == "visit" and str(destination.owner).is_empty():
			return _result(false, "Nobody lives here yet.")
		if member.lot_id==destination.id: return _result(true,"Already at "+str(destination.name)+". Your plan continues.")
		_clear_member(member,"Taking it easy","Travelled to "+str(destination.name)+".")
		member.lot_id = destination.id
		member.level=0
		member.next_action+=1
		var entry := _free_entry(destination,str(member.id))
		member.x = entry.x
		member.y = entry.y
		_event(str(member.name) + " arrived at " + str(destination.name) + ".")
		return _result(true, "Arrived at " + str(destination.name) + ".")
	if type=="use_stairs": return _use_stairs(member,lot,command)
	if type not in ["visit","go_home"]:
		if command.has("level") and (not _integer(command.level) or int(command.level)!=int(member.get("level",0))): return _result(false,"Use the stairs to reach this floor first.")
		lot=Storeys.view(lot,int(member.get("level",0)))
	if member.lot_id != lot_id:
		return _result(false, "Visit this lot before using it.")
	if lot.building:
		return _result(false, "This lot is under construction.")
	if member.queue.size() >= MAX_QUEUE and not (type=="meal" and command.get("action") in ["clear","choose"]) and not (type=="join_meal" and command.has("own_activity_id")):
		return _result(false, "The action queue is full (8 actions).")
	if type in ["join_game","join_dance","join_meal"]:
		var companion_id: Variant=command.get("companion_id")
		var activity_id: Variant=command.get("activity_id")
		if not companion_id is String or not activity_id is String or activity_id.is_empty():
			return _result(false,"Choose a resident’s current activity from People.")
		var option := leisure_option(member,companion_id,"game_table" if type=="join_game" else "stereo" if type=="join_dance" else "dining_table")
		if option.is_empty() or option.activity_id!=activity_id:
			return _result(false,"That activity has changed. Choose a current activity from People.")
		if not option.available: return _result(false,str(option.detail))
		if type=="join_meal":
			var own: String=option.get("own_activity_id","")
			if not command.get("own_activity_id","") is String or command.get("own_activity_id","")!=own: return _result(false,"Your meal changed. Choose from People again.")
			var intent := {"type":"meal","member_id":member.id,"lot_id":lot_id,"target_id":option.target_id,"action":"eat" if own.is_empty() else "choose","recipe":"","batch":_object(lot,str(option.target_id)).meal.batch}
			if not own.is_empty(): intent.activity_id=own
			return apply_command(profile_id,intent)
		var result := apply_command(profile_id,{"type":"interact","member_id":member.id,"lot_id":lot_id,"target_id":option.target_id})
		return result
	if type=="meal":
		var option := meal_option(profile_id,str(member.id),str(lot_id),command.get("target_id"),command.get("action"),command.get("recipe",""))
		if not option.ok: return option
		if not _integer(command.get("batch")) or int(command.batch)!=int(option.batch): return _result(false,"The meal changed. Choose from the table again.")
		if command.action=="choose":
			if not command.get("activity_id") is String or command.get("activity_id")!=option.activity_id: return _result(false,"Your meal changed. Choose it again at the table.")
			var chosen: Dictionary=member.task.duplicate(true)
			chosen.erase("automatic"); chosen.erase("social_started"); chosen.meal_chosen_at=float(chosen.elapsed)
			_queue_action(member,chosen); member.task=member.queue.pop_back()
			return _result(true,"Meal chosen · Your serving and remaining time are kept.")
		if command.action=="clear":
			var table := _object(lot,str(command.target_id)); var batch := int(table.meal.batch)+1
			table.meal=Meals.create(); table.meal.batch=batch
			return _result(true,"Leftovers cleared. The table is ready for a fresh meal.")
		_queue_action(member,{"type":"interact","target_id":option.target_id,"meal_action":command.action,"meal_table":command.target_id,"meal_recipe":option.recipe,"meal_batch":int(option.batch)})
	elif type=="admire_art":
		var option := admire_option(profile_id,str(member.id),str(lot_id),command.get("target_id"))
		if not option.ok: return option
		if not _integer(command.get("x")) or not _integer(command.get("y")) or int(command.x)!=int(option.x) or int(command.y)!=int(option.y): return _result(false,"This painting moved. Choose it again on the wall.")
		_queue_action(member,{"type":"interact","target_kind":"art","target_id":command.target_id,"art_x":int(option.x),"art_y":int(option.y)})
	elif type=="painting":
		var option := painting_option(profile_id,str(member.id),str(lot_id),command.get("target_id"),command.get("action"),command.get("subject",""))
		if not option.ok: return option
		if not _integer(command.get("revision")) or int(command.revision)!=int(option.revision): return _result(false,"This canvas changed. Choose from its current activities.")
		_queue_action(member,{"type":"interact","target_id":command.target_id,"paint_action":command.action,"subject":command.get("subject",""),"paint_revision":int(option.revision)})
	elif type=="garden":
		var option := garden_option(profile_id,str(member.id),str(lot_id),command.get("target_id"),command.get("action"),command.get("crop",""))
		if not option.ok: return option
		if not _integer(command.get("revision")) or int(command.revision)!=int(option.revision): return _result(false,"This garden bed changed. Choose from its current activities.")
		_queue_action(member,{"type":"interact","target_id":command.target_id,"garden_action":command.action,"crop":command.get("crop",""),"garden_revision":int(option.revision)})
	elif type == "move":
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
			if neighbor.is_empty() or neighbor.id == member.id or neighbor.lot_id != member.lot_id or int(neighbor.get("level",0))!=int(member.get("level",0)):
				return _result(false, "Choose another resident on this lot or a furnishing.")
			if not chat_status(member,str(neighbor.id)).is_empty(): return _result(false,"That conversation is already in this resident’s plan.")
			var goals := _social_cells(lot, neighbor)
			if not goals.has(_position(member)) and _path(lot, _position(member), goals).is_empty():
				return _result(false, "There is no path to chat with that resident.")
			_queue_action(member, {"type":"interact", "target_id":target_id, "target_kind":"member"})
		else:
			if object.kind=="stairs": return _use_stairs(member,state.lots[member.lot_id],{"direction":1})
			if str(Catalog.ITEMS[object.kind].need).is_empty(): return _result(false,"This furnishing decorates the home.")
			if object.kind=="dining_table": return _result(false,"Open the dining table to prepare or choose a meal.")
			if object.kind=="easel": return _result(false,"Open the easel to choose a subject or continue its painting.")
			if object.kind=="garden_bed": return _result(false,"Open the garden bed to choose planting, watering, or harvesting.")
			if not _can_reach_object(lot, _position(member), object):
				return _result(false, "There is no path to use that furnishing.")
			_queue_action(member, {"type":"interact", "target_id":target_id})
	else:
		return _result(false, "Unknown action.")
	# A direct order interrupts an autonomous task, but preserves player-queued work.
	var accepted: Dictionary=member.queue[-1]
	if bool(member.task.get("automatic", false)):
		member.task = {}
	if member.task.is_empty():
		_start_next(member, lot)
	var activity := str(accepted.title)
	if type=="interact" and accepted.get("target_kind","")!="member":
		activity=str(ACTION_NAMES.get(_object(lot,str(accepted.target_id)).get("kind",""),activity))
	var outcome := "Starting" if member.task.get("id")==accepted.id else "Queued"
	if member.task.get("id")!=accepted.id and not member.queue.has(accepted):
		return _result(true,str(member.name)+" · "+activity+" could not start: "+str(member.action))
	return _result(true,str(member.name)+" · "+outcome+": "+activity+". Manage in Plan.")

func _construction_space(profile_id: String,command: Dictionary,lot: Dictionary) -> Dictionary:
	var option:=ConstructionSpace.request(state,profile_id,str(lot.id))
	if not option.ok: return _result(false,str(option.message))
	if not _integer(command.get("revision")) or int(command.revision)!=int(lot.revision): return _result(false,"The lot changed. Try moving the family from the current draft.")
	if not ConstructionSpace.matches(command.get("orders"),option.orders): return _result(false,"The family's positions changed. Try moving them from their current places.")
	var moving: Array=option.orders.map(func(row): return str(row.member_id))
	var stationary: Array=[]
	for family: Dictionary in state.families.values():
		for resident: Dictionary in family.members:
			if resident.lot_id==lot.id and not moving.has(resident.id): stationary.append(_position(resident))
	var history: Dictionary=_build_history.get(lot.id,{"undo":[],"redo":[]})
	var placement:=ConstructionSpace.places(lot,option.orders,stationary,history.undo+history.redo,_build_backups.get(lot.id,{}))
	if not placement.ok: return _result(false,str(placement.message))
	var changed:=0
	for index in range(option.orders.size()):
		var member:=_member(state.families[profile_id],str(option.orders[index].member_id))
		var at: Vector2i=placement.places[index]
		if _position(member)!=at: changed+=1
		member.level=0
		_clear_member(member,"Waiting for construction","Moved aside for construction.")
		member.x=at.x; member.y=at.y; member.next_action+=1
	return _result(true,"Your family is already by the entrance." if changed==0 else ", ".join(option.names)+" moved aside. Keep building; Undo still restores your house edits.")

func travel_option(profile_id: String,lot_id: String,travelers: Variant) -> Dictionary:
	var result := {"ok":false,"message":"Choose household residents to travel.","orders":[],"places":[]}
	var family: Dictionary=state.families.get(profile_id,{})
	var lot: Dictionary=state.lots.get(lot_id,{})
	if family.is_empty() or lot.is_empty(): return result
	if lot.building or state.lots[family.home_lot].building:
		result.message="Finish construction before travelling."; return result
	if str(lot.owner).is_empty(): result.message="Nobody lives here yet."; return result
	if not travelers is Array or travelers.is_empty() or travelers.size()>family.members.size(): return result
	var seen := {}
	for id: Variant in travelers:
		if not id is String or seen.has(id) or _member(family,id).is_empty(): return result
		seen[id]=true
	for member: Dictionary in family.members:
		if not seen.has(member.id): continue
		if Character.is_baby(member): result.message="Babies stay at home in their bassinet."; return result
		if member.lot_id==lot_id: result.message=str(member.name)+" is already here. Review who is leaving."; return result
		if int(member.next_action)>=9007199254740000: result.message="This resident's action counter is exhausted."; return result
		result.orders.append(HouseholdTravel.stamp(member))
	result.places=_arrival_places(lot,result.orders.size())
	if result.places.size()!=result.orders.size(): result.message="Not enough clear arrival space by the entrance."; return result
	result.ok=true; result.message="Travel stops their current actions and clears their plans."
	return result

func _travel_household(profile_id: String,command: Dictionary) -> Dictionary:
	if not command.get("lot_id") is String: return _result(false,"Choose a destination for this household.")
	var option := travel_option(profile_id,str(command.lot_id),command.get("travelers"))
	if not option.ok: return _result(false,str(option.message))
	if not HouseholdTravel.matches(command.get("orders"),option.orders): return _result(false,"Someone's location or plan changed. Review who is leaving and try again.")
	# All ownership, plans and distinct arrival places are checked before anyone moves.
	var lot: Dictionary=state.lots[command.lot_id]; var names: PackedStringArray=[]
	for index in range(option.orders.size()):
		var member := _member(state.families[profile_id],str(option.orders[index].member_id))
		_clear_member(member,"Taking it easy","Travelled to "+str(lot.name)+".")
		member.lot_id=lot.id; member.level=0; member.x=option.places[index].x; member.y=option.places[index].y; member.next_action+=1
		names.append(str(member.name))
	_event(", ".join(names)+" arrived at "+str(lot.name)+".")
	return _result(true,"Arrived together at "+str(lot.name)+"." if names.size()>1 else str(names[0])+" arrived at "+str(lot.name)+".")

func _arrival_places(lot: Dictionary,count: int,ignore_member: String="") -> Array[Vector2i]:
	var occupied := {}; var result: Array[Vector2i]=[]
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot.id and int(member.get("level",0))==0 and member.id!=ignore_member: occupied[_position(member)]=true
	# The entrance flood is ordered nearest-first and never puts someone in a sealed room.
	for cell: Vector2i in BuildAccess.reachable_from(BuildAccess.obstacles(lot),BuildAccess.GATE):
		if occupied.has(cell): continue
		result.append(cell)
		if result.size()==count: break
	return result

func recreation_option(profile_id: String,member_id: String,lot_id: String,target_id: Variant,household: bool=false) -> Dictionary:
	var result := {"ok":false,"message":"Choose a game table or stereo.","orders":[],"rows":[],"kind":"","revision":0}
	var family: Dictionary=state.families.get(profile_id,{})
	var selected:=_member(family,member_id) if not family.is_empty() else {}
	if selected.is_empty(): result.message="Choose one of your household's residents."; return result
	var lot: Dictionary=Storeys.view(state.lots.get(lot_id,{}),int(selected.get("level",0)))
	if lot.is_empty() or not target_id is String: return result
	var object:=_object(lot,target_id)
	if not object.get("kind") in Recreation.KINDS: return result
	result.kind=str(object.kind); result.revision=int(lot.revision)
	if lot.building or state.lots[family.home_lot].building: result.message="Finish construction before planning recreation."; return result
	var residents: Array=[selected]
	if household:
		for resident: Dictionary in family.members:
			if resident.id!=selected.id: residents.append(resident)
	for resident: Dictionary in residents:
		var row := {"id":str(resident.id),"name":str(resident.name),"action":"","detail":""}
		var own:=Leisure.activity(state,resident)
		var current: bool=not own.is_empty() and own.id==target_id
		var planned: bool=resident.queue.any(func(task): return task.get("type")=="interact" and task.get("target_kind","object")=="object" and task.get("target_id")==target_id)
		if resident.lot_id!=lot_id: row.detail="Away · Visit this lot first"
		elif int(resident.get("level",0))!=int(selected.get("level",0)): row.detail="Another floor · Use the stairs first"
		elif (current and not resident.task.get("automatic",false)) or planned: row.detail="Already chosen here" if current else "Already in their plan"
		elif int(resident.next_action)>=9007199254740000: row.detail="Action limit reached"
		elif current: row.action="choose"; row.detail="Choose current play · Keep place and time"
		elif resident.queue.size()>=MAX_QUEUE: row.detail="Plan full · Make space in Plan"
		elif not _can_reach_object(lot,_position(resident),object): row.detail="No path · Clear a route first"
		else:
			row.action="start"
			row.detail="After their plan" if not resident.queue.is_empty() or (not resident.task.is_empty() and not resident.task.get("automatic",false)) else "Join now"
			if Leisure.spaces(state,lot,object,resident).available.is_empty(): row.detail+=" · Wait for a place"
		if not str(row.action).is_empty(): result.orders.append(Recreation.stamp(resident,str(row.action)))
		result.rows.append(row)
	result.ok=not result.orders.is_empty()
	var lines: PackedStringArray=[]
	for row: Dictionary in result.rows: lines.append(str(row.name)+": "+str(row.detail))
	result.message="\n".join(lines)+"\nOnly your household here. Existing plans stay first; different arrival times may mean playing separately."
	return result

func _recreation(profile_id: String,command: Dictionary,lot: Dictionary) -> Dictionary:
	if not command.get("household") is bool: return _result(false,"Choose this resident or the household.")
	var option:=recreation_option(profile_id,str(command.member_id),str(lot.id),command.get("target_id"),command.household)
	if not option.ok: return _result(false,str(option.message))
	if not _integer(command.get("revision")) or int(command.revision)!=int(option.revision): return _result(false,"The furnishing changed. Choose from its current activities.")
	if not Recreation.matches(command.get("orders"),option.orders): return _result(false,"Household plans changed. Review who can join and choose again.")
	# Resolve ordinary individual actions in one staged world, then publish only
	# the requested household members. Visitors remain under their own control.
	var staged: RefCounted=get_script().new(); staged.state=state.duplicate(true)
	for order: Dictionary in option.orders:
		var resident: Dictionary=staged._member(staged.state.families[profile_id],str(order.member_id))
		if order.action=="choose":
			var chosen: Dictionary=resident.task.duplicate(true)
			chosen.erase("automatic"); chosen.erase("social_started"); chosen.leisure_chosen_at=float(chosen.elapsed)
			staged._queue_action(resident,chosen); resident.task=resident.queue.pop_back()
		else:
			var accepted: Dictionary=staged.apply_command(profile_id,{"type":"interact","member_id":order.member_id,"lot_id":lot.id,"target_id":command.target_id})
			if not accepted.ok: return _result(false,"Recreation changed: "+str(accepted.message))
	var names: PackedStringArray=[]
	for order: Dictionary in option.orders:
		var resident:=_member(state.families[profile_id],str(order.member_id))
		resident.merge(staged._member(staged.state.families[profile_id],str(order.member_id)),true); names.append(str(resident.name))
	return _result(true,("Music & dancing" if option.kind=="stereo" else "Tabletop game")+" chosen · "+", ".join(names)+". Existing plans stay first.")

func meal_call_option(profile_id: String,member_id: String,lot_id: String,table_id: Variant) -> Dictionary:
	var result := {"ok":false,"message":"Choose a dining table.","orders":[],"rows":[],"batch":0}
	var family: Dictionary=state.families.get(profile_id,{})
	var preferred := _member(family,member_id) if not family.is_empty() else {}
	if preferred.is_empty(): result.message="Choose one of your household's residents."; return result
	var lot: Dictionary=Storeys.view(state.lots.get(lot_id,{}),int(preferred.get("level",0)))
	if lot.is_empty() or not table_id is String: return result
	var table := _object(lot,table_id)
	if table.get("kind")!="dining_table": return result
	result.batch=int(table.meal.batch)
	if lot.building or state.lots[family.home_lot].building:
		result.message="Finish construction before calling your household to a meal."; return result
	var residents: Array=[preferred]
	for resident: Dictionary in family.members:
		if resident.id!=member_id: residents.append(resident)
	var portions := Meals.available(state,lot,table)
	for resident: Dictionary in residents:
		var row := {"id":str(resident.id),"name":str(resident.name),"action":"","detail":""}
		if resident.lot_id!=lot_id: row.detail="Away · Visit this lot first"
		elif int(resident.get("level",0))!=int(preferred.get("level",0)): row.detail="Another floor · Use the stairs first"
		else:
			var choice := meal_option(profile_id,str(resident.id),lot_id,table_id,"choose")
			if choice.ok: row.action="choose"; row.detail="Choose current meal · Keep portion and time"
			else:
				var option := meal_option(profile_id,str(resident.id),lot_id,table_id,"eat")
				if option.ok and portions>0:
					row.action="eat"; portions-=1
					row.detail="After their plan · Reserve one portion" if not resident.queue.is_empty() or (not resident.task.is_empty() and not resident.task.get("automatic",false)) else "Join now · Reserve one portion"
				elif option.ok: row.detail="No unreserved portion left"
				else: row.detail=str(option.message)
		if not str(row.action).is_empty():
			result.orders.append({"member_id":str(resident.id),"action":str(row.action),"next_action":int(resident.next_action),"activity_id":str(resident.task.get("id","")),"queue":resident.queue.map(func(task): return str(task.id))})
		result.rows.append(row)
	result.ok=not result.orders.is_empty()
	var lines: PackedStringArray=[]
	for row: Dictionary in result.rows: lines.append(str(row.name)+": "+str(row.detail))
	result.message="\n".join(lines)+"\nOnly your household here. Existing plans stay first; arriving at different times may mean eating separately."
	return result

func _call_meal(profile_id: String,command: Dictionary) -> Dictionary:
	if not command.get("lot_id") is String or not command.get("target_id") is String: return _result(false,"Choose a dining table.")
	var option := meal_call_option(profile_id,str(command.member_id),str(command.lot_id),command.target_id)
	if not option.ok: return _result(false,str(option.message))
	if not _integer(command.get("batch")) or int(command.batch)!=int(option.batch): return _result(false,"The meal changed. Check the household call again.")
	if not Meals.matches_call(command.get("orders"),option.orders): return _result(false,"Household plans or portions changed. Check who can join and call again.")
	# Stage ordinary single-resident orders together. Publish no partial call if
	# any order fails, and preserve the identities of live member dictionaries.
	var staged: RefCounted=get_script().new(); staged.state=state.duplicate(true)
	for order: Dictionary in option.orders:
		var intent := {"type":"meal","member_id":order.member_id,"lot_id":command.lot_id,"target_id":command.target_id,"action":order.action,"recipe":"","batch":option.batch}
		if order.action=="choose": intent.activity_id=order.activity_id
		var accepted: Dictionary=staged.apply_command(profile_id,intent)
		if not accepted.ok: return _result(false,"The household call changed: "+str(accepted.message))
	var names: PackedStringArray=[]
	for order: Dictionary in option.orders:
		var member := _member(state.families[profile_id],str(order.member_id))
		member.merge(_member(staged.state.families[profile_id],str(order.member_id)),true); names.append(str(member.name))
	return _result(true,"Called to meal · "+", ".join(names)+". Existing plans stay first.")

func meal_option(profile_id: String,member_id: String,lot_id: String,table_id: Variant,action: Variant,recipe: Variant="") -> Dictionary:
	var family: Dictionary=state.families.get(profile_id,{})
	var member := _member(family,member_id) if not family.is_empty() else {}
	if member.is_empty(): return _result(false,"Choose one of your own residents.")
	var lot: Dictionary=Storeys.view(state.lots.get(lot_id,{}),int(member.get("level",0)))
	if lot.is_empty(): return _result(false,"Choose a dining table.")
	if lot.building or state.lots[family.home_lot].building: return _result(false,"Finish construction before preparing or sharing a meal.")
	if member.lot_id!=lot_id: return _result(false,"Visit this home with "+str(member.name)+" to share a meal.")
	if not table_id is String or not action is String or not action in ["prepare","eat","clear","choose"] or not recipe is String: return _result(false,"Choose a meal activity.")
	var table := _object(lot,table_id)
	if table.get("kind")!="dining_table": return _result(false,"Choose a dining table.")
	var meal: Dictionary=table.meal
	var plans := Meals.plans(state,lot_id,table_id)
	if action in ["prepare","clear"]:
		if lot.owner!=profile_id: return _result(false,"Only this household can prepare or clear its meals. Visitors can eat served food.")
		if int(meal.batch)>=Meals.MAX_BATCH: return _result(false,"This table has reached its meal limit.")
		if not plans.is_empty(): return _result(false,"A meal is already in "+str(plans[0].member.name)+"'s plan. Let them finish first.")
	if action=="clear":
		if not recipe.is_empty() or meal.recipe=="": return _result(false,"There are no leftovers to clear.")
		return {"ok":true,"message":"Remove remaining portions. No refund.","batch":int(meal.batch)}
	if action=="choose":
		if not recipe.is_empty() or not Meals.choosing(member,table) or not _meal_task_option(member,lot,member.task).ok: return _result(false,"Choose a current automatic meal for this resident.")
		return {"ok":true,"batch":int(meal.batch),"activity_id":str(member.task.id),"message":"Keep your serving and remaining time. Chosen company starts now."}
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The action queue is full (8 actions).")
	var spaces := Leisure.spaces(state,lot,table,member)
	if spaces.capacity==0: return _result(false,"No path to the dining table. Leave a clear place around it.")
	var result := {"ok":true,"batch":int(meal.batch),"target_id":table_id,"recipe":recipe,"message":""}
	if action=="prepare":
		if not Meals.RECIPES.has(recipe): return _result(false,"Choose a recipe from the dining table.")
		if int(meal.servings)>0: return _result(false,"Share the remaining portions or clear them before making a fresh meal.")
		var definition: Dictionary=Meals.RECIPES[recipe]
		if int(lot.funds)<int(definition.cost): return _result(false,"Need §%d more for these ingredients." % (int(definition.cost)-int(lot.funds)))
		var produce:=Pantry.can_cook(state,profile_id,recipe)
		if not produce.ok: return produce
		var best := {}; var score := INF
		for fridge: Dictionary in lot.objects:
			if fridge.kind!="fridge": continue
			var cells := _interaction_cells(lot,fridge); var path := _path(lot,_position(member),cells)
			if path.is_empty() and not cells.has(_position(member)): continue
			var start := _position(member) if path.is_empty() else Vector2i(int(path[-1][0]),int(path[-1][1]))
			if not _interaction_cells(lot,table).has(start) and _path(lot,start,_interaction_cells(lot,table)).is_empty(): continue
			var distance := float(path.size())+(1000.0 if not _object_user(lot_id,fridge,member_id).is_empty() else 0.0)
			if distance<score: score=distance; best=fridge
		if best.is_empty(): return _result(false,"A reachable kitchen fridge and dining table are needed to prepare a meal.")
		result.target_id=str(best.id); result.message="Four portions · §%d when served · Uses the kitchen fridge" % int(definition.cost)
		if not Pantry.ingredients(recipe).is_empty(): result.message="Four portions · "+str(produce.message)+" · Uses the kitchen fridge"
	else:
		if not recipe.is_empty(): return _result(false,"Choose the meal currently served on this table.")
		for plan: Dictionary in plans:
			if plan.member.id==member_id: return _result(false,"Already in "+str(member.name)+"'s plan.")
		if meal.recipe=="" or int(meal.servings)==0: return _result(false,"Prepare a meal before choosing a portion.")
		if Meals.available(state,lot,table)<=0: return _result(false,"The remaining portions are reserved in other residents' plans.")
		result.recipe=str(meal.recipe); result.message="One portion reserved · Hunger + comfort · Social when eating together"
		if spaces.available.is_empty(): result.message=Leisure.waiting_reason(spaces)+" Your portion will wait."
	return result

func _meal_task_option(member: Dictionary,lot: Dictionary,task: Dictionary) -> Dictionary:
	if task.get("automatic",false) and not Meals.can_autoeat(state,lot,member): return _result(false,"Automatic meals are for your own household while you are here.")
	var table := _object(lot,str(task.get("meal_table","")))
	if table.get("kind")!="dining_table" or int(table.meal.batch)!=int(task.meal_batch): return _result(false,"The meal or dining table changed.")
	if task.meal_action=="prepare":
		if not state.families.get(lot.owner,{}).get("members",[]).has(member): return _result(false,"Prepare meals at your own home.")
		if _object(lot,str(task.target_id)).get("kind")!="fridge": return _result(false,"The kitchen fridge is no longer here.")
		if int(table.meal.servings)>0 or not Meals.plans(state,str(lot.id),str(table.id),str(task.id)).is_empty(): return _result(false,"The table is already in use for a meal.")
		if int(lot.funds)<int(Meals.RECIPES[task.meal_recipe].cost): return _result(false,"The household no longer has enough for the ingredients.")
		var produce:=Pantry.can_cook(state,str(lot.owner),str(task.meal_recipe),str(task.id))
		if not produce.ok: return produce
	else:
		if table.meal.recipe!=task.meal_recipe: return _result(false,"The meal changed before eating.")
		if not task.get("meal_taken",false) and Meals.available(state,lot,table,str(task.id))<=0: return _result(false,"That portion is no longer available.")
	return {"ok":true,"table":table}

func _tick_meal(member: Dictionary,lot: Dictionary,task: Dictionary,delta: float) -> void:
	var option := _meal_task_option(member,lot,task)
	if not option.ok: _end_task(member,"failed",str(option.message)); return
	var table: Dictionary=option.table
	var furnishing: Dictionary=_object(lot,str(task.target_id)) if task.meal_action=="prepare" and task.meal_phase=="prepare" else table
	if not _interaction_cells(lot,furnishing).has(_position(member)):
		_end_task(member,"failed","The place for this meal is no longer reachable."); return
	if task.meal_action=="prepare":
		var serving: bool=task.meal_phase=="serve"
		member.action="Serving "+str(Meals.RECIPES[task.meal_recipe].name).to_lower() if serving else Meals.label("prepare",str(task.meal_recipe))
		var elapsed := minf(delta,float(task.remaining)-(0.0 if serving else Meals.SERVE_TIME))
		task.elapsed=float(task.elapsed)+elapsed; task.remaining-=elapsed
		if not serving and float(task.remaining)<=Meals.SERVE_TIME+0.000001:
			var spaces := Leisure.spaces(state,lot,table,member)
			if spaces.available.is_empty(): member.action="Waiting for a place · "+Leisure.waiting_reason(spaces); return
			var route := _path(lot,_position(member),spaces.available)
			if route.is_empty() and not spaces.available.has(_position(member)): _end_task(member,"failed","No path to serve the meal."); return
			task.path=route; task.meal_phase="serve"; task.label="Carry meal to the table"; member.walk_clock=0.0
			return
		if float(task.remaining)>0.000001: return
		var recipe: String=task.meal_recipe; var cost: int=Meals.RECIPES[recipe].cost
		if not _adjust_funds(str(lot.id),-cost): _end_task(member,"failed","The household budget changed before serving."); return
		Pantry.consume(state.families[lot.owner],recipe)
		table.meal={"recipe":recipe,"servings":Meals.PORTIONS,"batch":int(table.meal.batch)+1,"cook":str(member.id),"cook_name":str(member.name),"day":int(state.day)}
		_record_hobby(member,"fridge"); _finish_wish(member,task,"meal_prepare")
		_event(str(member.name)+" served "+str(Meals.RECIPES[recipe].name).to_lower()+" · Four portions ready.")
		_end_task(member,"done","Four portions served · "+(Pantry.cost_label(recipe)+" from the pantry." if not Pantry.ingredients(recipe).is_empty() else "Ingredients §%d." % cost))
	else:
		if not task.get("meal_taken",false): table.meal.servings-=1; task.meal_taken=true
		if not task.has("social_started"): task.social_started=int(state.tick)
		var elapsed := minf(delta,float(task.remaining)); task.elapsed=float(task.elapsed)+elapsed; task.remaining-=elapsed
		member.action="Eating "+str(Meals.RECIPES[task.meal_recipe].name).to_lower()
		for need: String in ["hunger","comfort"]: member.needs[need]=minf(100.0,float(member.needs[need])+float(Meals.RECIPES[task.meal_recipe][need])*elapsed)
		if Leisure.players(state,str(lot.id),str(table.id)).size()>1:
			member.needs.social=minf(100.0,float(member.needs.social)+4.0*elapsed); member.action="Eating together"
		if float(task.remaining)>0.000001: return
		_finish_wish(member,task,"fridge"); _end_task(member,"done","Meal finished · Hunger and comfort restored.")
		var courtesy := Courtesy.destination(state,lot,member,table,_path)
		if not courtesy.is_empty():
			_queue_action(member,{"type":"move","x":courtesy.cell.x,"y":courtesy.cell.y,"automatic":true,"courtesy":true,"title":"Making room for "+str(courtesy.name)})
			_start_next(member,lot); member.action=str(member.task.title)

func admire_option(profile_id: String,member_id: String,lot_id: String,target_id: Variant) -> Dictionary:
	var family: Dictionary=state.families.get(profile_id,{})
	var member := _member(family,member_id) if not family.is_empty() else {}
	if member.is_empty(): return _result(false,"Choose one of your own residents.")
	var lot: Dictionary=Storeys.view(state.lots.get(lot_id,{}),int(member.get("level",0)))
	if lot.is_empty(): return _result(false,"Choose a painting on a household wall.")
	if state.lots[family.home_lot].building or lot.building: return _result(false,"Finish construction before admiring artwork.")
	if member.lot_id!=lot_id: return _result(false,"Visit this home with "+str(member.name)+" to admire its paintings.")
	if not target_id is String: return _result(false,"Choose a painting on the wall.")
	var entry: Dictionary=lot.get("artworks",{}).get(target_id,{})
	if entry.is_empty() or int(entry.x)<0: return _result(false,"This painting is no longer on the wall.")
	var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
	for task: Dictionary in tasks:
		if task.get("target_kind")=="art" and task.get("target_id")==target_id: return _result(false,"Already in "+str(member.name)+"'s plan.")
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The action queue is full (8 actions).")
	var cells := ArtAdmiration.cells(lot,entry,_walkable)
	if not cells.has(_position(member)) and _path(lot,_position(member),cells).is_empty(): return _result(false,"No path to view this painting. Leave a clear space in front of it.")
	return {"ok":true,"message":"18 game minutes · Restores fun and comfort","x":int(entry.x),"y":int(entry.y),"label":ArtAdmiration.title(entry)}

func painting_option(profile_id: String,member_id: String,lot_id: String,target_id: Variant,action: Variant,subject: Variant="") -> Dictionary:
	var family: Dictionary=state.families.get(profile_id,{})
	var member := _member(family,member_id) if not family.is_empty() else {}
	if member.is_empty(): return _result(false,"Select a resident from your household.")
	var lot: Dictionary=Storeys.view(state.lots.get(lot_id,{}),int(member.get("level",0)))
	if lot.is_empty(): return _result(false,"That easel is no longer here.")
	if member.lot_id!=lot_id: return _result(false,"Go to this lot before painting.")
	if lot.building or state.lots[family.home_lot].building: return _result(false,"Finish construction before painting.")
	if not target_id is String: return _result(false,"Choose an easel.")
	var object := _object(lot,target_id)
	if object.get("kind")!="easel": return _result(false,"Choose an easel.")
	var option := Paintings.inspect(object.painting,action,subject,lot.owner==profile_id)
	if not option.ok: return option
	for household: Dictionary in state.families.values():
		for resident: Dictionary in household.members:
			if resident.lot_id!=lot_id: continue
			var tasks: Array=resident.queue.duplicate(); tasks.append(resident.task)
			for task: Dictionary in tasks:
				if task.get("target_id")==target_id and task.has("paint_action"): return _result(false,"Already in "+str(resident.name)+"'s plan.")
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The action queue is full (8 actions).")
	if not _can_reach_object(lot,_position(member),object): return _result(false,"There is no path to this easel.")
	return option

func _painting_task_option(member: Dictionary,lot: Dictionary,object: Dictionary,task: Dictionary) -> Dictionary:
	if object.get("kind")!="easel" or not Paintings.valid_task(task): return _result(false,"This painting activity is no longer available.")
	if int(task.paint_revision)!=int(object.painting.revision): return _result(false,"The canvas changed before this activity.")
	return Paintings.inspect(object.painting,task.paint_action,task.subject,state.families.get(lot.owner,{}).get("members",[]).has(member))

func _tick_painting(member: Dictionary,lot: Dictionary,object: Dictionary,task: Dictionary,delta: float) -> void:
	var option := _painting_task_option(member,lot,object,task)
	if not option.ok:
		_end_task(member,"failed",str(option.message),str(option.message)); return
	var picture: Dictionary=object.painting
	member.action=str(option.label)
	if task.paint_action=="sell":
		task.remaining-=delta
		if float(task.remaining)>0.000001: return
		if not _adjust_funds(str(lot.id),Paintings.VALUE):
			_end_task(member,"failed","The household budget cannot receive this sale."); return
		var title: String=Paintings.SUBJECTS[picture.subject]
		var revision: int=int(picture.revision)+1
		object.painting=Paintings.create(); object.painting.revision=revision
		_event(str(member.name)+" sold “"+title+"” for §%d." % Paintings.VALUE)
		_end_task(member,"done","Painting sold for §%d. The easel has a fresh canvas." % Paintings.VALUE)
		return
	if task.paint_action=="start":
		picture.subject=str(task.subject); picture.revision=int(picture.revision)+1
		task.paint_action="resume"; task.subject=""; task.paint_revision=int(picture.revision)
	Paintings.contribute(picture,member,minf(delta,Paintings.DURATION-float(picture.progress)))
	picture.progress=minf(Paintings.DURATION,float(picture.progress)+delta)
	task.remaining=Paintings.DURATION-float(picture.progress)
	var rates := personal_activity_rates(member,"easel")
	for need: String in rates:
		member.needs[need]=minf(100.0,float(member.needs[need])+float(rates[need])*delta)
	if not Paintings.finished(picture): return
	picture.day=int(state.day); picture.revision=int(picture.revision)+1
	var title: String=Paintings.SUBJECTS[picture.subject]
	member.wishes.journal.push_front({"day":int(state.day),"text":"Finished “"+title+"”. "+Paintings.credit(picture)+"."})
	if member.wishes.journal.size()>Wishes.MAX_JOURNAL: member.wishes.journal.resize(Wishes.MAX_JOURNAL)
	var household: Dictionary=state.families.get(lot.owner,{})
	if household.get("online",false):
		for artist: Dictionary in household.members:
			if Paintings.work_by(picture,str(artist.id))+0.000001>=MIN_ACTIVITY_TIME: _record_hobby(artist,"easel")
	_event(str(member.name)+" finished “"+title+"”. Keep it, hang it, or sell it.")
	_end_task(member,"done","Finished painting. Keep it on the easel, hang it, or choose to sell it.","Admiring the finished painting")

func garden_option(profile_id: String,member_id: String,lot_id: String,target_id: Variant,action: Variant,crop: Variant="") -> Dictionary:
	var family: Dictionary=state.families.get(profile_id,{})
	if family.is_empty(): return _result(false,"Join a household first.")
	var member := _member(family,member_id)
	if member.is_empty(): return _result(false,"Select a resident from your household.")
	var lot: Dictionary=Storeys.view(state.lots.get(lot_id,{}),int(member.get("level",0)))
	if lot.is_empty(): return _result(false,"That garden is no longer here.")
	if member.lot_id!=lot_id: return _result(false,"Visit this lot before gardening.")
	if lot.building or state.lots[family.home_lot].building: return _result(false,"Finish construction before gardening.")
	if not target_id is String: return _result(false,"Choose a garden bed.")
	var object := _object(lot,target_id)
	if object.get("kind")!="garden_bed": return _result(false,"Choose a garden bed.")
	var option := Gardens.inspect(object.garden,action,crop,lot.owner==profile_id,int(lot.funds))
	if not option.ok: return option
	if action=="keep":
		var room:=Pantry.can_keep(state,profile_id,str(object.garden.crop))
		if not room.ok: return room
		option.message=room.message
	for household: Dictionary in state.families.values():
		for resident: Dictionary in household.members:
			if resident.lot_id!=lot_id: continue
			var tasks: Array=resident.queue.duplicate(); tasks.append(resident.task)
			for task: Dictionary in tasks:
				if task.get("target_id")==target_id and task.has("garden_action"):
					return _result(false,"Already in "+str(resident.name)+"'s plan.")
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The action queue is full (8 actions).")
	if not _can_reach_object(lot,_position(member),object): return _result(false,"There is no path to this garden bed.")
	option.revision=int(object.garden.revision)
	return option

func _garden_task_option(member: Dictionary,lot: Dictionary,object: Dictionary,task: Dictionary) -> Dictionary:
	if object.get("kind")!="garden_bed" or not Gardens.valid_task(task): return _result(false,"This garden activity is no longer available.")
	if int(task.garden_revision)!=int(object.garden.revision): return _result(false,"The garden changed before this activity.")
	var owner: bool=state.families.get(lot.owner,{}).get("members",[]).has(member)
	var option:=Gardens.inspect(object.garden,task.garden_action,task.crop,owner,int(lot.funds))
	if option.ok and task.garden_action=="keep":
		var room:=Pantry.can_keep(state,str(lot.owner),str(object.garden.crop),str(task.id))
		if not room.ok: return room
		option.message=room.message
	return option

func _tick_garden(member: Dictionary,lot: Dictionary,object: Dictionary,task: Dictionary,delta: float) -> void:
	var option := _garden_task_option(member,lot,object,task)
	if not option.ok:
		_end_task(member,"failed",str(option.message),str(option.message)); return
	member.action=str(option.label)
	var rates := personal_activity_rates(member,"plant")
	for need: String in rates:
		member.needs[need]=minf(100.0,float(member.needs[need])+float(rates[need])*delta)
	task.remaining-=delta
	if float(task.remaining)>0.000001: return
	if not _adjust_funds(str(lot.id),-int(option.cost)):
		_end_task(member,"failed","The household budget changed.","The household budget changed"); return
	var crop: String=object.garden.crop
	if task.garden_action=="keep": Pantry.keep(state.families[lot.owner],crop)
	Gardens.apply(object.garden,str(task.garden_action),str(task.crop))
	_finish_hobby(member,task,"plant"); _finish_wish(member,task,"plant")
	_event(str(member.name)+" finished: "+str(option.label).to_lower()+(" · §%d earned." % -int(option.cost) if int(option.cost)<0 else "."))
	_end_task(member,"done","Kept %d %s in the pantry." % [Gardens.HARVEST_COUNT,str(Gardens.CROPS[crop].name).to_lower()] if task.garden_action=="keep" else "Harvest sold for §%d." % -int(option.cost) if int(option.cost)<0 else "Seeds planted." if task.garden_action=="plant" else "Garden watered.","Garden tended")

func move_option(profile_id: String,member_id: String,lot_id: String,goal: Vector2i) -> Dictionary:
	# Shared, read-only reachability for ground previews and accepted commands.
	if not state.get("families",{}).has(profile_id): return _result(false,"Join a household first.")
	if not state.get("lots",{}).has(lot_id): return _result(false,"That lot does not exist.")
	var family: Dictionary=state.families[profile_id]
	var member := _member(family,member_id)
	if member.is_empty(): return _result(false,"You can only direct your own family.")
	if state.lots[family.home_lot].building: return _result(false,"Finish construction before directing your family.")
	if member.lot_id!=lot_id: return _result(false,"Visit this lot before walking here.")
	var lot: Dictionary=_member_lot(member)
	if lot.building: return _result(false,"This lot is under construction.")
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The action queue is full (8 actions).")
	if not _inside(goal): return _result(false,"Choose a tile inside the lot.")
	if not _walkable(lot,goal): return _result(false,"That tile is occupied.")
	var route := _path(lot,_position(member),[goal])
	if route.is_empty() and _position(member)!=goal: return _result(false,"There is no path to that tile.")
	var ahead: int=member.queue.size()+(0 if member.task.is_empty() or member.task.get("automatic",false) else 1)
	return {"ok":true,"message":"Walk here" if ahead==0 else "Queue walk · %d %s first" % [ahead,"activity" if ahead==1 else "activities"],"path":route,"ahead":ahead,"cell":goal,"here":_position(member)==goal}

func _build(lot: Dictionary, command: Dictionary) -> Dictionary:
	if command.type=="landscape":
		var plan := Landscaping.inspect(lot,command)
		if not plan.ok: return plan
		Landscaping.apply(lot,plan)
		return _result(true,str(plan.message)+". Undo restores the whole stroke.")
	if command.type in ["clear_lot","erase_area"]:
		var area := BuildArea.bounds(command) if command.type=="erase_area" else Rect2i(0,0,16,16)
		if not area.has_area(): return _result(false,"Keep both corners inside the lot.")
		var plan := ClearLot.inspect(lot,area)
		if not plan.ok: return plan
		if not ClearLot.matches(command,plan): return _result(false,"The clearing quote changed. Review the selection again.")
		ClearLot.apply(lot,plan)
		var target := "Area" if command.type=="erase_area" else "Lot"
		var message := "%s cleared · §%d refunded." % [target,plan.refund]
		var stored: int=plan.stored+plan.paintings.size()
		if stored==1: message+=" One painting moved to the collection."
		elif stored>1: message+=" %d paintings moved to the collection." % stored
		return _result(true,message+" Undo restores the whole edit.")
	if command.type in ["art_hang","art_store","art_return"]:
		var plan := WallArt.inspect(lot,command)
		if not plan.ok: return plan
		WallArt.apply(lot,plan)
		return _result(true,str(plan.message)+". Undo restores the whole transfer.")
	if command.type=="recolor":
		var plan := FurnitureColors.inspect(lot,command)
		if not plan.ok: return plan
		FurnitureColors.set_style(_object(lot,str(command.object_id)),str(command.style))
		lot.revision+=1
		return _result(true,str(Catalog.ITEMS[plan.kind].name)+" recolored "+str(FurnitureColors.PALETTE[plan.style].name)+". No charge. Undo restores the previous color.")
	if not _valid_coord(command.get("x")) or not _valid_coord(command.get("y")):
		return _result(false, "Choose a tile inside the lot.")
	var cell := Vector2i(int(command.x), int(command.y))
	if command.type=="set_window":
		var plan := Windows.inspect(lot,command)
		if not plan.ok: return plan
		Windows.apply(lot,plan)
		return _result(true,str(plan.message)+". Undo restores this edit.")
	if command.type == "erase":
		if Landscaping.pooled(lot,cell.x,cell.y):
			lot.landscape.pools.erase([cell.x,cell.y]); lot.funds+=54; lot.revision+=1
			return _result(true,"Pool tile filled · §54 refunded.")
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
				lot.get("diagonal_walls",{}).erase(Landscaping.key(cell.x,cell.y))
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
	if command.type in ["copy_room","place_blueprint"]:
		var plan: Dictionary
		if command.type=="place_blueprint":
			var board: Dictionary=state.families[lot.owner].room_library
			if not RoomLibrary.revision_matches(board,command.get("library_revision")): return _result(false,"Saved rooms changed. Choose from the current library.")
			if not command.get("blueprint_id") is String: return _result(false,"Choose a saved room.")
			var entry:=RoomLibrary.find(board,command.blueprint_id)
			if entry.is_empty(): return _result(false,"This room design is no longer saved.")
			plan=RoomCopy.inspect_source(lot,command,residents,RoomLibrary.source(entry.layout))
		else: plan=RoomCopy.inspect(lot,command,residents)
		if not plan.ok: return plan
		if int(state.next_object)+plan.objects.size()>9007199254740991: return _result(false,"The furnishing identifier limit has been reached.")
		RoomCopy.apply_surfaces(lot,plan)
		for object: Dictionary in plan.objects:
			var copied := _new_object(str(object.kind),int(object.x),int(object.y),int(object.rotation))
			FurnitureColors.set_style(copied,FurnitureColors.at(object)); lot.objects.append(copied)
		lot.funds-=int(plan.cost); lot.revision+=1
		return _result(true,"Room copied for §%d. One Undo restores the whole placement." % int(plan.cost))
	if command.type=="place_area":
		var plan := BuildArea.inspect(lot,command,residents)
		if not plan.ok: return plan
		BuildArea.apply(lot,plan)
		return _result(true,"Built %s. Undo restores the whole area." % str(plan.message))
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
	for lot: Dictionary in state.lots.values():
		if lot.building: continue
		for level in range(Storeys.MAX_LEVEL+1):
			for object: Dictionary in Storeys.view(lot,level).objects:
				if object.kind=="garden_bed": Gardens.grow(object.garden,delta)
	var company_holds:=Leisure.company_windows(state,delta)
	_tick_shared_friendships(delta)
	for family: Dictionary in state.families.values():
		if HomeNews.away(family): family.home_news.minutes+=delta*MINUTES_PER_SECOND
		if state.lots[family.home_lot].building:
			continue
		for member: Dictionary in family.members:
			var lot: Dictionary = _member_lot(member)
			if Character.is_baby(member):
				member.action="Resting in the bassinet"
				continue
			for need: String in NEEDS:
				var floor_value := 0.0 if family.online else 55.0
				member.needs[need] = clampf(float(member.needs[need]) - float(DECAY[need]) * delta, floor_value, 100.0)
			_tick_member(member, lot, delta,bool(company_holds.get(str(member.id),{}).get("hold",false)))

func _tick_member(member: Dictionary, lot: Dictionary, delta: float,keep_company: bool=false) -> void:
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
	if task.get("target_kind")=="art" and not ArtAdmiration.current(lot,task):
		_end_task(member,"failed","The painting moved or left this home."); return
	if not task.path.is_empty():
		member.action = str(task.title) if task.get("courtesy",false) else "Walking" + (" · " + str(task.get("label", "")) if task.type == "interact" else "")
		member.walk_clock += delta
		while member.walk_clock+0.00000001>=0.22 and not task.path.is_empty():
			member.walk_clock=maxf(0.0,float(member.walk_clock)-0.22)
			var next: Array = task.path.pop_front()
			if task.get("courtesy",false) and Courtesy.traffic(state,lot,str(member.id)).has(Vector2i(int(next[0]),int(next[1]))):
				_end_task(member,"cancelled","Someone needs the space."); member.walk_clock=0.0; return
			if not _walkable(lot, Vector2i(int(next[0]), int(next[1]))):
				_clear_member(member, "Path changed", "The walking path became blocked; plan cleared.", "failed")
				return
			member.x = int(next[0])
			member.y = int(next[1])
		return
	if task.type == "move":
		if task.has("stairs_to"):
			var root: Dictionary=state.lots[member.lot_id]
			var lower := mini(int(member.get("level",0)),int(task.stairs_to))
			var stair := _object(Storeys.view(root,lower),str(task.stairs_id))
			if stair.get("kind")!="stairs": _end_task(member,"failed","The staircase changed."); return
			var arrival := Storeys.landing(stair,int(task.stairs_to)>lower)
			if not _walkable(Storeys.view(root,int(task.stairs_to)),arrival): _end_task(member,"failed","The stair landing is blocked."); return
			member.level=int(task.stairs_to); member.x=arrival.x; member.y=arrival.y
		_end_task(member,"done","Arrived.")
		return
	if task.get("target_kind", "object") == "member":
		var neighbor := _find_member(str(task.target_id))
		if neighbor.is_empty() or neighbor.lot_id != member.lot_id or int(neighbor.get("level",0))!=int(member.get("level",0)) or _position(member).distance_to(_position(neighbor)) > 2.0:
			_end_task(member,"failed","The other resident moved away.","They moved away")
			return
		if _chat_busy(neighbor,member):
			if float(task.get("elapsed",0))>0:
				_end_task(member,"failed","The other resident started something else.","They have something to do")
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
			_end_task(member,"done","Conversation finished.")
		return
	if task.get("target_kind")=="art":
		var entry: Dictionary=lot.artworks[task.target_id]
		if not ArtAdmiration.cells(lot,entry,_walkable).has(_position(member)):
			_end_task(member,"failed","The viewing spot is no longer available."); return
		var enjoyed := minf(delta,float(task.remaining))
		task.elapsed=float(task.get("elapsed",0.0))+enjoyed; task.remaining-=enjoyed
		member.action="Admiring a painting"
		for need: String in ArtAdmiration.RATES: member.needs[need]=minf(100.0,float(member.needs[need])+float(ArtAdmiration.RATES[need])*enjoyed)
		if float(task.remaining)<=0.000001: _end_task(member,"done","Enjoyed the painting · Fun and comfort restored.")
		return
	if task.has("meal_action"):
		_tick_meal(member,lot,task,delta); return
	task.elapsed = float(task.get("elapsed",0.0)) + delta
	var object := _object(lot, str(task.get("target_id", "")))
	if object.is_empty():
		_end_task(member,"failed","The furnishing is no longer here.")
		return
	if str(Catalog.ITEMS[object.kind].need).is_empty():
		_end_task(member,"done","Enjoyed the furnishing."); return
	if object.kind=="dining_table":
		_end_task(member,"failed","Choose a portion from the dining table."); return
	if object.kind=="easel" or task.has("paint_action"):
		_tick_painting(member,lot,object,task,delta); return
	if object.kind=="garden_bed" or task.has("garden_action"):
		_tick_garden(member,lot,object,task,delta); return
	if Leisure.KINDS.has(object.kind) and not task.has("social_started"): task.social_started=int(state.tick)
	var definition: Dictionary = Catalog.ITEMS[object.kind]
	member.action = ACTION_NAMES.get(object.kind, "Enjoying home")
	var need: String = definition.need
	var rates := personal_activity_rates(member,str(object.kind))
	for restored: String in rates:
		member.needs[restored]=minf(100.0,float(member.needs[restored])+float(rates[restored])*delta)
	if Leisure.KINDS.has(object.kind) and Leisure.players(state,str(lot.id),str(object.id)).size()>1:
		member.needs.social=minf(100.0,float(member.needs.social)+float(Leisure.KINDS[object.kind].social_rate)*delta)
		member.action=str(Leisure.KINDS[object.kind].together)
	if object.kind == "table":
		for family: Dictionary in state.families.values():
			for companion: Dictionary in family.members:
				if companion.id != member.id and companion.lot_id == member.lot_id and _position(companion).distance_to(_position(member)) <= 4.0:
					companion.needs.social = minf(100.0, float(companion.needs.social) + 2.0 * delta)
	task.remaining -= delta
	var minimum_time := 0.0 if task.get("automatic",false) else MIN_ACTIVITY_TIME
	if task.remaining <= 0.0 or (float(member.needs[need]) >= 99.0 and Leisure.chosen_time(task)>=minimum_time and not keep_company):
		_finish_wish(member,task,str(object.kind))
		_finish_hobby(member,task,str(object.kind))
		_end_task(member,"done",str(need).capitalize()+" fulfilled." if float(task.remaining)>0.0 else "Activity finished.")
		var courtesy := Courtesy.destination(state,lot,member,object,_path)
		if not courtesy.is_empty():
			_queue_action(member,{"type":"move","x":courtesy.cell.x,"y":courtesy.cell.y,"automatic":true,"courtesy":true,"title":"Making room for "+str(courtesy.name)})
			_start_next(member,lot)
			member.action=str(member.task.title)


func task_activity(task: Dictionary, lot_id: String) -> String:
	if task.has("meal_action"): return "dining_table" if task.meal_action=="eat" else ""
	if task.get("paint_action")=="sell": return ""
	if task.get("type")!="interact": return ""
	if task.get("target_kind")=="member": return "chat"
	if task.get("target_kind")=="art": return "admire_art"
	for level in range(Storeys.MAX_LEVEL+1):
		var object := _object(Storeys.view(state.lots[lot_id],level),str(task.get("target_id","")))
		if not object.is_empty(): return str(object.kind)
	return ""

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
	if kind in ["bed","sofa","easel"]: rates.comfort=float(rates.get("comfort",0.0))+2.0
	return rates

func care_status(member: Dictionary, need: String) -> String:
	if need=="social" and Leisure.is_shared(state,member): return "In progress"
	if Wellbeing.restores(task_activity(member.task,str(member.lot_id)),need): return "In progress"
	for task: Dictionary in member.queue:
		if Wellbeing.restores(task_activity(task,str(member.lot_id)),need): return "In your plan"
	return ""

func tabletop_option(member: Dictionary, companion_id: String) -> Dictionary:
	return leisure_option(member,companion_id,"game_table")

func leisure_option(member: Dictionary, companion_id: String, kind: String="") -> Dictionary:
	var companion := _find_member(companion_id)
	if companion.is_empty() or companion.id==member.id: return {}
	var object := Leisure.activity(state,companion,kind)
	if object.is_empty(): return {}
	var definition: Dictionary=Leisure.KINDS[object.kind]
	var noun: String=definition.noun; var place: String=definition.place
	var spaces := Leisure.spaces(state,state.lots[companion.lot_id],object,member)
	var option := {"available":false,"kind":str(object.kind),"label":"Join "+noun,"detail":"Adds a "+noun+" after your planned activities. Companions may finish before you arrive. Friendship needs 12 game minutes of chosen play by both residents.","summary":str(definition.title)+" · "+Leisure.summary(spaces),"target_id":str(object.id),"activity_id":str(companion.task.id),"lot_id":str(companion.lot_id)}
	if member.lot_id!=companion.lot_id:
		option.label="Visit to join"; option.detail="Visit this home, then choose Join "+noun+"."
		return option
	for family: Dictionary in state.families.values():
		if state.lots[family.home_lot].building and not _member(family,str(member.id)).is_empty():
			option.label="Under construction"; option.detail="Finish construction before directing your family."
			return option
	var tasks: Array=member.queue.duplicate()
	if not member.task.is_empty(): tasks.push_front(member.task)
	for task: Dictionary in tasks:
		if task==member.task and task.get("automatic",false):
			if object.kind!="dining_table": continue
			if Meals.choosing(member,object) and _meal_task_option(member,_member_lot(member),task).ok:
				option.available=true; option.own_activity_id=str(task.id)
				option.detail="Choose your current meal as shared time. Keep the same serving and remaining time; chosen company starts now."
				return option
		if task.get("type")=="interact" and task.get("target_kind","object")=="object" and task.get("target_id")==object.id:
			option.label="In your plan"; option.detail="This "+noun+" is already in your plan."
			if task==member.task and task.get("path",[]).is_empty() and float(task.get("elapsed",0.0))>0.0:
				option.label=str(definition.present); option.detail="You are already taking part here."
			return option
	if member.queue.size()>=MAX_QUEUE:
		option.label="Plan full"; option.detail="Make room in your plan before joining."
		return option
	if not _can_reach_object(_member_lot(member),_position(member),object):
		option.label="No path to "+noun; option.detail="There is no path to reach this "+place+"."
		return option
	if object.kind=="dining_table":
		if int(object.meal.servings)==0 or Meals.available(state,_member_lot(member),object)<=0:
			option.label="No free portion"; option.detail="The remaining portions are already reserved or eaten."; return option
		option.detail="Reserve a portion after your current plans. Hunger + comfort; eating together also restores social."
	option.available=true
	if spaces.available.is_empty():
		option.label="Queue "+noun; option.detail=Leisure.waiting_reason(spaces)+" Wait after your current plans."
	return option

func care_option(member: Dictionary, need: String) -> Dictionary:
	var profile_id := ""
	for family: Dictionary in state.families.values():
		if family.members.has(member): profile_id=str(family.id); break
	var status := care_status(member,need)
	if not status.is_empty(): return {"available":false,"status":status,"label":status,"detail":str(member.name)+" is already taking care of "+need+"."}
	var lot: Dictionary=_member_lot(member)
	var best: Dictionary={}
	var best_score := 100000.0
	for object: Dictionary in lot.objects:
		# Secondary comfort from sleeping is recognized in the plan, but a care
		# shortcut for comfort should choose a short break, not send someone to bed.
		if object.kind in ["garden_bed","easel"] or Catalog.ITEMS[object.kind].need!=need: continue
		if object.kind=="dining_table" and not meal_option(profile_id,str(member.id),str(lot.id),str(object.id),"eat").ok: continue
		var goals := _interaction_cells(lot,object)
		var path := _path(lot,_position(member),goals)
		if path.is_empty() and not goals.has(_position(member)): continue
		var busy := not _object_user(str(lot.id),object,str(member.id)).is_empty()
		if Leisure.KINDS.has(object.kind):
			var places := _shared_places(member,lot,object)
			busy=places.is_empty() or (not places.has(_position(member)) and _path(lot,_position(member),places).is_empty())
		var score := float(path.size())+(1000.0 if busy else 0.0)
		if score<best_score:
			best_score=score
			best={"available":true,"status":"","label":Wellbeing.ACTIONS.get(object.kind,str(Catalog.ITEMS[object.kind].name)),"detail":str(Catalog.ITEMS[object.kind].name)+(" · In use, wait your turn" if busy else " · Here on this lot"),"target_id":object.id,"busy":busy}
			if object.kind=="dining_table": best.meal_batch=int(object.meal.batch); best.label="Eat "+str(Meals.RECIPES[object.meal.recipe].name).to_lower()
	if need=="social":
		for family: Dictionary in state.families.values():
			for other: Dictionary in family.members:
				if other.id==member.id or other.lot_id!=member.lot_id or int(other.get("level",0))!=int(member.get("level",0)): continue
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

func meal_wish_option(profile_id: String,member_id: String,wish_id: String) -> Dictionary:
	var result := {"available":false,"label":"Unavailable","detail":"Choose an unfinished meal wish.","action":""}
	var family: Dictionary=state.families.get(profile_id,{})
	var member := _member(family,member_id) if not family.is_empty() else {}
	if member.is_empty() or not wish_id in Wishes.MEALS: return result
	if not member.wishes.wishes.any(func(wish): return wish.id==wish_id and not wish.done): return result
	var home: Dictionary=state.lots[family.home_lot]; var lot: Dictionary=_member_lot(member)
	if home.building or lot.building:
		result.label="Finish building"; result.detail="Finish construction before making time for a meal."; return result
	if wish_id=="homemade" or not lot.objects.any(func(object): return object.kind=="dining_table"): lot=home
	var table := {}; var score := INF
	var origin := _position(member) if member.lot_id==lot.id else BuildAccess.GATE
	for object: Dictionary in lot.objects:
		if object.kind!="dining_table": continue
		var distance := origin.distance_to(Vector2i(int(object.x),int(object.y)))
		if member.lot_id==lot.id and not _can_reach_object(lot,origin,object): distance+=10000
		if wish_id=="meal_together" and int(object.meal.servings)>0: distance-=100
		if member.task.get("meal_table")==object.id and member.lot_id==lot.id: distance-=1000
		if distance<score: score=distance; table=object
	result.available=true; result.lot_id=str(lot.id)
	if table.is_empty():
		result.action="build"; result.label="Build table"; result.lot_id=str(home.id)
		result.detail="Open Kitchen to place a Gathering dining table (§%d). A reachable fridge is needed to cook; choose and pay for ingredients separately." % int(Catalog.ITEMS.dining_table.cost)
		return result
	result.action="inspect"; result.target_id=str(table.id)
	result.label="Choose a recipe" if wish_id=="homemade" else "Choose a meal"
	result.detail="Open this dining table. Choose a recipe; ingredients are charged when served." if wish_id=="homemade" else "Open this table to choose food. Choose the other diner from People or let their player join. Both need 12 game minutes of chosen time together."
	if member.lot_id!=lot.id: result.label="See home table"; result.detail="View your home table, then go home before preparing or eating."
	elif member.task.get("meal_table")==table.id: result.label="See your table"
	elif not _can_reach_object(lot,origin,table): result.label="Check table access"; result.detail="This table needs a clear path. Inspect it, then adjust the room in Build & buy."
	return result

func wish_status(member: Dictionary, activity: String) -> String:
	if activity in ["meal_prepare","meal_company"]:
		var meal_action := "prepare" if activity=="meal_prepare" else "eat"
		if not member.task.get("automatic",false) and member.task.get("meal_action")==meal_action: return "In progress"
		for task: Dictionary in member.queue:
			if not task.get("automatic",false) and task.get("meal_action")==meal_action: return "In your plan"
		return ""
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
	if state.lots[family.home_lot].building or _member_lot(member).building:
		result.detail="Finish construction before directing your family."; return result
	var tasks: Array=member.queue.duplicate()
	if not member.task.is_empty(): tasks.append(member.task)
	for task: Dictionary in tasks:
		if task.get("routine_id")==routine_id: result.detail="Already in this resident's plan."; return result
	if member.queue.size()+entry.steps.size()>MAX_QUEUE:
		result.detail="Needs %d free places in the plan; %d available." % [entry.steps.size(),MAX_QUEUE-member.queue.size()]; return result
	var lot: Dictionary=_member_lot(member)
	var waits := 0
	for kind: String in entry.steps:
		var best: Dictionary={}; var best_score := 100000.0
		for object: Dictionary in lot.objects:
			if object.kind!=kind: continue
			var goals := _interaction_cells(lot,object)
			var path := _path(lot,_position(member),goals)
			if path.is_empty() and not goals.has(_position(member)): continue
			var busy := not _object_user(str(lot.id),object,str(member.id)).is_empty()
			if Leisure.KINDS.has(kind):
				var places := _shared_places(member,lot,object)
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
	if hobby=="painting": return _painting_hobby_option(member)
	var activity: String=Hobbies.CATALOG[hobby].activity
	var status := wish_status(member,activity)
	if not status.is_empty(): return {"available":false,"status":status,"detail":status}
	var lot: Dictionary=_member_lot(member)
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

func _painting_hobby_option(member: Dictionary) -> Dictionary:
	var lot: Dictionary=_member_lot(member)
	var household: Dictionary=state.families.get(lot.owner,{})
	if not household.get("members",[]).has(member): return {"available":false,"status":"At your own home","detail":"Paint at your household's easel. Visitors can inspect their neighbors' art."}
	if lot.building: return {"available":false,"status":"Under construction","detail":"Finish building before painting."}
	var best := {}; var distance := INF
	for object: Dictionary in lot.objects:
		if object.kind!="easel": continue
		var score := _position(member).distance_squared_to(Vector2i(int(object.x),int(object.y)))
		if score<distance:
			distance=score
			best={"available":true,"inspect":true,"lot_id":str(lot.id),"target_id":str(object.id),"status":"","label":"Choose a painting" if object.painting.subject=="" else "Continue this canvas" if not Paintings.finished(object.painting) else "See your finished painting","detail":"Opens the easel. Choose a subject, continue a canvas, or arrange a finished picture."}
	if best.is_empty(): return {"available":false,"status":"Easel needed","detail":"Find the Daydream easel in Build & buy → Living. Painting supplies are free."}
	return best

func _finish_hobby(member: Dictionary, task: Dictionary, activity: String) -> void:
	if bool(task.get("automatic",false)) or Leisure.chosen_time(task)<4.0: return
	_record_hobby(member,activity)

func _record_hobby(member: Dictionary,activity: String) -> void:
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
			if other.id==member.id or other.lot_id!=member.lot_id or int(other.get("level",0))!=int(member.get("level",0)): continue
			if other.task.get("target_kind")=="member" and other.task.get("target_id")==member.id and other.task.get("path",[]).is_empty() and float(other.task.get("elapsed",0))>0 and _position(other).distance_to(_position(member))<=2.0: return other
	return {}

func _finish_wish(member: Dictionary, task: Dictionary, activity: String, qualifying_delta: float=0.0) -> void:
	if bool(task.get("automatic",false)): return
	if task.has("leisure_chosen_at") and Leisure.chosen_time(task)+qualifying_delta+0.000001<MIN_ACTIVITY_TIME: return
	if task.has("meal_chosen_at") and Meals.chosen_time(task)+qualifying_delta+0.000001<MIN_ACTIVITY_TIME: return
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
	var ready_meal := false
	for object: Dictionary in lot.objects:
		if object.kind in ["garden_bed","easel"]: continue # Crops and artwork require deliberate plans.
		if object.kind=="dining_table" and (not Meals.can_autoeat(state,lot,member) or Meals.available(state,lot,object)<=0): continue
		if not _object_user(str(lot.id),object,str(member.id)).is_empty(): continue
		if Leisure.KINDS.has(object.kind):
			var places := _shared_places(member,lot,object)
			if places.is_empty() or (not places.has(_position(member)) and _path(lot,_position(member),places).is_empty()): continue
		var need: String = Catalog.ITEMS[object.kind].need
		if need.is_empty(): continue
		var value := float(member.needs[need])
		if value >= 78.0 or not _can_reach_object(lot, _position(member), object):
			continue
		candidates.append({"object":object,"need":value})
		ready_meal=ready_meal or object.kind=="dining_table"
		urgent=urgent or value<=Pastimes.URGENT
	for candidate: Dictionary in candidates:
		var object: Dictionary=candidate.object
		var value: float=candidate.need
		if ready_meal and object.kind=="fridge": continue # Eat available food before taking a fresh snack.
		if urgent and value>Pastimes.URGENT: continue
		var distance := _position(member).distance_to(Vector2i(int(object.x), int(object.y)))
		var score := value + distance * 0.2
		if not urgent:
			if Pastimes.matches(member,str(object.kind)): score-=Pastimes.PREFERENCE
			score-=Character.activity_bias(member,str(object.kind))
		if score < best_score:
			best = object
			best_score = score
	if not best.is_empty():
		var task := {"type":"interact","target_id":best.id,"automatic":true}
		if best.kind=="dining_table": task.merge({"meal_action":"eat","meal_table":best.id,"meal_recipe":best.meal.recipe,"meal_batch":int(best.meal.batch)})
		_queue_action(member,task)
		_start_next(member, lot)

func _queue_action(member: Dictionary, action: Dictionary) -> void:
	action.id = str(member.id) + ":" + str(int(member.get("next_action", 1)))
	member.next_action = int(member.get("next_action", 1)) + 1
	action.title=_activity_title(member,action)
	member.queue.append(action)

func _start_next(member: Dictionary, lot: Dictionary) -> void:
	if member.queue.is_empty():
		return
	var pending: Dictionary = member.queue[0]
	var shared_places: Array=[]
	if pending.type == "interact" and pending.get("target_kind", "object") == "object":
		var furnishing := _object(lot,str(pending.target_id))
		if furnishing.get("kind")=="dining_table" and not pending.has("meal_action"):
			member.queue.pop_front(); _record_activity(member,pending,"failed","Choose a portion from the dining table."); return
		if pending.has("meal_action"):
			var meal := _meal_task_option(member,lot,pending)
			if not meal.ok:
				member.queue.pop_front(); _record_activity(member,pending,"failed",str(meal.message)); member.action=str(meal.message); return
		if furnishing.get("kind")=="garden_bed" or pending.has("garden_action"):
			var garden := _garden_task_option(member,lot,furnishing,pending)
			if not garden.ok:
				member.queue.pop_front(); _record_activity(member,pending,"failed",str(garden.message)); member.action=str(garden.message); return
		if furnishing.get("kind")=="easel" or pending.has("paint_action"):
			var painting := _painting_task_option(member,lot,furnishing,pending)
			if not painting.ok:
				member.queue.pop_front(); _record_activity(member,pending,"failed",str(painting.message)); member.action=str(painting.message); return
		var user := _object_user(str(lot.id),furnishing,str(member.id))
		if not user.is_empty():
			member.action = "Waiting for " + str(user.name) + " · " + str(Catalog.ITEMS[furnishing.kind].name)
			return
		if Leisure.KINDS.has(furnishing.get("kind","")):
			var spaces := Leisure.spaces(state,lot,furnishing,member)
			shared_places=spaces.available
			if shared_places.is_empty():
				member.action="Waiting for a place · "+Leisure.waiting_reason(spaces)
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
	elif task.get("target_kind")=="art":
		if not ArtAdmiration.current(lot,task):
			_record_activity(member,task,"failed","The painting moved or left this home."); return
		goals=ArtAdmiration.cells(lot,lot.artworks[task.target_id],_walkable)
		task.remaining=ArtAdmiration.DURATION; task.label="Admire painting"
	elif task.get("target_kind", "object") == "member":
		var neighbor := _find_member(str(task.target_id))
		if neighbor.is_empty() or neighbor.lot_id != member.lot_id or int(neighbor.get("level",0))!=int(member.get("level",0)):
			_record_activity(member,task,"failed","The other resident left this lot.")
			return
		goals = _social_cells(lot, neighbor)
		task.remaining = 10.0
		task.label = "Chat with " + str(neighbor.name)
	else:
		var object := _object(lot, str(task.target_id))
		if object.is_empty():
			_record_activity(member,task,"failed","The furnishing is no longer here.")
			return
		goals = shared_places if Leisure.KINDS.has(object.kind) else _interaction_cells(lot, object)
		task.remaining = float(Catalog.ITEMS[object.kind].duration)
		task.label = str(Catalog.ITEMS[object.kind].name)
		if task.has("meal_action"):
			task.remaining=Meals.EAT_TIME if task.meal_action=="eat" else float(Meals.RECIPES[task.meal_recipe].prepare)+Meals.SERVE_TIME
			task.label=Meals.label(str(task.meal_action),str(task.meal_recipe))
			if task.meal_action=="prepare": task.meal_phase="prepare"
		if object.kind=="easel":
			var painting := _painting_task_option(member,lot,object,task)
			task.remaining=float(painting.seconds); task.label=str(painting.label)
		if object.kind=="garden_bed":
			task.remaining=float(Gardens.DURATIONS[task.garden_action])
			task.label=Gardens.label(str(task.garden_action),str(task.crop) if task.garden_action=="plant" else str(object.garden.crop))
	var route := _path(lot, _position(member), goals)
	if route.is_empty() and not goals.has(_position(member)):
		member.action = "Cannot reach destination"
		_record_activity(member,task,"failed","There is no path to the destination.")
		return
	task.path = route
	if task.type=="interact": task.elapsed=0.0
	member.task = task
	member.walk_clock = 0.0
	member.action = "Walking" + (" · " + str(task.get("label", "")) if task.type == "interact" else "") if not route.is_empty() else "Starting activity"

func _shared_places(member: Dictionary, lot: Dictionary, object: Dictionary) -> Array:
	return Leisure.spaces(state,lot,object,member).available

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
	for level in range(Storeys.MAX_LEVEL+1):
		var layer := Storeys.view(lot,level)
		if level>0 and layer.floors.is_empty() and layer.objects.is_empty(): continue
		if level>0 and layer.entrances.is_empty(): return "Add stairs and a clear upper landing to floor %d." % (level+1)
		for object: Dictionary in layer.objects:
			for cell: Vector2i in _object_cells(object):
				if [cell.x,cell.y] in layer.get("stairwells",[]): return "Move furnishings away from the stairwell on floor %d." % (level+1)
		var issue := str(build_access(layer).message)
		if not issue.is_empty(): return issue
		for stair: Dictionary in Storeys.stairs(lot,level):
			if level==Storeys.MAX_LEVEL: return "The top floor cannot have an upward staircase."
			if not _walkable(layer,Storeys.landing(stair,false)) or not _walkable(Storeys.view(lot,level+1),Storeys.landing(stair,true)): return "Keep both staircase landings clear and add flooring upstairs."
	return ""

func build_access(lot: Dictionary) -> Dictionary:
	var residents: Array=[]
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot.id and int(member.get("level",0))==int(lot.get("level",0)): residents.append(member)
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
	_relocate_build_residents(lot)
	_update_history_counts(lot)
	return _result(true,"Building edit " + ("redone." if redo else "undone. Funds restored."))

func _restore_build(lot: Dictionary) -> void:
	_apply_build_edit(lot,_build_backups[lot.id])
	_build_backups.erase(lot.id)
	_clear_build_history(lot)

func _relocate_build_residents(lot: Dictionary) -> void:
	# Paused residents stay put until a new obstacle or disconnected room would
	# strand them. This is part of the host transaction, never a render side effect.
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id!=lot.id: continue
			var layer := _member_lot(member)
			var report := BuildAccess.inspect(layer,[])
			if _walkable(layer,_position(member)) and report.reachable.has(_position(member)): continue
			member.level=0
			var at := _free_entry(lot,str(member.id))
			member.x=at.x; member.y=at.y
			_clear_member(member,"Waiting by the street","Moved aside for building.")

func _send_home(family: Dictionary, member: Dictionary, reason: String = "Household went away; returned home.") -> void:
	var lot: Dictionary = state.lots[family.home_lot]
	_clear_member(member,"Taking it easy",reason)
	member.lot_id = family.home_lot
	member.level=0
	member.next_action+=1
	var entry := _free_entry(lot,str(member.id))
	member.x = entry.x
	member.y = entry.y

func _free_entry(lot: Dictionary,ignore_member: String="") -> Vector2i:
	var places := _arrival_places(lot,1,ignore_member)
	if not places.is_empty(): return places[0]
	# Forced returns must also recover legacy homes with a blocked entrance.
	for y in range(GRID_SIZE-1,-1,-1):
		for x in range(GRID_SIZE):
			var cell:=Vector2i(x,y)
			if _walkable(lot,cell) and not _resident_at(str(lot.id),cell): return cell
	return BuildAccess.GATE

func _activity_title(member: Dictionary, task: Dictionary) -> String:
	if task.has("title"): return str(task.title)
	if task.has("meal_action"): return Meals.label(str(task.meal_action),str(task.meal_recipe))
	if task.get("target_kind")=="art": return ArtAdmiration.title(_member_lot(member).get("artworks",{}).get(task.get("target_id",""),{}))
	if task.get("type")=="move": return "Walk to %d, %d" % [int(task.x),int(task.y)]
	if task.get("target_kind")=="member":
		return ActivityLog.clean("Chat with "+str(_find_member(str(task.get("target_id",""))).get("name","neighbor")),100)
	var object := _object(_member_lot(member),str(task.get("target_id","")))
	if task.has("paint_action"): return Paintings.label(str(task.paint_action),str(task.subject) if task.paint_action=="start" else str(object.get("painting",{}).get("subject","")))
	if task.has("garden_action"):
		return Gardens.label(str(task.garden_action),str(task.crop) if task.garden_action=="plant" else str(object.get("garden",{}).get("crop","")))
	var title := ActivityLog.clean(str(Catalog.ITEMS.get(object.get("kind",""),{}).get("name",task.get("label","Activity"))),100)
	return "Activity" if title.is_empty() else title

func _record_activity(member: Dictionary, task: Dictionary, outcome: String, reason: String) -> void:
	if task.is_empty() or task.get("automatic",false): return
	ActivityLog.record(member,task,_activity_title(member,task),outcome,reason,state)

func _end_task(member: Dictionary, outcome: String, reason: String, label: String = "Taking it easy") -> void:
	_record_activity(member,member.task,outcome,reason)
	member.task={}
	member.action=label

func _clear_member(member: Dictionary, label: String = "Taking it easy", reason: String = "Plan cleared.", outcome: String = "cancelled") -> void:
	# Batch interruption presents the current activity first, then its next steps.
	for index in range(member.queue.size()-1,-1,-1):
		_record_activity(member,member.queue[index],"cancelled",reason)
	member.queue = []
	_end_task(member,outcome,reason,label)
	member.walk_clock = 0.0
	member.idle_clock = 0.0

func _new_object(kind: String, x: int, y: int, rotation: int) -> Dictionary:
	var id := "object_%d" % int(state.next_object)
	state.next_object += 1
	var object := {"id":id, "kind":kind, "x":x, "y":y, "rotation":rotation}
	if kind=="garden_bed": object.garden=Gardens.create()
	if kind=="easel": object.painting=Paintings.create()
	if kind=="dining_table": object.meal=Meals.create()
	return object

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
	return _inside(cell) and [cell.x,cell.y] not in lot.get("stairwells",[]) and (int(lot.get("level",0))==0 or [cell.x,cell.y] in lot.floors) and not Landscaping.pooled(lot,cell.x,cell.y) and not lot.walls.has([cell.x,cell.y]) and _object_at(lot, cell).is_empty()

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
	for tile: Array in lot.get("stairwells",[]): blocked[Vector2i(int(tile[0]),int(tile[1]))]=true
	for tile: Array in lot.get("landscape",{}).get("pools",[]): blocked[Vector2i(int(tile[0]),int(tile[1]))]=true
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
			if not _inside(next) or blocked.has(next) or previous.has(next) or (int(lot.get("level",0))>0 and [next.x,next.y] not in lot.floors):
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
	return _restore(data,preserve_runtime,false)

func restore_saved(data: Dictionary) -> bool:
	# Keep plans intact while browsing or validating. The session decides which
	# household can continue before activating the candidate world.
	return _restore(data,true,true)

func _restore(data: Dictionary, preserve_runtime: bool, continuing: bool) -> bool:
	if data.get("schema")==1:
		data=_migrate_v1(data)
	if data.get("schema")==2:
		if not data.get("lots") is Dictionary: return false
		for lot: Variant in data.lots.values():
			if not lot is Dictionary: return false
		data=data.duplicate(true); data.schema=3
		for lot: Dictionary in data.get("lots",{}).values(): lot.storeys={}
	# Reject foreign/future/corrupt worlds atomically; never partially adopt a save.
	if not _valid_state(data,continuing):
		return false
	state = data.duplicate(true)
	state.erase("solo_view")
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
			_clear_member(member,"Taking it easy","Neighborhood loaded; unfinished plans cleared.")
			if not _walkable(_member_lot(member), _position(member)):
				_send_home(family, member)
	return true

func prepare_continuation(profile_id: String) -> Dictionary:
	# Connection lifetimes end at a disk load. Only the solo household continues
	# its plans; absent households keep their usual caretaker/disconnect policy.
	var report := {"relocated":[],"interrupted":0,"details":[]}
	for lot: Dictionary in state.lots.values():
		lot.building=false
		_clear_build_history(lot)
	for id: String in state.families:
		if id==profile_id: continue
		var absent: Dictionary=state.families[id]
		HomeNews.departure(absent,false)
		absent.online=false
		for member: Dictionary in absent.members:
			if not _recover_saved_position(report,absent,member):
				_clear_member(member,"Taking it easy","Neighborhood loaded; household is away.")
	if not state.families.has(profile_id): return report
	var family: Dictionary=state.families[profile_id]
	for member: Dictionary in family.members:
		if _recover_saved_position(report,family,member): continue
		var lot := _member_lot(member)
		var queued: int=member.queue.size()
		for index in range(queued-1,-1,-1):
			var task: Dictionary=member.queue[index]
			var reason := _continuation_problem(member,lot,task,false)
			if reason.is_empty(): continue
			_note_load_interruption(report,member,task,reason)
			_record_activity(member,task,"cancelled",reason)
			member.queue.remove_at(index)
		if not member.task.is_empty():
			var reason := _continuation_problem(member,lot,member.task,true)
			if not reason.is_empty():
				_note_load_interruption(report,member,member.task,reason)
				_end_task(member,"cancelled",reason)
				member.walk_clock=0.0
		elif (queued>0 and member.queue.is_empty()) or str(member.action).begins_with("Chatting with "):
			member.action="Taking it easy"
	return report

func _recover_saved_position(report: Dictionary, family: Dictionary, member: Dictionary) -> bool:
	if _walkable(_member_lot(member),_position(member)): return false
	var reason := "Saved spot was blocked or the floor was unavailable."
	report.relocated.append(str(member.name))
	report.interrupted+=member.queue.size()+(0 if member.task.is_empty() else 1)
	report.details.append(str(member.name)+": "+reason+" Returned home.")
	_send_home(family,member,reason+" Returned to the home entrance.")
	return true

func _note_load_interruption(report: Dictionary, member: Dictionary, task: Dictionary, reason: String) -> void:
	report.interrupted+=1
	report.details.append("%s · %s: %s" % [member.name,_activity_title(member,task),reason])

func _continuation_problem(member: Dictionary, lot: Dictionary, task: Dictionary, active: bool) -> String:
	# Resume only actions whose complete state is the resident's route, clock and
	# one ordinary furnishing (whose reservation is derived from the active task).
	if task.has("stairs_to") or task.get("courtesy",false) or task.get("target_kind","object")!="object" or task.has("meal_action") or task.has("garden_action") or task.has("paint_action"):
		return "This activity stops when a neighborhood is loaded."
	var goals: Array
	if task.type=="move":
		var goal := Vector2i(int(task.x),int(task.y))
		if not _walkable(lot,goal): return "The saved destination is blocked."
		goals=[goal]
	else:
		var furnishing := _object(lot,str(task.target_id))
		if furnishing.is_empty(): return "The saved furnishing is no longer here."
		if furnishing.kind in ["dining_table","easel","garden_bed"] or Leisure.KINDS.has(furnishing.kind) or task.has("leisure_chosen_at"):
			return "This activity stops when a neighborhood is loaded."
		if str(Catalog.ITEMS[furnishing.kind].need).is_empty():
			return "The saved furnishing no longer offers an activity."
		goals=_interaction_cells(lot,furnishing)
		if active and not _object_user(str(lot.id),furnishing,str(member.id)).is_empty():
			return "The saved furnishing already has a resident using it."
	var at := _position(member)
	if not active:
		return "" if goals.has(at) or not _path(lot,at,goals).is_empty() else "There is no path to the saved destination."
	for tile: Array in task.path:
		var next := Vector2i(int(tile[0]),int(tile[1]))
		if next-at not in DIRECTIONS or not _walkable(lot,next):
			return "The saved walking route is blocked."
		at=next
	return "" if goals.has(at) else "The saved activity no longer ends at its destination."

static func _migrate_v1(data: Dictionary) -> Dictionary:
	# Additive creator schema. Legacy residents retain their exact looks and needs;
	# absent profiles are resolved to neutral defaults only when opening the creator.
	var migrated := data.duplicate(true)
	migrated.schema=2
	return migrated

func _creator_position(family: Dictionary, id: String) -> Vector2i:
	var lot: Dictionary=state.lots[family.home_lot]
	var places: Array[Vector2i]=[]
	for tile: Array in lot.floors:
		var cell := Vector2i(int(tile[0]),int(tile[1]))
		if _walkable(lot,cell) and not _resident_at(str(lot.id),cell): places.append(cell)
	places.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(Vector2i(7,7))<b.distance_squared_to(Vector2i(7,7)))
	for cell: Vector2i in places:
		if cell==BuildAccess.GATE or not _path(lot,BuildAccess.GATE,[cell]).is_empty(): return cell
	return _free_entry(lot,id)

func _create_resident(family: Dictionary, id: String, resident_name: String) -> Dictionary:
	var lot: Dictionary=state.lots[family.home_lot]
	var at := _creator_position(family,id)
	var needs := {}
	for need: String in NEEDS: needs[need]=85.0
	var member := {"id":id,"name":resident_name,"lot_id":family.home_lot,"x":at.x,"y":at.y,"needs":needs,"action":"Taking it easy","queue":[],"task":{},"activity_log":[],"walk_clock":0.0,"idle_clock":0.0,"autonomy":true,"next_action":1}
	member.wishes=Wishes.create(id,int(state.day)); member.hobbies=Hobbies.create(int(state.day))
	member.appearance=Appearance.defaults(member); member.favorite="variety"
	return member

func _normalize_numbers() -> void:
	# JSON has one numeric type. Tile-array equality in Godot distinguishes floats
	# from ints, so restore the canonical integer representation before simulation.
	for key: String in ["tick", "day", "next_object"]:
		state[key] = int(state[key])
	for lot: Dictionary in state.lots.values():
		lot.build_undo = int(lot.get("build_undo",0))
		if not lot.has("finishes"): lot.finishes=Finishes.create()
		if not lot.has("windows"): lot.windows={}
		if not lot.has("artworks"): lot.artworks={}
		if not lot.has("landscape"): lot.landscape=Landscaping.empty()
		if not lot.has("diagonal_walls"): lot.diagonal_walls={}
		if not lot.has("storeys"): lot.storeys={}
		for layer: Dictionary in lot.storeys.values():
			for field: String in ["floors","walls","doors"]:
				for tile: Array in layer[field]: tile[0]=int(tile[0]); tile[1]=int(tile[1])
			for object: Dictionary in layer.objects:
				for field: String in ["x","y","rotation"]: object[field]=int(object[field])
				if object.kind=="easel": Paintings.normalize(object.painting)
				if object.kind=="dining_table": Meals.normalize(object.meal)
				if object.kind=="garden_bed":
					for field: String in ["revision","harvests"]: object.garden[field]=int(object.garden[field])
		for tile: Array in lot.landscape.pools: tile[0]=int(tile[0]); tile[1]=int(tile[1])
		for entry: Dictionary in lot.artworks.values():
			entry.x=int(entry.x); entry.y=int(entry.y)
			Paintings.normalize(entry.picture)
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
			if object.kind=="easel":
				Paintings.normalize(object.painting)
			if object.kind=="dining_table": Meals.normalize(object.meal)
			if object.kind=="garden_bed":
				for key: String in ["revision","harvests"]: object.garden[key]=int(object.garden[key])
	for family: Dictionary in state.families.values():
		HomeNews.normalize(family)
		if not family.has("routines"): family.routines=Routines.create()
		Routines.normalize(family.routines)
		if not family.has("room_library"): family.room_library=RoomLibrary.create()
		RoomLibrary.normalize(family.room_library)
		if not family.has("commissions"): family.commissions=Commissions.create()
		Commissions.normalize(family.commissions)
		if not family.has("pantry"): family.pantry=Pantry.create()
		Pantry.normalize(family.pantry)
		family.identity_revision=int(family.get("identity_revision",0))
		for link: Dictionary in family.get("relations",[]): link.kind=int(link.kind)
		for member: Dictionary in family.members:
			if member.has("character"): Character.normalize(member.character)
			if not member.has("favorite"): member.favorite="variety"
			if not member.has("appearance"): member.appearance=Appearance.defaults(member)
			for key: String in member.appearance: member.appearance[key]=int(member.appearance[key])
			if not member.has("wishes"): member.wishes=Wishes.create(str(member.id),int(state.day))
			Wishes.normalize(member.wishes)
			if not member.has("hobbies"): member.hobbies=Hobbies.create(int(state.day))
			Hobbies.normalize(member.hobbies,int(state.day))
			ActivityLog.normalize(member)
			member.level=int(member.get("level",0))
			member.autonomy = member.get("autonomy", true)
			member.next_action = int(member.get("next_action", 1))
			member.x = int(member.x)
			member.y = int(member.y)
			var tasks: Array = member.queue.duplicate()
			if not member.task.is_empty():
				tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.get("target_kind")=="art": task.art_x=int(task.art_x); task.art_y=int(task.art_y)
				if not task.has("title"): task.title=ActivityLog.clean(_activity_title(member,task),100)
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

func _valid_state(data: Dictionary, continuing: bool = false) -> bool:
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
		if not _valid_lot_layout(lot,object_ids,data): return false
		if not lot.get("storeys",{}) is Dictionary or lot.get("storeys",{}).size()>Storeys.MAX_LEVEL: return false
		for key: Variant in lot.get("storeys",{}):
			if not key is String or key not in ["1","2"] or not lot.storeys[key] is Dictionary: return false
			var layer: Dictionary=lot.storeys[key]
			if layer.size()!=Storeys.FIELDS.size(): return false
			for field: String in Storeys.FIELDS:
				if not layer.has(field): return false
			var checked := lot.duplicate()
			for field: String in Storeys.FIELDS: checked[field]=layer[field]
			checked.landscape=Landscaping.empty()
			if not _valid_lot_layout(checked,object_ids,data): return false

	var members_seen := {}
	for profile_id: Variant in data.families:
		if not profile_id is String or profile_id.is_empty() or profile_id.length() > 128 or not data.families[profile_id] is Dictionary:
			return false
		var family: Dictionary = data.families[profile_id]
		if family.get("id") != profile_id or not family.get("name") is String or str(family.name).length() > 64 or not data.lots.has(family.get("home_lot")) or data.lots[family.home_lot].owner != profile_id or not family.get("online") is bool or not family.get("members") is Array or family.members.is_empty() or family.members.size() > Character.MAX_MEMBERS:
			return false
		if family.has("home_news") and not HomeNews.valid(family.home_news): return false
		if family.has("routines") and not Routines.valid(family.routines): return false
		if family.has("room_library") and not RoomLibrary.valid(family.room_library): return false
		if family.has("commissions") and not Commissions.valid(family.commissions,profile_id,int(data.day)): return false
		if family.has("pantry") and not Pantry.valid(family.pantry): return false
		if not _integer(family.get("identity_revision",0)) or float(family.get("identity_revision",0))<0 or float(family.get("identity_revision",0))>9007199254740000: return false
		for member: Variant in family.members:
			if not member is Dictionary or not member.get("id") is String or str(member.id).length() > 160 or members_seen.has(member.id) or not member.get("name") is String or str(member.name).length() > 32 or not data.lots.has(member.get("lot_id")) or not _valid_coord(member.get("x")) or not _valid_coord(member.get("y")) or not member.get("needs") is Dictionary:
				return false
			if not _integer(member.get("level",0)) or int(member.get("level",0))<0 or int(member.get("level",0))>Storeys.MAX_LEVEL: return false
			if not member.get("autonomy", true) is bool or not _integer(member.get("next_action", 1)) or float(member.get("next_action", 1)) < 1 or float(member.get("next_action", 1)) > 9007199254740000:
				return false
			if member.has("activity_log") and not ActivityLog.valid(member.activity_log,int(data.day),int(data.tick)): return false
			if member.has("favorite") and not Pastimes.valid(member.favorite): return false
			if member.has("appearance") and not Appearance.valid(member.appearance): return false
			if member.has("character") and not Character.valid(member.character): return false
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
			if not continuing and member.task.has("leisure_chosen_at") and not _object(data.lots[member.lot_id],str(member.task.target_id)).get("kind") in Recreation.KINDS: return false
			for need: String in NEEDS:
				if not _number(member.needs.get(need)) or float(member.needs[need]) < 0 or float(member.needs[need]) > 100:
					return false
		if family.has("relations") and not Character.relations_valid(family.relations,family.members): return false
	if data.has("friendships") and not Friendships.valid(data.friendships,members_seen,int(data.day),int(data.tick)): return false
	if not Meals.valid_reservations(data): return false
	if not Pantry.valid_reservations(data): return false
	if not Mailbox.valid(data): return false
	if not Commissions.valid_receipts(data): return false
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
	if not Recreation.valid_choice(value,active): return false
	if value.has("meal_action") or value.has("meal_table") or value.has("meal_recipe") or value.has("meal_batch") or value.has("meal_taken") or value.has("meal_phase") or value.has("meal_chosen_at"):
		if not Meals.valid_task(value,active): return false
	if value.get("target_kind")=="art":
		if not ArtAdmiration.valid_task(value,active): return false
	elif value.has("art_x") or value.has("art_y"): return false
	if value.has("paint_action") or value.has("paint_revision") or value.has("subject"):
		if not Paintings.valid_task(value): return false
	if value.has("garden_action") or value.has("garden_revision") or value.has("crop"):
		if not Gardens.valid_task(value): return false
	if value.has("routine_id") or value.has("routine_name"):
		if value.type!="interact" or not Routines.valid_id(value.get("routine_id")) or not HouseholdProfile.valid_name(value.get("routine_name"),32): return false
	if value.has("social_started") and (not _integer(value.social_started) or float(value.social_started)<0 or float(value.social_started)>9007199254740991): return false
	if value.has("stairs_to") and (value.type!="move" or not _integer(value.stairs_to) or int(value.stairs_to)<0 or int(value.stairs_to)>Storeys.MAX_LEVEL or not value.get("stairs_id") is String): return false
	if value.has("elapsed") and (not _number(value.elapsed) or float(value.elapsed)<0 or float(value.elapsed)>120): return false
	if value.has("id") and (not value.id is String or str(value.id).is_empty() or str(value.id).length() > 180):
		return false
	if value.has("title") and not ActivityLog.valid_text(value.title,100): return false
	if value.has("automatic") and not value.automatic is bool:
		return false
	if value.has("courtesy") and (not value.courtesy is bool or not value.courtesy or value.type!="move" or not value.get("automatic",false) or not active): return false
	if value.has("target_kind") and not value.target_kind in ["member", "object", "art"]:
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
		if not value.get("path") is Array or value.path.size() > GRID_SIZE * GRID_SIZE or (value.get("courtesy",false) and value.path.size()>1):
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

func _tick_shared_friendships(delta: float) -> void:
	# Sample both participants before ticking either one. A final shared step
	# counts even if both activities finish in this frame, independent of order.
	var participants: Array=[]
	for family: Dictionary in state.families.values():
		if not family.online or state.lots[family.home_lot].building: continue
		for member: Dictionary in family.members:
			var task: Dictionary=member.task
			if task.get("automatic",false) or not task.get("path",[]).is_empty() or float(task.get("elapsed",0.0))<=0.0 or not task.has("social_started"): continue
			var object := Leisure.activity(state,member)
			if not object.is_empty(): participants.append({"member":member,"object":object})
	for index in range(participants.size()):
		var first: Dictionary=participants[index]
		for next in range(index+1,participants.size()):
			var second: Dictionary=participants[next]
			if first.member.lot_id!=second.member.lot_id or first.object.id!=second.object.id: continue
			var a: Dictionary=first.member.task; var b: Dictionary=second.member.task
			var together := minf(Leisure.chosen_time(a),Leisure.chosen_time(b))+minf(delta,minf(float(a.remaining),float(b.remaining)))
			if together+0.0000001<Friendships.SHARED_TIME: continue
			var started := maxi(int(a.social_started),int(b.social_started))
			var result := Friendships.record(state,str(first.member.id),str(second.member.id),started,str(first.object.kind))
			_announce_friendship(first.member,second.member,result)
			if first.object.kind=="dining_table":
				_finish_wish(first.member,a,"meal_company",minf(delta,float(a.remaining))); _finish_wish(second.member,b,"meal_company",minf(delta,float(b.remaining)))

func _finish_conversation(member: Dictionary, neighbor: Dictionary, task: Dictionary) -> void:
	if task.get("automatic",false) or not _online_member(member) or not _online_member(neighbor): return
	var result := Friendships.record(state,str(member.id),str(neighbor.id),int(task.get("social_started",state.tick)))
	_announce_friendship(member,neighbor,result)

func _announce_friendship(member: Dictionary, neighbor: Dictionary, result: Dictionary) -> void:
	var milestone: String=result.get("milestone","")
	if milestone.is_empty(): return
	var detail := " got to know " if milestone=="met" else " became "+milestone+" with "
	_event(str(member.name)+detail+str(neighbor.name)+".")
	for pair in [[member,neighbor],[neighbor,member]]:
		var text := ("Got to know " if milestone=="met" else "Became "+milestone+" with ")+str(pair[1].name)+"."
		pair[0].wishes.journal.push_front({"day":int(state.day),"text":text})
		if pair[0].wishes.journal.size()>Wishes.MAX_JOURNAL: pair[0].wishes.journal.resize(Wishes.MAX_JOURNAL)

func _valid_lot_layout(lot: Dictionary,object_ids: Dictionary,data: Dictionary) -> bool:
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
		if object.kind=="garden_bed" and not Gardens.valid(object.get("garden")): return false
		if object.kind!="garden_bed" and object.has("garden"): return false
		if object.kind=="dining_table" and not Meals.valid(object.get("meal"),int(data.day)): return false
		if object.kind!="dining_table" and object.has("meal"): return false
		if object.kind=="easel" and not Paintings.valid(object.get("painting"),int(data.day)): return false
		if object.kind!="easel" and object.has("painting"): return false
		if not FurnitureColors.valid(object): return false
		for cell: Vector2i in _object_cells(object):
			if not _inside(cell) or occupied.has(cell) or (not Catalog.ITEMS[object.kind].get("outdoor",object.kind=="garden_bed") and not floor_cells.has(cell)):
				return false
			occupied[cell] = true
	if not Landscaping.valid(lot): return false
	if not Finishes.valid(lot) or not Windows.valid(lot) or not WallArt.valid(lot,int(data.day)): return false
	return true

func _member_lot(member: Dictionary) -> Dictionary:
	return Storeys.view(state.lots[member.lot_id],int(member.get("level",0)))

func _build_storey(lot: Dictionary,command: Dictionary) -> Dictionary:
	var level: Variant=command.get("level",0)
	if not _integer(level) or int(level)<0 or int(level)>Storeys.MAX_LEVEL: return _result(false,"Choose a floor from 1 to 3.")
	if int(level)==Storeys.MAX_LEVEL and command.get("kind")=="stairs": return _result(false,"This is the top floor.")
	var layer := lot if int(level)==0 else Storeys.view(lot,int(level)).duplicate(true)
	var outcome := _build(layer,command)
	if outcome.ok and int(level)>0: Storeys.commit(lot,layer,int(level))
	return outcome

func _use_stairs(member: Dictionary,lot: Dictionary,command: Dictionary) -> Dictionary:
	if member.lot_id!=lot.id or lot.building: return _result(false,"Finish building and visit this home first.")
	var direction: Variant=command.get("direction",1)
	if not _integer(direction) or int(direction) not in [-1,1]: return _result(false,"Choose upstairs or downstairs.")
	var level := int(member.get("level",0)); var destination := level+int(direction)
	if destination<0 or destination>Storeys.MAX_LEVEL: return _result(false,"There is no floor in that direction.")
	if member.queue.size()>=MAX_QUEUE: return _result(false,"The plan is full.")
	var current := _member_lot(member)
	for stair: Dictionary in Storeys.stairs(lot,mini(level,destination)):
		var start := Storeys.landing(stair,int(direction)<0)
		var arrival := Storeys.landing(stair,int(direction)>0)
		if not _walkable(Storeys.view(lot,destination),arrival) or not _walkable(current,start): continue
		if start!=_position(member) and _path(current,_position(member),[start]).is_empty(): continue
		_queue_action(member,{"type":"move","x":start.x,"y":start.y,"stairs_to":destination,"stairs_id":stair.id,"title":"Go upstairs" if int(direction)>0 else "Go downstairs"})
		if member.task.get("automatic",false): _end_task(member,"cancelled","Using the stairs.")
		return _result(true,"Stairs added to the plan.")
	return _result(false,"No reachable staircase with clear landings connects these floors.")
