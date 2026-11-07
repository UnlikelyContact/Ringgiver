class_name Encounters
extends RefCounted
## What the band meets on a sea lane: rival ships, merchants, outlaws, the
## levy, storms, a whale or a drifting wreck. Effects that need no fight are
## applied here; fights come back as `battle_required` requests
## ({kind, attackers, tier, text}) for the caller. See world-architecture.md,
## Module J.


## One encounter on the lane a -> b, or {}. Applies its effects to the band.
static func roll(rng: SimRng, rules: WorldRules, world: World, band: Band, lane_from: String, lane_to: String, log: PackedStringArray) -> Dictionary:
	if not happens(rng, rules, world, lane_from, lane_to):
		return {}
	return resolve(rng, rules, world, band, pick_kind(rng, rules), lane_from, lane_to, log)


## Whether anything is met on this lane (chance doubles on open sea).
static func happens(rng: SimRng, rules: WorldRules, world: World, lane_from: String, lane_to: String) -> bool:
	var chance := rules.encounter_chance
	if world.lane_is_open_sea(lane_from, lane_to):
		chance *= rules.open_sea_encounter_mult
	return rng.randf() < minf(1.0, chance)


## A kind from `encounter_weights`, keys taken in sorted order.
static func pick_kind(rng: SimRng, rules: WorldRules) -> String:
	var keys := rules.encounter_weights.keys()
	keys.sort()
	var total := 0
	for k in keys:
		total += maxi(0, int(rules.encounter_weights[k]))
	if total <= 0:
		return ""
	var r := rng.randi_range(1, total)
	for k in keys:
		r -= maxi(0, int(rules.encounter_weights[k]))
		if r <= 0:
			return k
	return keys[keys.size() - 1]


## Plays out one encounter of `kind` on the lane a -> b.
static func resolve(rng: SimRng, rules: WorldRules, world: World, band: Band, kind: String, lane_from: String, lane_to: String, log: PackedStringArray) -> Dictionary:
	var where := world.place(lane_to)
	var region: WorldTypes.Region = where.region if where != null else rules.home_region
	var sea := "off %s" % (where.display_name if where != null else lane_to)
	var out := {"kind": kind, "lane": [lane_from, lane_to]}
	match kind:
		"rival_ship":
			var tier := rival_tier(rules, world.region_alertness.get(region, 0))
			out.text = "A rival ship bears down %s, %d %s men at the oars." % [
				sea, rules.rival_crew, _tier_name(tier)]
			out.battle_required = _battle("rival_ship", rules.rival_crew, tier, out.text)
		"merchant":
			var home := _merchant_home(rng, world)
			var goods := WorldTypes.Good.values()
			var good: WorldTypes.Good = goods[rng.randi_range(0, goods.size() - 1)]
			var price := maxi(1, int(round(rules.base_price[good] * rules.merchant_discount)))
			var town := world.place(home)
			out.text = "A knarr out of %s %s offers %s at %d oz a unit." % [
				town.display_name if town != null else "the south", sea, WorldTypes.GOOD_NAMES[good], price]
			out.offer = {"good": good, "units": rules.merchant_cargo, "price": price, "home": home,
				"family": town.family if town != null else ""}
		"outlaws":
			out.text = "Outlaws in a small boat put out from the skerries %s." % sea
			var req := _battle("outlaws", rules.outlaw_crew, rules.outlaw_tier, out.text)
			req.bounty = rules.outlaw_bounty if band.outlawry == WorldTypes.Outlawry.NONE else 0
			out.battle_required = req
		"levy":
			var fid := where.faction_id if where != null else ""
			if band.outlawry != WorldTypes.Outlawry.NONE or at_war_with(rules, world, fid):
				out.text = "The levy ships of %s sight the band %s and come on." % [_faction_name(world, fid), sea]
				out.battle_required = _battle("levy", rules.levy_crew, rules.levy_tier, out.text)
			else:
				out.text = "The levy ships of %s hail the band %s and share the news." % [_faction_name(world, fid), sea]
				var heard := Knowledge.spread_rumor(rng, rules, world, band, lane_to, log)
				if heard != "":
					out.rumor = heard
		"storm":
			if band.ship != null:
				band.ship.damage += rules.storm_ship_damage
			out.ship_damage = rules.storm_ship_damage
			out.delay_days = rules.storm_delay_days
			out.text = "A storm %s drives the ship off course; %d days lost and the strakes sprung." % [
				sea, rules.storm_delay_days]
		"whale":
			band.food += rules.whale_food
			out.food = rules.whale_food
			if rng.randf() < rules.whale_not_wreck_chance:
				out.text = "A stranded whale %s: the band cuts %d rations of meat." % [sea, rules.whale_food]
			else:
				out.text = "A drifting wreck %s yields %d rations of stores." % [sea, rules.whale_food]
		_:
			out.text = "Nothing is met %s." % sea
	log.append(out.text)
	return out


