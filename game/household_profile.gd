extends RefCounted
const Pastimes = preload("res://game/pastimes.gd")
const Appearance = preload("res://game/appearance.gd")

static func valid_name(value: Variant, limit: int) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length()>limit: return false
	for index in range(value.length()):
		if value.unicode_at(index)<32 or value.unicode_at(index)==127: return false
	return true

static func edit(family: Dictionary, command: Dictionary) -> Dictionary:
	var revision: Variant=command.get("revision")
	if not (revision is int or revision is float) or not is_finite(float(revision)) or float(revision)!=float(family.get("identity_revision",0)):
		return _no("This household changed. Reopen the editor to see the latest choices.")
	if not valid_name(command.get("name"),64): return _no("Choose a household name between 1 and 64 characters on one line.")
	var members: Variant=command.get("members")
	if not members is Array or members.size()!=family.members.size(): return _no("Include both household members.")
	var updates := {}
	for member: Variant in members:
		if not member is Dictionary or not member.get("id") is String: return _no("Choose a member of your household.")
		var owned: Dictionary = {}
		for resident: Dictionary in family.members:
			if resident.id==member.id: owned=resident
		if owned.is_empty() or updates.has(member.id): return _no("You can only edit each of your own residents once.")
		if not valid_name(member.get("name"),32): return _no("Resident names need 1 to 32 characters on one line.")
		if not Appearance.valid(member.get("appearance")): return _no("Choose colors and hair from the available palette.")
		var favorite: Variant=member.get("favorite",Pastimes.of(owned))
		if not Pastimes.valid(favorite): return _no("Choose a pastime from the available list.")
		updates[member.id]={"name":member.name.strip_edges(),"appearance":member.appearance.duplicate(),"favorite":favorite}
	# Everything is checked before applying either resident's changes.
	family.name=command.name.strip_edges()
	for member: Dictionary in family.members:
		member.name=updates[member.id].name
		member.favorite=updates[member.id].favorite
		member.appearance=updates[member.id].appearance
		for key: String in member.appearance: member.appearance[key]=int(member.appearance[key])
	family.identity_revision=int(family.get("identity_revision",0))+1
	return {"ok":true,"message":"Household updated."}

static func _no(message: String) -> Dictionary:
	return {"ok":false,"message":message}
