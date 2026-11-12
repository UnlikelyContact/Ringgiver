class_name Market
extends RefCounted
## Module K: the regional market. Prices follow scarcity: a good is dear
## where stock is thin and cheap where it piles up, scaled by where in the
## world it is (furs are cheap in Hålogaland and dear at Hedeby). Buying and
## selling move stock one unit at a time, so a big purchase drives its own
## price up. Captives sell only at the great slave markets, and each one
## sold there this year lowers the next one's price.
## See world-architecture.md > Module K.


## Ounces per unit at this place's current stock. A place without a market
## sells only food (grain) at `farm_food_price`; any other good is 0 there
## (not for sale).
static func price(rules: WorldRules, place: Place, good: WorldTypes.Good) -> int:
	if not place.has_market:
		if place.trade.has(good):
			return _local_price(rules, place, good)
		return rules.farm_food_price if good == WorldTypes.Good.GRAIN else 0
	return _price_at(rules, place, good, int(place.stock.get(good, 0)))


## A farm's or a hall's own stall (Place.trade): what it makes is cheap,
## what it lacks dear, and either moves with the few units it has.
static func _local_price(rules: WorldRules, place: Place, good: WorldTypes.Good) -> int:
	var factor: float = rules.region_factor.get(place.region, {}).get(good, 1.0)
	factor *= rules.local_sell_factor if str(place.trade[good]) == "sells" else rules.local_buy_factor
	var stock := int(place.stock.get(good, rules.local_stock))
	var scarcity := clampf(float(rules.local_stock) / float(maxi(1, stock)), rules.price_floor, rules.price_ceiling)
	return maxi(1, roundi(float(rules.base_price[good]) * factor * scarcity))


## Whether the band can buy `good` here (a market's stall, or what a farm
## or a hall makes; grain anywhere settled) and sell it here (a market, or
## what a farm or a hall lacks).
static func sells_here(place: Place, good: WorldTypes.Good) -> bool:
	if place.has_market:
		return true
	if place.trade.has(good):
		return str(place.trade[good]) == "sells"
	return good == WorldTypes.Good.GRAIN


static func buys_here(place: Place, good: WorldTypes.Good) -> bool:
	return place.has_market or str(place.trade.get(good, "")) == "buys"


## Every stall of a farm or a hall mends toward its baseline by
## `local_mend_day` a day: its makings are made again, what it bought is
## used up. Fractions are carried in `place.stock_mend`.
static func mend_local(rules: WorldRules, world: World, days: float) -> void:
	for id in world.places:
		var place: Place = world.places[id]
		if place.trade.is_empty() or place.has_market:
			continue
		for g in place.trade:
			var s := int(place.stock.get(g, rules.local_stock))
			if s == rules.local_stock:
				place.stock_mend.erase(g)
				continue
			var acc := float(place.stock_mend.get(g, 0.0)) + days * rules.local_mend_day
			var step := int(acc)
			place.stock_mend[g] = acc - step
			if step > 0:
				place.stock[g] = (mini(rules.local_stock, s + step)) if s < rules.local_stock else maxi(rules.local_stock, s - step)


static func _price_at(rules: WorldRules, place: Place, good: WorldTypes.Good, stock: int) -> int:
	var factor: float = rules.region_factor.get(place.region, {}).get(good, 1.0)
	var scarcity := clampf(float(rules.stock_baseline) / float(maxi(1, stock)), rules.price_floor, rules.price_ceiling)
	return maxi(1, roundi(float(rules.base_price[good]) * factor * scarcity))


## What this band pays here: the price and the middlemen's spread, less
## its `trade_edge` gift (never under the price itself), dearer or cheaper
## by the band's standing with the house of the place (Families.spread_off,
## foe_factor).
## Rations at a farm are sold at the farm's price.
static func buy_price(rules: WorldRules, place: Place, band: Band, good: WorldTypes.Good) -> int:
	if not place.has_market and not place.trade.has(good):
		return price(rules, place, good)
	var over := maxf(0.0, rules.market_spread - float(band.gift("trade_edge", 0.0)) - Families.spread_off(rules, band, place))
	return maxi(1, ceili(float(price(rules, place, good)) * (1.0 + over) * Families.foe_factor(rules, band, place) - 0.0001))


