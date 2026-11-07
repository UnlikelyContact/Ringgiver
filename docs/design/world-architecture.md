# World simulation architecture (milestone 3: sandbox foundations)

The contract for `game/sim/world/`. Same ground rules as
`sim-architecture.md`: Godot 4.5 GDScript, tabs, static typing, `RefCounted`
only, every number in `WorldRules`, all randomness through a passed
`SimRng`, tests in `tests/test_<module>.gd`, human-readable log lines.
Interface changes go in this doc in the same commit.

Milestone 3 covers the summer half of the year: a free-sailing map of
Norway and its near neighbours, voyages and encounters, raiding and trade
with a regional market, factions with ambitions and the historical spine,
the Thing, feuds and outlawry, and "letting the years pass". Concept
sections: "Strategic map and economy", "Story > Historical spine", "Ranks,
politics and law", "Core structure > Saga pacing".

## Scales and time

- Summer runs from day 1 (about 1 April) to `summer_days` (about 200,
  late October). `Calendar.day` counts it. Voyages cost days per sea lane.
- Map coordinates are in leagues (roughly 3 nautical miles); the data file
  gives each place a position and the lanes give days directly, so no
  module needs to derive days from distance.
- Wealth 0–100 per place; defenses 0–10; alertness 0–10 (rises when
  raided, decays yearly). Region alertness 0–10 likewise.
- Silver in ounces, as in the campaign layer. Goods in units (a unit is a
  bundle a man can carry; a knarr holds `knarr_cargo` units).
- Faction strength is a number of men they can field (hird plus levy).
- Relations −100..100 between factions and toward the band.

## Existing core (do not restructure)

| File | Class | Role |
|---|---|---|
| `sim/world/world_types.gd` | `WorldTypes` | enums: PlaceKind, Region, Good, ShipKind, FactionKind, Outlawry, CaseKind, Verdict, EncounterKind |
| `sim/world/world_rules.gd` | `WorldRules` | all tunables, sectioned by module |
| `sim/world/place.gd` | `Place` | id, name, region, kind, pos, wealth, defenses, alertness, faction_id, family, has_market, stock (Good -> units), known |
| `sim/world/ship.gd` | `Ship` | kind, crew capacity, cargo capacity, damage; `can_sail()` |
| `sim/world/world.gd` | `World` | places by id, lanes (`days_between`, `neighbours`), region alertness, factions by id (Dictionary of `Faction`, Module L), `timeline_state`, `year`; `build_norway(rules)` loads `NorwayData` |
| `sim/world/norway_data.gd` | `NorwayData` | the map: places and lanes as const data |
| `sim/campaign/band.gd` (extended) | `Band` | `ship`, `cargo`, `location`, `outlawry`, `outlaw_until`, `rank`, `known_places`, `captives`, `land` |
| `sim/campaign/calendar.gd` (extended) | `Calendar` | `day`, `advance_days(n)`, `summer_left(rules)` |

`World.place(id) -> Place`, `World.days_between(a, b) -> int` (−1 if no
lane), `World.neighbours(id) -> Array[String]`, `World.places_in(region)`,
`World.log(line)` appends to `World.chronicle` with the year.

## Module J — voyages, knowledge and encounters (`voyage.gd`, `knowledge.gd`, `encounters.gd`)

```gdscript
# Voyage
static func plan(world: World, from: String, to: String) -> Array[String]   # shortest route by days, [] if none
static func sail(rng: SimRng, rules: WorldRules, world: World, band: Band, cal: Calendar, to: String, log: PackedStringArray) -> VoyageResult
# Knowledge
static func reveal(world: World, band: Band, place_id: String, log: PackedStringArray) -> void
static func hear_rumor(rng: SimRng, rules: WorldRules, world: World, band: Band, at: String, log: PackedStringArray) -> String   # reveals a place or returns ""
static func known_targets(world: World, band: Band) -> Array[Place]
# Encounters
static func roll(rng: SimRng, rules: WorldRules, world: World, band: Band, lane_from: String, lane_to: String, log: PackedStringArray) -> Dictionary   # {} or {kind, text, battle_required: {...}?, silver?: int, food?: int, ship_damage?: int, rumor?: String}
```

