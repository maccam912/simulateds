extends RefCounted
## Read-only lot discovery from the accepted world, distinct from player presence.
static func cards(state: Dictionary,profile_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var lots: Dictionary=state.get("lots",{})
	var families: Dictionary=state.get("families",{})
	for id: String in lots:
		var lot: Dictionary=lots[id]
		var owner: String=str(lot.get("owner",""))
		var household: Dictionary=families.get(owner,{})
		var occupied: bool=not household.is_empty()
		var playing: bool=bool(household.get("online",false))
		var building: bool=bool(lot.get("building",false))
		var people: Array[Dictionary]=[]
		var guest_players := {}
		var elsewhere: PackedStringArray=[]
		var owners: Array=families.keys()
		# Home residents appear before visitors; identity/order stays independent of actions.
		owners.sort_custom(func(a,b): return _priority(str(a),owner,profile_id)<_priority(str(b),owner,profile_id) if _priority(str(a),owner,profile_id)!=_priority(str(b),owner,profile_id) else str(a)<str(b))
		for family_id: String in owners:
			var family: Dictionary=families[family_id]
			for resident: Dictionary in family.get("members",[]):
				if resident.lot_id==id:
					people.append({"id":str(resident.id),"name":str(resident.name),"household":str(family.name),"home":family_id==owner,"playing":bool(family.online)})
					if family_id!=owner and family.online: guest_players[family_id]=true
				elif family_id==owner:
					elsewhere.append(str(resident.name)+" · "+str(lots.get(resident.lot_id,{}).get("name","Away")))
		var status := "Available lot" if not occupied else "Under construction · Closed" if building else ("Your home · Playing" if owner==profile_id else "Owner playing") if playing else "Owner away · Guests playing" if not guest_players.is_empty() else "Owner away · Caretaker"
		var roster := "No household yet" if not occupied and people.is_empty() else "Nobody here" if people.is_empty() else "%d here · " % people.size()+", ".join(people.map(func(person): return str(person.name)))
		var lines: PackedStringArray=[str(lot.get("name",id))]
		if occupied:
			lines.append(str(household.name)+(" · Player playing" if playing else " · Player away; caretakers tend the household"))
		else: lines.append("No household lives here yet.")
		if building: lines.append("Visits are closed during construction. The household waits; visitors return home.")
		if people.is_empty(): lines.append("No residents are here right now.")
		else:
			lines.append("Here now:")
			for person: Dictionary in people: lines.append(str(person.name)+" · "+str(person.household)+(" · At home" if person.home else " · Visiting")+(" · Player playing" if person.playing else " · Player away"))
		if not elsewhere.is_empty(): lines.append("Household elsewhere:\n"+"\n".join(elsewhere))
		lines.append("View this lot. Visit or Together… chooses who travels.")
		result.append({"id":id,"name":str(lot.get("name",id)),"status":status,"roster":roster,"people":people,"playing":playing,"guest_players":guest_players.size(),"building":building,"occupied":occupied,"tooltip":"\n".join(lines)})
	return result

static func _priority(id: String,owner: String,profile_id: String) -> int:
	return 0 if id==owner else 1 if id==profile_id else 2
