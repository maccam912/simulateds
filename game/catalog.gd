extends RefCounted
## Furniture is data. Add a catalog entry and a corresponding renderer to grow it.
const ITEMS: Dictionary = {
	"floor": {"name":"Oak floor", "cost":12, "size":[1,1], "color":"cfa77b", "need":"", "rate":0.0, "duration":0.0, "description":"A warm oak tile for your home."},
	"wall": {"name":"Cream wall", "cost":30, "size":[1,1], "color":"e7deca", "need":"", "rate":0.0, "duration":0.0, "description":"A solid wall tile. Leave room for a door."},
	"door": {"name":"Front door", "cost":55, "size":[1,1], "color":"93704f", "need":"", "rate":0.0, "duration":0.0, "description":"Replaces a wall with a walkable doorway."},
	"bed": {"exclusive":true, "name":"Cloud bed", "cost":450, "size":[1,2], "color":"8eabc9", "need":"energy", "rate":5.5, "duration":18.0, "description":"Sleep well. Restores energy and comfort."},
	"fridge": {"exclusive":true, "name":"Kitchen fridge", "cost":350, "size":[1,1], "color":"e9e9d9", "need":"hunger", "rate":8.0, "duration":10.0, "description":"Fix a simple meal. Restores hunger."},
	"shower": {"exclusive":true, "name":"Rain shower", "cost":320, "size":[1,1], "color":"94cbd1", "need":"hygiene", "rate":9.0, "duration":9.0, "description":"Wash away a busy day."},
	"toilet": {"exclusive":true, "name":"Porcelain toilet", "cost":180, "size":[1,1], "color":"f1eee2", "need":"bladder", "rate":14.0, "duration":6.0, "description":"A small but essential comfort."},
	"sofa": {"name":"Sunday sofa", "cost":280, "size":[2,1], "color":"d2866e", "need":"comfort", "rate":8.0, "duration":10.0, "description":"Put your feet up and take a breather."},
	"tv": {"name":"Little television", "cost":250, "size":[1,1], "color":"697480", "need":"fun", "rate":7.0, "duration":12.0, "description":"Watch something wonderfully silly."},
	"bookshelf": {"name":"Story shelf", "cost":160, "size":[1,1], "color":"a7845e", "need":"fun", "rate":6.0, "duration":12.0, "description":"Get lost in a good book."},
	"plant": {"name":"Leafy friend", "cost":45, "size":[1,1], "color":"6c9b64", "need":"comfort", "rate":4.0, "duration":8.0, "description":"Tend a little green corner."},
	"table": {"name":"Tea table", "cost":140, "size":[2,1], "color":"bb9364", "need":"social", "rate":6.5, "duration":12.0, "description":"Share tea and a conversation."}
}

static func footprint(kind: String, rotation: int = 0) -> Vector2i:
	var item: Dictionary = ITEMS.get(kind, {})
	var size: Array = item.get("size", [1,1])
	return Vector2i(int(size[1]), int(size[0])) if rotation % 2 else Vector2i(int(size[0]), int(size[1]))