## What this band is paid here: the price less the spread, plus its
## `trade_edge` gift (never over the price itself).
static func sell_price(rules: WorldRules, place: Place, band: Band, good: WorldTypes.Good) -> int:
	var under := maxf(0.0, rules.market_spread - float(band.gift("trade_edge", 0.0)) - Families.spread_off(rules, band, place))
	return maxi(0, floori(float(price(rules, place, good)) * (1.0 - under) / Families.foe_factor(rules, band, place) + 0.0001))


## Free cargo room: the ship's hold, or what the men can carry without one.
static func cargo_room(rules: WorldRules, band: Band) -> int:
	return maxi(0, cargo_capacity(rules, band) - band.cargo_units() - band.felag_units() - ceili(float(band.captives) / maxf(1.0, rules.captive_load)))


## What the band can carry: its men's loads on their backs (the leader's
## `no_ship_cargo` and `load_per_man` for every man with him), or its
## ship's hold if that is more.
static func cargo_capacity(rules: WorldRules, band: Band) -> int:
	var backs := rules.no_ship_cargo + rules.load_per_man * band.living_men().size()
	if band.ship != null:
		return maxi(band.ship.cargo_capacity(rules), backs)
	return backs


## Buys up to `units`, one at a time at the price of the moment, stopping
## when stock, silver or cargo room runs out. Returns units bought. At a
## place without a market only grain can be had, and it goes into the food
## store as rations (it takes no cargo room).
static func buy(rules: WorldRules, place: Place, band: Band, good: WorldTypes.Good, units: int, log: PackedStringArray) -> int:
	var bought := 0
	var paid := 0
	# Rations at a farm go into the food store; a farm's or a hall's own
	# makings go into the cargo like a market's.
	var farm := not place.has_market and not place.trade.has(good)
	if not sells_here(place, good):
		log.append("%s sells no %s" % [place.display_name, WorldTypes.GOOD_NAMES[good]])
		return 0
	while bought < units:
		if int(place.stock.get(good, rules.local_stock if place.trade.has(good) else 0)) <= 0:
			break
		if not farm and cargo_room(rules, band) <= 0:
			break
		var p := buy_price(rules, place, band, good)
		if band.silver < p:
			break
		band.silver -= p
		paid += p
		place.stock[good] = int(place.stock.get(good, rules.local_stock)) - 1
		if farm:
			band.food += 1
		else:
			band.cargo[good] = int(band.cargo.get(good, 0)) + 1
			var basis: Array = band.bought.get(good, [0, 0])
			band.bought[good] = [int(basis[0]) + 1, int(basis[1]) + p]
		bought += 1
	if bought > 0:
		if farm:
			log.append("bought %d rations at %s for %d oz" % [bought, place.display_name, paid])
		else:
			log.append("bought %d %s at %s for %d oz (now %d oz a unit)" % [
				bought, WorldTypes.GOOD_NAMES[good], place.display_name, paid, price(rules, place, good)])
	return bought


