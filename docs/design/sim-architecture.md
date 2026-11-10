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

- Ford: at the end of round `objective_ford_rounds` (16) the side with more
  standing men on the cells has it; ties go to the defender.
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
the defender's end, before anyone deploys: the ford is a stream two rows
before his line (see "Fields and terrain"), the ships a strip three rows
behind his front, the hall a building four rows behind it. The attacking
side brings `objective_attacker_shields` (2 at twelve men, scaled to the
band) more shields than the defender's draw would give. `vary=false` never
has an objective.
`tools/batch_player.gd` reports per strategy how fights ended (objective,
lines broke, drawn), the mix of fields and the win rate attacking,
defending and in the open.

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
the second row before the defender's line (a row of dry bank between),
crossed by one ford four hexes wide or two fords two wide, and two times in
five a one-hex bridge on a flank: the four or five crossing hexes are the
objective, so the fight for the ford is a fight for the crossing. (On the
row just before his line, as the old ford patch was, the attacker could
only come at the line through the crossing, unlocked and a man at a time,
and took it in one fight in fifteen; one row out, the crossing is ground
either side must come to.) The hall (`_place_hall`, `hall_shape`) is one or
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
- **Decisions.** In priority order:
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
