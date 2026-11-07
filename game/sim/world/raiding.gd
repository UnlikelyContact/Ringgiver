class_name Raiding
extends RefCounted
## Module K: raids and strandhögg. A raid is a battle the caller fights:
## `raid` describes it, the sandbox loop fights it, `after_raid` takes the
## plunder and leaves the coast warier. Raided places grow alert, raided
## regions light their beacons (defenders double), and the ruling family may
## take up a feud. Strandhögg is a quick shore raid with no battle.
## See world-architecture.md > Module K.


## What a raid on this place would face: {defenders, tier, expected_plunder,
## alert, beacons}.
static func assess(rules: WorldRules, world: World, place: Place, _band: Band) -> Dictionary:
	var defenders: int = int(rules.defenders_base.get(place.kind, 0)) + place.defenses \
			+ place.alertness * rules.defenders_per_alert
	var beacons := beacons_lit(rules, world, place.region)
	if beacons:
		defenders *= 2
	return {
		"defenders": defenders,
		"tier": defender_tier(rules, place),
		"expected_plunder": int(float(place.wealth) * rules.plunder_fraction),
		"alert": place.alertness,
		"beacons": beacons,
	}


static func beacons_lit(rules: WorldRules, world: World, region: WorldTypes.Region) -> bool:
	return int(world.region_alertness.get(region, 0)) >= rules.beacon_threshold


## Defender quality by the place's defenses.
static func defender_tier(rules: WorldRules, place: Place) -> CombatTypes.Tier:
	var t: Array = rules.defender_tier_defenses
	if place.defenses >= int(t[2]):
		return CombatTypes.Tier.CHAMPION
	if place.defenses >= int(t[1]):
		return CombatTypes.Tier.VETERAN
	if place.defenses >= int(t[0]):
		return CombatTypes.Tier.BLOODED
	return CombatTypes.Tier.GREEN


## The battle request for a raid: {kind: "raid", attackers, defenders, tier,
## place, text}. Nothing is fought or changed here. {} if the place is not
## on the map yet.
static func raid(_rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, log: PackedStringArray) -> Dictionary:
	if not place.is_open(world.year):
		return {}
	var a := assess(rules, world, place, band)
	var attackers := band.fighters()
	var text := "%d men fall on %s; %d %s defenders stand%s" % [
		attackers.size(), place.display_name, a.defenders, CombatTypes.TIER_NAMES[a.tier],
		" (the beacons are lit)" if a.beacons else ""]
	log.append(text)
	return {
		"kind": "raid",
		"attackers": attackers,
		"defenders": a.defenders,
		"tier": a.tier,
		"place": place.id,
		"text": text,
	}


## After the caller has fought the raid. On a win: silver from the place's
## wealth, goods from its stock (as cargo room allows), captives, and a
## chance the ruling family takes up a feud (recorded on the band). Win or
## lose, the place and its region grow more alert.
## Returns {silver, goods: {Good: units}, captives, feud}.
static func after_raid(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, won: bool, log: PackedStringArray) -> Dictionary:
	var out := {"silver": 0, "goods": {}, "captives": 0, "feud": false}
	if won:
		var frac := rules.plunder_fraction + (rng.randf() * 2.0 - 1.0) * rules.plunder_spread
		var silver := clampi(roundi(float(place.wealth) * frac), 0, place.wealth)
		place.wealth -= silver
		band.silver += silver
		out.silver = silver
		var goods := {}
		var keys: Array = place.stock.keys()
		keys.sort()
		for g in keys:
			var take := mini(int(float(place.stock[g]) * rules.loot_fraction), Market.cargo_room(rules, band))
			if take <= 0:
				continue
			place.stock[g] = int(place.stock[g]) - take
			band.cargo[g] = int(band.cargo.get(g, 0)) + take
			goods[g] = take
		out.goods = goods
		var captives := 0
		var guarded := place.kind == WorldTypes.PlaceKind.HALL and place.defenses >= rules.no_captives_defense
		if not guarded and place.kind != WorldTypes.PlaceKind.BAY:
			captives = maxi(0, rules.captives_per_win + rng.randi_range(-rules.captives_spread, rules.captives_spread))
		band.captives += captives
		out.captives = captives
		var goods_text := PackedStringArray()
		for g in goods:
			goods_text.append("%d %s" % [goods[g], WorldTypes.GOOD_NAMES[g]])
		log.append("%s plundered: %d oz%s, %d captives" % [
			place.display_name, silver, (", " + ", ".join(goods_text)) if not goods_text.is_empty() else "", captives])
		world.log("%s was raided and plundered of %d oz" % [place.display_name, silver])
		if place.family != "" and rng.randf() < rules.raid_feud_chance:
			band.add_feud(place.family, "raid on %s" % place.display_name, place.id)
			out.feud = true
			log.append("%s swear vengeance for the raid on %s" % [place.family, place.display_name])
	else:
		log.append("the raid on %s is beaten off" % place.display_name)
		world.log("raiders were beaten off at %s" % place.display_name)
	_raise_alert(world, place, rules.alert_per_raid, rules.region_alert_per_raid)
	return out


## A quick shore raid for cattle and stores: no battle. Food and a little
## silver (no more than the place has), the place grows alert, and its
## family may take up a feud. Returns {food, silver, feud}.
static func strandhogg(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, log: PackedStringArray) -> Dictionary:
	var out := {"food": 0, "silver": 0, "feud": false}
	if not place.is_open(world.year):
		return out
	var silver := mini(rules.strandhogg_silver, place.wealth)
	place.wealth -= silver
	band.silver += silver
	band.food += rules.strandhogg_food
	out.food = rules.strandhogg_food
	out.silver = silver
	_raise_alert(world, place, 1, 0)
	log.append("strandhögg at %s: %d rations, %d oz" % [place.display_name, rules.strandhogg_food, silver])
	if place.family != "" and rng.randf() < rules.strandhogg_feud_chance:
		band.add_feud(place.family, "strandhögg at %s" % place.display_name, place.id)
		out.feud = true
		log.append("%s swear vengeance for the cattle taken at %s" % [place.family, place.display_name])
	return out


static func _raise_alert(world: World, place: Place, by: int, region_by: int) -> void:
	place.alertness = clampi(place.alertness + by, 0, 10)
	world.region_alertness[place.region] = clampi(int(world.region_alertness.get(place.region, 0)) + region_by, 0, 10)
