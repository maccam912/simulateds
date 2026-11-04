extends RefCounted
## Small shared palette for world residents and the household preview.
const SKIN := [Color("f2d0b1"),Color("e9be99"),Color("e1b58a"),Color("bd8c68"),Color("93654c"),Color("694331")]
const HAIR := [Color("302e2b"),Color("625346"),Color("9e6545"),Color("d2b16e"),Color("8a8b85"),Color("e3ddd0")]
const SHIRT := [Color("557e8b"),Color("ad9975"),Color("be795b"),Color("967a9b"),Color("628e73"),Color("c0b77c"),Color("485b78"),Color("d18f83")]
const STYLES := ["Short","Bob","Curls","Shaved"]
const LABELS := {"skin":["Porcelain","Peach","Warm","Tan","Umber","Deep"],"hair":["Black","Brown","Auburn","Gold","Gray","Silver"],"shirt":["Blue","Sand","Rust","Plum","Fern","Oat","Navy","Rose"]}

static func defaults(member: Dictionary) -> Dictionary:
	return {"skin":2,"hair":1,"shirt":1 if str(member.get("name","")).hash()%2==0 else 0,"style":0}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=4: return false
	for key: String in ["skin","hair","shirt","style"]:
		var number: Variant=value.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)): return false
		var count: int={"skin":SKIN.size(),"hair":HAIR.size(),"shirt":SHIRT.size(),"style":STYLES.size()}[key]
		if int(number)<0 or int(number)>=count: return false
	return true

static func of(member: Dictionary) -> Dictionary:
	var value: Variant=member.get("appearance")
	return value if valid(value) else defaults(member)

static func draw_head(canvas: CanvasItem,p: Vector2,s: float,look: Dictionary,facing: Vector2=Vector2.DOWN) -> void:
	var skin: Color=SKIN[int(look.skin)]; var hair: Color=HAIR[int(look.hair)]
	var style := int(look.style)
	if style==1: canvas.draw_circle(p+Vector2(0,1)*s,7*s,hair)
	canvas.draw_circle(p,6*s,skin)
	match style:
		0: canvas.draw_arc(p+Vector2(0,-1)*s,5.5*s,PI,TAU+0.4,12,hair,3*s,true)
		1:
			canvas.draw_arc(p,5.8*s,PI,TAU,12,hair,3*s,true)
			canvas.draw_line(p+Vector2(-5,-1)*s,p+Vector2(-5,5)*s,hair,2.4*s,true)
			canvas.draw_line(p+Vector2(5,-1)*s,p+Vector2(5,5)*s,hair,2.4*s,true)
		2:
			for index in range(7):
				var angle := PI+float(index)*PI/6.0
				canvas.draw_circle(p+Vector2(cos(angle)*5.8,sin(angle)*5.8-1)*s,2.6*s,hair)
		3: canvas.draw_arc(p+Vector2(0,-0.5)*s,5.5*s,PI,TAU,12,hair,1*s,true)
	# Rear views show hair and ears; side views bring the near eye and nose forward.
	# The default remains a front portrait for the household editor and sleep pose.
	var rear := clampf(-facing.y*3.0,0.0,1.0)
	var side := facing.x
	if rear>0.0:
		var back := hair if style!=3 else skin.darkened(0.08)
		back.a=rear
		canvas.draw_circle(p+Vector2(0,0.4)*s,5.8*s,back)
		if style==1: canvas.draw_line(p+Vector2(-4,4)*s,p+Vector2(4,4)*s,back,4*s,true)
	if absf(side)>0.3:
		canvas.draw_circle(p+Vector2(-signf(side)*4.5,1.3)*s,1.4*s,skin.darkened(0.08))
		if rear<1.0:
			var nose := skin; nose.a=1.0-rear
			canvas.draw_circle(p+Vector2(side*5.8,1.0)*s,1.4*s,nose)
	if rear<1.0:
		for eye in [-1.0,1.0]:
			var ink := Color("42372e"); ink.a=1.0-rear
			if eye*side<0: ink.a*=1.0-absf(side)*0.85
			canvas.draw_circle(p+Vector2(side*2.8+eye*2.0*(1.0-absf(side)*0.7),0.7)*s,0.5*s,ink)
