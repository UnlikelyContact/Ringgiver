# Campaign simulation architecture (milestone 2: the band between battles)

The contract for `game/sim/campaign/`. Same ground rules as
`sim-architecture.md`: Godot 4.5 GDScript, tabs, static typing, `RefCounted`
only, every number in `CampaignRules`, all randomness through a passed
`SimRng`, tests in `tests/test_<module>.gd`, human-readable log lines.
Modules are built in parallel against this file; interface changes go in
this doc in the same commit.

Milestone 2 covers what happens to a band *between* battles across years:
growth, loyalty and bonds, one winter in the hall, and the leader's luck,
reputation and succession. The strategic map, economy and story threads are
milestone 3. Concept sections: "The band", "Leader, family and succession",
"Winter hall phase".

## Scales and time

- Stats 1–10, as in combat. Potential (hidden cap) 1–10 per stat.
- Effort pools: integers per stat. A stat rises by one when its pool reaches
  `growth_pool_per_point × current stat`, consuming the pool, never past the
  cap, never past the loose total cap without the penalty (see Module E).
- Age in years. Men join at 15–30, peak 25–35, decline from 40.
- Loyalty 0–100 per man. Below `loyalty_leave_below` at the thaw he leaves.
- Bond value −100..100 per pair of men (stored once, keyed by the lower id).
- Luck 0–10 (leader). Reputation: fame 0–100 and honor 0–100 (leader).
- Silver in ounces (`eyrir`), food in rations (one ration feeds one man for
  one winter turn). Bench space in seats.
- Time: `Calendar` has `year` (AD) and `season`. Winter has four turns:
  EARLY, YULE, DEEP, THAW.

## Existing core (do not restructure)

| File | Class | Role |
|---|---|---|
| `sim/campaign/campaign_types.gd` | `CampaignTypes` | enums: Season, WinterTurn, Ambition, Origin, Maim, Task, BondKind, Building |
| `sim/campaign/campaign_rules.gd` | `CampaignRules` | all tunables, sectioned by module |
| `sim/campaign/calendar.gd` | `Calendar` | year, season, winter turn; `advance_turn()`, `next_year()` |
| `sim/campaign/man.gd` | `Man` | a sworn man across years: identity, age, stats, potential, effort, tier, traits, ambition, loyalty, maims, gear, kin; `to_warrior(side, id)` |
| `sim/campaign/band.gd` | `Band` | the leader (a `Man`), his men, silver, food, hall seats and buildings, feuds, bond table, chronicle |
| `sim/combat/*` | | the battle sim; `Warrior.effort`, `Warrior.fate`, `BattleResult` are what comes back from a fight |

`Band.bond(a, b) -> int` and `Band.set_bond(a, b, value)` are the bond
table; `Band.feuds` is an `Array[Dictionary]` of `{against: String, cause:
String, year: int, settled: bool}`; `Band.chronicle` is a
`PackedStringArray` of saga lines; `Band.log(line)` appends with the year.

## Module E — growth and recruits (`potential.gd`, `growth.gd`, `recruits.gd`, `bridge.gd`)

Owner builds `sim/campaign/potential.gd` (`class_name Potential`),
`sim/campaign/growth.gd` (`class_name Growth`), `sim/campaign/recruits.gd`
(`class_name Recruits`), `sim/campaign/bridge.gd` (`class_name BattleBridge`),
tests `test_potential.gd`, `test_growth.gd`, `test_recruits.gd`,
`test_bridge.gd`. Depends on: core and `sim/combat`.

```gdscript
# Potential: hidden caps shown only as saga hints
static func hint(rules: CampaignRules, m: Man, stat: CombatTypes.Stat, judge_level: int) -> String
static func hints(rules: CampaignRules, m: Man, judge_level: int) -> PackedStringArray
static func is_coal_biter(rules: CampaignRules, m: Man) -> bool   # low stats, high caps
# Growth
static func add_effort(rules: CampaignRules, m: Man, stat: CombatTypes.Stat, amount: int, log: PackedStringArray) -> void
static func apply_growth(rules: CampaignRules, m: Man, log: PackedStringArray) -> Array[CombatTypes.Stat]  # stats that rose
static func winter_age(rng: SimRng, rules: CampaignRules, m: Man, log: PackedStringArray) -> void   # +1 year, decline rolls
static func drill(rules: CampaignRules, m: Man, stat: CombatTypes.Stat, log: PackedStringArray) -> void
static func tier_for(rules: CampaignRules, m: Man) -> CombatTypes.Tier
# Recruits
static func make(rng: SimRng, rules: CampaignRules, origin: CampaignTypes.Origin, age: int, name: String, id: int) -> Man
static func random(rng: SimRng, rules: CampaignRules, id: int) -> Man   # random origin, age, name
static func son_of(rng: SimRng, rules: CampaignRules, father: Man, mother_potential: Array[int], name: String, id: int) -> Man
# BattleBridge
static func after_battle(rules: CampaignRules, band: Band, warriors: Array[Warrior], result: BattleResult, log: PackedStringArray) -> void
```

