extends RefCounted
## Presentation-only interpolation between accepted simulation positions.
const World = preload("res://game/world.gd")
const Facing = preload("res://game/resident_facing.gd")
var tracks: Dictionary = {}
var _router = World.new()
var _lot := ""
var _revision := -1

func update(world: Dictionary, lot_id: String, delta: float, reduced: bool, duration: float = 0.22) -> void:
	if not world.get("lots",{}).has(lot_id): tracks.clear(); return
	var lot: Dictionary=world.lots[lot_id]
	if _lot!=lot_id or _revision!=int(lot.revision):
		tracks.clear(); _lot=lot_id; _revision=int(lot.revision)
	_router.state=world
	var seen := {}
	for family: Dictionary in world.get("families",{}).values():
		for member: Dictionary in family.members:
			if member.lot_id!=lot_id: continue
			var id: String=member.id
			seen[id]=true
			var target := Vector2(int(member.x),int(member.y))
			if not tracks.has(id): tracks[id]={"position":target,"target":target,"route":[],"speed":0.0,"walked":0.0,"heading":Facing.REST,"facing":Facing.REST,"snap":true}
			var track: Dictionary=tracks[id]
			if track.target!=target:
				var start := Vector2i(track.target)
				var route: Array=_router._path(lot,start,[Vector2i(target)])
				if Vector2(start).distance_to(target)>4.0 or route.is_empty() or route.size()+track.route.size()>8:
					track.position=target; track.route.clear(); track.snap=true
				else:
					for cell: Array in route: track.route.append(Vector2(int(cell[0]),int(cell[1])))
				track.target=target
				var distance := 0.0
				var previous: Vector2=track.position
				for waypoint: Vector2 in track.route:
					distance+=previous.distance_to(waypoint); previous=waypoint
				track.speed=maxf(4.5,distance/maxf(0.05,duration))
			if reduced:
				if not track.route.is_empty():
					var previous: Vector2=track.route[-2] if track.route.size()>1 else track.position
					track.heading=(target-previous).normalized()
				track.position=target; track.target=target; track.route.clear(); track.snap=true
			var travel := maxf(0.0,delta)*float(track.speed)
			while travel>0.0 and not track.route.is_empty():
				var point: Vector2=track.route[0]
				var distance: float=Vector2(track.position).distance_to(point)
				if distance>0.00001: track.heading=(point-Vector2(track.position)).normalized()
				var step := minf(travel,distance)
				track.position=Vector2(track.position).move_toward(point,step)
				track.walked+=step
				travel-=step
				if distance<=step+0.00001: track.position=point; track.route.pop_front()
	for id: String in tracks.keys():
		if not seen.has(id): tracks.erase(id)

	# All positions settle first so both sides of a conversation use the same frame.
	for family: Dictionary in world.get("families",{}).values():
		for member: Dictionary in family.members:
			if member.lot_id!=lot_id: continue
			var track: Dictionary=tracks[member.id]
			var desired: Vector2=track.heading
			if not track.route.is_empty():
				desired=(Vector2(track.route[0])-Vector2(track.position)).normalized()
			else:
				var attention := Facing.direction(Facing.activity(world,member),member,tracks)
				var path: Array=member.get("task",{}).get("path",[])
				if not attention.is_zero_approx(): desired=attention
				elif not path.is_empty():
					var next := Vector2(float(path[0][0]),float(path[0][1]))-Vector2(track.position)
					if next.length()<=1.5 and not next.is_zero_approx(): desired=next.normalized()
			if desired.is_zero_approx(): desired=Facing.REST
			track.heading=desired
			track.facing=desired if track.snap or reduced else Vector2.from_angle(rotate_toward(Vector2(track.facing).angle(),desired.angle(),maxf(0.0,delta)*12.0))
			track.snap=false

func direction(member: Dictionary) -> Vector2:
	return tracks.get(member.id,{}).get("facing",Facing.REST)

func position(member: Dictionary) -> Vector2:
	return tracks.get(member.id,{}).get("position",Vector2(int(member.x),int(member.y)))

func moving(member_id: String) -> bool:
	return not tracks.get(member_id,{}).get("route",[]).is_empty()

func stride(member_id: String) -> float:
	return sin(float(tracks.get(member_id,{}).get("walked",0.0))*TAU*1.4)
