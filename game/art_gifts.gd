extends RefCounted
## Transfer one original through mail escrow. Claimed cards are receipts only.
const Art=preload("res://game/wall_art.gd")
const Paintings=preload("res://game/paintings.gd")

static func send_option(world: Dictionary,owner: String,command: Dictionary) -> Dictionary:
	return Art.transfer_option(world,owner,command)

static func detach(world: Dictionary,plan: Dictionary) -> void:
	Art.detach(world,plan)

static func claim_option(world: Dictionary,owner: String,art: Dictionary) -> Dictionary:
	var home: Dictionary=world.lots[world.families[owner].home_lot]
	if home.building: return _no("Finish construction before collecting this painting. It will keep waiting here.")
	if home.get("artworks",{}).size()>=Art.LIMIT: return _no("Your collection holds 64 paintings. Make room; this gift will keep waiting.")
	if home.get("artworks",{}).has(art.id): return _no("This painting is already in your collection.")
	return {"ok":true,"message":"The original painting will move into your household collection."}

static func collect(world: Dictionary,owner: String,art: Dictionary) -> void:
	var home: Dictionary=world.lots[world.families[owner].home_lot]
	if not home.has("artworks"): home.artworks={}
	home.artworks[art.id]={"picture":art.picture.duplicate(true),"x":-1,"y":-1}; home.revision+=1

static func valid_payload(value: Variant,day: int) -> bool:
	return value is Dictionary and value.size()==2 and Art.valid_id(value.get("id")) and Paintings.valid(value.get("picture"),day) and Paintings.finished(value.picture)

static func valid_custody(world: Dictionary) -> bool:
	var held := {}
	for lot: Dictionary in world.lots.values():
		for entry: Dictionary in Art.sources(lot).values():
			if held.has(entry.art_id): return false
			held[entry.art_id]=true
	for family: Dictionary in world.families.values():
		for entry: Dictionary in family.get("mailbox",{}).get("items",[]):
			if not entry.has("art") or entry.claimed: continue
			if held.has(entry.art.id): return false
			held[entry.art.id]=true
	return true

static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
