# Ring-Giver

A historical saga sandbox set in Viking-age Norway. See
[`docs/design/concept.md`](docs/design/concept.md) for the design.

## Layout

- `docs/design/` — concept doc and review notes
- `game/` — the Godot 4.5 project
  - `sim/` — the rules layer: plain `RefCounted` classes, no scene tree, fully
    headless. Everything here must be deterministic from a `SimRng` seed.
  - `tests/` — headless tests (`test_*.gd` extending `TestCase`)
  - `tools/` — batch simulation and balance tools
- `scripts/` — setup and test helpers

## Running

```bash
ring-giver/scripts/setup-godot.sh     # installs Godot 4.5 and builds the class cache
ring-giver/scripts/test.sh            # runs the test suite
cd ring-giver/game && godot --headless --path . -s tools/margin_table.gd -- 3   # margin table for a +3 edge
```

`class_name` lookups need Godot's class cache (`game/.godot/`), which is
gitignored. `setup-godot.sh` and `test.sh` build it with an import pass.

## Rules for `sim/`

- No `randi()`/`randf()`; every roll goes through a `SimRng`.
- No `Node`, no scene tree, no autoloads. The sim must run under
  `godot --headless -s`.
- Every rule from the concept doc gets a test before it gets a sprite.
