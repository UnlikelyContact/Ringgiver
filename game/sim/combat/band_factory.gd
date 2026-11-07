class_name BandFactory
extends RefCounted
## Builds bands of warriors for tests and batch runs. The campaign layer will
## replace this with real recruits; keep it deterministic from the rng.

const NAMES := [
	"Egil", "Grim", "Thorolf", "Kveldulf", "Skalla", "Arinbjorn", "Olvir", "Bard",
	"Hallvard", "Sigtrygg", "Ketil", "Gunnar", "Hoskuld", "Njal", "Kari", "Flosi",
	"Asgrim", "Mord", "Gizur", "Geir", "Hrut", "Unn", "Thorkel", "Bjorn",
	"Eyvind", "Ragnar", "Ivar", "Halfdan", "Ulf", "Orm", "Steinar", "Vigfus",
]

## Stat center by tier (1-10 scale, see sim-architecture.md > Scales).
const TIER_CENTER := {
	CombatTypes.Tier.GREEN: 3,
	CombatTypes.Tier.BLOODED: 4,
	CombatTypes.Tier.VETERAN: 5,
	CombatTypes.Tier.CHAMPION: 7,
}

static var _next_id := 1


static func make_band(rng: SimRng, side: int, count: int, tier: CombatTypes.Tier,
		armor: CombatTypes.Armor = CombatTypes.Armor.NONE, name_offset := 0) -> Array[Warrior]:
	var out: Array[Warrior] = []
	var center: int = TIER_CENTER[tier]
	for i in count:
		var stats: Array = []
		for s in 5:
			stats.append(clampi(center + rng.randi_range(-1, 1), 1, 10))
		var name: String = NAMES[(name_offset + i) % NAMES.size()]
		var w := Warrior.make(name, side, stats, tier)
		w.id = _next_id
		_next_id += 1
		w.armor = armor
		if i == 0:
			w.is_leader = true
			w.might += 1
			w.skill += 1
			w.nerve += 1
			w.display_name += " the leader"
		elif i == 1:
			w.is_banner = true
		elif i == 2:
			w.is_horn = true
		out.append(w)
	return out


## Deploys a band in a column at x = `column`, centered vertically, facing
## `facing` (east for side 0, west for side 1 is the usual).
static func deploy_column(grid: BattleGrid, band: Array[Warrior], column: int, facing: Vector2i, rules: CombatRules) -> void:
	var start_y := maxi(0, (grid.height - band.size()) / 2)
	var order: Array[Warrior] = []
	# Leader in the middle of the line, everyone else around him.
	var leader: Warrior = null
	for w in band:
		if w.is_leader:
			leader = w
		else:
			order.append(w)
	var mid := (band.size() - 1) / 2
	if leader != null:
		order.insert(mid, leader)
	for i in order.size():
		var w := order[i]
		w.reset_for_battle(rules)
		w.facing = facing
		grid.place(w, Vector2i(column, start_y + i))