Rules:

- **Hints.** Each cap maps to a phrase per stat (`CampaignRules.hint_phrases`
  keyed by stat then bucket: low 1–3, middling 4–6, high 7–8, great 9–10).
  `judge_level` 0 reveals nothing but "no one can say"; 1 reveals whether
  the cap is above or below the current stat; 2 reveals the bucket; 3
  reveals the bucket and names the best stat. Hints are text only, never
  numbers.
- **Coal-biter:** average current stat ≤ `coal_biter_max_stat` and at least
  two caps ≥ `coal_biter_min_cap`.
- **Effort and natures.** `add_effort` multiplies by the personality nature:
  Reckless (Might ×`nature_up`, Wits ×`nature_down`), Grim (Nerve up, Skill
  down), Boastful (Skill up, Grit down), Steady (Nerve up, Might down),
  Greedy (Wits up, Nerve down), Superstitious (Grit up, Wits down). Then by
  the age multiplier (`age_growth_under_20`, `_20_25`, `_26_35`, `_36_plus`).
- **Growth** raises a stat when its pool reaches
  `growth_pool_per_point × stat`, at most one point per stat per call,
  never above `potential[stat]`. **Loose total cap:** when the sum of stats
  is at or above `total_soft_cap`, the threshold doubles.
- **Aging.** `winter_age` adds one year. From `decline_age` each winter,
  with `decline_chance`, Might or Grit drops one (log it); from
  `old_age` the chance doubles. An old veteran keeps his tier (tier never
  falls).
- **Tiers.** From `battles_survived`: Blooded at `tier_blooded_battles`,
  Veteran at `tier_veteran_battles`, Champion at `tier_champion_battles`
  and at least one stat ≥ `tier_champion_min_stat`. Tier never falls.
- **Recruits.** Origin sets starting ranges and a trait: fisherman (Grit,
  sea), younger son (balanced), outlaw (Might, Nerve; loyalty starts low),
  freedman (low stats, high loyalty), exiled jarl's son (Skill, Wits;
  ambition fame). Caps are rolled per stat from `cap_mean` ± spread; with
  `coal_biter_chance` a recruit gets low stats and high caps. Age from
  origin range. One or two personality traits, never contradictory
  (`personality_conflicts`). Ambition weighted by origin
  (`ambition_weights`). `son_of` averages father's caps and
  `mother_potential` with `inherit_spread` randomness.
- **Bridge.** For each warrior that maps to a man (`Warrior.id` == `Man.id`):
  copy `effort` into the man through `add_effort`; `battles_survived += 1`
  if not Down or fate RECOVERED; fate DEAD → `alive = false` and a
  chronicle line; MAIMED → a random `Maim` from `CampaignTypes.Maim`
  appended to `maims` with its stat penalty applied (`maim_penalties`); then
  `apply_growth` and `tier_for` update. Fled men lose `loyalty_fled_penalty`.
  Survivors of a battle gain `bond_fought_together` with every other survivor
  (through `Band.set_bond`).

Gate test: 200 recruits over 20 simulated years of `add_effort` from a
fixed yearly budget: men reach their caps and stop; coal-biters end above
average; nobody exceeds a cap; total-cap men grow more slowly after it.

## Module F — loyalty, ambitions and bonds (`loyalty.gd`, `bonds.gd`)

Owner builds `sim/campaign/loyalty.gd` (`class_name Loyalty`),
`sim/campaign/bonds.gd` (`class_name Bonds`), tests `test_loyalty.gd`,
`test_bonds.gd`. Depends on: core only.

