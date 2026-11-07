class_name FactionAI
extends RefCounted
## What the factions do on their own each year: expanders take neighbouring
## holdings from weaker enemies, the weak are absorbed, friends ally and
## marry, and allies sometimes betray each other. See world-architecture.md,
## Module L.

const BAND := "band"


## One year of faction politics. Returns events {kind, a, b, place?, text},
## kind one of "war", "alliance", "marriage", "conquest", "betrayal", "absorbed".
static func yearly(rng: SimRng, rules: WorldRules, world: World, _band: Band, log: PackedStringArray) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_expansion(rng, rules, world, log, events)
	_absorption(rules, world, log, events)
	_alliances(rng, rules, world, log, events)
	return events


static func relation(world: World, faction_id: String, other: String) -> int:
	var f: Faction = world.factions.get(faction_id, null)
	if f == null:
		return 0
	return f.relations.get(other, 0)


## Moves faction_id's relation toward other (a faction id or "band").
static func shift(world: World, faction_id: String, other: String, delta: int) -> void:
	var f: Faction = world.factions.get(faction_id, null)
	if f == null:
		return
	f.relations[other] = clampi(f.relations.get(other, 0) + delta, -100, 100)


static func ruler_of(world: World, place_id: String) -> Faction:
	var p := world.place(place_id)
	if p == null or p.faction_id == "":
		return null
	return world.factions.get(p.faction_id, null)


## The band raided a place: its ruler thinks less of the band.
static func on_raid(rules: WorldRules, world: World, place_id: String, log: PackedStringArray) -> void:
	var f := ruler_of(world, place_id)
	if f == null:
		return
	shift(world, f.id, BAND, -rules.raid_relation_hit)
	log.append("%s will remember the raid on %s" % [f.name, world.place(place_id).display_name])


## Factions (alive, not `f`) holding a place one lane from any of f's holdings.
static func neighbours_of(world: World, f: Faction) -> Array[Faction]:
	var out: Array[Faction] = []
	for h in f.holdings:
		for n in world.neighbours(h):
			var other := ruler_of(world, n)
			if other != null and other != f and other.alive and not out.has(other):
				out.append(other)
	return out


## Moves a place to the conqueror. The loser gives up its share of men for the
## holding and the winner gains `conquest_strength_gain` of it. A faction left
## with nothing is no longer alive.
static func conquer(rules: WorldRules, world: World, place_id: String, to_id: String, log: PackedStringArray) -> bool:
	var p := world.place(place_id)
	var to: Faction = world.factions.get(to_id, null)
	if p == null or to == null or p.faction_id == to_id:
		return false
	var from: Faction = world.factions.get(p.faction_id, null)
	if from != null:
		var share := from.strength / maxi(1, from.holdings.size())
		from.strength -= share
		from.holdings.erase(place_id)
		to.strength += int(share * rules.conquest_strength_gain)
	p.faction_id = to_id
	to.holdings.append(place_id)
	var line := "%s takes %s" % [to.name, p.display_name]
	if from != null:
		line += " from %s" % from.name
	log.append(line)
	world.log(line)
	if from != null and from.holdings.is_empty() and from.alive:
		absorb(world, from, to, log)
	return true


## `by` swallows `f`: every holding, every man.
static func absorb(world: World, f: Faction, by: Faction, log: PackedStringArray) -> void:
	for h in f.holdings.duplicate():
		var p := world.place(h)
		if p != null:
			p.faction_id = by.id
		if not by.holdings.has(h):
			by.holdings.append(h)
	f.holdings.clear()
	by.strength += f.strength
	f.strength = 0
	f.alive = false
	f.absorbed_by = by.id
	for other in world.factions.values():
		(other as Faction).allies.erase(f.id)
	f.allies.clear()
	if f.id == "harald":
		world.timeline_state["harald_line"] = false
	var line := "%s is no more; %s holds what it held" % [f.name, by.name]
	log.append(line)
	world.log(line)


