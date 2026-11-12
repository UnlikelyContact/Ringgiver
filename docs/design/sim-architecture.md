# Combat simulation architecture (milestone 1)

The contract for `game/sim/combat/`. Modules are built in parallel against
this file; if you need to change an interface here, change the doc in the
same commit and say so in your report.

## Ground rules

- Godot 4.5 GDScript, tabs, static typing everywhere (`var x: int`, typed
  arrays, `->` return types). One `class_name` per file.
- `RefCounted` only. No `Node`, no scene tree, no autoloads, no signals. The
  sim runs under `godot --headless -s`.
- All randomness through a `SimRng` passed in. Never `randi()`/`randf()`.
- Every number lives in `CombatRules`, in your module's section, with a
  default. Modules receive a `CombatRules`; they never hard-code a value.
- Modules may read and mutate `Warrior` state and the `BattleGrid` (that is
  what they are for), but they do not call each other except as listed under
  "depends on". The battle loop wires them together.
- Tests: `tests/test_<module>.gd` extending `TestCase`, run with
  `ring-giver/scripts/test.sh`. Test the rule, not the implementation: for
  anything probabilistic, run thousands of seeded trials and assert a range.
- Log lines: modules append human-readable strings to a `PackedStringArray`
  log they are given, one per notable event ("Egil hits Grim: wounded").
  The batch runner and future replay viewer read these.

## Scales

- Stats 1–10. Fresh recruit 2–5, veteran 4–7, champion 6–9.
- Rolls: stat + modifiers + 2d6, opposed (`OpposedRoll`). Margin 1–2
  glancing, 3–5 hit, 6+ heavy.
- Morale: starts at Nerve (1–10 scale) and moves by whole points. A man at
  or below `morale_break_threshold` must check or break.
- Breath: `breath_base + grit * breath_per_grit`; actions cost breath;
  penalties at half and at zero (`Warrior.fatigue_penalty`).
- Grid: hexes since 8 Nov 2026 (see "Hex grid" below): hex distance, six
  facings. Arcs relative to facing: FRONT, FRONT_RIGHT (open, no flank
  bonus), RIGHT (exposed flank), REAR (two cells), LEFT. Shield covers
  FRONT and LEFT.

## Existing core (do not restructure)

| File | Class | Role |
|---|---|---|
| `sim/rng.gd` | `SimRng` | seeded dice, `fork(label)` for sub-streams |
| `sim/combat/combat_types.gd` | `CombatTypes` | all enums and name tables |
| `sim/combat/rules.gd` | `CombatRules` | all tunables, sectioned by module |
| `sim/combat/opposed_roll.gd` | `OpposedRoll` | one opposed 2d6 roll and its tier |
| `sim/combat/action.gd` | `Action` | a man's intent for the round |
| `sim/combat/warrior.gd` | `Warrior` | stats, gear, roles, battle state |
| `sim/combat/battle_grid.gd` | `BattleGrid` | cells, occupancy, facing and arc math |

## Round structure (owned by `Battle`, module D)

1. Each leader picks a shout (player input or `LeaderAI`).
2. `Shouts.propagate` sets each man's `heard_order` and `order_lag`.
3. `Decision.choose` gives every active man an `Action`. Simultaneous: no
   man sees another's choice.
4. Beats, in order:
   1. **Movement.** All MOVE and FLEE actions. Two men choosing the same
      cell: higher Might + 2d6 takes it, the other stays. Fleeing men who
      reach a map edge are `fled`.
   2. **Missiles.** All SHOOT actions (`MeleeExchange.resolve_shot`).
   3. **Melee.** Every pair with at least one ATTACK between them resolves
      once (`MeleeExchange.resolve`). A man attacked by several enemies
      resolves against each; order is deterministic (by warrior id).
   4. **The push.** `Push.resolve` for lines in contact.
   5. **Morale.** `Morale.round_update`: modifiers, break checks, panic
      spread.
5. End check: a side with no active, unbroken men loses; `max_rounds`
   is a draw.

## Objectives (`objective.gd`)

An `Objective` (RefCounted) gives a field something to take or hold, so one
side must come on. Kinds: `HOLD_GROUND` (the ford), `REACH_THE_SHIPS`,
`THE_HALL`. Each has `attacker` (side), `cells` (it owns the list; `place`
draws its ground and lists every hex it drew in `features`), `rounds`,
`name`, `brief(side)` and
`progress(battle)` for the HUD. `check(battle)` returns -1 or the winning
side and sets `reason`; it counts once per round (the hall's two-round
streak), so a second call in a round is free.

