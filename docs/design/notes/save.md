# The save: a saga survives closing the tab (12 Nov 2026)

Until now nothing was saved: a phone player who closed or reloaded the tab
lost the saga, and a saga now spans generations. This package saves the
whole of the player's saga and restores it exactly, without a hand-written
`to_dict` per class, so that the fields other packages add tomorrow are
saved with no change here, and a test proves it by behaviour.

## What the player sees

- **The title.** When an autosave holds a saga that has not ended, the
  first button is "Continue the saga", with the save's line under it
  ("Egil the Viking, summer of 871, at Fitjar, 9 men"); "Begin a saga"
  and "Another beginning" become secondary and ask first ("Begin a new
  saga?": your saga is kept in the autosave; a new saga is saved over it,
  the one before is kept a little while; to keep it, put it in a slot
  under Sagas), with Begin anew, Sagas, Back. If the autosave cannot be
  read, a red line says so and Continue takes up the autosave before it,
  if that one reads. "Read the last saga" stays; "Sagas" is new.
- **Sagas** (the title, and Settings > The saga > "Sagas: keep, load,
  copy" on the map): the autosave, the save before it (when there is
  one) and three slots, each with its line and when it was saved ("Saved
  12 Nov, 14:05", local time). Load; Save here (the slots, with a saga in
  hand and no battle up); Copy; Delete (asked: "It cannot be got back.").
  "Paste a save" takes the text copied on another device, checks it and
  keeps it in a slot. A browser that will not keep IndexedDB (a private
  window: `OS.is_userfs_persistent()` false) gets a red line saying so.
- **Loading** puts the saga back where it stood: the map's camera, zoom,
  follow, the place picked and the pause; the hints already read (they
  were in memory only; now they ride in the save); a decision waiting, a
  winter at its step, the grave-ale at its card, an ended saga at its
  ending. The settings stay in `user://ringgiver.cfg` as before.
- **A fight.** The autosave is written as the battle screen opens and
  never while it is up. A saga saved in a fight therefore resumes at the
  fight's start (the same battle, the same seed, round 0): nothing else is
  lost. The codec itself can save a battle in progress (the continuation
  test saves four rounds into one and plays it out), but the battle
  screen's own state (the HUD, the tutorial, the camera) is not restored,
  so the game does not offer it.

## The files (sim/save/save_store.gd, `SaveStore`)

`user://saves/<slot>.save`, slots `auto`, `auto_prev` (the autosave before
the last: each autosave moves the old one there), `slot1`..`slot3`. A file:

```
RINGGIVER-SAVE\n
{"format":1,"game_build":"...","saved_at":<unix>,"summary":{leader,year,day,place,men,silver,generation,winter,over},"bytes":<n>,"sha":"<sha256 of the body>"}\n
<gzip of JSON {"data": SaveCodec.encode(journey), "view": {hints, map}}>
```

The title reads the head and checks the sha (no decode). `read` checks
magic, format, sha, the inflated size and that the root is a Journey with
a campaign and a map, and returns `{journey, view, head, report}` or
`{error}` in words ("the save is damaged", "the save was made by a newer
build of the game", "this is not a saga's save"); nothing a file holds can
crash the title. A write goes to `<slot>.save.tmp`, then is renamed into
place (the old autosave first renamed to `auto_prev`), so a write cut
short leaves the last save whole.

Copy and paste: `export_text(slot)` is `RINGGIVER1:` and the file in
base64 (already compressed: 19 KB of text for a one-year saga, 58 KB at
thirty years). `import_text` forgives line breaks and spaces, then checks
the whole file as `read` does before writing it to a slot. Copy uses the
clipboard where the platform has one; on the web, where a browser may
refuse silently, the text is also shown selected in a box to copy by
hand (as the saga screen does). Paste on the web cannot read the
clipboard (the browser's clipboard read is asynchronous and asks
permission), so the player pastes into the box.

## The codec (sim/save/save_codec.gd, `SaveCodec`)

`encode(root)` walks the graph from the Journey: every property of every
script object with `PROPERTY_USAGE_SCRIPT_VARIABLE` (so the private
`_rng`, `_ale`, `_offers` too), and every object's metadata (the
chronicle keeps its chapters, verses and the ending in `Band` metadata;
the first run lost them, and the `told` comparison below is what would
have caught it had the encoding not). Objects go once into a table
(`{"c": tag, "p": {props}, "m": {meta}}`) and are referred to as
`{"$r": index}` everywhere else: a man in the band, in a decision and in a
battle comes back as one man; cycles cost nothing. The tag is the
class_name, `Outer.Inner` for an inner class (`Roam.Party`,
`Decision.Option`), `@RandomNumberGenerator` for the one engine class
reached, a path for an unnamed script.