## Buys from a merchant's offer at his discount. Returns units bought,
## limited by silver, the offer and free cargo space.
static func buy_from_merchant(rules: WorldRules, band: Band, enc: Dictionary, units: int, log: PackedStringArray) -> int:
	if not enc.has("offer"):
		return 0
	var offer: Dictionary = enc.offer
	var space := band.ship.cargo_capacity(rules) - band.cargo_units() if band.ship != null else 0
	var n := mini(mini(units, offer.units), mini(space, band.silver / maxi(1, offer.price)))
	if n <= 0:
		return 0
	band.silver -= n * offer.price
	band.cargo[offer.good] = band.cargo.get(offer.good, 0) + n
	offer.units -= n
	log.append("The band buys %d units of %s from the merchant for %d oz." % [n, WorldTypes.GOOD_NAMES[offer.good], n * offer.price])
	return n


## The battle request for robbing a merchant instead of trading.
static func rob_merchant(rules: WorldRules, enc: Dictionary) -> Dictionary:
	var text := "The band falls on the merchant's knarr."
	var req := _battle("merchant", rules.merchant_crew, rules.merchant_tier, text)
	if enc.has("offer"):
		req.offer = enc.offer
	return req


## After the caller has fought a battle from this module: a robbed merchant
## yields `merchant_cargo` goods (as space allows) and a feud with his home
## town's family; outlaws pay their bounty. Returns what was gained.
static func after_battle(rules: WorldRules, band: Band, req: Dictionary, won: bool, log: PackedStringArray) -> Dictionary:
	var out := {}
	if not won:
		return out
	match req.get("kind", ""):
		"merchant":
			var offer: Dictionary = req.get("offer", {})
			if offer.is_empty():
				return out
			var space := band.ship.cargo_capacity(rules) - band.cargo_units() if band.ship != null else rules.merchant_cargo
			var n := mini(rules.merchant_cargo, maxi(0, space))
			band.cargo[offer.good] = band.cargo.get(offer.good, 0) + n
			out.goods = {offer.good: n}
			log.append("The band takes %d units of %s from the knarr." % [n, WorldTypes.GOOD_NAMES[offer.good]])
			if offer.family != "" and band.add_feud(offer.family, "robbed a merchant of %s" % offer.home, offer.home):
				out.feud = offer.family
				log.append("%s will not forget the robbery." % offer.family)
		"outlaws":
			var bounty: int = req.get("bounty", 0)
			if bounty > 0:
				band.silver += bounty
				out.silver = bounty
				log.append("The band takes %d oz of bounty for the outlaws' heads." % bounty)
	return out


## Tier of a rival crew from the region's alertness.
static func rival_tier(rules: WorldRules, alertness: int) -> CombatTypes.Tier:
	var step := clampi(alertness / maxi(1, rules.rival_alert_per_tier), 0, CombatTypes.Tier.CHAMPION)
	return step as CombatTypes.Tier


## Whether the faction is at war with the band (relation toward the band at
## or below `war_relation`). Unknown factions are not.
static func at_war_with(rules: WorldRules, world: World, faction_id: String) -> bool:
	var f = world.factions.get(faction_id, null)
	if f == null or not ("relations" in f):
		return false
	return int(f.relations.get("band", 0)) <= rules.war_relation


static func _battle(kind: String, attackers: int, tier: CombatTypes.Tier, text: String) -> Dictionary:
	return {"kind": kind, "attackers": attackers, "tier": tier, "text": text}


static func _merchant_home(rng: SimRng, world: World) -> String:
	var ids: Array[String] = []
	for p in world.open_places():
		if p.has_market:
			ids.append(p.id)
	if ids.is_empty():
		return ""
	ids.sort()
	return ids[rng.randi_range(0, ids.size() - 1)]


static func _faction_name(world: World, faction_id: String) -> String:
	var f = world.factions.get(faction_id, null)
	if f != null and ("name" in f):
		return f.name
	return "the local lord" if faction_id == "" else faction_id


static func _tier_name(tier: CombatTypes.Tier) -> String:
	return ["green", "blooded", "veteran", "champion"][tier]