`VoyageResult` (`sim/world/voyage_result.gd`): `route: Array[String]`,
`days: int`, `arrived: bool`, `wrecked: bool`, `encounters:
Array[Dictionary]`, `stopped_at: String`.

Rules:

- **Routes** are shortest by days over the lanes (Dijkstra). A band only
  plans through known places plus the destination's unknown neighbours
  being revealed on arrival. Unknown destinations cannot be chosen.
- **Sailing** moves lane by lane: each lane costs its days (plus
  `storm_delay_days` if a storm fires), rolls one encounter per lane with
  `encounter_chance`, and stops the voyage if an encounter requires a
  battle (the caller fights it, then calls `sail` again from
  `stopped_at`). Open-sea lanes (`NorwayData` marks `open_sea: true`) roll
  shipwreck at `wreck_chance` (ship damage `wreck_damage`, cargo lost, and
  `wreck_men_lost` random men drowned, more with mail). A ship with damage
  ≥ `ship_unsailable_damage` cannot sail. Sailing past `summer_days` is
  refused: `arrived = false`, the band stays.
- **Knowledge.** `band.known_places` starts as the home region. Arrival
  reveals the place and its lane neighbours. `hear_rumor` at a market or
  hall reveals a random unknown place within `rumor_radius_days` and
  appends to `band.rumors`.
- **Encounters** (weights in `WorldRules.encounter_weights`): rival ship
  (battle, `rival_crew` men of a tier from the region's alertness),
  merchant (trade offer: buy at `merchant_discount` or rob: battle then
  `merchant_cargo` goods but a feud with the merchant's home town's
  family), outlaws (small battle, bounty `outlaw_bounty` if the band is not
  itself outlawed), the king's levy (if the band is outlawed or at war with
  the ruling faction: battle; else a rumor), storm (delay and ship
  damage), whale or wreck (food). Encounter chance doubles on open sea.

Gate test: a route from Hordaland to Trøndelag is found and costs between
`route_min_days` and `route_max_days`; 1000 coastal lanes wreck nobody;
1000 open-sea lanes wreck at about `wreck_chance`; a band never arrives
after `summer_days`.

## Module K — market, trade and raiding (`market.gd`, `raiding.gd`)

```gdscript
# Market
static func price(rules: WorldRules, place: Place, good: WorldTypes.Good) -> int   # ounces per unit
static func buy(rules: WorldRules, place: Place, band: Band, good, units: int, log) -> int   # units bought
static func sell(rules: WorldRules, place: Place, band: Band, good, units: int, log) -> int   # ounces earned
static func sell_captives(rules: WorldRules, place: Place, band: Band, count: int, log) -> int
static func yearly_drift(rng: SimRng, rules: WorldRules, world: World, log) -> void
static func best_trade(world: World, band: Band, from: String) -> Dictionary   # {good, to, profit_per_unit} among known markets, or {}
# Raiding
static func assess(rules: WorldRules, world: World, place: Place, band: Band) -> Dictionary   # {defenders, tier, expected_plunder, alert}
static func raid(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, log) -> Dictionary   # battle_required: {kind: "raid", attackers/defenders, tier, place}
static func after_raid(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, won: bool, log) -> Dictionary  # {silver, goods: {good: units}, captives, feud: bool}
static func strandhogg(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, log) -> Dictionary  # quick: food and small silver, no battle, alertness and feud chance
```

Rules:

- **Prices.** `price = base[good] × region_factor[region][good] ×
  clamp(stock_baseline / max(1, stock), price_floor, price_ceiling)`.
  Buying removes stock and raises the price; selling adds stock. A place
  with `has_market` false buys nothing but sells food at `farm_food_price`.
  `yearly_drift` moves every stock `drift_fraction` toward its baseline and
  adds supply at sources (furs in the north, amber in the Baltic, Frankish
  blades in the south; the table is `good_sources`).
