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

## Ids are assigned from `first_id` so a battle is reproducible: rng streams
## are forked by id, so ids must not depend on how many bands were made
## before in the same process.
static func make_band(rng: SimRng, side: int, count: int, tier: CombatTypes.Tier,
		armor: CombatTypes.Armor = CombatTypes.Armor.NONE, name_offset := 0, first_id := 1,
		stat_center := -1) -> Array[Warrior]:
	var out: Array[Warrior] = []
	var center: int = TIER_CENTER[tier] if stat_center < 0 else stat_center
	for i in count:
		var stats: Array = []
		for s in 5:
			stats.append(clampi(center + rng.randi_range(-1, 1), 1, 10))
		var name: String = NAMES[(name_offset + i) % NAMES.size()]
		var w := Warrior.make(name, side, stats, tier)
		w.id = first_id + i
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


## A band of mixed arms: `shields` shield-bearers (the leader, banner and
## horn among them, each with a throwing spear), `spears` second-rank
## spearmen and `bows` archers, in that order of ids.
static func make_mixed_band(rng: SimRng, side: int, shields: int, spears: int, bows: int,
		tier: CombatTypes.Tier, rules: CombatRules, armor: CombatTypes.Armor = CombatTypes.Armor.NONE,
		name_offset := 0, first_id := 1) -> Array[Warrior]:
	var out := make_band(rng, side, shields + spears + bows, tier, armor, name_offset, first_id)
	for i in out.size():
		var w: Warrior = out[i]
		if i < shields:
			w.role = CombatTypes.Role.SHIELD
			w.javelins = rules.javelins_per_man
		elif i < shields + spears:
			w.role = CombatTypes.Role.SPEAR
			w.weapon = CombatTypes.Weapon.SPEAR
		else:
			w.role = CombatTypes.Role.MISSILE
			w.weapon = CombatTypes.Weapon.BOW
			w.has_shield = false
	return out


## Deploys a band in `template` (null: the plain line) through `anchor`, the
## leader on it, facing `facing`.
static func deploy_formation(grid: BattleGrid, band: Array[Warrior], anchor: Vector2i, facing: Vector2i,
		rules: CombatRules, template: FormationTemplate) -> void:
	var leader: Warrior = null
	var others: Array[Warrior] = []
	for w in band:
		w.reset_for_battle(rules)
		w.facing = facing
		if w.is_leader:
			w.line_facing = facing
			w.formation = template
		if w.is_leader and leader == null:
			leader = w
		else:
			others.append(w)
	if leader == null:
		leader = others.pop_front()
		leader.line_facing = facing
		leader.formation = template
	grid.place(leader, anchor)
	var plan := Formation.template_slots(grid, leader, others, template)
	var unplaced: Array[Warrior] = []
	for w in others:
		if plan.has(w) and grid.is_free(plan[w]):
			grid.place(w, plan[w])
		else:
			unplaced.append(w)
	# Anyone without a cell takes the nearest free one to the leader.
	for w in unplaced:
		var seen := {anchor: true}
		var queue: Array[Vector2i] = [anchor]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			if grid.is_free(c):
				grid.place(w, c)
				break
			for n in grid.neighbors(c):
				if not seen.has(n) and grid.in_bounds(n):
					seen[n] = true
					queue.append(n)


## Deploys a band as a line through the cell at offset column `column` and
## the map's middle row, facing `facing` (east for side 0, west for side 1
## is the usual). The leader stands at the anchor; the rest fill the line's
## slots outward, right first, exactly as Formation.line_slots orders them.
static func deploy_column(grid: BattleGrid, band: Array[Warrior], column: int, facing: Vector2i, rules: CombatRules) -> void:
	deploy_line(grid, band, BattleGrid.from_offset(column, grid.height / 2), facing, rules)


## Deploys a band as a line through `anchor` (axial), the leader on it,
## facing `facing`.
static func deploy_line(grid: BattleGrid, band: Array[Warrior], anchor: Vector2i, facing: Vector2i, rules: CombatRules) -> void:
	var leader: Warrior = null
	var others: Array[Warrior] = []
	for w in band:
		w.reset_for_battle(rules)
		w.facing = facing
		if w.is_leader:
			w.line_facing = facing
		if w.is_leader and leader == null:
			leader = w
		else:
			others.append(w)
	if leader == null and not others.is_empty():
		leader = others.pop_front()
	grid.place(leader, anchor)
	var dirs := BattleGrid.line_dirs(facing)
	var k := 1
	var i := 0
	while i < others.size() and k < 64:
		for d in dirs:
			if i >= others.size():
				break
			var c: Vector2i = anchor + d * k
			if grid.is_free(c):
				grid.place(others[i], c)
				i += 1
		k += 1
