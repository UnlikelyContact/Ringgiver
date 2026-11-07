class_name Band
extends RefCounted
## The player's (or an AI jarl's) band across years: the leader, his sworn
## men, wealth, hall, feuds, bonds and the chronicle. Modules mutate this;
## the campaign loop owns the order in which they do.

var leader: Man = null
var men: Array[Man] = []
var silver := 40
var food := 40
var ship_damage := 0
var rumors: PackedStringArray = []
var vows: Array[Dictionary] = []  # {year, text, kept: bool or null}
var feuds: Array[Dictionary] = []  # {against, cause, year, settled}
var chronicle: PackedStringArray = []
var year := 866

# Leader resources (Module H).
var luck := 5
var fame := 10
var honor := 50
var sworn_second_id := -1

# Family (Module H).
var wife := ""
var household_skill := 0
var sons: Array[Dictionary] = []
var alliances: PackedStringArray = []

# Hall (Module G owns the Hall class; set when the module lands).
var hall: RefCounted = null

var _bonds := {}  # "lo:hi" -> int
var _bond_kinds := {}  # "lo:hi" -> CampaignTypes.BondKind
var _next_id := 1


func next_id() -> int:
	var v := _next_id
	_next_id += 1
	return v


func add_man(m: Man, p_year := -1) -> void:
	if m.id == 0:
		m.id = next_id()
	else:
		_next_id = maxi(_next_id, m.id + 1)
	m.joined_year = year if p_year < 0 else p_year
	men.append(m)


func remove_man(m: Man) -> void:
	men.erase(m)


func man_by_id(id: int) -> Man:
	if leader != null and leader.id == id:
		return leader
	for m in men:
		if m.id == id:
			return m
	return null


func living_men() -> Array[Man]:
	var out: Array[Man] = []
	for m in men:
		if m.alive:
			out.append(m)
	return out


## Everyone who fights: the leader first, then living men.
func fighters() -> Array[Man]:
	var out: Array[Man] = []
	if leader != null and leader.alive:
		out.append(leader)
	out.append_array(living_men())
	return out


static func _key(a: Man, b: Man) -> String:
	return "%d:%d" % [mini(a.id, b.id), maxi(a.id, b.id)]


func bond(a: Man, b: Man) -> int:
	return _bonds.get(_key(a, b), 0)


func set_bond(a: Man, b: Man, value: int) -> void:
	_bonds[_key(a, b)] = clampi(value, -100, 100)


func add_bond(a: Man, b: Man, delta: int) -> void:
	set_bond(a, b, bond(a, b) + delta)


func bond_kind(a: Man, b: Man) -> CampaignTypes.BondKind:
	return _bond_kinds.get(_key(a, b), CampaignTypes.BondKind.NONE)


func set_bond_kind(a: Man, b: Man, kind: CampaignTypes.BondKind) -> void:
	_bond_kinds[_key(a, b)] = kind


func add_feud(against: String, cause: String) -> bool:
	for f in feuds:
		if f.against == against and not f.settled:
			return false
	feuds.append({"against": against, "cause": cause, "year": year, "settled": false})
	return true


func unsettled_feuds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in feuds:
		if not f.settled:
			out.append(f)
	return out


func log(line: String) -> void:
	chronicle.append("%d: %s" % [year, line])


func describe() -> String:
	var lines := PackedStringArray()
	lines.append("%s's band, %d: %d men, %d oz silver, %d rations, luck %d, fame %d, honor %d" % [
		leader.display_name if leader else "nobody", year, living_men().size(), silver, food, luck, fame, honor])
	for m in men:
		lines.append("  " + m.describe())
	return "\n".join(lines)