Values: ints as JSON numbers within 2^53, beyond as `"~i<digits>"` (the
RNG's 64-bit state and seeds); floats as `"~f"` + `var_to_str` when that
reads back to the same bits, else `"~b"` + the 64 bits (the first matrix
run found `fray_until` and `rest_until` drifting in the last digit after a
year: `var_to_str` is not always exact); strings as they are with a leading
`~` doubled; StringNames `"~n"`; arrays as lists, typed ones as
`{"$a": [builtin, class, script tag], "v": [...]}` (an `Array[Vector2i]`
flat as `"xy"`); dictionaries as JSON objects when every key is a String
(insertion order kept: `JSON.stringify(..., sort_keys = false)` and Godot's
parser keep it; a key starting `$` or `~` gets a `~`), else
`{"$K": keys, "$V": values}` (int keys, `Vector2i` keys, object keys),
typed ones with `"$t"`; packed arrays tagged (`$ps`, `$pb` base64, `$pi`,
`$pl`, `$pf`, `$pd`); other built-ins `{"$v": var_to_str}` when exact,
else `{"$vb": var_to_bytes}`; a Callable to a static function
`{"$fn": [tag, method]}`.

`decode(data)` makes every object first (`new()`; a constructor that
needs arguments gets an empty value of each argument's type, read from
`get_script_method_list`: `Battle`, `Objective`, `Decision.Option`, the
calendar; no class needed changing), then assigns properties, so
references and cycles resolve. It tolerates an older or newer build:

| met in a save | what happens | counted in `report` |
|---|---|---|
| a property the class no longer has | ignored | `unknown_props` |
| a property the class has and the save lacks | the default `new()` gave | `missing_props` |
| a value of the wrong type | the default kept | `mismatched` |
| int for float, float for int, an untyped list for a typed array whose items fit, an untyped dict for a typed one | converted | `converted` |
| a class that no longer exists | null | `unknown_classes` |

`strict` (the tests) lists every value that could not be encoded in
`errors` (a lambda, a Node, a Signal, an unnamed class); the game skips it
and pushes a warning, and the save goes on.

`digest(root)` is the sha256 of the canonical JSON of the encoding;
`digest_parts(root)` digests a level or two down, for bisecting.

### The registry: what is not saved as it stands

All in `SaveCodec`, at the top, one constant each:

- `SKIP` (class -> properties never saved): `Band.friends`, a getter over
  `standing`.
- `DIFF_FROM_DEFAULT`: `CombatRules`, `CampaignRules`, `WorldRules` are
  saved as their difference from a fresh instance (an empty dictionary
  for the game's own rules): a balance patch reaches an old save, and a
  test that changed a rule still round-trips its change.
- `SHARED` (class -> static getter): `MapGrid` -> `norway`. The grid the
  saga walks is the one built from `NorwayData` (immutable after the
  build); it is saved as a token and found again; another grid would be
  saved whole.
- `CALLABLE_DEFAULT`: `Campaign.fight_policy` when it is the class's own
  default lambda. The journey's policy is `Callable(Sandbox,
  "choose_fight")`, saved by name. No other Callable is reachable from a
  saga; a lambda anywhere else is an error in strict mode.
- `TRIM` (class -> {property: newest lines kept}): `Campaign.log` keeps its
  last 400 lines. It is the sim's working record, half a megabyte in
  thirty years, read only by the call writing it (a mark, then the lines
  since). `Journey.said` (the chronicle the player reads, all of it, in
  the map's book) and the band's and world's chronicles are kept whole.
  The digest is of the trimmed encoding, so the continuation test sees
  the trim alike in both runs.
- `NATIVE`: the engine classes that may be reached and the properties
  that are their state, in order: `RandomNumberGenerator` [seed, state]
  (the state set after the seed, which resets it).
- `STATICS`: every `static var` in sim/ with the reason it needs no saving
  (caches over the fixed grid, the stand-in player's habits, the codec's
  own lookups). Statics are not saved. `test_every_static_in_the_sim_is_
  accounted_for` fails on a new one: a static the sim writes while it
  plays would be shared by a saga and its loaded copy in one process, so
  the continuation test could not see it, while a real reload would lose
  it.

**Adding an exception**: a new field needs nothing. A field that is
derived goes in `SKIP`; a large deterministic table built from static
data goes in `SHARED` (with a static getter returning the one instance);
a lambda property the constructor sets goes in `CALLABLE_DEFAULT` (better:
use a static function, which saves by name); a log only the writing call
reads goes in `TRIM`; a new static var in `STATICS` with its reason. Never
make a class unconstructible with `new()`: give `_init` arguments
defaults or plain types (an empty value of each type is passed).

### No Node is reachable from the sim

Checked in strict mode on every encoding the tests make (a Node is an
error). The view's state that matters is saved beside the journey, not in
it: `view: {hints: [ids], map: {cam, zoom, follow, selected, paused}}`.

## The continuation test (sim/save/save_play.gd, `SavePlay`)

`SavePlay.step(j, bent)` is one move of `JourneyBot.play_year`'s loop (a
winter kept, a decision answered, the road walked, points spent, a deed;
a fight waiting for the battle screen fought out by the AIs).
`SavePlay.reach(seed, origin, bent, point)` plays a new saga to a save
point; `continue_check(j, bent, years)` saves `j` to text, loads it into a
new graph, checks the copy's digest equals the original's (else the codec
itself is wrong: `at_save`), plays both on the same way, and compares the
digests (`after`) and, independently of the codec, what the saga says
through its own functions (`told`: the status, the saga as told with its
chapters, the household, the facts: silver, men and their loyalty,
standings, the houses' tidings, party positions, the saga's lines). No
field of the sim is named anywhere: whatever another package adds is in
the encoding and in what the bot does.

The save points (`SavePlay.POINTS`): `start` (for the burned hall, the
escape's battle waiting in `fight`), `road` (under way on land, day 20+),
`sea` (afloat), `decision` (anything but a fight), `fight_offer`,
`battle` (taken on the battle screen's terms and four rounds fought,
then saved), `winter:0`..`winter:4` (the stepped winter, n steps in),
`grave_ale` and `grave_ale:1` (the death card, and a card on), `ended`
(died old, the saga ended), `years` (years let pass, the spring card
waiting), `gen2` (the heir's first summer, day 30+), `year3`.

`tests/test_save.gd::test_continuation_at_save_points` runs seven of them
(road, the escape waiting, mid-battle, winter step 2, the grave-ale, years
let pass, generation 2, over five bents and three origins), a year on:
about 43 s. `tools/save_check.gd` runs the matrix:

```
godot --headless --path game -s tools/save_check.gd -- 5 all all all 1      # 5 seeds x 3 origins x 6 bents x 17 points
godot --headless --path game -s tools/save_check.gd -- 2 younger_son viking winter:2,battle 2
godot --headless --path game -s tools/save_check.gd -- 0 - - - 0 sizes      # sizes and times only
```

Reading a report: `OK origin bent seed point <digest>`; `--` the saga
never came to that point (no sea that year, a death card without an end);
`DIFF` followed by up to twelve paths where the two runs differ, walked
side by side through the two encodings, e.g.

```
DIFF burned_hall lawman seed 1 winter:2
       after  root.c.band.men[3].loyalty: 52 / 53
       told   status: {...} / {...}
```

`at_save` lines mean the loaded copy differs before anything was played:
the codec lost or changed a value (fix the codec or add a registry
entry). `after` lines mean the copies went apart while playing: something
that decides what happens is not in the encoding (a static, a cache whose
contents change behaviour, an engine object not in `NATIVE`), or a value
was not exact. Fix by finding it (the first path is usually the cause,
the rest its consequences), never by loosening the test.

## Autosave (view/game.gd)

`game.autosave()` marks a save due; `_process` writes it once
`SAVE_GAP_MS` (1.5 s) has passed since the last, so a burst of beats is
one write and none is lost. The beats: every `MapScreen.refresh()` (it
follows each answer, deed, arrival, winter's start and end, a modal
closed), each winter step (`WinterScreen._press`), a fight concluded
(`leave_battle`); while the band is under way, at most every
`TRAVEL_SAVE_MS` (20 s). Written at once: as the battle screen opens
(`start_battle`), and on `NOTIFICATION_WM_CLOSE_REQUEST`,
`NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT` and
`NOTIFICATION_WM_WINDOW_FOCUS_OUT` (never while the battle screen is up).
Loading a slot writes the autosave at once (the saga taken up is the one
Continue finds). A tool's run (`use_config` off or `fixed_seed`) has
autosave off, so `screenshot_map.gd` and the like never touch the
player's saves; `screenshot_game.gd` turns it on into `user://shot_saves/`
for the save's own shots.

## Measured

Sizes and times (`save_check.gd -- 0 - - - 0 sizes`, younger son, the
viking stand-in, seed 4, this machine, best of three):

| saga | objects | JSON | of it `said` | file (gzip) | encode+pack | write | read+decode |
|---|---|---|---|---|---|---|---|
| 1 year | 107 | 80 KB | 8 KB | 14 KB | 17 ms | 0.3 ms | 21 ms |
| 10 years | 123 | 238 KB | 85 KB | 33 KB | 26 ms | 0.3 ms | 32 ms |
| 30 years | 139 | 398 KB | 154 KB | 43 KB | 34 ms | 0.4 ms | 43 ms |

Before the `Campaign.log` trim the thirty-year JSON was 900 KB (518 KB of
it the log). The file stays far under 1 MB; no further trimming is
needed. The encode is GDScript walking every property (about 12 ms of a
one-year save is spread evenly over the places, the houses and the rules'
diffs); on a phone's browser expect several times this. It runs at a beat
(after a tap), at most every 1.5 s, never during the battle screen, so it
is not on a busy frame; a write off the main thread was not needed on
these numbers, and the web build has no threads to give it. If the phone
proves slow, the first thing to try is saving the places' unchanging
fields as a diff from `Sandbox.setup` (as the rules are).

The matrix: see the report of this package for the counts of the last
run (5 seeds x 3 origins x 6 bents x 17 points, a year on each).

## Web persistence

Godot 4.5's web build mounts `user://` on IndexedDB (IDBFS) and copies it
there when a file opened for writing is closed. A rename or a removal
after that is copied only at the next sync, so `SaveStore.sync()` calls
`JavaScriptBridge.force_fs_sync()` after every write, rename and removal
on the web (`OS.has_feature("web")`); elsewhere it does nothing. A closed
tab may not wait for the save on focus-out or for the sync to finish; that
is why the beats save, so the last autosave is at most one beat old.

**Unverified**: no export templates are installed here
(`~/.local/share/godot/export_templates` is empty), so the web build was
not exported or run locally. To check on the live build: begin a saga,
walk a few days, answer a decision, close the tab, open the page again:
the title should offer "Continue the saga" with the right line; Continue
should put the map back where it was. Then: reload in the middle of a
winter (the hall should come back at its step); reload during a battle
(the fight should start again from its first round); Sagas > Copy, then in
a private window Sagas > Paste a save; a private window should show the red
line that saves are not kept. Also watch which notifications the browser
delivers on a tab hidden or closed (`NOTIFICATION_WM_WINDOW_FOCUS_OUT` on
blur is expected; `APPLICATION_PAUSED` on hide is not certain).

## Files

New: `sim/save/save_codec.gd` (SaveCodec), `sim/save/save_play.gd`
(SavePlay), `sim/save/save_store.gd` (SaveStore), `view/saves_modal.gd`
(SavesModal), `tests/test_save.gd`, `tools/save_check.gd`. Changed:
`view/game.gd` (autosave, load, the title), `view/map_screen.gd`
(`view_state`, `restore_view`, two autosave calls), `view/winter_screen.gd`
(one autosave call), `view/settings.gd` (the Sagas button),
`tools/screenshot_game.gd` (`save`, `save:<slot>`, `load`, `sagas`; what
`continue`, `sagas`, `confirm`; saves go to `user://shot_saves/`). No sim
class needed changing to be constructible or saved.

Also `view/hints.gd`: the hint card waits while the winter hall is up (a
saga loaded in winter showed an unread hint over the hall).

Screens (844x390), in `docs/design/notes/save-shots/`:
`1_title_continue.png`, `2_sagas.png`, `3_begin_anew.png`,
`4_map_loaded.png` (the same shot as `4_map_before.png`, after a save and
a load: camera, zoom, pick and the decision waiting all as they were),
`6_paste.png`, `7_winter_loaded.png` (loaded at the winter's third step).
The Sagas button in the settings is under the fold of the settings modal
at this size (scroll to "The saga").

## Open

- A battle in progress is not resumed on the battle screen (see above);
  the codec could, if the battle screen learned to start from a battle
  past round 0.
- Paste on the web reads no clipboard: the player pastes into the box.
- The saved-at time is the device's clock.
- The continuation compares a saga with its copy in one process; the
  `STATICS` test is what guards against state kept in statics.
