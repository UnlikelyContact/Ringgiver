class_name Palette
extends RefCounted
## The decided look (concept-art-prompts.md): madder red, woad blue, walnut,
## undyed grey, cold northern light. Hard outlines, limited palette.

const BG := Color("3b3f44")
const GROUND := Color("5a5f55")
const GROUND_LINE := Color("4a4f47")
const MUD := Color("4a4036")
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

## Side colours: the player's band in madder, the enemy in woad.
static func side_color(side: int) -> Color:
	return MADDER if side == 0 else WOAD
