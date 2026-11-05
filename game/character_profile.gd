extends RefCounted
## Serializable creator choices. Renderers consume copies; only commands write them.
const MAX_MEMBERS := 8
const AGES := ["Baby", "Toddler", "Child", "Teen", "Young adult", "Adult", "Elder"]
const PRONOUNS := ["They / them", "She / her", "He / him"]
const HAIRSTYLES := ["Side part", "Bob", "Curls", "Close crop", "Long waves", "Ponytail", "Bun", "Coils", "Braids", "Bald"]
const EYES := [Color("70482f"),Color("34312b"),Color("648caa"),Color("66845a"),Color("a58a50"),Color("919b9f"),Color("b0c6cf"),Color("8c7a9a")]
const EYE_NAMES := ["Brown", "Deep brown", "Blue", "Green", "Hazel", "Gray", "Ice", "Violet"]
const COLORS := [Color("526f8a"),Color("e6dac0"),Color("b66b50"),Color("897198"),Color("67866d"),Color("c6a565"),Color("303e55"),Color("c68483"),Color("383737"),Color("f0e9da"),Color("713e47"),Color("7faaa5")]
const COLOR_NAMES := ["Denim", "Linen", "Terracotta", "Lilac", "Sage", "Honey", "Midnight", "Rose", "Charcoal", "Ivory", "Burgundy", "Sea glass"]
const OCCASIONS := ["casual", "formal", "sleep", "swim", "athletic", "party", "outdoors"]
const OCCASION_NAMES := ["Casual", "Formal", "PJs", "Swimming", "Athletic", "Party", "Outdoors"]
const TOPS := ["T-shirt", "Collared shirt", "Knit sweater", "Cardigan", "Blazer", "Tank top", "Pajama shirt", "Swim top"]
const BOTTOMS := ["Straight trousers", "Slim trousers", "Shorts", "A-line skirt", "Long skirt", "Joggers", "Pajama bottoms", "Swim shorts"]
const SHOES := ["Sneakers", "Lace-up shoes", "Ankle boots", "Flats", "Sandals", "Slippers", "Barefoot"]
const ACCESSORIES := ["None", "Round glasses", "Square glasses", "Pendant", "Stud earrings"]
const PATTERNS := ["Plain", "Stripes", "Contrast trim"]
const VOICES := ["Warm", "Bright", "Mellow", "Clear"]
const TRAITS := ["Creative", "Bookworm", "Outgoing", "Homebody", "Active", "Playful", "Neat", "Food lover", "Loves outdoors", "Gentle", "Curious", "Music lover"]
const TRAIT_KINDS := {"Creative":"easel", "Bookworm":"bookshelf", "Outgoing":"table", "Homebody":"sofa", "Active":"stereo", "Playful":"game_table", "Neat":"shower", "Food lover":"dining_table", "Loves outdoors":"plant", "Gentle":"plant", "Curious":"bookshelf", "Music lover":"stereo"}
const INTERESTS := ["Reading", "Television", "Gardening", "Tea & company", "Tabletop games", "Music & dancing", "Painting", "Cooking"]
const INTEREST_KINDS := ["bookshelf", "tv", "plant", "table", "game_table", "stereo", "easel", "dining_table"]
const RELATIONS := ["Housemates", "Partners", "Spouses", "Siblings", "Parent of", "Child of", "Grandparent of", "Grandchild of"]
const REVERSE := [0,1,2,3,5,4,7,6]

static func defaults(member: Dictionary = {}) -> Dictionary:
	var look: Dictionary = member.get("appearance",{})
	var outfits := {}
	for occasion: String in OCCASIONS:
		var top := 0; var bottom := 0; var shoes := 0
		match occasion:
			"formal": top=4; bottom=1; shoes=1
			"sleep": top=6; bottom=6; shoes=5
			"swim": top=7; bottom=7; shoes=6
			"athletic": top=5; bottom=5
			"party": top=1; bottom=3; shoes=3
			"outdoors": top=2; bottom=0; shoes=2
		outfits[occasion]={"top":top,"bottom":bottom,"shoes":shoes,"top_color":int(look.get("shirt",0)),"bottom_color":6,"shoe_color":8,"accessory":0,"accessory_color":5,"pattern":0}
	return {"version":1,"age":5,"pronouns":0,"eyes":0,"hairstyle":int(look.get("style",0)),"height":50,"build":50,"shoulders":50,"hips":50,"face":50,"nose":50,"voice":0,"pitch":50,"traits":[],"likes":[],"dislikes":[],"outfits":outfits,"wearing":"casual"}

