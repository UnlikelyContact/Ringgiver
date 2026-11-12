class_name WorldTypes
extends RefCounted
## Shared enums for the world layer. Keep small and stable.

enum PlaceKind { FARMSTEAD, HALL, TOWN, THING_SITE, FORT, BAY }

enum Region { VIKEN, AGDER, ROGALAND, HORDALAND, SOGN, MORE, TRONDELAG, HALOGALAND,
	DENMARK, SWEDEN, BALTIC, WEST, ICELAND, EAST, FRANKIA }

enum Good { FURS, WALRUS_IVORY, IRON, SOAPSTONE, AMBER, FRANKISH_BLADES, WINE, SILK, GRAIN }

enum ShipKind { KARVE, SNEKKJA, LONGSHIP, KNARR, FAERING }

enum FactionKind { KING, JARL, CHIEFTAINS, TOWN }

enum Outlawry { NONE, LESSER, FULL }

enum Rank { THRALL, FREEDMAN, KARL, HERSIR, JARL, KING }

enum CaseKind { KILLING, RAID, LAND, INSULT }

enum Verdict { PENDING, COMPENSATION, LESSER_OUTLAWRY, FULL_OUTLAWRY, FAILED }

enum EncounterKind { RIVAL_SHIP, MERCHANT, OUTLAWS, LEVY, STORM, WHALE }

const PLACE_KIND_NAMES := ["farmstead", "hall", "town", "thing site", "fort", "bay"]
const REGION_NAMES := ["Viken", "Agder", "Rogaland", "Hordaland", "Sogn", "Møre", "Trøndelag", "Hålogaland",
	"Denmark", "the Swedish lands", "the Baltic", "the western isles", "Iceland", "the east", "Frankia"]
const GOOD_NAMES := ["furs", "walrus ivory", "bog iron", "soapstone", "amber", "Frankish blades", "wine", "silk", "grain"]
const SHIP_NAMES := ["karve", "snekkja", "longship", "knarr", "færing"]
const RANK_NAMES := ["thrall", "freedman", "karl", "hersir", "jarl", "king"]
const VERDICT_NAMES := ["pending", "compensation", "lesser outlawry", "full outlawry", "failed"]