*The clock (10 Nov 2026).* `rounds` count from the round the lines meet,
not from round one: `check` sets `clock_start` the first round
`Battle.lines_met()` is true (a standing man of one side at arm's length of
one of the other) and logs it ("the lines meet: 16 rounds for side 0 to
take the ford"); `elapsed`, `rounds_left`, `clock_running` and
`clock_text` ("16 once they meet", "10 left") read it. So the walk across
the field, a green wall's hesitations (a quarter of its rounds) and the
ground in the way cost the attacker nothing; before this the attacker on
a ford often never reached the enemy before the clock ran out. An
attacker who has not closed by `objective_approach_rounds` (24) has given
the day up. The AI attacker's nudge to push fires at half the rounds by
either count.

- Ford: when the clock runs out the attacker has it if `ford_men` of his
  standing men are on the crossing or over the stream, on the defender's
  bank (`ford_count`); fewer, and the defender keeps it. `size_for_band`
  sets `ford_men` to `ceil(band * objective_ford_fraction)` (a quarter:
  three of twelve), at least `objective_ships_min_men`. Forcing a held
  crossing is the hardest task on the field: the men come through the
  water a few at a time, unlocked, into a formed line.
- Ships: `ships_men` standing attackers on the strip wins at once; the
  defender wins at `objective_ships_rounds` (20). `size_for_band(band)` sets
  `ships_men` to `ceil(band * objective_ships_fraction)` (a third), at least
  `objective_ships_min_men` (2): four for twelve men, two for four to six.
  Built without a band it keeps `objective_ships_men` (4).
- Hall: the attacker on at least half the cells for `objective_hall_streak`
  (2) rounds running; the defender wins at `objective_hall_rounds` (18).

`Battle.objective` (null for an open fight) is checked first in the end
check; a decision sets `BattleResult.by_objective`. The other end checks
stand, except that a stall ("neither side will close again") with an
objective goes to the defender. Two overrides in `Battle._objective_nudge`
act on an AI leader's chosen shout without touching `LeaderAI`: an
attacker told to hold past half the objective's rounds pushes; a defender
told to push while none of his men is engaged holds.

`Scenario.build(..., vary=true)` draws the objective from its own seed fork
(`objective_chance` 0.7, `objective_player_attacks` 0.5) and places it at
the defender's end, before anyone deploys: the ford is a stream on the
row before his line, so his line is the bank (see "Fields and terrain"),
the ships a strip three rows
behind his front, the hall a building four rows behind it. The attacking
side brings `objective_attacker_shields` (2 at twelve men, scaled to the
band) more shields than the defender's draw would give. `vary=false` never
has an objective.
`tools/batch_player.gd` reports per strategy how fights ended (objective,
lines broke, drawn), the mix of fields and the win rate attacking,
defending and in the open. `tools/diag_mixed.gd` prints one line per
fight (field, objective, role, enemy, doctrine, outcome) and takes
`kind=ford role=attack edge=N more=F ford_frac=F ford_rounds=N` to filter
and to try tunables, and `log` for the whole log with the field drawn
after every round.

## Origins, paths and the free-roam map (`origins.gd`, `way.gd`, `map_grid.gd`, `roam.gd`, 12 Nov 2026)

This replaces what the next section says about starting as a way and
sailing lane by lane; the deeds, the fight hand-off and the screens'
structure stand.

`Origins.DEFS` (burned_hall, younger_son, freedman: origin enum,
followers, silver, `at`, `feud_with`). `Campaign.start_from(key, name)`;
`Journey.begin(seed, origin_key, name)` puts the band at its place with
no ship, knowing the places within `known_leagues_start`, and for the
burned hall adds the feud and `Band.vengeance` (`Journey._vengeance`
tells it when that feud is settled).

`Way`: `DEFS[way].ranks[0..2]` = {name, text, gifts} (the whole of the
edges at that step). `Band.paths` (Way.Id -> 1..3). `points_earned` =
`START_POINTS` (1) + total deeds / `POINT_DEEDS` (6); a step costs its
number; `can_invest`, `invest`, `refresh` (rebuilds `Band.gifts`, sets
`Man.fury` and the trait). `standing(band)` is what he is by his steps,
`epithet` what the saga calls him by his deeds. `Journey.invest(way)`
also costs every lord's trust at the berserk's first step. New gifts
read: `strandhogg`, `raid_captives` (Raiding), `price_talk` (MapScreen),
`champion_fee`, `verse_fame` (Callings); `fury` is now a level
(`Warrior.fury_level`).

`MapGrid` (one static grid, `MapGrid.norway()`): 180 by 140 one-league
cells from `ORIGIN` (-58, -14); `T` {DEEP, SEA, SHORE, LAND, MOUNTAIN}
from `NorwayData.SHORES` (point in polygon), every place's cell forced
to land and given water at one of its four sides by `_harbour` (a fjord
cut back along the shortest land walk to the sea, round other places),
then terrain by four-way distance (`SHORE_WITHIN` 2, `LAND_WITHIN` 5,
`DEEP_BEYOND` 4). `COST` per terrain. `find_path(from, to, foot, sail,
aboard, ship_cell, deep_ok)` is A* over (cell, with-ship): water needs
the ship, a ship lands and launches square on and never cuts a corner
of land, walking on leaves her, reaching `ship_cell` on foot picks her
up; returns {cells, aboard, days}. A closed set keeps it finite (without
it, equal-cost re-pushes never ended).

`Roam`: the band's `pos`, `aboard`, `ship_at`, its `route`; `plot`,
`step_band` (to the next cell centre; `last_cell` is where she is left);
cached `sea_route` and `place_days`; `Party` (merchant, raiders,
outlaws, levy) with `populate` each spring and `step_parties` (follow a
sea route, wander near a farm, or `_chase` the band over its own
element when it likes the odds; returns the party in contact).

`Journey`: `go_to_place`, `go_to_point`, `advance(dt)` (band, clock,
`_look_about` for places in sight, `_weather` afloat, parties, `_meet`),
`travel`, `sail(to)` (both, for the stand-in), `days_to`, `foot_speed`,
`sail_speed` (0 without a hull, with too few hands or too many men),
`ship_trouble`; `_pass(days)` for days spent at a deed. New deeds:
`hull:<kind>` (`hulls_for_sale`, `hull_cost`), `passage:<place>`
(`passages`), `camp` in the wilds, `winter` at any settled place (a
guest pays `guest_winter_per_man`). `here()` is null in the wilds.
`JourneyBot.play_year(j, bent)` spends points down its bent and buys a
hull that carries its men.

The view: `game.show_origins`; `MapScreen` draws the grid as a texture
(nearest filtering, five terrain colours), the course, the known places,
the parties within sight, the ship where she lies and the band, with a
camera that follows or is dragged, zoom, and Pause / Faster / Stop;
`_process` advances the journey while the band is under way; a tap on
the map sets the course; "Your ways" shows the points and the steps.

## Ways of life and the player's summer (`way.gd`, `callings.gd`, `journey.gd`, 12 Nov 2026)

`Way` (campaign): `Id` {VIKING, TRADER, LAWMAN, BERSERK, SKALD,
KINGS_MAN}, `DEFS` (name, model, blurb, origin, followers, silver, ship,
the leader's stat changes, `gifts`, epithet). `Way.apply(band, way)` sets
`Band.way`, `Band.gifts` and the leader's stats (and the trait "berserk"
for the fury); `Campaign.start_as(way, name)` is `start` + `apply`.
World modules read an edge through `Band.gift(name, default)`:
`raid_plunder` (Raiding.after_raid), `trade_edge` (Market.buy_price /
sell_price, cancelling `market_spread`), `law` (Thing.procedure,
Callings.counsel), `counsel_fee`, `foresight` (Campaign.offer_fight: the
scout reads as Wits 10 and seasoned, `they_know_first` never), `fury`,
`dread` (Callings.holmgang_yields), `verse`, `verse_gift`, `contract_pay`
and `rank_progress` (Contracts.complete), `lords_favour` and
`knows_markets` (Journey.begin). `Way.add_deed(band, way, points)` counts
on `Band.deeds`; `renowned_for`, `epithet` and `title` name the man once
a way has `EPITHET_DEEDS` (6). Deed points are WorldRules `deed_*`.

`Callings` (world): `has_dispute` / `can_counsel` / `counsel`; `can_verse`
/ `verse_need` / `verse`; `can_challenge` / `holmgang_terms` /
`holmgang_opponent` / `holmgang_yields` / `challenge` / `after_holmgang`;
`can_champion` / `bully` / `after_champion`. Once a year a place each
(`Band.counselled`, `versed`, `challenged`, `championed`, `raided`);
disputes and bullies are drawn from the place, the year and `World.salt`.
Friends (`Band.friends`) count `friend_support` each in
`Thing.gather_support`.

Combat: `Warrior.fury` / `in_fury(rules)`; `condition_penalty` returns
`-fury_bonus` in the fury and wound + fatigue + `fury_spent_penalty` out
of it; `Morale.round_update` takes `morale_fury_near` from a man with an
enemy in the fury beside him. `Battle.duel`: the end check finishes at
first blood (`duel_first_blood`, WOUNDED) with `End.FIRST_BLOOD`.
`Scenario.build_duel(seed, rules, ours, theirs)`: one man each on a bare
9 by 8 field, three rows apart.

`Campaign.resolve_offer` is now `settle_choice` + `fade` or `build_fight`
+ `battle.run()` + `conclude_fight`; `build_duel(opponent, seed)` builds
a holmgang for the same `conclude_fight` (no flat plunder, no luck).
`_arm_new_men` gives each new man a place in the line (shield, spear or
bow, whichever the band is shortest of against `Scenario.band_split`).
On the map a won fight pays `plunder_per_win_world` (10), not 30.

`Journey` (world) is the player in place of `Sandbox.summer`.
`Journey.begin(seed, way, name, home)` makes the campaign, the world
(`Sandbox.setup`), the way's ship and knowledge, and calls
`begin_summer` (spine events and feud events become decisions).
`decisions` is a queue of {kind: spine | demand | merchant | fight, text,
options: [{id, label, enabled}]}; `answer(id)` answers the first. A
fight is a `FightOffer` with a context (sea, rob, raid, contract, spine,
feud, thing, duel, champion); answered, it is either told quickly
(`quick`) or left in `fight` {offer, built, ctx} with side 0's AI cleared
(`Battle.clear_ai`) for the battle screen, which calls
`fight_done(result)`; `_after_fight` then does what the fight was for
(plunder, the lord's pay, the bounty, the stake). `sail(to)` goes lane by
lane (`_voyage`), stopping for what is met; `actions()` lists what the
place allows as {id, label, hint, enabled} and `act(id)` does it;
`market()`, `buy`, `sell` are the trading; `_settle` goes on with what
was interrupted (the voyage, work that waits at a place, the closing
season, the winter) up to the next thing a person must answer. `_winter`
runs `Campaign.winter` and keeps its lines in `winter_report`, then the
next spring begins. `status()` is what the screen shows. `JourneyBot.
play_year(j)` is a stand-in player for each way; `tools/batch_ways.gd
[sagas] [years] [seed] [way|all] [log]` reports what became of them.

The view: `view/game.tscn` (`game.gd`) is the main scene: the title
(Begin a saga, A single fight), `show_ways` (six cards and a name),
`begin_saga`, `show_map` (`MapScreen`), `start_battle` (instantiates
`main.tscn` with `host` set and calls `main.start_hosted(built,
shouts)`), `fight_over(result)` (the HUD's aftermath lines come from
`Journey.fight_done`), `leave_battle`. `MapScreen` draws the known
places, the lanes between them and rough shores on a `MapCanvas` (tap a
place to pick it), the status, the place and its deeds and market on the
right, the last lines of `Journey.said` below, and modals for the
decision, the winter report, the saga's end and the roster ("Your men").
`tools/screenshot_game.gd <out> [way|title|ways] [seed] [commands]`
renders any of it.

## Drill and custom shouts (`formation_template.gd`, `custom_shout.gd`, 11 Nov 2026)

`FormationTemplate.learned` marks a shape the band must drill: `wedge()`
and the new `refused()` (Shape.REFUSED: `Formation.template_slots` moves
the two outermost front slots a hex straight back, unless a second-rank
man has the cell), and any `custom(name, shape, rank_of)`. `presets()`
now ends with the learned two; `named(name)` finds one. `Warrior.drill`
(name -> points, copied from `Man.drill` by `to_warrior`) and
`familiar(template, full)` (1 for a shape every leader knows, points over
`drill_points_full` (3) for a learned one). `Battle.familiarity(side)` is
the mean over the leader's chain; `_plan_wall` scales the wall's test by
`lerp(drill_unfamiliar_factor (0.4), 1, familiarity)`; `Decision._form`
braces instead of stepping to the slot with chance `(1 - familiar) *
drill_fumble_chance` (0.5), with a reason.

`CustomShout` (name, template, order). `Battle.call_custom(side, shout)`
sets the leader's formation, a pending SHIELD_WALL, and `_follow_up`;
the shout is logged under its name, men whose familiarity is 0 have
their heard order cleared ("N of X's men do not know the word"), and the
round after, the order is given unless another shout was set first. On
the campaign side: `Man.learn(shape, full, year)`, `Band.custom_shouts`,
`Band.drilling`, `Band.familiarity(shape, rules)`; `WinterPlan.
drill_shape` (the default plan takes `band.drilling`), a point a DRILL
turn (`Winter.run_turn`, `WinterReport.drilled_shape`); `Campaign._thaw`
takes `drill_decay` (1) from every man whose `drilled_year` is not this
year; `BattleBridge.after_battle` gives every man who stood a point in
the learned shape the leader fought in. The prototype: `BattleView.
pending_custom`, the HUD's custom shout button (one, the row narrowed),
the familiarity after the Form button's name, and `_show_drill_yard`
(drill a learned shape, swear a shout: `main.drill`, `main.swear_shout`).
Six tests in `test_drill.gd`.

## The choice before the fight (`fight_offer.gd`, `scouting.gd`, 11 Nov 2026)

`Campaign.fight(kind, tier, size, attacking, stat_center, at_sea,
cornered)` is now `offer_fight` + `fight_policy.call(offer)` +
`resolve_offer`. `FightOffer` carries the enemy as the world has them
(size and tier from the caller; shields, spears and bows by
`Scenario.band_split`, all shields at sea; a leader's name
(`BandFactory.leader_name`) and doctrine from the offer's seed), the
flags `attacking`, `at_sea`, `cornered`, `we_know_first`,
`they_know_first`, `our_men`, `odds_max`, and the scout's `report`.
`options()`: TAKE_THE_FIELD always; WAIT_FOR_THEM when not attacking and
not at sea; LAY_AMBUSH when `we_know_first` and not at sea; FADE_AWAY
unless cornered; none at all when `they_know_first`. `scenario_for`
maps a choice to a Scenario name: "equal_green" (the open field, `pick`
objective -1), "hold" (the river, HOLD_GROUND with the enemy attacking),
"ambush", or "ambushed" when they saw you first.

`Scouting.pick_scout` is the sharpest living man (seasoned before green
at equal wits). `error(rules, wits, tier)` = `scout_error` (4) less
`scout_error_per_wits` a point above one, less `scout_veteran_bonus`,
floored at zero; `report` draws a shift in ±error and gives
[truth+shift-error, truth+shift+error], the arms in kind, the leader's
name from `scout_leader_wits` (3) and his manner (`LeaderAI.
DOCTRINE_MANNER`) to a seasoned scout, "at sea" when there is no ground.
`spots_first` = `scout_first_chance` (0.15) + `scout_first_per_wits`
(0.05) a point + `scout_first_veteran` (0.1). In `offer_fight`, only when
not attacking, not at sea and not cornered: `we_know_first` by that roll,
else `they_know_first` by `caught_chance` (0.25).

`resolve_offer`: FADE_AWAY tallies `faded`, logs it, and calls
`Leader.on_battle(..., WITHDREW)` (honor −`honor_withdrew`, no luck);
returns null, which every caller now guards. Otherwise the band's men
(`Man.to_warrior`) and a mixed enemy (`make_mixed_band` with the
`stat_center`) go to `Scenario.build(name, seed, rules, vary, band, "",
{ours, theirs}, pick)`, which takes ready-made bands and forced picks
(objective, attacker, doctrine); at sea the symmetric flat field. Our AI
is AGGRESSIVE when attacking or ambushing, STEADY when waiting; theirs
AGGRESSIVE when they come at the bank or caught us. The tally counts
`faded`, `ambushes`, `waited`, `caught`. `Sandbox.choose_fight` is the
policy: ambush if offered, else wait if offered, else fade when the
scout's mid count exceeds `our_men * odds_max` (world `raid_odds_max`),
else take the field. Call sites pass `at_sea` for sea fights, `cornered`
for the hall and the Thing, and `attacking` false for a feud's blades.

`BattleResult.how` (End: ROUT, DRAW_OFF, STALL, OBJECTIVE, TIMEOUT,
WITHDRAWAL) is set by every `Battle._finish`; `outcome(side)` is the
ladder (Outcome: ROUTED_THEM, DROVE_THEM_OFF, WON_THE_FIELD,
BOTH_DREW_OFF, WITHDREW, DRIVEN_OFF, ROUTED, LOST_THE_FIELD), with
`won`, `withdrew`, `outcome_text`. `Battle.withdraw(side)` ends the fight
as a WITHDRAWAL when `can_withdraw` (no standing man of the side at arm's
length of an enemy); nobody is counted as fled. `Leader.on_battle` takes
the outcome: `fame_rout` on top of a rout, `honor_withdrew` for a
withdrawal and no luck, nothing for both drawing off. The prototype's
HUD shows the offer panel before round one on a fresh field
(`_show_offer`: the scout is you, the rolls from the seed), a Withdraw
button in the top bar, and the ladder's title on the result panel.

## What a fight leaves behind (`aftermath.gd`, `bridge.gd`, 11 Nov 2026)

`Aftermath.apply(rules, band, warriors, result, rng, on_land, log)` is
what both the campaign (`resolve_offer`) and the prototype's roster
(`main.after_fight`) call after a fight. It runs `BattleBridge.
after_battle`, which now returns what it did by name ({dead, maimed,
wounded, grievous, fled, broke, deeds, tiers}) and also: puts
`Warrior.kills` (counted in `Battle._after_exchange`) on `Man.kills`,
with a deed (`Man.deeds`) at `deed_kills` (2) in one fight; sets
`Man.healing_turns` from the wound the man ends with (`wound_turns` by
CombatTypes.Wound: 0, 1, 2, 4, 4 for a man carried off and recovered),
never lowering it; and for a man who broke but did not get away,
`broke_count` += 1, loyalty −`loyalty_broke_penalty` (3), and the trait
"broke and ran once" the first time. Then loot (`loot_per_man` 8 oz per
`Warrior.looted`, on a win) into `band.silver`, and on a win on land a
recruit (`Recruits.random`) by `recruit_after_rout_chance` (0.35) after a
rout or `recruit_after_win_chance` (0.15), from the battle's rng fork so
it replays. `Aftermath.lines(told)` reads it out in plain words.

The wound carried: `Man.current_wound(rules)` derives it from
`healing_turns` (≥ `grievous_turns` 4: grievous; ≥ 2: wounded; ≥ 1:
bruised), `too_hurt_to_fight` is grievous, `Band.fighters(rules)` leaves
such men out and `Band.hurt(rules)` lists them, `Band.mend(turns)` heals
everyone a turn (the campaign calls it with `mend_between_fights` (1)
before every fight; winter turns did already). `Man.to_warrior(side,
rules, javelins)` now sets the role (`Man.role`: SHIELD, SPEAR or
MISSILE; a bowman has no shield, a shield-bearer carries the javelins)
and the wound. The prototype's `main.make_roster` draws you and eleven
men (`Recruits`, roles by `Scenario.band_split`), `start` builds the
fight from `roster.fighters(rules)` with the Scenario builders' `bands`,
`after_fight` applies the aftermath and writes `after_lines` for the
result panel, `next_fight` mends a turn; your death sets `saga_over`
and the next fight gathers a new band.

## The ambush (`Scenario.build_ambush`, 10 Nov 2026)

`Scenario.build("ambush", seed, rules, _, band)` is the fight you chose
(concept.md, "Picking your fights"). No objective, no Field template: the
enemy, drawn at `ambush_more_shields` (half) more shields than yours and
as many spears and bows, stands in a column along `track_row` (the row
above the middle), leader in the centre, the rest in march order either
side of him with every `ambush_gap_every`th (third) place empty, all
facing east with `line_facing` east and a `line()` formation. Your band
forms in ranks `ambush_distance` (2) rows below facing up, the wood
(TREE, three in four hexes, then nine in ten) from two rows behind your
line to the edge, and three trees or mud patches about the track.
`Battle.surprise(side, rounds, morale)` sets `ambushed_side` and strikes
the leader dumb: no shout for `ambush_surprise_rounds` (2, logged once),
his men lose `ambush_morale` (0 now; a point or two and the column runs
before it has fought) never below the break threshold. The round he
wakes, `_face_about` sets his stance (`BattleGrid.state_toward`) to face
the ambushers, so the column is a line where it stands and his men need
only turn; `LeaderAI.choose` counts its forming rounds from then, skips
the "scattered, gather" rule for an ambushed side (a column is strung
out, not milling), and the doctrine is steady or cunning, never one that
charges. `Morale.in_file`: a friend straight ahead or behind is company,
so neither a file nor a second rank takes the alone penalty. The HUD's
result panel toggles "Lay an ambush" / "Take the field"; `is_surprised`
shows "they: surprised" in the status line. Three tests in
`test_ambush.gd`, the third a gate at six wins in ten.

## Fields and terrain (`field.gd`, `battle_grid.gd`, 10 Nov 2026)

`CombatTypes.Terrain` is FLAT, MUD, WATER, SLOPE, TREE, ROCK, FENCE,
BUILDING, FORD, BRIDGE, DOOR.

- *Impassable:* WATER, TREE, ROCK, FENCE, BUILDING (`BattleGrid.blocks`).
  `is_passable(c)` is on the map and not one of these; `is_free(c)` is
  passable and empty. Every movement choice (the wall step, decisions,
  formation slots through `Formation._usable`, shoves, follow-ups,
  deployment) goes through `is_free`, so nobody ever stands there, and so
  nobody is struck or flanked from there: a man with a wall of the hall at
  his right is not flanked from that side because nobody can stand in it.
  The wall step (`Battle._plan_wall`) and the push's follow-up
  (`Push._advance`) treat any impassable hex as they treated water: the man
  holds. In the wall step he no longer holds his neighbours with him: the
  rule that a stepper who would lose a linked neighbour holds
  (`_keeps_a_hand_on`) ignores a man held by the ground (`ground_held`).
  Before terrain this never came up beyond a single test hex of water;
  with a stream or a tree in front of one man it froze the whole wall, the
  hold cascading man to man. Now the line flows past him, and he finds his
  place again once he is round (he may drop out of the chain for a round).
  *The way round (10 Nov 2026).* A whole line at a stream was another
  matter: the men before water held, the men before the crossing stepped
  into it, fell out of the chain there (a man straight ahead of his
  neighbour is not at his shoulder), and Decision's "rejoin the wall"
  stepped them back out of the water the next round, for ever; an attack
  on a ford never reached the far bank. Three rules end it. In the wall
  step a third pass sends every ground-held man along the first step of
  the shortest walk over passable ground to the enemy (`LeaderAI.route`),
  letting go of the men beside him, run to a fixpoint so a file of men
  steps into each other's places; logged once ("make for the way round").
  A man ordered to push who stands in a ford goes on over, in the chain or
  not (`Decision._push`): there is no line to rejoin in the water. And
  `Decision._step_toward`, when no neighbouring hex brings a man nearer
  his mark, takes the first step of `BattleGrid.path_to` round the ground
  in the way, so stragglers rejoining a wall that has crossed come through
  the crossing after it.
- *MUD and FORD* cost breath: a man who ends a step in either spends
  `breath_cost_move * terrain_breath_extra` more (`Battle._wade`), whether
  he walked there alone or stepped with the wall (the wall step paid no mud
  toll before).
- *FORD breaks the lock.* `BattleGrid.line_neighbors` returns nobody for a
  man standing in a ford and never lists one: so he has no lock bonus, no
  brace against a shove, no push line, and counts as alone for morale, and
  his neighbours on the bank lose him from theirs. The check lives there
  rather than in `MeleeExchange.is_locked` because the lock, the push
  groups, the "alone" morale and the drawn shield bars all read
  `line_neighbors`, so one rule covers what is counted and what is drawn.
  `chain` (the wall's membership) is untouched: a wall wades across
  together, unlocked.
- *BRIDGE and DOOR* are plain passable ground (a stream's crossing, a
  hall's doorway).
- *SLOPE* is high ground: `Push.group_strength` adds `slope_push_bonus`
  (3) times the share of the group standing on SLOPE.

*Templates.* `Field.make(grid, rules, seed, their_row, our_row, objective,
forced)` draws a named template from the seed (fork "field-template"):

| template | features | when |
|---|---|---|
| `meadow` | 3-6 trees and rocks off the middle third, a fence line half the time | ships (3 in 4), open |
| `river` | a stream across a middle row, fords and maybe a bridge, trees on the banks | the ford, open |
| `farmstead` | a hall (the objective's, or a steading out on a flank), a yard fence, a tree or two | the hall, open |
| `wood_edge` | trees thick along one flank, thinning inward | ships (1 in 4), open |
| `hillside` | SLOPE under one side's lines and the row before them (the defender's, or either in an open fight) | open |

Open fights draw by `field_weights` (40/5/5/15/35), which with objectives on
seven fields in ten brings the whole mix to about 30/25/25/10/10. Features
never stand on the deployment rows (`Field.deployment_rows`: each side's
front and two ranks; SLOPE is ground and the one exception) or on the
objective's `features`. `Field.open_ways` must hold after a draw: every row
between the lines has two runs of two or more passable hexes, or one of
four, and a breadth-first walk over "wide" hexes (passable with a passable
neighbour in its row) joins the two front rows. A draw that fails is undone
and made again from the next fork ("try:n"), up to `field_tries` (8); after
that the template's features are cleared.

*Objectives on features.* The ford (`Objective._place_ford`,
`stream_crossings`) is a stream of WATER the whole width of the field on
the row before the defender's line, so his line stands on the bank,
crossed by one ford four hexes wide or two fords two wide, and two times in
five a one-hex bridge on a flank: the four or five crossing hexes are the
objective, and the attacker takes it with a foothold of `ford_men` on or
over them when the clock runs out. (A row of dry bank between, which the
first version had, was no kinder to the attacker, 19% against 23-28%,
and cost the defender who held his line: the attacker crossed unopposed
and stood "over" at once.) The hall (`_place_hall`, `hall_shape`) is one or
two hexes of floor four rows behind the defender's front (or on his edge
row), ringed by BUILDING, with one or two DOOR hexes in the ring toward the
fight: four to six walls, and the doors and floor are the objective. On the
smallest field (12 rows) the ring's front reaches the defender's third rank
row; it is drawn before deployment, so the men who would stand there stand
elsewhere. The ships keep their strip; a meadow or wood edge sometimes puts
a tree or fence post at its ends and a broken fence beyond it.

*Band size.* `Scenario.build(name, seed, rules, vary, band := 12,
template := "")`. `band_split(n)` arms the player's band:
`band_shield_share` (2/3) shields, rounded, the rest spears then bows (12:
8/2/2, 8: 5/2/1, 6: 4/1/1, 4: 3/1/0). The varied enemy draws shields from
ours to a quarter more, spears and bows from one fewer than ours to ours;
`objective_attacker_shields` scales by band/12. `field_size(n)` is
`field_min_width` x `field_min_height` (14 x 12) up to `field_small_band`
(6) men, `field_width` x `field_height` (22 x 16) at `field_band` (12),
linear between and beyond, the height kept even. The dict carries `field`
(null when flat), `field_name` ("flat" without `vary`), `band` and `size`.
With `vary` false the field is exactly the old symmetric one.
`tools/batch_player.gd` takes the band as the fifth argument;
`tools/screenshot.gd` takes a template and a band after the seed.

*The way round* (`LeaderAI.route_target`, `route`). When a hex within
`ai_route_lookahead` (3) of the leader's wall step straight ahead is
impassable, the AI leader takes the shortest walk over passable hexes from
himself to a hex beside an enemy and wheels (one stance a round, through
`_wheel_if_needed`, never while engaged) toward the first ford, bridge or
door on it, else toward the walk's hex `ai_route_lookahead` steps on. The
battle's own wall step is unchanged.

*View.* `BattleView._draw_ground` (turf, mud, slope with a hatch, water,
ford with ripples, bridge planks, timber with a roof ridge, a door's
lighter notch) and `_draw_feature` (tree crowns with a trunk dot, rock
lumps, fence rails and posts) draw under the tokens, which are child nodes.
Colours in `Palette`. The HUD's opening line names the field ("River. you:
Hold the ford until round 16").

## Module A — exchanges and fate (`attack.gd`, `fate.gd`)

Owner builds: `sim/combat/attack.gd` (`class_name MeleeExchange`),
`sim/combat/exchange_result.gd` (`class_name ExchangeResult`),
`sim/combat/fate.gd` (`class_name Fate`), `tests/test_attack.gd`,
`tests/test_fate.gd`. Depends on: core only.

```gdscript
# MeleeExchange
static func resolve(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        a: Warrior, b: Warrior, a_attacks: bool, b_attacks: bool,
        a_braced: bool, b_braced: bool, log: PackedStringArray) -> ExchangeResult
static func resolve_shot(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        archer: Warrior, target: Warrior, log: PackedStringArray) -> ExchangeResult
static func score(rules: CombatRules, grid: BattleGrid, me: Warrior,
        foe: Warrior, attacking: bool, braced: bool) -> int   # exposed for tests
# Fate
static func roll(rng: SimRng, rules: CombatRules, w: Warrior) -> CombatTypes.Fate
```

Rules to implement:

- **Score** = Skill + weapon bonus − `condition_penalty` + arc bonus
  against the foe (flank/rear, from `BattleGrid.arc_of(foe, me.pos)`) +
  second-rank support (an active friend with a SPEAR directly behind me)
  + shield defense if my shield is usable and the foe's arc on me is
  covered + locked shields (a usable-shield line neighbor on at least one
  side) + brace bonus if braced.
- One opposed roll per pair. Positive margin: `a` wins and `b` suffers;
  negative: the reverse. Tie: locked, both lose a point of breath.
- A winner who was not attacking (only bracing) deals at most GLANCING.
- **Reach:** a SPEAR may attack at distance 2 through a friendly occupied
  cell; if the defender wins such an exchange, nothing happens to the
  attacker.
- GLANCING: if the loser has a usable shield, shield damage
  (`shield_damage_glancing`, plus `shield_damage_axe_extra` for a bearded
  axe); otherwise a shove: `ExchangeResult.shove_to` is the cell directly
  away from the winner if free, else `Vector2i(-1,-1)`. The battle applies
  the move.
- HIT: `steps_hit` wound steps, HEAVY: `steps_heavy`. Before applying,
  armor rolls once to absorb one step (`absorb_leather`, `absorb_mail`,
  `+absorb_helmet_bonus`). A shield that absorbs nothing is unaffected;
  an absorbed step damages the shield by `shield_damage_glancing`.
- LONG_AXE and BOW users never get shield bonuses (`has_shield` is false
  for them; enforce in score, do not assume).
- Breath: attackers pay `breath_cost_attack` whether they win or lose.
- Effort: winner `add_effort(SKILL)`; a man who takes a wound and stays up
  `add_effort(GRIT)`.
- **Missiles:** archer Skill + bow bonus − one per `missile_range_penalty_per`
  tiles beyond 3, versus target Skill + shield if covered; only HIT/HEAVY
  do anything, never a shove; rain (`conditions.rain`, passed via rules
  for now as `rain_bow_penalty`) applies.
- **Fate:** 2d6 + Grit; below `fate_dead_below` → DEAD, below
  `fate_maimed_below` → MAIMED, else RECOVERED. Sets `w.fate`.

Gate for this module: with default rules, two unhurt equal men (all 4s,
spear and shield, no armor) take on average 4–7 exchanges for one to go
Down; mail roughly doubles that; an attack from the REAR roughly halves it.
Write those as tests with ranges.

## Line geometry (`battle_grid.gd`)

A wall runs on one of four axes (`BattleGrid.Axis`: LEVEL, SLANT_R, PLUMB,
SLANT_L) and faces one side of it: eight stances (`STATES`), each with
the bearing of its front. A leader carries `line_axis` and `line_facing`
(`Warrior.wall_axis()`, `wall_facing()`, `wheel_wall(steps)`); a lone
man's axis follows his facing (`default_axis`). `along(pos, axis, facing,
right)` is the next cell along the line; `forward(pos, axis, facing)` the
straight step (`forward_pair` gives the two straddling steps, `across_key`
the coordinate whose parity picks between them, constant along the line);
`state_toward(bearing)` the stance that best fronts a direction;
`state_of`, `wheel_state`, `state_steps` work on the eight-cycle. The old
`along_line`/`advance_step`/`behind` use the default axis. Formation,
deployment, the wall step, shoves, follow-ups, relief and the view all
go through these. The view straightens a plumb line by column, never
more than half a cell.

## Formations and arms (`formation_template.gd`, `formation.gd`, roles)

A `Warrior.role` is SHIELD, SPEAR or MISSILE. `FormationTemplate` is a
named shape (LINE or WEDGE) with a rank per role: 1 the line through the
leader, 2 straight behind it, 3 two behind, loose. `Formation
.template_slots(grid, leader, band, template)` assigns every man a cell;
`BandFactory.make_mixed_band` and `deploy_formation` build and place mixed
bands; `Decision._form` forms on the leader's `formation` (null is the
line). The wall (`BattleGrid.chain`) is the shields and spears; MISSILE men
are never in it. Second-rank spears strike at reach (`Decision._in_reach`,
`MeleeExchange.can_reach`). Shield-bearers carry `javelins`; a wall closing
with spears to throw halts one round within `javelin_range` and throws
(`Battle._plan_wall`, `Decision._throw`, `MeleeExchange.resolve_shot` with
`thrown`), and a spear caught on a shield costs it `javelin_shield_damage`.
Bowmen shoot under any order but Break them, and step away from an enemy
at arm's length (`Decision._step_away`).

## Enemy doctrine (`leader_ai.gd`)

`LeaderAI.choose(battle, side)` gives one shout a round under a doctrine:
STEADY, AGGRESSIVE, RECKLESS or CUNNING. All but RECKLESS mind the wall
first, every round, before choosing the shout:

- *Wheel toward the threat.* `threat_men` is the nearest
  `ai_threat_fraction` (a third) of the enemy wall (or of their standing
  men when they have no wall of two), measured from our wall;
  `threat_point` is its centre weighted toward the nearest. When that is
  `ai_threat_wheel_min_steps` stances or more off the front the leader
  wheels one stance a round, two when `outflanked` (their nearest man is
  behind the plane of our line). No cooldown; never while any of the wall
  is engaged.
- *Refuse the flank* (`refuse_flanks`). An enemy wall member within
  `ai_refuse_range` of an end of our wall, level with it beyond the end or
  behind the line there, makes up to `ai_refuse_men` men at that end hinge
  back one facing: the end man at once, each man inside only once the man
  outside him has hinged, and only where he stays linked to both
  neighbours, so the chain never breaks. The battle's `_dress_line` turns
  them back once the threat is gone. Logged once a spell.
- *Ranks against ranks.* When both leaders' formations are ranked
  (`ranked`), STEADY and CUNNING hold and taunt instead of pushing after
  `ai_patience_rounds`, and do not answer a taunt; they push when their
  weighted strength (`strength`: shield 1.0, spear 0.9, bow 0.6, standing
  men) is `ai_push_advantage` times the enemy's, when the enemy's mean
  morale (`mean_morale`) is below `ai_push_when_wavering`, or once the
  lines are engaged. AGGRESSIVE pushes regardless.
- *CUNNING* also reads a wall marching across his front: when the enemy's
  nearest man is more than 45 degrees off his front and their leader is
  moving (or under Push!), he wheels toward a point `ai_cunning_lead` hexes
  along their wall facing from the threat, as soon as that is a stance off.

`Scenario.build` with `vary` draws STEADY or AGGRESSIVE as before, then
makes two fights in five CUNNING. `tools/batch_flank.gd` plays the
playtester's tactics (wheel and come at a flank; hold and taunt; push
straight) against each doctrine; `tools/replay_flank.gd` prints one.

## Module B — morale and the push (`morale.gd`, `push.gd`)

Owner builds: `sim/combat/morale.gd` (`class_name Morale`),
`sim/combat/push.gd` (`class_name Push`), `tests/test_morale.gd`,
`tests/test_push.gd`. Depends on: core only.

```gdscript
# Morale
static func on_down(rules: CombatRules, grid: BattleGrid, downed: Warrior,
        all: Array[Warrior], log: PackedStringArray) -> void
static func round_update(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        all: Array[Warrior], leaders: Dictionary, log: PackedStringArray) -> Array[Warrior]
        # leaders: side -> Warrior (or null if down/fled). Returns men who broke this round.
static func rally(rules: CombatRules, grid: BattleGrid, leader: Warrior,
        all: Array[Warrior], log: PackedStringArray) -> void   # "To me!" heard
static func is_flanked(grid: BattleGrid, w: Warrior) -> bool
# Push
static func resolve(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        all: Array[Warrior], log: PackedStringArray) -> PushResult
```

Rules to implement:

- `on_down`: friends adjacent to the downed man take
  `morale_ally_down_adjacent`; friends within `morale_visible_radius`
  take `morale_ally_down_visible`; enemies within that radius gain
  `morale_enemy_down_visible`. If the downed man `is_leader`, his whole
  side takes `morale_leader_down`; if `is_banner`, `morale_banner_lost`.
- `round_update`, per active man: `+morale_leader_adjacent` if his leader
  is adjacent and active; `morale_flanked` if `is_flanked` (an active
  enemy in his RIGHT or REAR arc); clamp to 0–10. Then every man with
  morale ≤ `morale_break_threshold` who is not already broken checks:
  2d6 + Nerve + personality mod ≥ `morale_check_target` or he breaks
  (`broken = true`). Steady and Grim get `+morale_steady_bonus`; Reckless
  never breaks while an enemy is adjacent. Each man who breaks gives
  adjacent friends `morale_panic_spread`, and they check too, once, this
  round (no chains beyond one hop).
- A broken man whose morale climbs back above the threshold while his
  leader is within `rally_radius` becomes unbroken (`rally`). `rally` adds
  `morale_rally_to_me` to friends within earshot of the leader (use
  `hear_certain_radius + hear_horn_radius_bonus` if a horn is on that
  side).
- **Push:** the line is the unit: a group is a run of active, unbroken men
  standing shoulder to shoulder (`BattleGrid.line_neighbors`: beside each
  other, facings within `wall_link_turn`), so a bent line pushes as one,
  and it pushes if any man of it is in contact. Find contact: a man is "in contact" if an active enemy
  is in his FRONT arc and adjacent. Group contacted men by side into
  connected components over line-neighbor adjacency. For each pair of
  opposing components that touch, strength = Σ over members of
  (Might × (1 + `push_morale_weight` × morale / 10)) + `push_second_rank_bonus`
  for each member with an active friend directly behind. One opposed
  roll on the two strengths (treat strength as the stat). Loser's members
  are each shoved one cell directly away from their facing if free;
  blocked men stay and lose `push_blocked_breath`. Winners'
  `add_effort(MIGHT)`. Return a `PushResult` (`sim/combat/push_result.gd`)
  listing shoved warriors and the winning side, or `-1` if no contact.
- **Lull:** if no man on either side attacked this round (`Battle` passes
  `any_attacks: bool` into `round_update`), every active man recovers
  `breath_recover_lull`.

Gate: a line of six all-4s men with their leader adjacent to the middle
holds for 10 rounds of `round_update` with one friend going down per round
far more often than the same line without a leader; write it as a test.

## Module C — shouts and decisions (`shout.gd`, `formation.gd`, `decision.gd`)

Owner builds: `sim/combat/shout.gd` (`class_name Shouts`),
`sim/combat/formation.gd` (`class_name Formation`),
`sim/combat/decision.gd` (`class_name Decision`), `tests/test_shout.gd`,
`tests/test_formation.gd`, `tests/test_decision.gd`. Depends on: core only.

```gdscript
# Shouts
static func propagate(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        leader: Warrior, shout: CombatTypes.Shout, band: Array[Warrior],
        fog: bool, log: PackedStringArray) -> void
static func hear_chance(rules: CombatRules, distance: int, wits: int,
        has_horn: bool, fog: bool) -> float   # exposed for tests
# Formation
static func line_slots(grid: BattleGrid, leader: Warrior, count: int) -> Array[Vector2i]
static func wedge_slots(grid: BattleGrid, leader: Warrior, count: int) -> Array[Vector2i]
static func assign(slots: Array[Vector2i], men: Array[Warrior]) -> Dictionary  # Warrior -> Vector2i, nearest pair first
# Decision
static func choose(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        w: Warrior, leader: Warrior, all: Array[Warrior],
        log: PackedStringArray = PackedStringArray()) -> Action
```

Rules to implement:

- **Hearing.** Distance = Chebyshev to the leader. Within
  `hear_certain_radius` (+`hear_horn_radius_bonus` if any active man on the
  side `is_horn`, +`hear_banner_radius_bonus` if an active `is_banner`):
  certain. Beyond: chance drops `hear_falloff_per_tile` per tile, plus
  `hear_wits_bonus` × Wits, minus `hear_fog_penalty` in fog, clamped 0–1.
  A `NONE` shout propagates nothing. On success: `heard_order = shout`,
  and a GREEN man gets `order_lag = 1` with `green_lag_chance`. On failure:
  with the tier's mishear chance (`mishear_green` etc., CHAMPION never)
  he sets `heard_order` to a random *other* shout; otherwise he keeps his
  previous order. Log each mishearing.
- **Formations.** `line_slots`: cells on the line through the leader
  perpendicular to his facing, alternating right and left of him, skipping
  cells that are not free (or occupied by a friend, which counts as
  filled). `wedge_slots`: the leader at the tip, then the two cells
  behind-left and behind-right, then the next rank out, and so on.
  `assign` is a greedy nearest-first match: of all (man, slot) pairs the
  closest is matched first, then the closest remaining, so a man already on
  a slot keeps it and a man walking to his slot is not re-routed (ties: man
  nearer the leader's side of the line, then id, then slot order). Slots
  never include the leader's own cell.
- **Decisions.** In priority order (the first cut; now a weighed choice,
  see "Decision model" below):
  1. `broken` → FLEE one cell directly away from the nearest active enemy
     (prefer a free cell; if none, IDLE).
  2. `order_lag > 0` → decrement, then act on the *previous* behavior:
     BRACE in place.
  3. GREEN with morale ≤ `morale_break_threshold`: with
     `green_panic_ignore_chance` ignore the order and BRACE (log it).
  4. RECKLESS with an active enemy within `reckless_charge_radius`:
     behave as BREAK_THEM regardless of order.
  5. CHAMPION whose leader has two or more adjacent enemies and who is
     within 2 of the leader: ATTACK one of those enemies (move adjacent
     first if needed).
  6. VETERAN or better with no order-driven move and a gap beside him
     (a line neighbor cell empty because its man went Down this battle
     and an enemy is adjacent to that gap): MOVE into the gap.
  7. By `heard_order`:
     - NONE: GREEN braces; others behave as HOLD.
     - SHIELD_WALL: if not on his assigned line slot, MOVE one step toward
       it (facing the leader's facing); if on it, behave as HOLD.
     - HOLD: ATTACK an active enemy adjacent in FRONT arc (nearest; prefer
       a wounded one), else BRACE facing the nearest enemy.
     - PUSH: if an enemy is adjacent in FRONT, ATTACK; else MOVE one cell
       in the leader's facing direction if free, else BRACE.
     - TO_ME: if Chebyshev to leader > 1, MOVE one step toward the leader;
       else behave as HOLD.
     - BREAK_THEM: ATTACK any adjacent active enemy (nearest first), else
       MOVE one step toward the nearest enemy, facing him.
     - FALL_BACK: GREEN or BLOODED with morale ≤ `fall_back_steady_morale`
       behaves as if broken for this round only (log "the line wavers");
       otherwise MOVE one cell directly behind (keep facing), else BRACE.
     - SVINFYLKING: like SHIELD_WALL but with `wedge_slots`; once in place,
       behave as PUSH.
  8. BOASTFUL prefers the enemy leader or a CHAMPION when choosing an
     adjacent target. Bow users with no adjacent enemy SHOOT the nearest
     enemy within `missile_range` instead of moving (unless ordered
     BREAK_THEM).
- Decisions must be pure given `rng` state: same seed, same world, same
  action. They read the grid and warriors and never mutate anything except
  `order_lag` and log.

Gate: a GREEN band of eight hears SHIELD_WALL from a leader five cells
away in fog and forms a complete line within far more rounds than a
VETERAN band does; write the comparison as a test over many seeds (drive
the men by repeatedly calling `propagate`, `choose`, and applying MOVE
actions to the grid yourself in the test).

## Decision model (`decision.gd`, 10 Nov 2026)

The priority list above was the first cut. `Decision.choose` is now a
weighed choice, so a veteran and a green man in the same spot do
different, sensible things, and so do a reckless and a steady one. The
signature is unchanged apart from an optional last argument,
`objective: Objective = null`.

**Rules first (not judgement).** In order: an inactive man idles; a broken
man runs; a man with `wall_move` set goes with his wall (standing, he still
weighs whom to strike or whether to throw); a green man with `order_lag`
braces; a frightened green man may freeze (`green_panic_ignore_chance`).
The player's own action override stays in `Battle`.

**Options.** ORDER is what his order says, the old per-order behaviour
(`_by_order`: form, hold, push, to me, break them, fall back, wedge; bows
shoot; a bracing man throws). The alternatives, in tie order: throw early,
brace for a charge, fill a gap, face a flanker, drop back, cover the
leader, give ground (bows), charge, loot, step out, go for a wounded man,
make for the objective, lose heart (run). Each is built only if he can
see it and it is possible, scored, and the best wins; ties go to the
earlier option, so the order wins every tie.

**Scores** (all `CombatRules.dm_*`, spaced a point or more apart):
ORDER 10, plus 3 when it means a step, a blow or a run; throw early and
brace for a charge 14; fill a gap 12; face a flanker 11.5; drop back 14
grievous, 6 wounded, +3 without a shield, -8 reckless, -4 grim; cover the
leader 15; give ground 14; charge 16 for a reckless man (16 for a
superstitious one when the enemy's banner is down), -6 steady or grim;
loot 14; step out 11.5; go for a wounded man 8 + 1.5 per wound step;
objective 13.5; lose heart 9, +3 when shaken. The heard order bears on
each (`dm_order_bearing`): Hold, Shield wall and To me weigh a point
against leaving his place, Push and Break them a point for going forward,
Fall back a point for dropping back. A man with friends at his shoulders
is held in the wall: charging or stepping out from it costs
`dm_leave_wall` (6), so a reckless man in a wall leans to the blow
instead, and alone he goes.

**Choosing a mark** is weighed too: the man in front (14) over the man
beside (7) over the man at a spear's reach (0), then one point per wound
step. Blooded and better add a point for a spoiled shield and, at reach,
a point per friend the enemy is pressing (two at most), so a spearman
strikes the man on his neighbour; a boastful man adds 11 for the enemy
leader or a champion.

**What a tier sees.**

| Tier | Sees |
|---|---|
| Green | The man in front and the order; his own grievous wound. His weights are blurred by a jitter of ±0.3 (`dm_green_blur`) from `rng.fork("blur")`, so near-ties go either way. A green man who missed the shout does as the men at his shoulders do when two or more of them, and all of them, act on one order that is not his. |
| Blooded | Also his neighbours: the gap where one has just fallen (a friend down on the cell), the enemy pressing his friends, a spoiled enemy shield, a flanker two hexes off the open end of his line; his own lesser wound and lost shield. |
| Veteran | Also the flank (a flanker three off), any gap in his line, a hurt enemy two cells off when he stands alone, and a leader beset (`guard_min_tier`). |
| Champion | Also intentions: an enemy two off under Break them or Push will land next round, so he braces toward him; the lines will meet next round, so he throws now. |

**Personalities.** Reckless: charges anything within
`reckless_charge_radius` whatever the order, leans to the blow, will not
drop back. Steady and grim: lean to holding and covering, never charge;
grim fights on hurt. Boastful: strikes the enemy leader or a champion over
a hurt man, steps out where the enemy leader will see him. Greedy: leaves
the line to strip a fallen enemy leader or banner man within three hexes,
once (`Warrior.looted`). Superstitious: goes at them when the enemy's
banner falls; when his own does, his order is worth two points less and
running more, so a shaken superstitious man runs a step.
`BandFactory.make_band` now rolls personalities from its own fork of the
seed (`roll_personality`; stats are unchanged): 30% none, 60% one, 10%
two (leaders 20% none), weighted steady 3, reckless 3, grim 2, boastful 2,
greedy 1, superstitious 1, never reckless with steady or boastful with
grim.

**Reasons and tells.** When the chosen option is not the plain default
for his order, `Warrior.last_reason` holds a short line in his voice by
tier ("Olvir is hurt and falls back behind Thorolf", "Grim sees the gap
and steps into it", "Bard will not wait: he goes at them", "Hallvard's
spear goes for the man on Skalla") and it is appended to the `log` passed
in; `last_option` names what he chose. Lines never contain " beats ",
" shoots ", " spears " or "DOWN", so the blow scan and the view's parsing
ignore them. The HUD keeps up to three a round in their own colour (read
from the men, so they show whether or not `Battle` passes its log); the
muster preview carries each man's reason and draws a gold dot over a man
who is thinking for himself; a grievously wounded man is drawn three
pixels lower over his shadow and a reckless man half a pixel forward of
his line.

**Not yet wired.** `Battle.run_round` calls `choose` without its log or
objective, so reasons reach the HUD from the men, not the battle log, and
loose attackers do not yet make for the objective. Passing `log` and
`objective` in the two calls turns both on.

**Measured** (`tools/batch_decisions.gd`, 100 varied fields with mixed
tiers, Shield wall then Push): 11 reasons a fight; reasons are 2-3% of
green, blooded and veteran decisions and 8% of champions' (brace for a
charge 3.6%, throw early 1.9%). The symmetric batches did not move beyond
noise (green vs veteran 0/100, equal green 49/51, equal veteran 53/47,
mail 77/23), nor the varied field (push 51.5%, hold 35%, steady AI 48%).
Before the wall held reckless men, personalities alone took equal green
to 65/35 and push to 64%: reckless men broke from the holding side's wall
piecemeal at three hexes while the pushing side's were carried by their
wall's move.

## Module D — battle loop, leader AI, batch runner (after A–C merge)

`sim/combat/battle.gd` (`class_name Battle`), `sim/combat/leader_ai.gd`
(`class_name LeaderAI`), `sim/combat/battle_result.gd`,
`tools/batch_battles.gd`, `tools/replay.gd` (prints the log and a grid
snapshot per round). Written by the integrator once A–C are in.

Gate for milestone 1 (from concept.md): across 1000 seeded battles, a
GREEN band of eight versus a VETERAN band of eight under the same shouts
differs clearly in win rate, rounds to decision and men lost; and the
default rules give skirmishes of roughly 8–15 rounds, not 3.

## Integration notes (as built, 7 Nov 2026)

Module D is in: `battle.gd`, `leader_ai.gd`, `band_factory.gd`,
`battle_result.gd`, `tools/batch_battles.gd`, `tools/replay.gd`,
`tests/test_battle.gd`. Interfaces that drifted from the spec above, and
rules added while integrating:

- `Decision.choose(..., all, log := PackedStringArray())` takes a trailing
  log. `Formation.assign` matches the closest man-slot pair first (the
  literal "men ordered by distance to the leader" oscillated).
- Morale starts at Nerve + `morale_start_bonus` (3), clamped to 10. With
  morale equal to raw Nerve, a green man stood at the break threshold
  before anything happened.
- The push resolves only in a round where a leader shouted PUSH or
  SVINFYLKING, and only moves a line when the winner's margin reaches
  `push_min_margin`. Winners step into vacated ground (`PushResult.advanced`).
  Without these, lines dissolved into a shove-fest and almost no blows landed.
- PUSH drives toward the nearest enemy, keeping the line's facing while he is
  ahead, and fights any adjacent enemy before walking past him. "In front"
  for HOLD and PUSH means FRONT or FRONT_RIGHT; the push's contact test uses
  the same arcs.
- A veteran covers a gap only when a friend stands on the far side of it
  (the open end of a line is not a gap) and only when he has nobody to
  attack. The literal rule made every veteran shuffle sideways forever.
- A man falling back who is more than `fall_back_regroup_distance` from his
  leader steps toward him instead; this stops misheard fall-back orders
  walking men off the map.
- Facing chosen with a brace applies; attackers turn toward their target.
- End conditions: no unbroken active men on a side; or a side whose leader
  called FALL_BACK and whose men are all at least `withdraw_distance` from
  every enemy has left the field; or `max_rounds` is a draw.
- Determinism: warrior ids are assigned per battle (`BandFactory.make_band`
  `first_id`), because rng streams are forked by id.
- Each round logs `actions: brace N move N attack N ...`, which is the first
  thing to read when a battle looks wrong.

### Milestone 1 gate, measured

1000 seeded battles, eight green (aggressive leader) against eight veteran
(steady leader), default rules: veterans win 95.5%, draw 4.0%; mean 19.7
rounds of which about six are approach and forming; green lose 5.4 down and
1.2 fled per battle against 0.9 and 0.1. Equal veteran bands decide about
70% of fights inside 30 rounds; the rest are running fights that have not
finished. Encoded in `tests/test_battle.gd`.

Known tuning questions for the playable prototype, not for the sim:

- The aggressive attacker beats a steady defender of equal quality about
  two to one (`equal_green`: 68% to 20%). Holding should be worth more.
- Equal veteran fights run long (mean 26 rounds). Lethality, max rounds or
  deployment distance are the levers; none was changed to hit a number.

### Formation pass (8 Nov 2026, from the phone playtest)

The player could not tell whether being in the wall mattered, and the
leader died fast with every enemy on him. Changes, all in `CombatRules`:

- `locked_shields_bonus` 1 → 2, full only with a shield-bearer on both
  sides, half with one.
- `locked_braces_against_shove`: a man with a locked neighbour cannot be
  shoved by a glancing blow; his neighbours brace him.
- `morale_alone` −1: a man with no friend beside him loses heart each round.
- `guard_min_tier` VETERAN: veterans as well as champions step in when the
  leader has `guard_threats` (2) or more enemies on him.
- "Push!" advances the line as a line (every man steps toward the enemy's
  centre), and the line forms on where the leader is *going* when the
  player steps, so the wall moves with him.
- `push_min_margin` 3 → 4.

Measured after: veterans win 100% of 200 green-versus-veteran fights in
17.9 rounds; equal green bands 61.5% to 35.0% with 3.5% draws.

### Hex grid (8 Nov 2026)

`BattleGrid` is now a pointy-top hex grid in axial coordinates (q, r) with
six facings, clockwise from north-west; opposite directions are three
apart. Bounds are a rectangle in odd-r offset coordinates
(`from_offset`/`to_offset`). Distance is hex distance (`chebyshev` kept as
an alias). Arcs relative to facing: 0 FRONT (covered), 1 FRONT_RIGHT
(open, no flank bonus), 2 RIGHT (flank), 3–4 REAR, 5 LEFT (covered).
`line_dirs(facing)` = [rotate(f,2), rotate(f,5)] are a man's right and
left line neighbours, so a line facing (0,−1) runs along (±1,0). Wedge
ranks: back-left rotate(f,4), back-right rotate(f,3). `direction_to` and
`snap_direction` pick the nearest hex direction from a cartesian vector.
`BandFactory.deploy_line(grid, band, anchor, facing)` deploys along the
line axis; `deploy_column` wraps it at the map's middle row. Rolls,
wounds, morale, shouts, the campaign and the world are untouched.

### Walls advance square, the push moves lines (8 Nov 2026)

No hex direction is perpendicular to a hex row, so a wall stepping the way
it faces slides sideways half a hex a round (the "waltz"). `BattleGrid.
advance_step` alternates the two directions straddling the facing, keyed
on the coordinate constant along the row, so every man steps the same way
and keeps his column over two steps. "Push!" uses it. The push beat now
moves a losing line together when at least `push_line_fraction` of it has
room, else the whole line holds, tires and loses `push_pressed_morale`;
winners follow only when the line moved. Two locked walls grind longer,
so `max_rounds` is 40. Measured: veterans win 97% of 200 green fights
(21 rounds); equal green 59/37 with 4% draws; equal veteran 47/35 with
18.5% draws.

### Scripted playtest (8 Nov 2026, `tools/playtest.gd`)

Drives the prototype like a player (shield wall, push, hold, wheel, fall
back) with a screenshot and the log every round. Found and fixed:

- Men who attacked turned to face their target during the blows beat, so
  the push beat that followed saw every attacker as a lone man and shoved
  walls apart one man at a time. A man now turns only if his target is
  not already ahead of him.
- The player's own man could break and run off the field. Leaders never
  break (`leaders_never_break`); a leader's nerve is a choice, the
  player's or the AI's fall back.
- The AI wheeled its wall every round as scattered enemies moved its
  target; `ai_wheel_cooldown` (3 rounds).
- Winners of a push stepped into vacated ground one by one and broke their
  own wall; the winning line now follows square to its facing all together
  or not at all, and only a leader's wall follows up (`may_advance`).
- Men outside a wall that fell back kept walking away; they now rejoin.
- The batch and campaign deployments put eight-man lines on the diagonal
  axis of a 16x12 map, where the end men were off the edge and the wall
  could never step; both now deploy across the map like the prototype.
  That alone took equal-fight draws from 48% to 4.5%.
- A side still falling back after `retreat_stall_rounds` without a blow has
  quit the field (a pursuit at equal speed never catches anyone).
- Broken men no longer hear or mishear shouts; "in contact" is logged once
  per spell; wall log lines say whose wall.

Measured after: equal green 46/49.5 with 4.5% draws (24 rounds); veterans
win 95.5% of green fights; equal veteran 45.5/38 with 16.5% draws.

### Second scripted playtest (8 Nov 2026)

- A won push's follow-up stepped each man by his own facing; a man who had
  turned to strike stepped sideways and the wall broke. The follow-up now
  uses the side's wall facing (`Push.resolve` takes `wall_facing`).
- The wall's single test never failed: it is now the mean hearing chance
  scaled by the wall's average tier (`wall_test_tier_factor`, green 0.75),
  so green walls hesitate about one step in four.
- A man standing behind a wall that falls back is carried back with it
  when he has room; falling back into an enemy is still blocked.
- The prototype camera sat too high once the lines reached the upper rows.

Measured: equal green 45/52.5 with 2.5% draws; veterans win 99.5% of green
fights in 17 rounds.

## The whole game (12 Nov 2026)

The modules added when the prototype became one game. Each has notes in
`docs/design/notes/<name>.md` with its rules, numbers and measurements;
this is the map of what is where.

| Area | Files | Notes |
|---|---|---|
| Houses and standing | `sim/world/family.gd` (`House`), `families.gd` | `families.md` |
| The summer's own life | `sim/world/world_life.gd`, `hiring.gd`, `trade_road.gd`, `roam.gd` | `world-life.md` |
| The stepped winter | `sim/world/winter_hall.gd` over `sim/campaign/winter*.gd` | `winter.md` |
| Years, household, succession, the saga | `sim/world/years.gd`, `sim/campaign/{family,succession,chronicle}.gd` | `generations.md` |
| The saga's fights | `sim/combat/{scenario,objective,field}.gd` (escape, hall defence, burning, break-out, deck), `Campaign.stake` | `saga-fights.md`, `tutorial.md`, `first-fight.md` |
| Law, land, the unfree, omens | `sim/world/{thing_play,outlawry,landtake,thralls,omens}.gd` | `law-land.md` |
| Saving | `sim/save/{save_codec,save_play,save_store}.gd` | `save.md` |
| The whole weighed | `Campaign.room`, `Journey.vengeance_outlook`, `tools/saga_trace.gd`, `tests/test_balance.gd` | `balance.md` |
| The wider world | `sim/world/east_road.gd` (rivers, portages, the guard), `norway_data.gd`, `market.gd` | `wider-world.md` |
| The leader's nature, arms and works | `sim/campaign/natures.gd`, the men-and-silver section of `journey.gd`, `Man.woman` and `Warrior.said` | `men-silver.md` |
| Wings, strandhogg, the great battle | `sim/combat/{wing,sector}.gd`, `Scenario.build_strandhogg`, `build_sector`, `Objective.Kind.CATTLE` | `battles-2.md` |
| The view | `view/{ui_theme,ui_modal,map_canvas,map_art,map_icons,winter_screen,saga_screen,men_panel,settings,saves_modal,audio,audio_synth,tutorial,hints,battle_hints}.gd` | `ui.md`, `map-art.md`, `shell.md` |

Rules that hold across all of it:

- **`Journey` is the player's seam.** Everything the player can do is an
  entry in `Journey.actions()`, a decision in its queue answered through
  `answer()`, a fight handed over in `Journey.fight` and concluded in
  `fight_done()`, or a step of the winter (`winter_state`,
  `winter_choose`). `JourneyBot` plays through the same seam and is the
  instrument for every batch.
- **Special fights are flag-guarded.** The escape, the hall fights and
  the deck change rules only inside their own scenarios;
  `tools/diag_mixed.gd` and `tools/diag_identity.gd` fingerprint ordinary
  battles and must stay byte-identical when a special fight is touched.
- **The save is generic.** `SaveCodec` walks every script variable (and
  object metadata) reachable from the Journey; nothing is listed per
  class. State that must not be saved is named in one registry in
  `save_codec.gd`, and a test fails on any `static var` under `sim/`
  that is not in it. `tools/save_check.gd` saves at many points, loads,
  and plays original and copy on side by side; any difference is a bug.
- **The view reads plain values.** Screens are built from dictionaries
  the sim hands out (`Families.report`, `Journey.household`,
  `price_book`, `winter_state`, `saga`), with `UiTheme` and `UiModal`.
- **Lists drag under a thumb.** A button keeps a touch to itself, so a
  list made of rows could not be scrolled on a phone. `UiTheme.touch_scroll`
  (called for every node from the audio autoload's `node_added` hook)
  makes buttons and panels inside a `ScrollContainer` pass the touch on;
  the engine drops the row's press when the scroll begins. New lists get
  this for free; a control that must keep the touch inside a scroll sets
  its own filter after entering the tree.