```gdscript
# Loyalty
static func gift(rules: CampaignRules, band: Band, m: Man, silver: int, log: PackedStringArray) -> void
static func gift_gear(rules: CampaignRules, band: Band, m: Man, item: String, log: PackedStringArray) -> void
static func share_plunder(rules: CampaignRules, band: Band, total_silver: int, leader_share: float, log: PackedStringArray) -> void
static func ambition_progress(rules: CampaignRules, band: Band, m: Man, amount: int, log: PackedStringArray) -> void
static func winter_drift(rules: CampaignRules, band: Band, m: Man, fed: bool, seated: bool, log: PackedStringArray) -> void
static func departures(rng: SimRng, rules: CampaignRules, band: Band, log: PackedStringArray) -> Array[Man]   # at the thaw
static func seating_offense(rules: CampaignRules, band: Band, moved_up: Man, passed: Man, log: PackedStringArray) -> void
# Bonds
static func after_battle(rules: CampaignRules, band: Band, survivors: Array[Man], fallen: Array[Man], log: PackedStringArray) -> void
static func winter_drift(rng: SimRng, rules: CampaignRules, band: Band, log: PackedStringArray) -> void
static func oath_brothers(band: Band, m: Man) -> Array[Man]
static func rivals(band: Band, m: Man) -> Array[Man]
static func on_death(rules: CampaignRules, band: Band, dead: Man, killer: String, log: PackedStringArray) -> void
```

Rules:

- **Gifts.** Silver raises loyalty by `loyalty_per_ounce` per ounce, capped
  per gift at `gift_cap`; arm-ring-sized gifts (≥ `ring_gift_ounces`) add
  `loyalty_ring_bonus` and a chronicle line. Gear gifts raise loyalty by
  `loyalty_gear_gift` and set the man's gear (`item` is "sword", "mail",
  "helmet", "shield", "spear", "axe"). A man whose ambition is SILVER gains
  `ambition_gift_bonus` extra.
- **Plunder.** `share_plunder` splits silver: leader takes `leader_share`
  (0–1), the rest evenly. If the leader's share exceeds `fair_leader_share`,
  every man loses `loyalty_unfair_share`; otherwise gains
  `loyalty_fair_share`. GREEDY men double both.
- **Ambitions.** Each man has one (`Man.ambition`); `ambition_progress`
  adds to `Man.ambition_progress`, and when it reaches `ambition_fulfilled`
  loyalty jumps by `loyalty_ambition_met` and `Man.ambition_met = true`.
  A man whose ambition is HOME with loyalty below `loyalty_leave_below`
  always leaves at the thaw. VENGEANCE progresses only through feuds (the
  campaign loop calls it).
- **Winter drift.** Per winter turn: unfed `loyalty_unfed_per_turn`;
  unseated (no bench) `loyalty_unseated`; otherwise `loyalty_winter_rest`
  (small positive). Leader luck above `luck_loyalty_above` adds
  `loyalty_luck_bonus`; below `luck_loyalty_below` subtracts it.
- **Departures.** At the thaw: loyalty < `loyalty_leave_below` → leaves
  (log and chronicle); loyalty < `loyalty_turn_below` with GREEDY or OUTLAW
  → with `turn_chance` he steals `turn_theft_ounces` on the way out. Oath
  brothers of a leaver lose `bond_brother_left` loyalty. Returns the men who
  left; the caller removes them.
- **Seating.** Moving a man up past another: the passed man loses
  `loyalty_seating_passed`; BOASTFUL loses double; the moved man gains
  `loyalty_seating_honor`.
- **Bonds.** `after_battle`: every pair of survivors +`bond_fought_together`;
  survivors adjacent to a fallen man are unknown to the campaign, so every
  survivor −`bond_lost_friend` toward nobody but gains `loyalty_grief` loss
  if an oath brother fell. Pairs at or above `bond_oath_threshold` become
  oath brothers (`BondKind.OATH_BROTHER`, chronicle line) once; pairs at or
  below `bond_rival_threshold` become rivals. `winter_drift`: each winter,
  pairs with clashing personalities (`personality_conflicts`) drift by
  −`bond_clash_drift`; same-origin pairs +`bond_kin_drift`; RECKLESS versus
  STEADY drunk-quarrel chance `quarrel_chance` logs a quarrel and drops the
  bond by `bond_quarrel`. `on_death`: for each oath brother of the dead
  man, add a feud `{against: killer, cause: "<dead> slain", year, settled:
  false}` through `band.add_feud` unless one already exists against that
  name, set the brother's ambition to VENGEANCE if it was not already
  something stronger (keep VENGEANCE, FAME), and log the vow.

Gate test: a band of ten men over ten winters with fair shares and feasts
loses at most one man; the same band unfed and unshared loses most of them;
two Reckless and Steady men end as rivals more often than two Steady men.

