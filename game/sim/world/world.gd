class_name World
extends RefCounted
## The map and everything on it: places, sea lanes, regional alertness,
## factions (Module L fills `factions`), the historical timeline's state,
## and the world's own chronicle.

var places := {}  # id -> Place
var _lanes := {}  # id -> Array of [other_id, days, open_sea]
var region_alertness := {}  # Region -> int
var factions := {}  # id -> Faction (Module L)
var timeline_state := {}  # event id -> true once fired
var chronicle: PackedStringArray = []
var year := 866
## A number of this world's own, so that what is drawn from a place and a
## year (a dispute at a farm) differs from one saga to the next.
var salt := 0
## The houses, their ties and the band's standing with them (Families).
var families: Families = null


static func build_norway(rules: WorldRules, p_year := 866) -> World:
	var w := World.new()
	w.year = p_year
	for d in NorwayData.PLACES:
		var p := Place.new()
		p.id = d.id
		p.display_name = d.name
		p.region = d.region
		p.kind = d.kind
		p.pos = d.pos
		p.wealth = d.wealth
		p.base_wealth = d.wealth
		p.defenses = d.defenses
		p.faction_id = d.get("faction", "")
		p.family = d.get("family", "")
		p.has_market = d.get("market", false)
		p.open_year = d.get("open_year", 0)
		if p.has_market:
			for g in WorldTypes.Good.values():
				p.stock[g] = Market.depth(rules, p)
		elif p.kind == WorldTypes.PlaceKind.FARMSTEAD:
			p.stock[WorldTypes.Good.GRAIN] = rules.stock_baseline
		w.places[p.id] = p
	for lane in NorwayData.LANES:
		w.add_lane(lane[0], lane[1], lane[2], lane[3])
	for r in WorldTypes.Region.values():
		w.region_alertness[r] = 0
	w.families = Families.build(rules, w, 0)
	return w


func add_lane(a: String, b: String, days: int, open_sea := false) -> void:
	if not _lanes.has(a):
		_lanes[a] = []
	if not _lanes.has(b):
		_lanes[b] = []
	_lanes[a].append([b, days, open_sea])
	_lanes[b].append([a, days, open_sea])


func place(id: String) -> Place:
	return places.get(id, null)


func neighbours(id: String) -> Array[String]:
	var out: Array[String] = []
	for lane in _lanes.get(id, []):
		out.append(lane[0])
	return out


## Days along the direct lane, or -1 if there is none.
func days_between(a: String, b: String) -> int:
	for lane in _lanes.get(a, []):
		if lane[0] == b:
			return lane[1]
	return -1


func lane_is_open_sea(a: String, b: String) -> bool:
	for lane in _lanes.get(a, []):
		if lane[0] == b:
			return lane[2]
	return false


func places_in(region: WorldTypes.Region) -> Array[Place]:
	var out: Array[Place] = []
	for p in places.values():
		if p.region == region and p.is_open(year):
			out.append(p)
	return out


func open_places() -> Array[Place]:
	var out: Array[Place] = []
	for p in places.values():
		if p.is_open(year):
			out.append(p)
	return out


func log(line: String) -> void:
	chronicle.append("%d: %s" % [year, line])


func describe() -> String:
	var lines := PackedStringArray()
	for p in open_places():
		lines.append(p.describe())
	return "\n".join(lines)
