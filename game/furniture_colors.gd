extends RefCounted
## A bounded material palette. Missing metadata preserves every legacy color.
const Catalog = preload("res://game/catalog.gd")
const PALETTE := {
	"original":{"name":"Original","color":"d8ccb1"},
	"sage":{"name":"Sage","color":"8fa985"},
	"sky":{"name":"Sky","color":"88a9bc"},
	"rose":{"name":"Rose","color":"c58f8d"},
	"honey":{"name":"Honey","color":"c9a363"},
	"ink":{"name":"Ink","color":"596d78"}
}
const MATERIALS := {"bed":"Bedding","sofa":"Upholstery","fridge":"Enamel","shower":"Wall panel","toilet":"Porcelain","tv":"Cabinet","stereo":"Cabinet","bookshelf":"Woodwork","plant":"Pot","table":"Woodwork","game_table":"Woodwork","garden_bed":"Frame"}

static func at(object: Dictionary) -> String: return str(object.get("color_style","original"))

static func valid(object: Dictionary) -> bool:
	return not object.has("color_style") or (object.color_style is String and PALETTE.has(object.color_style) and MATERIALS.has(object.get("kind")))

static func material(object: Dictionary, original: String, lightness: float=0.0) -> Color:
	var style := at(object)
	if style=="original" or not PALETTE.has(style): return Color(original)
	var color := Color(PALETTE[style].color)
	return color.lightened(lightness) if lightness>=0.0 else color.darkened(-lightness)

static func set_style(object: Dictionary, style: String) -> void:
	if style=="original": object.erase("color_style")
	else: object.color_style=style

static func inspect(lot: Dictionary, command: Dictionary) -> Dictionary:
	if not command.get("object_id") is String or not command.get("style") is String or not PALETTE.has(command.style): return {"ok":false,"message":"Choose a furnishing and a color from the palette."}
	var object: Dictionary={}
	for item: Dictionary in lot.get("objects",[]):
		if item.id==command.object_id: object=item; break
	if object.is_empty() or not MATERIALS.has(object.kind): return {"ok":false,"message":"Choose a furnishing to recolor."}
	var result := {"ok":at(object)!=command.style,"object_id":str(object.id),"style":str(command.style),"kind":str(object.kind),"x":int(object.x),"y":int(object.y),"rotation":int(object.rotation)}
	if not result.ok:
		result.reason="unchanged"; result.message=str(Catalog.ITEMS[object.kind].name)+" · Already "+str(PALETTE[command.style].name)
	else: result.message=str(Catalog.ITEMS[object.kind].name)+" · "+str(MATERIALS[object.kind])+": "+str(PALETTE[command.style].name)+" · Free · Click to apply"
	return result

static func is_applied(lot: Dictionary, command: Dictionary) -> bool:
	return lot.get("objects",[]).any(func(object): return object.id==command.get("object_id") and at(object)==command.get("style"))
