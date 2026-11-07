# Ring-Giver

A historical saga sandbox set in Viking-age Norway. See
[`docs/design/concept.md`](docs/design/concept.md) for the design.

## Layout

- `docs/design/` — concept doc, review notes, architecture contracts and concept art
- `game/` — the Godot 4.5 project
  - `sim/` — the rules layer: plain `RefCounted` classes, no scene tree, fully
    headless. Everything here must be deterministic from a `SimRng` seed.
  - `tests/` — headless tests (`test_*.gd` extending `TestCase`)
  - `tools/` — batch simulation and balance tools
- `scripts/` — setup and test helpers

## Running

```bash
scripts/setup-godot.sh     # installs Godot 4.5 and builds the class cache
scripts/test.sh            # runs the test suite
cd game && godot --headless --path . -s tools/margin_table.gd -- 3   # margin table for a +3 edge
cd game && godot --headless --path . -s tools/batch_battles.gd -- all 200 1   # 200 battles per scenario
cd game && godot --headless --path . -s tools/replay.gd -- green_vs_veteran 7  # one battle, round by round
cd game && timeout 600 godot --headless --path . -s tools/batch_years.gd -- 20 10 1   # 20 campaigns x 10 years
cd game && timeout 900 godot --headless --path . -s tools/batch_sandbox.gd -- 6 8 1  # 6 sandbox campaigns on the map
```

Wrap tools in `timeout`: if a tool script fails to compile, Godot idles
instead of exiting.

Design docs: `docs/design/concept.md` (the game),
`docs/design/sim-architecture.md` (the combat sim),
`docs/design/campaign-architecture.md` (the campaign layer) and
`docs/design/world-architecture.md` (the map, economy, factions and law),
each with the contract and what was actually built.

`class_name` lookups need Godot's class cache (`game/.godot/`), which is
gitignored. `setup-godot.sh` and `test.sh` build it with an import pass.

## Rules for `sim/`

- No `randi()`/`randf()`; every roll goes through a `SimRng`.
- No `Node`, no scene tree, no autoloads. The sim must run under
  `godot --headless -s`.
- Every rule from the concept doc gets a test before it gets a sprite.
