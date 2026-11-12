class_name Contracts
extends RefCounted
## Making a living by others' work: escort, hunting outlaws, the levy, debt
## collection and tribute, offered at halls and towns by the ruling faction
## when it thinks well enough of the band. Battles and voyages are the
## caller's: `accept` says which is needed, `complete` pays.

const KINDS: Array[String] = ["escort", "hunt_outlaws", "levy", "debt", "tribute"]


## Offers at `at`: {kind, from_faction, pay, fame, to_place?, against?, days,
## text}. None at farms, bays or Thing sites, from no faction, or while the
## ruler's relation toward the band is below `contract_relation`.
static func offers(rng: SimRng, rules: WorldRules, world: World, band: Band, at: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := world.place(at)
	if p == null or not (p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN):
		return out
	var f := FactionAI.ruler_of(world, at)
	if f == null or not f.alive or FactionAI.relation(world, f.id, FactionAI.BAND) < rules.contract_relation:
		return out
	var candidates: Array[Dictionary] = []
	for kind in KINDS:
		var c := _make(rng, rules, world, band, p, f, kind)
		if not c.is_empty():
			candidates.append(c)
	while not candidates.is_empty() and out.size() < rules.contract_offers_max:
		out.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return out


## Takes the work on. Returns {battle_required: {kind, attackers, tier, text}}
## for outlaw hunts and the levy, or {voyage_required: place id} for escort,
## debt and tribute.
static func accept(_rules: WorldRules, world: World, _band: Band, contract: Dictionary, log: PackedStringArray) -> Dictionary:
	contract["accepted"] = true
	var f: Faction = world.factions.get(contract.from_faction, null)
	log.append("the band takes %s's offer: %s" % [f.name if f else contract.from_faction, contract.text])
	if contract.has("battle"):
		var b: Dictionary = contract.battle
		return {"battle_required": {"kind": contract.kind, "attackers": b.attackers, "tier": b.tier, "text": contract.text}}
	if contract.has("to_place"):
		return {"voyage_required": contract.to_place}
	return {}


## Settles the contract. Success pays silver and fame, raises the giver's
## relation by `contract_relation_gain` and adds `rank_progress`; failure
## costs `contract_fail_relation_hit`.
static func complete(rules: WorldRules, world: World, band: Band, contract: Dictionary, success: bool, log: PackedStringArray) -> void:
	var fid: String = contract.from_faction
	var f: Faction = world.factions.get(fid, null)
	var who: String = f.name if f else fid
	if not success:
		FactionAI.shift(world, fid, FactionAI.BAND, -rules.contract_fail_relation_hit)
		log.append("the band fails %s: %s" % [who, contract.text])
		return
	var pay := roundi(float(contract.pay) * float(band.gift("contract_pay", 1.0)))
	band.silver += pay
	band.fame = mini(100, band.fame + int(contract.fame))
	band.rank_progress += rules.rank_progress_per_contract * int(band.gift("rank_progress", 1))
	FactionAI.shift(world, fid, FactionAI.BAND, rules.contract_relation_gain)
	log.append("%s pays the band %d oz and speaks well of it (%s)" % [who, pay, contract.kind])


## The highest rank whose threshold the band's progress has reached (for the
## integrator to grant); the band's current rank if none is higher.
static func rank_earned(rules: WorldRules, band: Band) -> WorldTypes.Rank:
	var best := band.rank
	for r in rules.rank_thresholds:
		if band.rank_progress >= rules.rank_thresholds[r] and r > best:
			best = r
	return best


static func _make(rng: SimRng, rules: WorldRules, world: World, band: Band, at: Place, f: Faction, kind: String) -> Dictionary:
	var c := {"kind": kind, "from_faction": f.id, "at": at.id, "days": rules.contract_days[kind],
			"fame": rules.contract_fame[kind]}
	var base: int = rules.contract_pay[kind]
	var spread := 1.0 + (rng.randf() * 2.0 - 1.0) * rules.contract_pay_spread
	c["pay"] = int(round(base * spread))
	match kind:
		"escort":
			var markets: Array[Place] = []
			for p in world.open_places():
				# (The wider world: not over the river road from the home waters, nor back.)
				if p.has_market and p.id != at.id and Roam.far_east(p) == Roam.far_east(at):
					markets.append(p)
			if markets.is_empty():
				return {}
			var to: Place = markets[rng.randi_range(0, markets.size() - 1)]
			c["to_place"] = to.id
			c["text"] = "escort a merchant of %s to %s" % [f.name, to.display_name]
		"hunt_outlaws":
			c["battle"] = {"attackers": rules.contract_outlaws, "tier": rules.contract_outlaw_tier}
			c["text"] = "hunt the outlaws troubling %s" % at.display_name
		"levy":
			var enemy := _enemy_of(rules, world, f)
			if enemy == null:
				return {}
			c["against"] = enemy.id
			c["battle"] = {"attackers": rules.contract_levy_men, "tier": rules.contract_levy_tier}
			c["text"] = "stand in %s's levy against %s this summer" % [f.name, enemy.name]
		"debt":
			var farm := _farm_of(world, f, at)
			if farm == null:
				return {}
			c["to_place"] = farm.id
			c["text"] = "collect a debt owed to %s at %s" % [f.leader, farm.display_name]
		"tribute":
			if band.rank < rules.tribute_min_rank:
				return {}
			var farm := _farm_of(world, f, at)
			if farm == null:
				return {}
			c["to_place"] = farm.id
			c["text"] = "gather %s's tribute from %s" % [f.leader, farm.display_name]
	return c


## A living faction the giver is at war with (relation at or below `war_relation`).
static func _enemy_of(rules: WorldRules, world: World, f: Faction) -> Faction:
	for other_id in f.relations:
		if other_id == FactionAI.BAND:
			continue
		var g: Faction = world.factions.get(other_id, null)
		if g != null and g.alive and g != f and f.relations[other_id] <= rules.war_relation:
			return g
	return null


## A farmstead the faction holds other than `at`.
static func _farm_of(world: World, f: Faction, at: Place) -> Place:
	for h in f.holdings:
		var p := world.place(h)
		if p != null and p.id != at.id and p.kind == WorldTypes.PlaceKind.FARMSTEAD and p.is_open(world.year):
			return p
	return null
