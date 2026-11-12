class_name CampaignTypes
extends RefCounted
## Shared enums for the campaign layer. Keep small and stable.

enum Season { SUMMER, WINTER }

enum WinterTurn { EARLY, YULE, DEEP, THAW }

## What a man wants (concept.md, Ambitions, loyalty and bonds).
enum Ambition { SILVER, LAND, VENGEANCE, FAME, WIFE, HOME }

enum Origin { FISHERMAN, YOUNGER_SON, OUTLAW, FREEDMAN, EXILED_JARLS_SON }

## Lasting injuries; each has a stat penalty in CampaignRules.maim_penalties.
enum Maim { LOST_HAND, LAME_LEG, ONE_EYE, BROKEN_RIBS, SCARRED_FACE }

enum Task { DRILL, HEAL, REPAIR, HUNT, FISH, GUARD, TRAVEL, IDLE }

enum BondKind { NONE, OATH_BROTHER, RIVAL, KIN }

enum Building { BENCHES, STOREHOUSE, SMITHY, BOATHOUSE, BYRE }

const SEASON_NAMES := ["summer", "winter"]
const WINTER_TURN_NAMES := ["early winter", "Yule", "deep winter", "the thaw"]
const AMBITION_NAMES := ["silver", "land", "vengeance", "fame", "a wife", "to go home"]
const ORIGIN_NAMES := ["fisherman", "younger son", "outlaw", "freedman", "exiled jarl's son"]


## "a fisherman", "an outlaw": the origin with its article, for the saga's lines.
static func a_origin(origin: int) -> String:
	var n: String = ORIGIN_NAMES[origin]
	return ("an " if n.left(1) in ["a", "e", "i", "o", "u"] else "a ") + n
const MAIM_NAMES := ["a lost hand", "a lame leg", "one eye", "broken ribs", "a scarred face"]
const TASK_NAMES := ["drill", "heal", "repair", "hunt", "fish", "guard", "travel", "idle"]
const BUILDING_NAMES := ["benches", "storehouse", "smithy", "boathouse", "byre"]