## Module G — the winter hall (`hall.gd`, `winter.gd`, `winter_events.gd`)

Owner builds `sim/campaign/hall.gd` (`class_name Hall`),
`sim/campaign/winter.gd` (`class_name Winter`),
`sim/campaign/winter_events.gd` (`class_name WinterEvents`),
`sim/campaign/winter_plan.gd` (`class_name WinterPlan`), tests
`test_hall.gd`, `test_winter.gd`, `test_winter_events.gd`. Depends on: core
only. Loyalty and growth effects are *reported* through `WinterReport`
(`sim/campaign/winter_report.gd`) and applied by the campaign loop, so this
module does not call Modules E or F.

```gdscript
# Hall (owned by Band.hall)
var seats: int; var buildings: Array[CampaignTypes.Building]; var seating: Array[int]  # man ids, high seat first
func build(rules: CampaignRules, b: CampaignTypes.Building, band: Band, log) -> bool   # pays silver, adds effect
func has(b: CampaignTypes.Building) -> bool
func food_capacity(rules: CampaignRules) -> int
# WinterPlan: what the player (or AI) chose this turn
var tasks: Dictionary   # man id -> CampaignTypes.Task
var drill_stat: Dictionary   # man id -> CombatTypes.Stat (for DRILL)
var feast: bool   # Yule only
var vow: String   # Yule only, "" for none
var gifts: Dictionary   # man id -> ounces (Yule)
# Winter
static func run_turn(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, plan: WinterPlan, log: PackedStringArray) -> WinterReport
static func default_plan(rules: CampaignRules, band: Band, cal: Calendar) -> WinterPlan   # a sensible AI plan
# WinterEvents
static func roll(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, guarded: bool, log: PackedStringArray) -> Array[Dictionary]  # events that fired
```

`WinterReport` fields: `fed: Dictionary` (man id -> bool), `seated:
Dictionary` (man id -> bool), `food_eaten`, `food_gained`, `drilled:
Dictionary` (man id -> stat), `healed: Array[int]`, `repaired: int`,
`feasted: bool`, `vow: String`, `events: Array[Dictionary]`,
`battle_required: Dictionary` (empty, or `{kind: "hall_burning"|"feud_attack",
attackers: int, tier: CombatTypes.Tier}` for the loop to fight with the
combat sim), `men_without_seat: Array[int]`.

Rules:

- **Seats.** `seats` starts at `hall_base_seats`; BENCHES adds
  `benches_seats` each. The leader and his family do not take seats. Men
  beyond the seat count (lowest in `seating` order) are unseated this turn.
- **Food.** Each turn every man and the leader eats one ration. Stores
  above `food_capacity` (STOREHOUSE raises it) spoil at the start of
  winter. Shortage: the lowest-seated go unfed first. HUNT and FISH tasks
  add rations (`hunt_rations` ± spread, FISH only with a BOATHOUSE,
  `fish_rations`). BYRE adds `byre_rations` per turn. The household's
  skill (`Band.household_skill`, 0–5) stretches food: each point saves one
  ration per turn.
- **Tasks.** One per man: DRILL (report drilled stat; an unlocked shout is
  the loop's business), HEAL (men with `Man.healing_turns > 0` reduce it by
  two instead of one), REPAIR (restores one unit of `Band.ship_damage` and
  resets `shield_hp` of all men; SMITHY doubles), HUNT, FISH, GUARD (halves
  the chance of a feud attack and hall-burning), TRAVEL (adds one rumor:
  `band.rumors.append(...)` from `rumor_lines`).
- **Yule.** `feast` costs `feast_rations_per_man` per man; report
  `feasted`. `vow` is recorded in `band.vows` with the year. Gifts move
  silver from the band to the man and are reported for Module F to score.
- **Events.** Each turn roll `events_per_turn` times against a weighted
  list in `CampaignRules.winter_events` (skald, trader, outlaw seeks
  shelter, marriage offer, jarl's envoy, sickness, storm damages ship,
  thrall unrest, drunken quarrel, feud attack, hall-burning). Each event is
  a dictionary with `kind`, a `text`, and its effects already applied to
  the band (silver, food, ship damage, a new man for outlaw via a
  `recruit_request: true` flag so the loop can build him) or the
  `battle_required` dictionary. Feud attacks only when `band.feuds` has an
  unsettled entry; chance `feud_attack_chance` (halved by GUARD). Sickness
  gives `sickness_men` random men `healing_turns`.
