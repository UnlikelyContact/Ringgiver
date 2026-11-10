class_name Palette
extends RefCounted
## The decided look (concept-art-prompts.md): madder red, woad blue, walnut,
## undyed grey, cold northern light. Hard outlines, limited palette.

const BG := Color("3b3f44")
const GROUND := Color("5a5f55")
const GROUND_LINE := Color("4a4f47")
const MUD := Color("4a4036")
## Terrain (BattleView._draw_ground, _draw_feature): water in a cold blue,
## the ford paler, the slope a lighter turf; trees, rocks and fences on
## top; the hall in dark timber with a lighter roof ridge.
const WATER := Color("34506b")
const FORD := Color("5f7d93")
const RIPPLE := Color("a9bfcd")
const SLOPE := Color("737862")
const HATCH := Color("8f9479")
const TREE := Color("2f4a2c")
const TREE_LIGHT := Color("3f5e38")
const TRUNK := Color("4a3420")
const ROCK := Color("85878a")
const ROCK_DARK := Color("5d5f62")
const FENCE := Color("7a5634")
const TIMBER := Color("3a2a1c")
const ROOF := Color("7a6450")
const DOOR := Color("a08664")
const PLANK := Color("8a6a46")
const OUTLINE := Color("1c1a18")
const MADDER := Color("8b2a24")
const WOAD := Color("2f4a7a")
const WALNUT := Color("6b4a2e")
const UNDYED := Color("b9b2a3")
const BONE := Color("e4dccb")
const IRON := Color("8e9398")
const GOLD := Color("c9a227")
const BLOOD := Color("b5261e")
const WARN := Color("e0b43a")
const HEARD := Color("7bbf5a")
const BREATH := Color("9fb3c8")
const TEXT := Color("e8e2d6")
const DIM := Color("9a948a")
## Objective ground: the ford in bone, the ships' strand in blue-grey, the
## hall in gold.
const SHIPS := Color("a3b4c9")


static func objective_color(kind: int) -> Color:
	match kind:
		Objective.Kind.REACH_THE_SHIPS:
			return SHIPS
		Objective.Kind.THE_HALL:
			return GOLD
		_:
			return BONE

## Side colours: the player's band in madder, the enemy in woad.
static func side_color(side: int) -> Color:
	return MADDER if side == 0 else WOAD
