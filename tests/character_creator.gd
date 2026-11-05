extends SceneTree
const World = preload("res://game/world.gd")
const Profile = preload("res://game/character_profile.gd")
const Household = preload("res://game/household_profile.gd")
const Appearance = preload("res://game/appearance.gd")
const Transfer = preload("res://network/household_transfer.gd")
var world: RefCounted
var family: Dictionary

func _initialize() -> void: call_deferred("_run")

func _command() -> Dictionary:
	var members: Array=[]
	for resident: Dictionary in family.members:
		members.append({"id":resident.id,"name":resident.name,"appearance":Appearance.of(resident).duplicate(true),"favorite":resident.favorite,"character":Profile.of(resident).duplicate(true)})
	return {"type":"household_edit","revision":family.identity_revision,"name":family.name,"members":members,"relations":family.get("relations",[]).duplicate(true)}

func _run() -> void:
	world=World.new(); world.initialize(); world.ensure_family("owner","Alex"); world.ensure_family("neighbor","Robin")
	family=world.state.families.owner
	var before: Dictionary=world.snapshot()
	var command := _command()
	assert(Profile.valid(command.members[0].character))
	command.members[0].character.merge({"eyes":3,"height":82,"build":68,"hairstyle":7,"age":6,"traits":["Creative","Gentle","Bookworm"],"likes":["Painting","Reading"],"dislikes":["Television"],"voice":2,"pitch":37},true)
	command.members[0].character.outfits.formal.top_color=10
	command.members[0].character.outfits.swim.bottom=7
	command.members[1].character.age=4
	for index in range(2,8):
		var member := {"id":Household.new_id(family,index),"name":"Resident "+str(index),"appearance":Appearance.defaults({}),"favorite":"variety"}
		member.character=Profile.defaults(member); member.character.age=index-2
		command.members.append(member)
	command.relations=[{"a":command.members[0].id,"b":command.members[1].id,"kind":4},{"a":command.members[1].id,"b":command.members[2].id,"kind":4},{"a":command.members[0].id,"b":command.members[2].id,"kind":6}]
	assert(world.apply_command("owner",command).ok,"Complete multigeneration household is accepted atomically")
	assert(family.members.size()==8 and family.identity_revision==1)
	assert(world.state.lots==before.lots and world.state.families.neighbor==before.families.neighbor)
	assert(family.members[0].needs==before.families.owner.members[0].needs)
	assert(family.members[0].character.outfits.formal.top_color==10 and family.members[0].character.outfits.casual.top_color!=10)
	assert(Profile.activity_bias(family.members[0],"bookshelf")>0 and Profile.activity_bias(family.members[0],"tv")<0)
	var baby: Dictionary=family.members[2]
	var needs: Dictionary=baby.needs.duplicate(true); var at := Vector2(baby.x,baby.y)
	assert(not world.apply_command("owner",{"type":"move","member_id":baby.id,"x":9,"y":9}).ok)
	assert(not world.travel_option("owner",world.state.families.neighbor.home_lot,[baby.id]).ok)
	world.step(0.5)
	assert(needs.keys().all(func(key): return baby.needs[key]>=needs[key]) and Vector2(baby.x,baby.y)==at and baby.task.is_empty(),"Babies keep comfortable needs and remain in their bassinet; nearby company may improve social need")
	var saved: Dictionary=world.snapshot(); var loaded := World.new()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(loaded.state.families.owner.members[0].character==family.members[0].character)
	assert(loaded.state.families.owner.relations==family.relations and loaded.state.families.owner.members.size()==8)
	var accepted: Dictionary=world.snapshot()
	assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted)
	for defect in range(10):
		var bad := _command()
		match defect:
			0: bad.members[0].character.height=NAN
			1: bad.members[0].character.height=101
			2: bad.members[0].character.eyes=1.5
			3: bad.members[0].character.outfits.erase("formal")
			4: bad.members[0].character.likes=["Reading"]; bad.members[0].character.dislikes=["Reading"]
			5: bad.members[0].character.traits=["Gentle","Gentle"]
			6: bad.members[0].character.traits=Profile.TRAITS.duplicate()
			7: bad.members[0].id=world.state.families.neighbor.members[0].id
			8: bad.relations=[{"a":bad.members[0].id,"b":bad.members[2].id,"kind":2}]
			9: bad.relations.append({"a":bad.members[0].id,"b":bad.members[1].id,"kind":2})
		assert(not world.apply_command("owner",bad).ok and world.snapshot()==accepted,"Invalid creator edit is atomic: "+str(defect))
	var malformed := saved.duplicate(true); malformed.families.owner.members[0].character.outfits.formal.top=-1
	assert(not loaded.restore(malformed))
	var legacy := before.duplicate(true); legacy.schema=1
	assert(loaded.restore(legacy) and loaded.state.schema==World.SCHEMA and loaded.state.families.owner.members.size()==2)
	assert(loaded.state.families.owner.members[0].appearance==before.families.owner.members[0].appearance)
	var future := saved.duplicate(true); future.schema=99; assert(not loaded.restore(future))
	var ties: Array=family.relations.duplicate(true); var revision: int=family.identity_revision
	assert(world.apply_command("owner",{"type":"rename_family","name":"Rowan"}).ok)
	assert(family.identity_revision==revision+1 and family.relations==ties,"Renaming invalidates stale creators without changing family ties")
	_test_transfer(_command())
	print("CHARACTER_CREATOR_PASS"); quit()