- **Thaw.** `run_turn` at THAW reports `men_without_seat` for the whole
  winter so the loop can apply departures.
- **default_plan:** wounded men HEAL, if food will run short the two
  hungriest men HUNT (FISH with a boathouse), one man GUARDs when there is
  an unsettled feud, the rest DRILL their lowest stat; feast at Yule when
  food allows; gifts to the three lowest-loyalty men if silver allows.

Gate test: a band of twelve with rations for ten turns and no hunting ends
winter with men unfed in the last turns; with two hunters it does not; a
hall-burning or feud attack never fires without an unsettled feud; a
storehouse lets stores above the base capacity survive.

## Module H — leader, family and succession (`leader.gd`, `family.gd`, `succession.gd`, `chronicle.gd`)

Owner builds `sim/campaign/leader.gd` (`class_name Leader`),
`sim/campaign/family.gd` (`class_name Family`),
`sim/campaign/succession.gd` (`class_name Succession`),
`sim/campaign/chronicle.gd` (`class_name Chronicle`), tests
`test_leader.gd`, `test_family.gd`, `test_succession.gd`,
`test_chronicle.gd`. Depends on: core only (Module E's `son_of` is called
by the campaign loop, not by Family; Family only records births with the
mother's potential array).

```gdscript
# Leader (state lives on Band: luck, fame, honor, vows)
static func on_battle(rules: CampaignRules, band: Band, won: bool, led_from_front: bool, odds: float, log) -> void
static func on_vow_kept(rules, band, vow: String, log) -> void
static func on_vow_broken(rules, band, vow: String, log) -> void
static func on_oath_broken(rules, band, log) -> void
static func on_feast(rules, band, lavish: bool, log) -> void
static func on_omen_ignored(rng, rules, band, log) -> void
static func luck_modifier(rules, band) -> int   # -1..+1 for combat rolls and events
static func recruits_drawn(rules, band) -> int   # how many men want to join this year, from fame
# Family (state on Band: wife, sons: Array[Dictionary] {name, born, potential, fostered_with, alive})
static func marry(rules, band, wife_name: String, wife_potential: Array[int], household_skill: int, alliance: String, log) -> void
static func winter_births(rng, rules, band, cal, log) -> Array[Dictionary]   # new sons
static func foster_out(rules, band, son: Dictionary, lord: String, log) -> void
static func sons_of_age(rules, band, cal) -> Array[Dictionary]
# Succession
static func heir(rules, band, cal) -> Dictionary   # {kind: "son"|"second"|"none", son: Dictionary or null, man: Man or null}
static func name_second(band, m: Man, log) -> void
static func succeed(rng, rules, band, cal, heir_man: Man, feast_ounces: int, vow: String, log, death_cause := "") -> Array[Man]  # men who leave; death_cause "battle"|"old"|"outlaw"|"sickness"|"oathbreaker"
# Chronicle
static func year_lines(band: Band, year: int) -> PackedStringArray
static func generation_text(band: Band, leader_name: String, from_year: int, to_year: int, death_cause := "", rules: CampaignRules = null) -> String  # cause defaults to the one succeed recorded
static func line(band: Band, text: String) -> void   # appends "<year>: text"
```

Rules:

- **Luck.** `on_battle`: won against `odds` < `long_odds` → +`luck_long_odds`;
  won → +`luck_win`; lost → −`luck_loss`; `led_from_front` false → −`luck_hung_back`
  and −`honor_hung_back`. Vows kept: +luck, +honor, +fame; broken: −luck,
  −honor. Oath broken: −`luck_oath_broken`, −`honor_oath_broken`. Lavish
  feast: +fame. Omen ignored: with `omen_chance` −luck. Clamp 0–10 and
  0–100. `luck_modifier`: luck ≥ `luck_high` → +1, ≤ `luck_low` → −1.
  `recruits_drawn`: `fame / fame_per_recruit`, at least `recruits_min`.
- **Family.** `marry` sets `band.wife`, `band.household_skill`, records the
  alliance. `winter_births`: if married, chance `birth_chance` per winter
  of a son (sons only matter for succession in this milestone; record
  daughters too with `daughter_chance` share, as `{name, born, daughter:
  true}`). Sons keep the mother's potential array for `son_of`. Fostering
  sends a son away (`fostered_with`) and adds an alliance line.
- **Succession.** `heir`: eldest living son aged ≥ `heir_min_age` (not
  fostered away unless `foster_returns_at_age`), else the named sworn
  second (`band.sworn_second_id`) if alive, else none. `succeed`: the heir
  becomes `band.leader` (a son becomes a `Man` built by the loop from
  `son_of`; `succeed` receives him as `heir_man`); the old leader's feuds
  carry over in full; luck carries `luck_inherit_fraction` of the old
  leader's luck (plus `luck_good_death` if he died in battle, minus
  `luck_shameful_death` if outlawed or of a broken oath); fame carries
  `fame_inherit_fraction`. Grave-ale: `feast_ounces` spent; every man
  re-decides: stays if loyalty + bond with heir + heir fame/10 + feast
  bonus ≥ `stay_threshold` else leaves (returned). The `vow` is recorded.
  A sworn second who was passed over for a son with bond < 0 toward the
  son leaves with his oath brothers (`challenge_chance` logs a challenge
  instead; resolution is a holmgang the loop fights).
