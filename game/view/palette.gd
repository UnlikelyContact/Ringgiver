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

## Side colours: the player's band in madder, the enemy in woad; with the
## colours kinder to colour-blind eyes (Settings), a light ochre-orange and
## a deep woad, apart in lightness as well as hue.
static func side_color(side: int) -> Color:
	if colour_safe:
		return SAFE_OURS if side == 0 else SAFE_THEIRS
	return MADDER if side == 0 else WOAD


# --- The interface (view/ui_theme.gd, docs/design/notes/ui.md) ---------------
## Carved wood and worn iron round a saga chart: deep charcoal-brown
## panels, bone text, a tarnished gold rule and accent, parchment for long
## reading, blood only for danger, the map's teal for water and calm.

## The darkest ground, behind every screen and under the dimmed backdrop.
const UI_NIGHT := Color("14100d")
## Panel wood, from sunken to raised.
const UI_WELL := Color("1a1511")
const UI_WOOD := Color("241d17")
const UI_WOOD_RAISED := Color("332920")
const UI_WOOD_HOVER := Color("3e3226")
## The rule round panels and buttons: tarnished gold, and the bright gold
## of titles and the chosen thing.
const UI_RULE := Color("8a6d36")
const UI_RULE_DIM := Color("4d3d26")
const UI_GOLD := Color("dcb862")
const UI_GOLD_DEEP := Color("a9822e")
## Text: bone for reading, muted for what is said aside, faint for what
## cannot be done now.
const UI_TEXT := Color("ece3cf")
const UI_MUTED := Color("ab9f8a")
const UI_FAINT := Color("6e6556")
## Parchment, for the long reading surfaces and the hints on the map, with
## its own ink.
const UI_PARCHMENT := Color("e3d5b4")
const UI_PARCHMENT_EDGE := Color("b29d72")
const UI_INK := Color("33271b")
const UI_INK_MUTED := Color("6b5a42")
## Danger and calm.
const UI_BLOOD := Color("b8433a")
const UI_BLOOD_DEEP := Color("6e211c")
const UI_TEAL := Color("5f9c98")
const UI_FRIEND := Color("9cb35c")
## Our side and theirs on the battle screen's strip: the shields' madder
## and woad, raised to read as text on the dark.
const UI_OURS := Color("d9776a")
const UI_THEIRS := Color("86a4d6")
## The fire of the opening's cards.
const UI_EMBER := Color("e8823a")


# --- Colours kinder to colour-blind eyes (Settings, docs/design/notes/shell.md) --
## Madder and woad are the same lightness (about L* 31), told apart by hue
## alone. With the setting on, the two sides are an ochre-orange (L* about
## 56) and a deep woad (about 26), and the battle strip's words follow; a
## friendly house's colour is a light blue, not green.

## Whether the safer colours are used; Settings.apply sets it.
static var colour_safe := false
const SAFE_OURS := Color("c96a2b")
const SAFE_THEIRS := Color("243a68")
const UI_SAFE_OURS := Color("f0a860")
const UI_SAFE_THEIRS := Color("6c88cc")
const UI_SAFE_FRIEND := Color("8ec5e8")


## The battle strip's colour for a side's words.
static func ui_side(side: int) -> Color:
	if colour_safe:
		return UI_SAFE_OURS if side == 0 else UI_SAFE_THEIRS
	return UI_OURS if side == 0 else UI_THEIRS