- **Captives** sell at `captive_price` × (1 − `captive_glut` × captives
  sold here this year); at Hedeby, Birka and Dublin only
  (`slave_markets`). A band that keeps captives over winter needs a ration
  each per turn (the campaign loop handles that; here just the count).
- **Raids.** Defenders = `defenders_base[kind]` + defenses + alertness ×
  `defenders_per_alert`, tier by defenses. `raid` returns a battle request
  the caller fights; `after_raid` on a win: silver = wealth ×
  `plunder_fraction` ± spread, goods from stock (`loot_fraction`),
  captives = `captives_per_win` ± spread (none from halls with defenses ≥
  `no_captives_defense`); the place loses that wealth, alertness += 
  `alert_per_raid`, region alertness += `region_alert_per_raid`;
  the ruling family starts a feud with the band with
  `raid_feud_chance` (returned as `feud: true`; the caller records it with
  `band.add_feud(family, "raid on <place>")`). On a loss alertness still
  rises. **Beacons:** when region alertness ≥ `beacon_threshold`,
  `defenders` doubles for every place in it.
- **Strandhögg** needs no battle: food `strandhogg_food` and silver
  `strandhogg_silver`, alertness +1, feud with `strandhogg_feud_chance`.

Gate test: buying 20 units of furs at Kaupang raises the price by at least
`price_rise_min`; furs bought in Hålogaland and sold at Hedeby make a
profit; five raids on one farm leave it with under a third of its wealth
and `alertness ≥ 5`; region alertness reaching the beacon threshold
doubles defenders.

## Module L — factions, the historical spine and contracts (`faction.gd`, `faction_ai.gd`, `timeline.gd`, `contracts.gd`)

```gdscript
# Faction (data class, stored in World.factions)
var id: String; var name: String; var leader: String; var kind: WorldTypes.FactionKind
var holdings: Array[String]; var strength: int; var ambition: String  # "expand" | "hold" | "trade"
var relations: Dictionary  # faction id -> int; "band" -> int toward the band
var alive := true
# FactionAI
static func yearly(rng: SimRng, rules: WorldRules, world: World, band: Band, log) -> Array[Dictionary]  # events: {kind: "war"|"alliance"|"marriage"|"conquest"|"betrayal", a, b, place?, text}
static func relation(world: World, faction_id: String, other: String) -> int
static func shift(world: World, faction_id: String, other: String, delta: int) -> void
static func ruler_of(world: World, place_id: String) -> Faction
# Timeline
static func pending(rules: WorldRules, world: World, year: int) -> Array[Dictionary]   # spine events due this year whose preconditions hold
static func fire(rng: SimRng, rules: WorldRules, world: World, band: Band, event: Dictionary, player_choice: String, log) -> Dictionary  # {text, battle_required?: {...}, place_opened?: String, faction_changes...}
static func outcome_options(event: Dictionary) -> Array[String]   # choices the player has
# Contracts
static func offers(rng: SimRng, rules: WorldRules, world: World, band: Band, at: String) -> Array[Dictionary]  # {kind: "escort"|"hunt_outlaws"|"levy"|"debt"|"tribute", from_faction, pay, to_place?, days, text}
static func accept(rules: WorldRules, world: World, band: Band, contract: Dictionary, log) -> Dictionary   # battle_required? or voyage_required: to
static func complete(rules: WorldRules, world: World, band: Band, contract: Dictionary, success: bool, log) -> void   # pay, relations, rank progress
```

Rules:

- **Factions** are loaded from `NorwayData.FACTIONS` by `World.build_norway`
  (Module L adds the loading code in `faction.gd` as `Faction.load_all(world)`
  called by the integrator). Harald's faction id is `"harald"`.
- **Yearly AI.** Each faction with `expand` ambition picks a neighbouring
  holding of a weaker faction with relation ≤ `war_relation` and takes it
  with chance `conquest_chance × strength ratio`; relations between the
  two drop by `war_relation_hit`. Factions with relation ≥
  `alliance_relation` ally (log once). Marriage between allies with
  `marriage_chance` raises relation. A faction whose strength falls below
  `absorb_strength` is absorbed by its strongest neighbour. Relations
  toward the band shift from the band's deeds (the integrator calls
  `shift` on raids and contracts); the ruler of a raided place drops by
  `raid_relation_hit`.
