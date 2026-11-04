extends SceneTree
const World = preload("res://game/world.gd")
const Appearance = preload("res://game/appearance.gd")
var world: RefCounted
var family: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _command() -> Dictionary:
	var members: Array=[]
	for member: Dictionary in family.members:
		members.append({"id":member.id,"name":member.name,"appearance":member.appearance.duplicate()})
	return {"type":"household_edit","name":family.name,"revision":family.identity_revision,"members":members}

func _run() -> void:
	world=World.new(); world.initialize(); world.ensure_family("owner","Alex"); world.ensure_family("neighbor","Violet")
	family=world.state.families.owner
	var original: Dictionary=world.snapshot()
	var command := _command(); command.name="The Koskis"
	command.members[0].name="Matt"; command.members[0].appearance={"skin":4,"hair":0,"shirt":6,"style":2}
	command.members[1].name="Violet"; command.members[1].appearance={"skin":1,"hair":2,"shirt":3,"style":1}
	assert(world.apply_command("owner",command).ok)
	assert(family.name=="The Koskis" and family.members[1].name=="Violet" and family.members[0].appearance.shirt==6)
	assert(family.members[0].wishes==original.families.owner.members[0].wishes and world.state.lots==original.lots,"Identity changes preserve money, homes, wishes, and needs")
	var accepted: Dictionary=world.snapshot()
	assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted,"Stale editors cannot overwrite newer choices")
	command=_command(); command.members[1].id=world.state.families.neighbor.members[0].id
	assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted,"A neighbor cannot be edited")
	command=_command(); command.members[1].id=command.members[0].id
	assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted,"Duplicate resident IDs are rejected")
	for bad in ["", "\nName", "a".repeat(33)]:
		command=_command(); command.members[0].name="Would change"; command.members[1].name=bad
		assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted,"Invalid second resident leaves the first untouched")
	for bad in [{"skin":0,"hair":0,"shirt":99,"style":0},{"skin":-1,"hair":0,"shirt":0,"style":0},{"skin":1.5,"hair":0,"shirt":0,"style":0},{"skin":0,"hair":0,"shirt":0},"blue"]:
		command=_command(); command.members[1].appearance=bad
		assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted,"Appearance values stay within the supported palette")
	var loaded := World.new()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot()))))
	assert(loaded.state.families.owner.members[1].appearance==family.members[1].appearance,"Appearance survives JSON and numeric normalization")
	var malformed: Dictionary=world.snapshot(); malformed.families.owner.members[0].appearance.skin=999
	assert(not loaded.restore(malformed),"Corrupt saved appearance is rejected atomically")
	var legacy: Dictionary=world.snapshot()
	for household: Dictionary in legacy.families.values():
		household.erase("identity_revision")
		for member: Dictionary in household.members: member.erase("appearance")
	assert(loaded.restore(legacy))
	assert(loaded.state.families.owner.identity_revision==0 and Appearance.valid(loaded.state.families.owner.members[0].appearance),"Older households gain valid defaults")
	assert(world.apply_command("owner",{"type":"rename_family","name":"Matthew"}).ok and family.name=="The Koskis","Profile name changes preserve a custom household name")
	command=_command(); command.name="😀".repeat(64)
	for member: Dictionary in command.members:
		member.id="a".repeat(64)+"_1"; member.name="😀".repeat(32)
	assert(JSON.stringify({"type":"command","id":2147483647,"intent":command}).to_utf8_buffer().size()<=1024,"Largest ordinary editor request fits the transport packet")
	print("HOUSEHOLD_PASS")
	quit()
