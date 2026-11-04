extends RefCounted
## Cosmetic light follows the shared clock. Homes have automatic evening lights.
const HOURS := [0.0,5.0,6.5,8.0,16.5,18.5,20.0,24.0]
const TINTS := [Color(0.07,0.12,0.25,0.64),Color(0.07,0.12,0.25,0.64),Color(0.51,0.32,0.34,0.24),Color.TRANSPARENT,Color.TRANSPARENT,Color(0.67,0.30,0.15,0.22),Color(0.07,0.12,0.25,0.64),Color(0.07,0.12,0.25,0.64)]
const NIGHT := [1.0,1.0,0.4,0.0,0.0,0.35,1.0,1.0]

static func sample(minutes: float) -> Dictionary:
	var hour := fposmod(minutes,1440.0)/60.0
	var index := 0
	while index<HOURS.size()-2 and hour>HOURS[index+1]: index+=1
	var blend := smoothstep(HOURS[index],HOURS[index+1],hour)
	var phase := "Night"
	if hour>=5 and hour<8: phase="Dawn"
	elif hour>=8 and hour<17: phase="Daytime"
	elif hour>=17 and hour<20: phase="Evening"
	return {"overlay":TINTS[index].lerp(TINTS[index+1],blend),"night":lerpf(NIGHT[index],NIGHT[index+1],blend),"phase":phase}

static func outside(color: Color, light: Dictionary) -> Color:
	return color.blend(light.overlay)