static func of(member: Dictionary) -> Dictionary:
	return member.get("character",defaults(member))

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=18 or not integer(value.get("version"),1,1): return false
	for entry: Array in [["age",6],["pronouns",2],["eyes",7],["hairstyle",9],["voice",3],["height",100],["build",100],["shoulders",100],["hips",100],["face",100],["nose",100],["pitch",100]]:
		if not integer(value.get(entry[0]),0,entry[1]): return false
	for key: String in ["traits","likes","dislikes"]:
		var items: Variant=value.get(key)
		if not items is Array or items.size()>(3 if key=="traits" else 8): return false
		var allowed: Array=TRAITS if key=="traits" else INTERESTS
		var seen := {}
		for item: Variant in items:
			if not item is String or not item in allowed or seen.has(item): return false
			seen[item]=true
	for item: String in value.likes:
		if item in value.dislikes: return false
	if not value.get("wearing") is String or not value.wearing in OCCASIONS: return false
	var outfits: Variant=value.get("outfits")
	if not outfits is Dictionary or outfits.size()!=OCCASIONS.size(): return false
	for occasion: String in OCCASIONS:
		var outfit: Variant=outfits.get(occasion)
		if not outfit is Dictionary or outfit.size()!=9: return false
		for entry: Array in [["top",7],["bottom",7],["shoes",6],["top_color",11],["bottom_color",11],["shoe_color",11],["accessory",4],["accessory_color",11],["pattern",2]]:
			if not integer(outfit.get(entry[0]),0,entry[1]): return false
	return true

static func normalize(value: Dictionary) -> void:
	for key: String in value:
		if value[key] is float: value[key]=int(value[key])
	for outfit: Dictionary in value.outfits.values():
		for key: String in outfit: outfit[key]=int(outfit[key])

static func height_scale(profile: Dictionary) -> float:
	return [0.40,0.52,0.70,0.92,1.0,1.0,0.96][int(profile.age)] * lerpf(0.88,1.12,float(profile.height)/100.0)

static func is_baby(member: Dictionary) -> bool:
	return int(member.get("character",{}).get("age",5))==0

static func activity_bias(member: Dictionary, kind: String) -> float:
	if not member.has("character"): return 0.0
	var profile: Dictionary=member.character
	var bias := 0.0
	for trait_name: String in profile.traits:
		if TRAIT_KINDS.get(trait_name)==kind: bias+=2.0
	var interest := INTEREST_KINDS.find(kind)
	if interest>=0:
		if INTERESTS[interest] in profile.likes: bias+=4.0
		if INTERESTS[interest] in profile.dislikes: bias-=4.0
	return bias

static func relations_valid(value: Variant, members: Array) -> bool:
	if not value is Array or value.size()>28: return false
	var residents := {}; var pairs := {}; var ancestors := {}; var partners := {}
	for member: Dictionary in members: residents[member.id]=member
	for link: Variant in value:
		if not link is Dictionary or link.size()!=3 or not link.get("a") is String or not link.get("b") is String or link.a==link.b or not residents.has(link.a) or not residents.has(link.b) or not integer(link.get("kind"),1,7): return false
		var ids: Array=[link.a,link.b]; ids.sort(); var key: String=str(ids)
		if pairs.has(key): return false
		pairs[key]=int(link.kind)
		var age_a := int(of(residents[link.a]).age); var age_b := int(of(residents[link.b]).age)
		if int(link.kind) in [1,2]:
			if age_a<4 or age_b<4 or partners.has(link.a) or partners.has(link.b): return false
			partners[link.a]=link.b; partners[link.b]=link.a
		elif int(link.kind) in [4,5,6,7]:
			var reverse := int(link.kind) in [5,7]
			var older: String=link.b if reverse else link.a; var younger: String=link.a if reverse else link.b
			var gap := int(of(residents[older]).age)-int(of(residents[younger]).age)
			if gap<(2 if int(link.kind) in [6,7] else 1) or int(of(residents[older]).age)<4: return false
			if not ancestors.has(younger): ancestors[younger]=[]
			ancestors[younger].append(older)
	# Reject romantic relationships between known ancestors or siblings, including
	# siblings implied by a shared parent. Pair order never changes this rule.
	for id: String in partners:
		var other: String=partners[id]
		var first := _ancestors(id,ancestors); var second := _ancestors(other,ancestors)
		if other in first or id in second: return false
		for ancestor: String in first:
			if ancestor in second: return false
		for link: Dictionary in value:
			if int(link.kind)==3 and ((link.a==id and link.b==other) or (link.b==id and link.a==other)): return false
	return true

static func _ancestors(id: String, links: Dictionary) -> Array:
	var result: Array=[]; var pending: Array=links.get(id,[]).duplicate()
	while not pending.is_empty():
		var next: String=pending.pop_back()
		if next in result: continue
		result.append(next); pending.append_array(links.get(next,[]))
	return result

static func relation_label(family: Dictionary, first: String, second: String) -> String:
	for link: Dictionary in family.get("relations",[]):
		var kind := 0
		if link.a==first and link.b==second: kind=int(link.kind)
		elif link.b==first and link.a==second: kind=REVERSE[int(link.kind)]
		if kind>0: return ["Housemate","Partner","Spouse","Sibling","Child","Parent","Grandchild","Grandparent"][kind]
	return ""
