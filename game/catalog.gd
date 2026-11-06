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
	"stereo": {"name":"Little hi-fi", "cost":260, "size":[1,1], "color":"967450", "need":"fun", "rate":6.0, "duration":18.0, "description":"Make a music corner. Up to four residents can dance in separate places around it; dancing together also restores social."},
	"easel": {"exclusive":true, "name":"Daydream easel", "cost":220, "size":[1,1], "color":"ae8259", "need":"fun", "rate":5.0, "duration":24.0, "description":"Paint a meadow, harbor, or flowers. Restore fun and comfort. Leave the canvas side clear. Unfinished work keeps; finished pictures stay on the easel until you choose to sell them."},
	"bookshelf": {"name":"Story shelf", "cost":160, "size":[1,1], "color":"a7845e", "need":"fun", "rate":6.0, "duration":12.0, "description":"Get lost in a good book."},
	"garden_bed": {"exclusive":true, "name":"Kitchen garden bed", "cost":180, "size":[2,1], "color":"89654d", "need":"comfort", "rate":4.0, "duration":8.0, "description":"Grow radishes or tomatoes. Place on grass or floor, then choose seeds in live mode. Dry crops wait safely; harvest when ripe."},
	"plant": {"name":"Leafy friend", "cost":45, "size":[1,1], "color":"6c9b64", "need":"comfort", "rate":4.0, "duration":8.0, "description":"Tend a little green corner."},
	"dining_table": {"name":"Gathering dining table", "cost":280, "size":[2,2], "color":"bd9e77", "need":"hunger", "rate":8.0, "duration":10.0, "description":"Serve four portions from your fridge. Each resident chooses to eat; sharing a meal also restores social. Leave clear places around the table."},
	"table": {"name":"Tea table", "cost":140, "size":[2,1], "color":"bb9364", "need":"social", "rate":6.5, "duration":12.0, "description":"Share tea and a conversation."},
	"game_table": {"name":"Checkered game table", "cost":340, "size":[2,2], "color":"a88161", "need":"fun", "rate":6.0, "duration":16.0, "description":"A tabletop puzzle for one, or a game for up to four. Restores fun; playing together also restores social. Each resident joins through their own plan."},
	"armchair": {"name":"Reading armchair","cost":175,"size":[1,1],"color":"8fa985","need":"comfort","rate":8,"duration":10,"description":"A deep upholstered chair for a quiet corner."},
	"loveseat": {"name":"Linen loveseat","cost":240,"size":[2,1],"color":"ddd3bc","need":"comfort","rate":8,"duration":10,"description":"A compact two-seat sofa in warm linen."},
	"long_sofa": {"name":"Family sofa","cost":380,"size":[3,1],"color":"88a9bc","need":"comfort","rate":9,"duration":10,"description":"Three generous cushions for a roomy sitting area."},
	"wood_chair": {"name":"Spindle chair","cost":65,"size":[1,1],"color":"bd9e77","need":"comfort","rate":5,"duration":8,"description":"A solid oak chair with an open spindle back."},
	"garden_bench": {"name":"Garden bench","cost":140,"size":[2,1],"color":"9b7955","need":"comfort","rate":6,"duration":10,"description":"A slatted outdoor seat.","outdoor":true},
	"floor_lamp": {"name":"Linen floor lamp","cost":95,"size":[1,1],"color":"e8d5ad","need":"","rate":0,"duration":0,"description":"A tall shaded lamp casting a warm pool of light.","light":[1.45,4.8,1.5,"ffe1ac"]},
	"arc_lamp": {"name":"Brass reading lamp","cost":125,"size":[1,1],"color":"c3a573","need":"","rate":0,"duration":0,"description":"An angled reading lamp with soft golden light.","light":[1.3,3.5,1.2,"ffdd9a"]},
	"globe_lamp": {"name":"Opal globe lamp","cost":110,"size":[1,1],"color":"eee7d5","need":"","rate":0,"duration":0,"description":"A glowing opal globe on a slim stand.","light":[1.25,4.0,1.35,"fff1d5"]},
	"pendant_lamp": {"name":"Kitchen pendant","cost":130,"size":[1,1],"color":"8fa985","need":"","rate":0,"duration":0,"description":"A hanging enamel shade over its own clear floor tile.","light":[1.85,5.2,1.7,"fff0cd"]},
	"garden_lantern": {"name":"Garden lantern","cost":85,"size":[1,1],"color":"536c65","need":"","rate":0,"duration":0,"description":"A low lantern for paths and garden borders.","outdoor":true,"light":[0.72,3.0,1.4,"ffdca1"]},
	"lamp_post": {"name":"Porch lamp post","cost":160,"size":[1,1],"color":"536c65","need":"","rate":0,"duration":0,"description":"A tall outdoor lantern with warm light.","outdoor":true,"light":[2.4,5.0,2.0,"ffe3b0"]},
	"linden_tree": {"name":"Linden tree","cost":180,"size":[2,2],"color":"6b9153","need":"","rate":0,"duration":0,"description":"A leafy shade tree with a solid trunk and branching canopy.","outdoor":true},
	"hedge": {"name":"Garden hedge","cost":45,"size":[1,1],"color":"6b9153","need":"","rate":0,"duration":0,"description":"A dense leafy border shrub.","outdoor":true},
	"flowers": {"name":"Cottage flowers","cost":30,"size":[1,1],"color":"df9785","need":"","rate":0,"duration":0,"description":"A mixed clump of original modeled flowers.","outdoor":true},
	"picket_fence": {"name":"Picket fence","cost":35,"size":[1,1],"color":"eee7d5","need":"","rate":0,"duration":0,"description":"A painted garden fence segment. Rotate to follow the border.","outdoor":true},
	"boulder": {"name":"Garden boulder","cost":55,"size":[1,1],"color":"9b9e8c","need":"","rate":0,"duration":0,"description":"A rounded natural stone for the garden.","outdoor":true},
	"stairs": {"name":"Oak staircase","cost":550,"size":[1,3],"color":"a17c58","need":"","rate":0,"duration":0,"description":"A straight staircase connecting this floor to the one above. Keep both landings clear."}
}

static func footprint(kind: String, rotation: int = 0) -> Vector2i:
	var item: Dictionary = ITEMS.get(kind, {})
	var size: Array = item.get("size", [1,1])
	return Vector2i(int(size[1]), int(size[0])) if rotation % 2 else Vector2i(int(size[0]), int(size[1]))
