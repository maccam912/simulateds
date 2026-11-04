extends SceneTree
const Audio = preload("res://game/activity_audio.gd")
var sampler = Audio.new()
var residents: Array[Dictionary]=[]

func _initialize() -> void:
	call_deferred("_run")

func _resident(id: String="a") -> Dictionary:
	return {"id":id,"cell":Vector2.ZERO,"position":Vector2(100,100),"kind":"","task":"","elapsed":0.0,"walking":false,"indoors":true}

func _sample(delta: float=0.2, active: bool=true, context: String="lot_1") -> Array[Dictionary]:
	return sampler.sample(context,residents,delta,active)

func _run() -> void:
	residents=[_resident()]
	var member: Dictionary=residents[0]
	assert(_sample().is_empty())
	member.walking=true; member.cell=Vector2(0.7,0)
	assert(_sample().is_empty())
	member.cell=Vector2(1.4,0)
	var events := _sample()
	assert(events.size()==1 and events[0].sound=="step_wood" and events[0].position==Vector2(100,100))
	member.cell=Vector2(2.8,0)
	assert(_sample(0.1).is_empty(),"Per-resident footsteps cannot chatter at high frame rates")
	member.cell=Vector2(3.5,0); member.indoors=false
	events=_sample(0.5); assert(events.size()==1 and events[0].sound=="step_grass")
	member.cell=Vector2(12,12)
	assert(_sample().is_empty(),"Teleporting does not sound like a walk")
	member.walking=false
	for kind: String in Audio.ACTIVITIES:
		sampler.reset(); member.task="task_"+kind; member.kind=""; member.elapsed=0.0
		assert(_sample().is_empty())
		member.kind=kind; member.elapsed=0.1
		events=_sample()
		assert(events.size()==1 and events[0].sound==Audio.ACTIVITIES[kind][0],"Every supported activity has a bounded onset cue")
		for index in range(10): assert(_sample().is_empty(),"An unchanged snapshot cannot keep making activity sounds")
		var interval: float=Audio.ACTIVITIES[kind][1]
		member.elapsed=maxf(1.0,interval)+0.1
		assert(_sample().size()==(1 if interval>0.0 else 0),"Only repeating textures repeat, on accepted activity progress")
	member.kind="bookshelf"; member.task="reading"; member.elapsed=20.0
	assert(_sample(0.2,false).is_empty() and sampler.tracks.is_empty())
	assert(_sample().is_empty(),"Resuming a menu, mute, or pause does not replay old cues")
	member.elapsed=25.1
	assert(_sample().size()==1)
	assert(_sample(0.2,true,"lot_2").is_empty(),"Opening another lot starts without a chorus")
	residents.clear(); _sample()
	assert(sampler.tracks.is_empty(),"Offscreen and departed residents do not retain sound tracks")
	# A last footstep can briefly occupy the mix gap when a short activity starts.
	residents=[_resident()]; member=residents[0]; sampler.reset(); _sample()
	member.walking=true; member.cell=Vector2(1.4,0); assert(_sample().size()==1)
	member.walking=false; member.kind="bookshelf"; member.task="short-reading"; member.elapsed=0.1
	assert(_sample(0.05).is_empty())
	member.elapsed=0.2; events=_sample(0.14)
	assert(events.size()==1 and events[0].sound=="page","A still-running short activity gets its onset after the footstep gap")
	assert(_sample().is_empty(),"The retained onset plays only once")
	sampler.reset(); member.kind=""; member.task=""; member.elapsed=0; _sample()
	member.walking=true; member.cell+=Vector2(1.4,0); assert(_sample().size()==1)
	member.walking=false; member.kind="table"; member.task="cancelled-tea"; member.elapsed=0.1
	assert(_sample(0.05).is_empty())
	member.kind=""; member.task=""; member.elapsed=0
	assert(_sample(0.2).is_empty(),"Cancellation discards an onset still waiting for the mix gap")
	# Several residents starting together alternate representation, with no backlog.
	residents=[_resident("a"),_resident("b")]; sampler.reset(); _sample()
	for resident: Dictionary in residents: resident.kind="bookshelf"; resident.task="read"; resident.elapsed=0.1
	events=_sample(); assert(events.size()==1)
	var first: String=events[0].member
	for resident: Dictionary in residents: resident.elapsed=5.1
	events=_sample(); assert(events.size()==1 and events[0].member!=first,"Simultaneous residents share the limited sound mix")
	residents.clear(); sampler.reset()
	for index in range(8): residents.append(_resident(str(index)))
	_sample()
	var count := 0
	var heard := {}
	for frame in range(600):
		for resident: Dictionary in residents:
			resident.cell.x+=0.08; resident.walking=true
		for event: Dictionary in _sample(1.0/60.0):
			count+=1; heard[event.member]=true
	assert(count<=56 and count>10 and heard.size()==8,"Eight walkers stay bounded and every resident can be heard")
	var sound: Node=root.get_node("Soundscape")
	assert(not sound.enabled and sound._world_effects.is_empty())
	sound.sync_world(true,"test")
	assert(not sound.play_world({"sound":"page","position":Vector2.ZERO}),"Headless simulation never starts audio")
	print("ACTIVITY_AUDIO_PASS")
	quit()
