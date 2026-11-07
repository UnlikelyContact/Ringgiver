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
- Grid: Chebyshev distance, eight facings (`BattleGrid.DIRS`, clockwise
  from north). Arcs relative to facing: FRONT (ahead and front-left),
  FRONT_RIGHT, LEFT, RIGHT (exposed flank), REAR. Shield covers FRONT and
  LEFT.

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
- **Push:** find contact groups: a man is "in contact" if an active enemy
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
static func assign(slots: Array[Vector2i], men: Array[Warrior]) -> Dictionary  # Warrior -> Vector2i, nearest-first
# Decision
static func choose(rng: SimRng, rules: CombatRules, grid: BattleGrid,
        w: Warrior, leader: Warrior, all: Array[Warrior]) -> Action
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
  `assign` is a greedy nearest-first match (each man to the closest
  unassigned slot, men ordered by distance to the leader).
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
