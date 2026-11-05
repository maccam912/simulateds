extends RefCounted
const Pastimes = preload("res://game/pastimes.gd")
const Character = preload("res://game/character_profile.gd")
const Appearance = preload("res://game/appearance.gd")

static func valid_name(value: Variant, limit: int) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length()>limit: return false
	for index in range(value.length()):
		if value.unicode_at(index)<32 or value.unicode_at(index)==127: return false
	return true

static func edit(family: Dictionary, command: Dictionary, create_member: Callable=Callable()) -> Dictionary:
	var revision: Variant=command.get("revision")
	if not Character.integer(revision,0,9007199254739999) or float(revision)!=float(family.get("identity_revision",0)):
		return _no("This household changed. Reopen the creator to see the latest choices.")
	if not valid_name(command.get("name"),64): return _no("Choose a household name between 1 and 64 characters on one line.")
	var members: Variant=command.get("members")
	if not members is Array or members.size()<family.members.size() or members.size()>Character.MAX_MEMBERS: return _no("Keep your residents and choose up to eight household members.")
	var updates := {}; var staged: Array=[]
	for index in range(members.size()):
		var member: Variant=members[index]
		if not member is Dictionary or not member.get("id") is String: return _no("Choose a member of your household.")
		var owned: Dictionary = {}
		for resident: Dictionary in family.members:
			if resident.id==member.id: owned=resident
		var is_new := owned.is_empty()
		if updates.has(member.id) or (is_new and (not create_member.is_valid() or member.id!=new_id(family,index))): return _no("You can only edit your own residents and add new members once.")
		if not valid_name(member.get("name"),32): return _no("Resident names need 1 to 32 characters on one line.")
		if not Appearance.valid(member.get("appearance")): return _no("Choose colors and hair from the available palette.")
		var favorite: Variant=member.get("favorite",Pastimes.of(owned))
		if not Pastimes.valid(favorite): return _no("Choose a pastime from the available list.")
		var update := {"id":member.id,"name":member.name.strip_edges(),"appearance":member.appearance.duplicate(),"favorite":favorite}
		if member.has("character") or owned.has("character"):
			var character: Variant=member.get("character",owned.get("character"))
			if not Character.valid(character): return _no("Check this resident's looks, outfits, traits and interests. Likes and dislikes must be different.")
			update.character=character.duplicate(true); Character.normalize(update.character)
		updates[member.id]=update; staged.append(update)
	for member: Dictionary in family.members:
		if not updates.has(member.id): return _no("Existing residents must remain in their household.")
	var relations: Variant=command.get("relations",family.get("relations",[]))
	if not Character.relations_valid(relations,staged): return _no("Check family ties: partners must be adults, parents must be older, and relatives cannot be partners.")
	# Validate the entire household before creating residents or touching live state.
	family.name=command.name.strip_edges()
	for index in range(members.size()):
		var update: Dictionary=updates[members[index].id]
		var owned: Dictionary={}
		for resident: Dictionary in family.members:
			if resident.id==update.id: owned=resident
		if owned.is_empty():
			owned=create_member.call(family,update.id,update.name)
			family.members.append(owned)
		for key: String in ["name","favorite","appearance","character"]:
			if update.has(key): owned[key]=update[key]
		for key: String in owned.appearance: owned.appearance[key]=int(owned.appearance[key])
	if command.has("relations") or family.has("relations"):
		family.relations=relations.duplicate(true)
		for link: Dictionary in family.relations: link.kind=int(link.kind)
	family.identity_revision=int(family.get("identity_revision",0))+1
	return {"ok":true,"message":"Household updated."}

static func new_id(family: Dictionary, index: int) -> String:
	return str(family.id)+"_c"+str(int(family.get("identity_revision",0)))+"_"+str(index)

static func _no(message: String) -> Dictionary:
	return {"ok":false,"message":message}
