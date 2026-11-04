extends SceneTree
const World=preload("res://game/world.gd")
const Paintings=preload("res://game/paintings.gd")
const Hobbies=preload("res://game/hobbies.gd")
var world: RefCounted
var lot: Dictionary
var easel: Dictionary
var alex: Dictionary
var robin: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet"); world.set_online("a",true)
	lot=world.state.lots.lot_1; alex=world.state.families.a.members[0]; robin=world.state.families.a.members[1]
	for member: Dictionary in [alex,robin]: member.autonomy=false
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"easel","x":9,"y":9}).ok)
	easel=lot.objects[-1]
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	alex.x=8; alex.y=9; robin.x=9; robin.y=8
func _paint(member: Dictionary,action: String,subject: String="") -> void:
	assert(world.apply_command("a",{"type":"painting","lot_id":lot.id,"target_id":easel.id,"member_id":member.id,"action":action,"subject":subject,"revision":easel.painting.revision}).ok)
func _work(seconds: float) -> void:
	var target := float(easel.painting.progress)+seconds
	for step in range(500):
		world.step(0.1)
		if float(easel.painting.progress)+0.000001>=target: return
	assert(false,"Painting must make the expected contribution")
func _finish(member: Dictionary) -> void:
	for step in range(400):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"A creative activity must finish")
func _cancel(member: Dictionary) -> void: assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
func _run() -> void:
	_fresh()
	var before: Dictionary=world.snapshot()
	var option: Dictionary=world.hobby_option(alex,"painting")
	assert(option.available and option.inspect and option.target_id==easel.id and world.snapshot()==before)
	assert(not world.apply_command("a",{"type":"practice_hobby","member_id":alex.id,"hobby":"painting"}).ok and world.snapshot()==before,"Hobby navigation must not choose or sell a subject")
	_paint(alex,"start","meadow"); _work(7); _cancel(alex)
	assert(alex.hobbies.painting.sessions==0 and Paintings.work_by(easel.painting,alex.id)==7.0)
	var partial: Dictionary=world.snapshot_for_save()
	var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(partial))))
	assert(replica.state.lots.lot_1.objects[-1].painting.artists==easel.painting.artists and is_equal_approx(replica.state.lots.lot_1.objects[-1].painting.progress,easel.painting.progress))
	_paint(robin,"resume"); _finish(robin)
	assert(alex.hobbies.painting.sessions==1 and robin.hobbies.painting.sessions==1,"Both qualifying contributors earn practice when their shared canvas finishes")
	assert(Paintings.work_by(easel.painting,alex.id)+Paintings.work_by(easel.painting,robin.id)==24.0)
	assert(world.hobby_option(alex,"painting").label=="See your finished painting")
	var progress: Array=[alex.hobbies.duplicate(true),robin.hobbies.duplicate(true)]
	# Arranging and selling existing work never grants practice again.
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"art_hang","lot_id":lot.id,"source":"easel:"+str(easel.id),"x":8,"y":3,"revision":lot.revision}).ok)
	var art_id: String=lot.artworks.keys()[0]
	assert(world.apply_command("a",{"type":"art_return","lot_id":lot.id,"source":"art:"+art_id,"target_id":easel.id,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	_paint(alex,"sell"); _finish(alex)
	assert(alex.hobbies==progress[0] and robin.hobbies==progress[1])
	_paint(alex,"start","harbor"); _finish(alex)
	assert(alex.hobbies.painting.sessions==2 and Hobbies.rank(alex.hobbies.painting)==2 and alex.wishes.journal.any(func(entry): return entry.text.contains("Color explorer")))
	_paint(alex,"sell"); _finish(alex); _paint(alex,"start","flowers"); _finish(alex)
	assert(alex.hobbies.painting.sessions==2 and robin.hobbies.painting.sessions==1,"The daily cap still permits creative recreation")
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.families.a.members[0].hobbies==alex.hobbies)
	world.state.day_minutes=1439.9; world.step(0.1)
	_paint(alex,"sell"); _finish(alex); _paint(alex,"start","meadow"); _work(2); _cancel(alex)
	_paint(robin,"resume"); _finish(robin)
	assert(alex.hobbies.painting.sessions==2 and robin.hobbies.painting.sessions==2 and robin.hobbies.painting.today==1,"Tiny contributions receive artist credit but not practice")
	# Contributions add across interruptions, independent of final task duration.
	_paint(alex,"sell"); _finish(alex); _paint(alex,"start","harbor"); _work(3); _cancel(alex)
	_paint(alex,"resume"); _work(1); _cancel(alex); _paint(robin,"resume"); _finish(robin)
	assert(alex.hobbies.painting.sessions==3 and robin.hobbies.painting.sessions==3)
	# Rank perks affect actual need recovery; they do not shorten or price the art.
	var yields: Array=[]
	for sessions: int in [0,14]:
		_fresh(); alex.hobbies.painting.sessions=sessions
		alex.needs.fun=10.0; alex.needs.comfort=10.0
		_paint(alex,"start","flowers"); _work(1)
		yields.append([alex.needs.fun,alex.needs.comfort]); assert(is_equal_approx(easel.painting.progress,1.0))
		var budget: int=lot.funds; _finish(alex); _paint(alex,"sell"); _finish(alex); assert(lot.funds==budget+60)
	assert(yields[1][0]>yields[0][0]+1.0 and yields[1][1]>yields[0][1]+3.0)
	# Legacy progress stays exact; old artist credit cannot invent measured work.
	var legacy: Dictionary=partial.duplicate(true)
	for family: Dictionary in legacy.families.values():
		for member: Dictionary in family.members:
			member.hobbies.erase("painting"); member.hobbies.reading={"sessions":5,"day":1,"today":1}
	for artist: Dictionary in legacy.lots.lot_1.objects[-1].painting.artists: artist.erase("work_ms")
	assert(replica.restore(JSON.parse_string(JSON.stringify(legacy))))
	var restored: Dictionary=replica.state.families.a.members[0]
	assert(restored.hobbies.reading=={"sessions":5,"day":1,"today":1} and restored.hobbies.painting.sessions==0)
	assert(Paintings.work_by(replica.state.lots.lot_1.objects[-1].painting,restored.id)==0)
	world=replica; lot=world.state.lots.lot_1; easel=lot.objects[-1]; alex=restored; robin=world.state.families.a.members[1]; world.set_online("a",true)
	_paint(robin,"resume"); _finish(robin)
	assert(alex.hobbies.painting.sessions==0 and robin.hobbies.painting.sessions==1)
	# Malformed contribution data and hobby shapes never partially replace a world.
	var clean: Dictionary=world.snapshot()
	for amount: Variant in [-1,0.5,24001,NAN,INF,24000]:
		var bad: Dictionary=clean.duplicate(true); bad.lots.lot_1.objects[-1].painting.artists[0].work_ms=amount
		assert(not world.restore(bad,true) and world.snapshot()==clean)
	for board: Variant in [{},null,{"reading":{"sessions":0,"day":1,"today":0}}, {"reading":{},"gardening":{},"cooking":{},"unknown":{}}]:
		var bad: Dictionary=clean.duplicate(true); bad.families.a.members[0].hobbies=board
		assert(not world.restore(bad,true) and world.snapshot()==clean)
	world.set_online("a",false); progress=[alex.hobbies.duplicate(true),robin.hobbies.duplicate(true)]
	for step in range(1000): world.step(1.0)
	assert(alex.hobbies==progress[0] and robin.hobbies==progress[1])
	print("PAINTING_HOBBY_PASS"); quit()