static func _expansion(rng: SimRng, rules: WorldRules, world: World, log: PackedStringArray, events: Array[Dictionary]) -> void:
	for f in world.factions.values():
		var me: Faction = f
		if not me.alive or me.ambition != "expand":
			continue
		for n in neighbours_of(world, me):
			if n.strength < me.strength and not me.allies.has(n.id):
				shift(world, me.id, n.id, -rules.expand_hostility)
		var targets: Array[String] = []
		for h in me.holdings:
			for n in world.neighbours(h):
				var p := world.place(n)
				if p == null or not p.is_open(world.year) or targets.has(n):
					continue
				var them := ruler_of(world, n)
				if them == null or them == me or not them.alive:
					continue
				if them.strength < me.strength and relation(world, me.id, them.id) <= rules.war_relation:
					targets.append(n)
		if targets.is_empty():
			continue
		var target: String = targets[rng.randi_range(0, targets.size() - 1)]
		var defender := ruler_of(world, target)
		var share := float(me.strength) / float(me.strength + defender.strength)
		shift(world, me.id, defender.id, -rules.war_relation_hit)
		shift(world, defender.id, me.id, -rules.war_relation_hit)
		var place_name := world.place(target).display_name
		if rng.randf() < rules.conquest_chance * share:
			var d_id := defender.id
			conquer(rules, world, target, me.id, log)
			events.append({"kind": "conquest", "a": me.id, "b": d_id, "place": target,
					"text": "%s takes %s" % [me.name, place_name]})
		else:
			var line := "%s wars on %s over %s but cannot take it" % [me.name, defender.name, place_name]
			log.append(line)
			world.log(line)
			events.append({"kind": "war", "a": me.id, "b": defender.id, "place": target, "text": line})


static func _absorption(rules: WorldRules, world: World, log: PackedStringArray, events: Array[Dictionary]) -> void:
	for f in world.factions.values():
		var weak: Faction = f
		if not weak.alive:
			continue
		if not weak.holdings.is_empty() and weak.strength >= rules.absorb_strength:
			continue
		var best: Faction = null
		for n in neighbours_of(world, weak):
			if best == null or n.strength > best.strength:
				best = n
		if best == null:
			if weak.holdings.is_empty():
				weak.alive = false
			continue
		absorb(world, weak, best, log)
		events.append({"kind": "absorbed", "a": best.id, "b": weak.id,
				"text": "%s absorbs %s" % [best.name, weak.name]})


static func _alliances(rng: SimRng, rules: WorldRules, world: World, log: PackedStringArray, events: Array[Dictionary]) -> void:
	var list: Array = world.factions.values()
	for i in list.size():
		var a: Faction = list[i]
		if not a.alive:
			continue
		for j in range(i + 1, list.size()):
			var b: Faction = list[j]
			if not b.alive:
				continue
			var friendly := relation(world, a.id, b.id) >= rules.alliance_relation \
					and relation(world, b.id, a.id) >= rules.alliance_relation
			var allied := a.allies.has(b.id)
			if allied and not friendly:
				a.allies.erase(b.id)
				b.allies.erase(a.id)
				continue
			if not friendly:
				continue
			if not allied:
				a.allies.append(b.id)
				b.allies.append(a.id)
				var line := "%s and %s swear friendship" % [a.name, b.name]
				log.append(line)
				world.log(line)
				events.append({"kind": "alliance", "a": a.id, "b": b.id, "text": line})
				continue
			if rng.randf() < rules.betrayal_chance:
				var traitor := a if rng.randf() < 0.5 else b
				var victim := b if traitor == a else a
				shift(world, a.id, b.id, -rules.betrayal_relation_hit)
				shift(world, b.id, a.id, -rules.betrayal_relation_hit)
				a.allies.erase(b.id)
				b.allies.erase(a.id)
				var line := "%s breaks faith with %s" % [traitor.name, victim.name]
				log.append(line)
				world.log(line)
				events.append({"kind": "betrayal", "a": traitor.id, "b": victim.id, "text": line})
			elif rng.randf() < rules.marriage_chance:
				shift(world, a.id, b.id, rules.marriage_relation_gain)
				shift(world, b.id, a.id, rules.marriage_relation_gain)
				var line := "a marriage binds %s to %s" % [a.name, b.name]
				log.append(line)
				world.log(line)
				events.append({"kind": "marriage", "a": a.id, "b": b.id, "text": line})