func _test_transfer(command: Dictionary) -> void:
	# Maximum supported household goes through small packets, never partial edits.
	command.name="😀".repeat(64)
	for member: Dictionary in command.members: member.name="😀".repeat(32)
	var packets: Array=Transfer.packets(17,command)
	assert(packets.size()>1)
	for packet: Dictionary in packets: assert(JSON.stringify(packet).to_utf8_buffer().size()<=1024)
	var transfer := Transfer.new(); var result := {}
	for index in range(packets.size()-1,-1,-1):
		result=transfer.receive(2,packets[index],100)
		if index>0: assert(result.is_empty())
	assert(result.id==17 and result.intent==JSON.parse_string(JSON.stringify(command)))
	var half: int=packets.size()/2
	for index in range(half): assert(transfer.receive(2,packets[index],200).is_empty())
	for index in range(half,packets.size()): assert(transfer.receive(3,packets[index],200).is_empty(),"Assemblies are isolated per authenticated sender")
	assert(transfer.receive(2,packets[-1],10300).is_empty(),"Expired partial edits cannot apply")
	var bad: Dictionary=packets[0].duplicate(true); bad.count=999999; assert(transfer.receive(4,bad,10400).is_empty())
	bad=packets[0].duplicate(true); bad.size=Transfer.RAW_LIMIT+1; assert(transfer.receive(4,bad,10400).is_empty())
	var session := root.get_node("Session")
	session.set_physics_process(false); session.saving_enabled=false; session.world.restore(world.snapshot(),true)
	session.role="host"; session.players={2:"owner"}
	var original: Dictionary=session.world.snapshot()
	packets=Transfer.packets(19,command)
	for packet: Dictionary in packets: session._receive(999,packet)
	assert(session.world.snapshot()==original,"Unauthenticated creator packets are ignored")
	for index in range(packets.size()):
		session._receive(2,packets[index])
		if index<packets.size()-1: assert(session.world.snapshot()==original)
	assert(session.state.families.owner.identity_revision==original.families.owner.identity_revision+1)
	var applied: Dictionary=session.world.snapshot()
	for packet: Dictionary in packets: session._receive(2,packet)
	assert(session.world.snapshot()==applied,"Duplicate transfer cannot create residents twice")
	session.role="offline"; session.players={}