- **Timeline** (`WorldRules.spine`): ordered events with `year`, `id`,
  `precondition` (a string the module evaluates: `"harald_alive"`,
  `"harald_holds:<place>"`, `"always"`), `options` (player choices such as
  `"serve"`, `"resist"`, `"ignore"`, `"fight_for_harald"`,
  `"fight_against"`) and `effects`. Events: Harald's vow (866), conquest
  of Trøndelag (868: Harald takes Lade), conquest of the west (870:
  Harald takes Avaldsnes), Hafrsfjord (872: a shield-wall sector battle;
  if the player fights against and wins, Harald's expansion stops and a
  rival jarl faction gets `expand`), Iceland opens (874: `place_opened`),
  Orkney earldom (875), Rollo outlawed (900), Eric Bloodaxe (930), Haakon
  the Good (934). Each fires once (`world.timeline_state[id] = true`).
  History can be changed: if Harald's faction is not alive or lacks a
  precondition, later Harald events do not fire and a replacement event
  fires instead (`spine_fallback`).
- **Contracts** are offered at halls and towns by the ruling faction when
  its relation toward the band ≥ `contract_relation`: escort (sail a
  merchant to a market, pay on arrival), hunt outlaws (a small battle),
  levy (join a faction war this summer: a sector battle, pay in fame),
  debt collection (visit a farm; a strandhögg-like take), tribute (later
  ranks). `complete` pays silver and fame, raises relation by
  `contract_relation_gain`, and adds `rank_progress` on `band` (the
  integrator promotes rank at thresholds).

Gate test: with no player interference, by 880 Harald holds at least
`harald_min_holdings` places and at least two petty factions are absorbed;
if Harald's faction is killed at Hafrsfjord, no Harald event fires after
872 and a fallback does; contracts pay and raise relations.

## Module M — law: the Thing, feuds and outlawry (`thing.gd`, `feud.gd`, `outlawry.gd`)

```gdscript
# Thing
static func open_case(rules: WorldRules, band: Band, kind: WorldTypes.CaseKind, against: String, claim_ounces: int, plaintiff_is_band: bool) -> ThingCase
static func gather_support(rng: SimRng, rules: WorldRules, world: World, band: Band, c: ThingCase, silver_spent: int, log) -> int   # supporters
static func procedure(rng: SimRng, rules: WorldRules, band: Band, c: ThingCase, log) -> bool   # false = a slip sinks the case
static func standoff(rng: SimRng, rules: WorldRules, band: Band, c: ThingCase, log) -> Dictionary   # {weight_us, weight_them, violence: bool}
static func outcome(rng: SimRng, rules: WorldRules, world: World, band: Band, c: ThingCase, log) -> WorldTypes.Verdict
static func run(rng, rules, world, band, c, silver_spent, log) -> WorldTypes.Verdict   # the four stages in order
# Feud
static func start(rules: WorldRules, band: Band, family: String, cause: String, place_id: String, log) -> void
static func summer_events(rng: SimRng, rules: WorldRules, world: World, band: Band, log) -> Array[Dictionary]   # ambushes: battle_required, demands, offers to settle
static func offer_settlement(rules: WorldRules, band: Band, family: String) -> int   # wergild asked
static func settle(rules: WorldRules, band: Band, family: String, ounces: int, log) -> bool
static func escalate(rules: WorldRules, band: Band, family: String, log) -> void
static func wergild(rules: WorldRules, rank: int) -> int
# Outlawry
static func declare(rules: WorldRules, band: Band, cal: Calendar, full: bool, log) -> void
static func is_outlawed(band: Band, cal: Calendar) -> bool
static func halls_closed(band: Band, cal: Calendar) -> bool
static func bounty_hunters(rng: SimRng, rules: WorldRules, band: Band, cal: Calendar, log) -> Dictionary   # {} or battle_required
static func lift(band: Band, log) -> void
```