## Sells up to `units` from the band's cargo, one at a time; each unit sold
## adds to stock and lowers the next price. Returns ounces earned. A place
## without a market buys nothing.
static func sell(rules: WorldRules, place: Place, band: Band, good: WorldTypes.Good, units: int, log: PackedStringArray) -> int:
	if not buys_here(place, good):
		log.append("%s does not buy %s" % [place.display_name, WorldTypes.GOOD_NAMES[good]])
		return 0
	var n := mini(units, int(band.cargo.get(good, 0)))
	var earned := 0
	for i in n:
		# The unit goes onto the stall first and is paid for at the price it
		# then stands at: the same price a buyer would pay to take it back,
		# so selling and buying back is never a gain.
		place.stock[good] = int(place.stock.get(good, rules.local_stock if place.trade.has(good) else 0)) + 1
		earned += sell_price(rules, place, band, good)
	if n > 0:
		band.cargo[good] = int(band.cargo[good]) - n
		if band.cargo[good] <= 0:
			band.cargo.erase(good)
		band.silver += earned
		# The margin on what was bought (not on loot) is the trader's deed.
		var basis: Array = band.bought.get(good, [0, 0])
		var of_bought := mini(n, int(basis[0]))
		if of_bought > 0:
			var cost := int(round(float(basis[1]) * of_bought / float(basis[0])))
			var margin := int(round(float(earned) * of_bought / float(n))) - cost
			band.bought[good] = [int(basis[0]) - of_bought, int(basis[1]) - cost]
			if int(band.bought[good][0]) <= 0:
				band.bought.erase(good)
			band.trade_margin += maxi(0, margin)
			var deeds: int = band.trade_margin / rules.deed_trade_margin
			if deeds > 0:
				band.trade_margin -= deeds * rules.deed_trade_margin
				Way.add_deed(band, Way.Id.TRADER, deeds)
		log.append("sold %d %s at %s for %d oz" % [n, WorldTypes.GOOD_NAMES[good], place.display_name, earned])
	return earned


## Price of the next captive here, or 0 where captives are not bought.
static func captive_price(rules: WorldRules, place: Place) -> int:
	if not rules.slave_markets.has(place.id):
		return 0
	return maxi(0, roundi(float(rules.captive_price) * (1.0 - rules.captive_glut * float(place.captives_sold))))


## Sells up to `count` captives, each at the glutted price of the moment;
## stops when the price reaches nothing. Returns ounces earned.
static func sell_captives(rules: WorldRules, place: Place, band: Band, count: int, log: PackedStringArray) -> int:
	if not rules.slave_markets.has(place.id):
		log.append("%s does not buy captives" % place.display_name)
		return 0
	var sold := 0
	var earned := 0
	while sold < mini(count, band.captives):
		var p := captive_price(rules, place)
		if p <= 0:
			break
		earned += p
		sold += 1
		place.captives_sold += 1
	if sold > 0:
		band.captives -= sold
		band.silver += earned
		log.append("sold %d captives at %s for %d oz" % [sold, place.display_name, earned])
	return earned


## Once a year: every stock moves `drift_fraction` of the way back to its
## baseline, source regions add `source_supply` ± spread, and the captive
## glut clears. Farms refill their grain the same way.
static func yearly_drift(rng: SimRng, rules: WorldRules, world: World, log: PackedStringArray) -> void:
	var ids: Array = world.places.keys()
	ids.sort()
	for id in ids:
		var place: Place = world.places[id]
		place.captives_sold = 0
		var goods: Array = WorldTypes.Good.values() if place.has_market else place.stock.keys()
		for g in goods:
			if place.trade.has(g) and not place.has_market:
				continue  # a farm's stall mends by the day (mend_local)
			var s := int(place.stock.get(g, 0))
			s += roundi(float(rules.stock_baseline - s) * rules.drift_fraction)
			if place.has_market and rules.good_sources.get(g, []).has(place.region):
				s += maxi(0, rules.source_supply + rng.randi_range(-rules.source_supply_spread, rules.source_supply_spread))
			place.stock[g] = maxi(0, s)
	log.append("the markets settle after a year")


## The most profitable good to carry from `from` to another known, open
## market, judged at today's prices: {good, to, profit_per_unit}, or {} if
## nothing pays. The contract signature has no rules; pass them as the
## optional fourth argument when they differ from the defaults.
static func best_trade(world: World, band: Band, from: String, rules: WorldRules = null) -> Dictionary:
	if rules == null:
		rules = WorldRules.new()
	var src := world.place(from)
	if src == null or not src.has_market:
		return {}
	var best := {}
	var best_profit := 0
	for g in WorldTypes.Good.values():
		if int(src.stock.get(g, 0)) <= 0:
			continue
		var cost := price(rules, src, g)
		for id in world.places:
			var dst: Place = world.places[id]
			if id == from or not dst.has_market or not dst.is_open(world.year) or not band.knows(id):
				continue
			var profit := price(rules, dst, g) - cost
			if profit > best_profit:
				best_profit = profit
				best = {"good": g, "to": id, "profit_per_unit": profit}
	return best
