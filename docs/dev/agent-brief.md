# Working in this repo (brief for sub-agents)

Ring-Giver is a Viking-age saga sandbox (Godot 4.5, GDScript), a web
prototype deployed from `main` to GitHub Pages. You are one of several
agents working in parallel on separate branches. An orchestrator merges
your branch. Read this whole file before you start.

## Where things are

- `game/` is the Godot project. `game/sim/` is the simulation (pure
  `RefCounted`, deterministic, no nodes): `sim/combat/` (battles on a hex
  grid), `sim/campaign/` (the band, its men, winters, ways of life),
  `sim/world/` (places, factions, markets, the Thing, feuds, the
  free-roam map and the player's summer). `game/view/` is everything on
  screen. `game/tests/` is the headless suite. `game/tools/` are batch
  and screenshot tools.
- `docs/design/concept.md` is the game design with dated playtest notes;
  `docs/design/sim-architecture.md` describes the sim as built. Read the
  sections named in your task; skim the last 300 lines of `concept.md`
  for the current state ("Ways of life", "One start, any path, no boat,
  a map to roam").
- The entry points you will most likely need:
  - `sim/world/journey.gd` (`Journey`): the player's summer, one decision
    at a time. `begin`, `advance`, `go_to_place`, `actions`, `act`,
    `decisions`, `answer`, `fight`, `fight_done`, `status`.
  - `sim/world/roam.gd`, `map_grid.gd`: the free-roam map and its parties.
  - `sim/campaign/campaign.gd` (`Campaign`): `offer_fight`, `build_fight`,
    `conclude_fight`, `winter`. `sim/campaign/way.gd`, `origins.gd`.
  - `sim/combat/battle.gd`, `scenario.gd`, `objective.gd`, `decision.gd`.
  - `view/game.gd` (root: title, origins, map, battle hand-off),
    `view/map_screen.gd` (side panel and modals), `view/map_canvas.gd`
    (the drawn map), `view/main.gd` + `view/hud.gd` + `view/battle_view.gd`
    (the battle screen).
  - `sim/world/journey_bot.gd`: a stand-in player used by tests and
    `tools/batch_ways.gd`.

## Set up your own worktree (do this first)

Do not work in `/home/user/ringgiver` itself: other agents share it.

```
git -C /home/user/ringgiver worktree add /home/user/wt-<your-task> -b <your-branch> main
cd /home/user/wt-<your-task>/game && timeout 300 godot --headless --path . --import
```

Work, test and commit only inside `/home/user/wt-<your-task>`. Do not
push, do not merge, do not touch `main`.

## Commands

All from `<worktree>/game` unless noted. ALWAYS wrap godot in `timeout`:
a script error leaves the engine hanging instead of exiting.

- The suite (about 4 minutes): `cd <worktree> && timeout 900 scripts/test.sh 2>&1 | grep -v "^  ok" | tail -30`.
  It must end `N tests, 0 failed` with no `SCRIPT ERROR`.
- One quick compile check after adding a `class_name`: `timeout 300 godot --headless --path . --import 2>&1 | grep -i error`.
- Balance of the ways of life: `timeout 1200 godot --headless --path . -s tools/batch_ways.gd -- 6 4 1 all younger_son`
  (sagas, years, seed, bent, origin). No `STALL`s, and men survive.
- Screens (needs a display): `timeout 300 xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_game.gd -- /tmp/x.png younger_son 7 answer:ignore`
  (read the header of `tools/screenshot_game.gd` for its commands), and
  the battle alone: `... -s tools/screenshot.gd -- 6 /tmp/b.png 1 equal_green 7`.
  Look at the PNGs you make (the Read tool shows images). 844x390 is a
  phone in landscape, which is the target; the design size is about
  1169x540 (stretch mode canvas_items, aspect expand).
- When piping godot output through grep, use `grep --line-buffered`.

## Rules that are not negotiable

1. The suite stays green. Add tests for what you build (`game/tests/test_*.gd`,
   `extends TestCase`, functions named `test_*`, `assert_true`, `assert_eq`,
   `assert_between`). If you change a rule an existing test pins, update
   the test and say so in your report.
2. Every screen you touch renders with zero `SCRIPT ERROR` lines in the
   screenshot tool's output. A script error in the view breaks the live
   build for every player.
3. The sim is deterministic: all randomness comes from `SimRng` forks
   (`rng.fork("label")`), never `randi()`/`randf()` globals. Tunables live
   in the rules classes (`CombatRules`, `CampaignRules`, `WorldRules`)
   with a comment saying what they mean, not as literals in the logic.
4. The sim never imports the view. The view reads the sim.
5. Stay inside the files your task says you own. If you must touch a
   file another agent owns, make the smallest possible change and list
   it in your report.

## GDScript pitfalls that have bitten this repo

- `var x := <expression>` fails to compile when the expression is a
  Variant (dictionary values, `a if c else b` with mixed types, `.get()`).
  Write the type: `var x: int = d.get("k", 0)`.
- Typed arrays: build them explicitly (`var out: Array[Vector2i] = []`).
- `PackedStringArray` is passed by reference; the sim's functions append
  to a `log` argument.
- New `class_name` scripts need `godot --headless --path . --import` once
  before anything can see them.
- The web font has no fancy glyphs: plain Latin text only (no ●, →, ✓).
- Code comments are plain prose that says why, in the voice of the rest
  of the file. No emoji. Names in the sagas' register ("the band", "the
  hall"), not game jargon, in anything the player reads.

## Writing for the player

Text the player reads is plain, short and in the saga voice already in
the game ("Egil comes to Fitjar on day 26."). No modern idiom, no
exclamation marks except the shouts.

## Delivering

- Commit on your branch in your worktree, in logical commits, each
  message ending with exactly:

```
Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P5EsvQHo48suzdDpxkAELG
```

- Do NOT edit `docs/design/concept.md` or `docs/design/sim-architecture.md`
  (every agent would collide there). Write your design notes and what
  you built to `docs/design/notes/<your-task>.md` instead: what the
  player sees, the rules and their numbers, the classes and functions,
  what you measured, what is still open.
- Your final message is a report for the orchestrator, not the user:
  the branch name and worktree path, what you built, the files you
  changed outside your ownership, the suite's last line, any numbers you
  measured, and what you left undone or are unsure of. Be exact; do not
  claim a check you did not run.