`ThingCase` (`sim/world/thing_case.gd`): `kind`, `against`, `claim`,
`plaintiff_is_band`, `supporters`, `their_supporters`, `procedure_ok`,
`verdict`, `wergild`, `log`. As built it also carries `victim_rank`
(killings), `lawman_hired` (pay `lawman_fee` for the reroll),
`their_armed`, `weight_us`, `weight_them`, `violence` and
`battle_required` (the `thing_brawl`, since `run` returns only the
verdict). The verdict is judged against the defendant: COMPENSATION and
the outlawries fall on the defendant, FAILED is the plaintiff's loss and
starts a feud. Feud events are `{kind: "ambush", family,
battle_required}` and `{kind: "demand", family, ounces}`.

Rules:

- **Support.** Supporters = base from fame/`fame_per_supporter` + silver
  spent / `ounces_per_supporter` + oath brothers among the men + allied
  factions' relation bonus (`faction_support_relation`). Their side gets
  `their_supporters_base` + the family's standing (`family_standing` by
  place wealth) ± spread.
- **Procedure.** The band's best Wits (leader or a man with the "law-wise"
  trait) + 2d6 against `procedure_difficulty[kind]`; a fail is a slip and
  the case is lost outright, as in Njáls saga. Spending
  `lawman_fee` buys a reroll once.
- **Standoff.** Weight = supporters + armed men × `arms_weight`. If the
  weights are within `standoff_margin` and both sides are armed, violence
  breaks out with `violence_chance`: a battle request (`thing_brawl`) and
  honor −`thing_violence_honor` for the side that struck (the band, if it
  loses the roll of who struck first).
- **Outcome.** Weight ratio decides: COMPENSATION (wergild paid by the
  loser: `wergild(rank)` for a killing, the claim for a raid or land),
  LESSER_OUTLAWRY for `lesser_outlawry_years`, FULL_OUTLAWRY for killings
  with ratio ≥ `full_outlawry_ratio`, or FAILED (the dispute moves to a
  feud; the case logs "the matter goes to the sword").
- **Feuds.** `band.feuds` entries gain `family`, `place`, `level` (1–3)
  and `settled`. Each summer each unsettled feud: with
  `ambush_chance × level` an ambush battle request; with `demand_chance`
  a demand for wergild (settle or escalate); at level 3 the family hires
  `hired_blades` extra men for its attacks. Settling costs
  `offer_settlement` (wergild scaled by level) and sets `settled`;
  refusing escalates. Honor −`feud_refusal_honor` when the band refuses
  a fair offer twice.
- **Outlawry.** `declare` sets `band.outlawry` and `outlaw_until` (year;
  full is open-ended). While outlawed: `halls_closed` (no contracts, no
  winter hospitality, markets refuse: the integrator checks), and
  `bounty_hunters` fires with `bounty_chance` per voyage. `lift` on
  expiry or a Thing verdict.

Gate test: with 50 ounces spent and fame 60 the band wins a raid
compensation case far more often than with nothing spent and fame 10; a
procedural slip rate near `procedure_slip_target` for a Wits-3 leader;
feuds escalate to level 3 after two refusals and then produce attacks
with hired blades; a full outlaw gets bounty hunters.

## Module N — sandbox loop (integrator, after J–M merge)

`sim/world/sandbox.gd` (`class_name Sandbox`): the summer, driven over the
map by a `SummerPlanner` (an AI standing in for the player: raid the
richest known soft target within reach, trade when a profitable route is
known, take contracts when relations allow, go to the Thing when a feud
demands it, go home by the last sailing day); `Campaign` gains a `world`
and uses `Sandbox.summer` instead of fixed raids; `Sandbox.pass_years(n)`
auto-resolves summers (land income, faction AI, timeline, market drift,
aging) until an interrupt (a feud attack, a summons, a spine event, a son
of age, a vow due). `tools/batch_sandbox.gd`; `tests/test_sandbox.gd`.
