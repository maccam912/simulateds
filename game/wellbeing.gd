extends RefCounted
## Presentation vocabulary derived from needs; it does not add a second stat.
const ORDER := ["hunger","energy","hygiene","bladder","fun","social","comfort"]
const ACTIONS := {"fridge":"Have a bite to eat","bed":"Get some sleep","shower":"Take a shower","toilet":"Use the bathroom","tv":"Watch a little TV","bookshelf":"Read a good book","table":"Have a cup of tea","sofa":"Put your feet up","plant":"Tend the plants","chat":"Have a chat","game_table":"Play a tabletop game","stereo":"Dance to some music"}
const LOW := {"hunger":"Hungry","energy":"Tired","hygiene":"Needs a wash","bladder":"Needs the bathroom","fun":"Bored","social":"Lonely","comfort":"Uncomfortable"}
const URGENT := {"hunger":"Very hungry","energy":"Exhausted","hygiene":"Really needs a wash","bladder":"Bathroom, please!","fun":"Restless","social":"Missing company","comfort":"Needs a proper rest"}
const FURNISHINGS := {"hunger":"fridge","energy":"bed","hygiene":"shower","bladder":"toilet","fun":"television or bookshelf","social":"tea table or another resident","comfort":"sofa or plant"}

static func mood(needs: Dictionary) -> Dictionary:
	var lowest := "hunger"
	var value := 100.0
	for need: String in ORDER:
		if float(needs.get(need,100))<value: lowest=need; value=float(needs[need])
	if value<20: return {"label":URGENT[lowest],"tone":"low","need":lowest}
	if value<45: return {"label":LOW[lowest],"tone":"low" if value<30 else "warm","need":lowest}
	return {"label":"Feeling great" if value>=75 else "Content" if value>=55 else "Doing okay","tone":"good","need":lowest}

static func restores(kind: String, need: String) -> bool:
	if kind=="chat": return need=="social"
	if kind=="dining_table": return need in ["hunger","comfort"]
	if kind=="admire_art": return need in ["fun","comfort"]
	var item: Dictionary=preload("res://game/catalog.gd").ITEMS.get(kind,{})
	return item.get("need","")==need or (need=="comfort" and kind in ["bed","easel"])
