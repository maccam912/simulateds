extends RefCounted
## Tabletop-specific queries retain their meaning as more shared leisure is added.
const Leisure = preload("res://game/shared_leisure.gd")
const CAPACITY := 4
const SOCIAL_RATE := 5.0

static func activity(world: Dictionary, member: Dictionary) -> Dictionary:
	return Leisure.activity(world,member,"game_table")

static func is_shared(world: Dictionary, member: Dictionary) -> bool:
	return Leisure.is_shared(world,member,"game_table")

static func players(world: Dictionary, lot_id: String, object_id: String, arrived_only: bool=true) -> Array[Dictionary]:
	return Leisure.players(world,lot_id,object_id,arrived_only)

static func place(member: Dictionary) -> Vector2i:
	return Leisure.place(member)
