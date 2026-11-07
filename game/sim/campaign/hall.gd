class_name Hall
extends RefCounted
## The band's winter hall: bench seats, buildings and the seating order.
## Owned by Band.hall; create it with Hall.ensure().

var seats := 8
var buildings: Array[CampaignTypes.Building] = []
## Man ids, high seat first. The leader and his family take no seat.
var seating: Array[int] = []
## Men who sat without a bench at any turn this winter (reset each EARLY).
var winter_unseated: Array[int] = []


## Returns band.hall, creating and assigning it if missing, and brings the
## seating order up to date with the band's living men.
static func ensure(band: Band, rules: CampaignRules) -> Hall:
	if band.hall == null:
		var h := Hall.new()
		h.seats = rules.hall_base_seats
		band.hall = h
	var hall: Hall = band.hall as Hall
	hall.sync(band)
	return hall


## Drops ids of dead or departed men and appends newcomers at the bottom.
func sync(band: Band) -> void:
	var living: Array[int] = []
	for m in band.living_men():
		living.append(m.id)
	var kept: Array[int] = []
	for id in seating:
		if living.has(id) and not kept.has(id):
			kept.append(id)
	for id in living:
		if not kept.has(id):
			kept.append(id)
	seating = kept


func has(b: CampaignTypes.Building) -> bool:
	return buildings.has(b)


func count(b: CampaignTypes.Building) -> int:
	return buildings.count(b)


## Pays silver and adds the building. Benches can be built again and again
## (each adds benches_seats); every other building once.
func build(rules: CampaignRules, b: CampaignTypes.Building, band: Band, log: PackedStringArray) -> bool:
	var bname: String = CampaignTypes.BUILDING_NAMES[b]
	if b != CampaignTypes.Building.BENCHES and has(b):
		log.append("The hall already has a %s." % bname)
		return false
	var cost: int = rules.building_costs.get(b, 0)
	if band.silver < cost:
		log.append("Too little silver to build %s (%d oz needed, %d held)." % [bname, cost, band.silver])
		return false
	band.silver -= cost
	buildings.append(b)
	if b == CampaignTypes.Building.BENCHES:
		seats += rules.benches_seats
	log.append("Built %s for %d oz." % [bname, cost])
	band.log("built %s at the hall" % bname)
	return true


func food_capacity(rules: CampaignRules) -> int:
	return rules.food_base_capacity + rules.storehouse_capacity * count(CampaignTypes.Building.STOREHOUSE)


func is_seated(id: int) -> bool:
	var i := seating.find(id)
	return i >= 0 and i < seats


## Seat position (0 = high seat), or -1.
func rank(id: int) -> int:
	return seating.find(id)


## Moves a man to a new seat index. The loyalty offense to men passed is
## Module F's business (Loyalty.seating_offense), called by the loop.
func move(id: int, to_index: int) -> void:
	var i := seating.find(id)
	if i < 0:
		return
	seating.remove_at(i)
	seating.insert(clampi(to_index, 0, seating.size()), id)