- **Chronicle.** `year_lines` filters `band.chronicle` by year prefix;
  `generation_text` joins the years into a short saga paragraph with the
  leader's name and a closing line by how he died (`death_lines`).

Gate test: a leader with high fame and honor, dying in battle, keeps more
men through succession than a low-fame leader dying outlawed; a son of 12
is never the heir; feuds carry over.

## Module I — campaign loop (integrator, after E–H merge)

`sim/campaign/campaign.gd` (`class_name Campaign`): one year = summer of
`battles_per_summer` fights (built with `BandFactory` for the enemy, the
band's men through `Man.to_warrior`), bridge and bonds after each, luck
after each; then winter: four `Winter.run_turn` calls with
`default_plan`, loyalty drift from the report, births, aging and growth at
the thaw, departures; succession when the leader dies. `tools/batch_years.gd`
runs N seeded campaigns of Y years and reports: survival, stat growth,
tiers, departures, successions, coal-biters found. `tests/test_campaign.gd`
is the gate: a ten-year campaign runs without error and replays exactly;
men grow and reach tiers; an unfed band scatters; a dead leader is
succeeded.

## Integration notes (as built, 7 Nov 2026)

Module I is in: `campaign.gd`, `tools/batch_years.gd`, `tests/test_campaign.gd`.
Interface drift from the spec above, and rules added while integrating:

- `Man.to_warrior(side)` (no id parameter; ids are preserved from the Man).
- `Succession.succeed(rng, rules, band, cal, heir_man, feast_ounces, vow, log,
  death_cause := "")`; `Chronicle.generation_text` takes optional
  `death_cause` and `rules`. The wife's potential is kept in band metadata
  (`Family.wife_potential`). Daughters live in `band.sons` with
  `daughter: true`.
- `Loyalty.gift` does not move silver (the hall's Yule gifts already did).
  Both `BattleBridge.after_battle` and `Bonds.after_battle` award
  "fought together"; the loop zeroes the tunable around the second call.
- Enemy bands are built to the band's **mean stat** (`BandFactory.make_band`
  `stat_center`) and a tier relative to the band's own, with size tracking
  the band. Matching enemies by tier alone made every fight a loss once the
  men were Blooded with green stats.
- The player's leader gets the same +1 Might, Skill and Nerve an enemy
  leader gets (`leader_start_bonus`).
- A sworn second is named at the start and whenever the slot is empty
  (highest tier, then best bond). Marriage offers are accepted when the
  leader is unmarried; outlaws seeking shelter join. Without these, four
  of five sagas ended in year one of a leader's death.
- `growth_pool_per_point` 10 → 6 and `drill_effort` 3 → 6: at the old
  values original men gained under one stat point in ten years.
- `fate_maimed_below` 10 → 8: a third of all downed men were being maimed.
- Winter feud attacks never fire in batch runs because feuds only start
  when an oath brother dies and the oath threshold is rarely reached in
  ten years. The feud system needs more sources (raids, the Thing) in
  milestone 3.

### Milestone 2 gate, measured

50 seeded campaigns of 10 years from a leader and four men: 5 ended with
no heir; mean 10.7 men at the end; per campaign 27.9 battles, 15.7 won,
5.5 dead, 6.2 maimed, 3.9 left, 16.0 joined, 0.4 successions, 2.5
coal-biters found; original men still serving gained 6.1 stat points;
tiers at the end across all bands: 103 green, 65 blooded, 318 veteran,
49 champion. Every campaign replays exactly from its seed. Encoded in
`tests/test_campaign.gd`.
