# The interface's look (ui-polish)

Branch `ui-polish`. The overworld had just been redrawn as a painted saga
chart; everything round it was prototype grey (default Godot buttons and
panels, default sizes, a text dump for a side panel, a see-through result
panel). Now the whole interface is one look, built in code from Godot's own
Theme and StyleBoxes and the default font: dark carved wood and worn iron
with a thin tarnished-gold rule, parchment where there is a lot to read,
bone text, blood only for danger, the map's teal for calm.

Before and after shots (844 x 390, a phone held sideways, unless the name
says 1280) are in `ui-shots/`: `<n>_<screen>_before.png` and
`<n>_<screen>_after.png`.

## The rules

### Colour (view/palette.gd, the `UI_` entries)

| name | use |
|---|---|
| `UI_NIGHT` 14100d | the ground behind every screen, the dimmed backdrop, the HUD's strips |
| `UI_WELL` / `UI_WOOD` / `UI_WOOD_RAISED` / `UI_WOOD_HOVER` | panel wood from sunken (inputs, stat wells) to raised (buttons) |
| `UI_RULE` 8a6d36, `UI_RULE_DIM` | the rule round panels and buttons |
| `UI_GOLD` dcb862, `UI_GOLD_DEEP` a9822e | titles, the chosen thing, the primary button's face |
| `UI_TEXT` / `UI_MUTED` / `UI_FAINT` | read / said aside / cannot be done now |
| `UI_PARCHMENT`, `UI_INK`, `UI_INK_MUTED` | long reading: the winter, the chronicle, the told lines after a fight, the hints on the map, the tutorial's banner |
| `UI_BLOOD` | danger only: feuds, outlaw, defeat, a grievous wound, food running short, the summer nearly gone |
| `UI_TEAL` | calm: you are here, your home, unhurt, the escape |
| `UI_FRIEND` | a friendly house |
| `UI_OURS` / `UI_THEIRS` | the walls on the battle strip and the result table (the shields' madder and woad, lifted to read on the dark) |
| `UI_EMBER` | the opening's fire |

The older entries (BG, GOLD, TEXT, the field's colours) are untouched; the
battle field keeps its own grey ground.

### Type (UiTheme constants; design pixels, the design is 540 high)

| size | px | on a 390-px phone | use |
|---|---|---|---|
| `DISPLAY` | 60 | 43 | the title screen's name only |
| `TITLE` | 26 | 19 | a modal's or a screen's title, a place's name |
| `HEADING` | 20 | 14 | a section, a card's name, the leader's name |
| `BODY` | 17 | 12.3 | everything that is read; the opening's cards use `SagaLabel` at 21 |
| `SMALL` | 14 | 10.1 | hints under a row, descriptions, the log |
| `KEY` | 12 | 8.7 | spaced capitals over a stat's value, chips; nothing else |

One font, the default, in cuts made with `FontVariation`: body, bold
(embolden 0.45), display (0.7, spaced 3), caps (0.25, spaced 1). Plain Latin
only.

### Space and touch

A 4-pixel grid (`S1` 4, `S2` 8, `S3` 12, `S4` 16, `S5` 24). The primary
control is `TOUCH` = 62 high (45 screen px on the phone), every other
control `ROW` = 52 (38 px; the map's three list buttons 48, the battle's top
row 48). `EDGE` = 14 is kept clear at the left and right edges of every
screen (a phone's rounded corners); the map's side panel pads its right
side 20.

### States

Every button variation has normal, hover, pressed (the face darker and the
words a pixel or two lower: a press is felt), disabled (faded face, faint
words, no gold) and a thin gold focus ring. A toggled button that is on
(the shout given, Follow, the map's pause while the days stand) takes the
pressed face with gold words; the battle's command buttons add a heavy gold
top edge when on.

## UiTheme (view/ui_theme.gd)

`UiTheme.theme()` builds the Theme once. `UiTheme.apply(root)` puts it on a
screen's root. game.gd also puts it on the window (tooltips, pickers); a
CanvasLayer does not pass a theme down, so the battle HUD applies it to its
own root. A new screen added from game.gd through `_swap` gets it for free.

Variations (set `theme_type_variation`, or pass the name to a helper):

- Labels: `DisplayLabel`, `TitleLabel`, `HeadingLabel`, `BodyLabel` (the
  default), `StrongLabel`, `SmallLabel`, `KeyLabel`, `ValueLabel`,
  `SagaLabel` (the opening's large reading text), `InkLabel`,
  `InkSmallLabel`, `InkHeadingLabel` (on parchment), `DangerLabel`.
- Buttons: the plain button is the secondary; `PrimaryButton` (gold, one
  to a screen), `QuietButton` (Back), `RowButton` (a row in a list),
  `CommandButton` (the shouts), `ToolButton` (small controls over the map or
  the field), `CardButton` (a card to choose).
- Panels (PanelContainer): plain wood, `FramePanel` (a modal), `SidePanel`,
  `CardPanel`, `WellPanel`, `ParchmentPanel`, `StripPanel` (translucent, over
  the map or the field), `ChipPanel`, `ClearPanel`.

Helpers (all static, all return a node to add):

```gdscript
UiTheme.label(text, variant := "", wrap := true) -> Label
UiTheme.button(text, on := Callable(), variant := "", min_size := Vector2.ZERO) -> Button
UiTheme.primary(text, on, width := 0.0)      # 62 high
UiTheme.secondary(text, on, width := 0.0)    # 52 high
UiTheme.quiet(text, on, width := 0.0)
UiTheme.section(text) -> HBoxContainer       # a gold heading and a rule to the right
UiTheme.rule(knot := true) -> UiOrnament     # a rule, with a small knot at its middle
UiTheme.stat(key, value, color) -> VBoxContainer   # KEY over value; UiTheme.set_stat(box, value, color)
UiTheme.kv_row(key, value, color) -> HBoxContainer
UiTheme.chip(text, color) -> PanelContainer  # a rank, a standing, "Outlaw"
UiTheme.list_row(title, hint, on, enabled := true, reason := "") -> Button
UiTheme.panel(variant := "") -> PanelContainer
UiTheme.titled_panel(title, variant := "CardPanel") -> PanelContainer   # its body: get_meta("body")
UiTheme.modal(host, title, max_width := 760.0) -> UiModal   # added to host and opened
UiTheme.scroll(child) -> ScrollContainer     # up and down only
UiTheme.gap(h, w) -> Control
UiTheme.fade_in(node, seconds := 0.22)       # off when UiTheme.motion is false (the tools)
UiTheme.standing_color(standing) -> Color    # blood-enemy red .. stranger .. friend green-gold
UiTheme.box(bg, border, bw, radius, mx, my) -> StyleBoxFlat
UiTheme.font(kind) -> Font                   # "body", "bold", "display", "caps", "italic"
UiTheme.build_stamp() -> String
```

A winter screen, say, from a file that has not seen any of this:

```gdscript
var root := Control.new()            # game.gd's _swap applies the theme
root.add_child(UiEmbers.new(0.6))    # or a plain dark ground
var col := VBoxContainer.new()
col.add_child(UiTheme.label("The winter of 866", "TitleLabel"))
col.add_child(UiTheme.rule())
var tale := UiTheme.panel("ParchmentPanel")
tale.add_child(UiTheme.label(text, "InkLabel"))
col.add_child(UiTheme.scroll(tale))
col.add_child(UiTheme.primary("Spring", on_spring, 220))
```

or, over the map, a modal:

```gdscript
var m := UiTheme.modal(map_screen, "The winter of 866")
m.body.add_child(UiTheme.label(text))
m.add_button("Spring", func() -> void: m.close(), "PrimaryButton", 220)
```

### The small pieces

- `UiModal` (view/ui_modal.gd), a Container: the screen dimmed behind
  (`dim`), a `FramePanel` with gold corner brackets, `title_label` over a
  knotted rule, `body` (a VBox in `scroll`) and `footer` (an HFlow, so a
  row of choices wraps rather than overflows). It is as tall as its words
  and never taller than the screen less `margin`. `open(title)` clears and
  shows (fading in), `clear()`, `close()` (signal `closed`),
  `add_button(text, on, variant, width)`. It stops touches to what is
  behind it.
- `UiOrnament` (view/ui_ornament.gd): RULE, KNOT_RULE, INTERLACE (a
  two-strand band, under the title), RING (the title's open arm-ring of
  twisted gold with round terminals), PIPS (`filled` of `count` diamonds: a
  way's steps); and `UiOrnament.corners(canvas_item, rect, color, len)`.
  Each draws only when resized.
- `UiIconButton` (view/ui_icon_button.gd): a `ToolButton` that draws a
  sign ("pause", "play", "fast", "stop", "plus", "minus", "follow",
  "book"); the word is its tooltip.
- `UiEmbers` (view/ui_embers.gd): the opening's backdrop, a night with a
  fire's glow along the bottom (drawn once a resize) and sparks rising
  (CPUParticles2D, no script per frame); `strength` 0..1.

## What each screen became

- **Title**: the arm-ring (the ring-giver's gift) over RING-GIVER in the
  display cut with a dark outline, an interlace band, the saga line; Begin
  a saga as the gold primary, Another beginning and A single fight as
  secondaries under it; the build tag faint in the corner. Fire glow low.
- **Name, the night's cards, the told escape**: the same night with more
  fire; a small spaced kicker ("THE NIGHT THE HALL BURNED 1 OF 3"), the
  text at 21 with air between lines, one primary button.
- **Another beginning**: two cards (`CardButton` with the name, a rule, the
  blurb and how you start), the chosen one gold-edged with a "Chosen" chip;
  the name field, Back (quiet) and Begin (primary) along the foot.
- **The map**: the time controls a cluster of drawn signs (pause turns to a
  gold play sign while the days stand, fast lit while fast; halt; nearer,
  further, follow; "?"), still an HBoxContainer so the map's names keep off
  it. The saga's last lines (as many whole messages as fit in four lines)
  on a dark backing at the foot, with a book button for the whole
  chronicle. The side panel: the leader's name and his rank and feud /
  outlaw chips, the date and place with the days left, a thin bar of the
  summer gone, a stat strip (silver, food, men and hurt, fame, honor, luck;
  food in red when short), the ship and hold in a line, the three lists
  (Your ways turns gold while there is a point to spend), a knotted rule,
  then the place card (name, chips for kind, region, home, feud; who rules
  it; the ruling house's line coloured by its standing) and either "Make
  for it" as the primary, or the market (a row a good: name, prices, stock,
  +1 +5 -1 All) and "What may be done" as rows (title and hint; greyed when
  it cannot be done).
- **Modals on the map** (decisions, the winter, the saga's end): one
  UiModal, the decision's words at 21, the choices in the footer; the
  winter's tale on parchment. **Side lists** (another UiModal): Your men as
  rows (name, You chip, what he is, M S G N W, a wound chip teal/gold/red
  and "stays behind"); Your ways as cards in two columns (name, three pips
  for the steps taken, the steps lit as taken, the next muted, the rest
  faint, and "Take the step: <name> (cost)" gold when it can be taken);
  the families as cards with a standing chip coloured from blood to friend,
  the tidings on parchment above; the chronicle on parchment, scrolled to
  the newest. The hints: a slip of parchment under the time controls; "What
  you have learned" a modal of cards.
- **The battle**: a strip top-left (Round, the task and its clock, the
  orders given; then our wall in madder with its spears, bows and stance,
  theirs in woad; then your man's line in gold, or yellow when the wall is
  broken). The controls are small tool buttons on the right; on a narrow
  screen (the 16:9 desktop, a fight with every control) the strip goes
  under them, and the camera and the tutorial's banner measure where the
  top ends (`hud.top_height()`). The shouts are command buttons, the given
  one gold-topped; Next round the gold primary. The log on a dark backing
  whose top fades. Before the fight, the result and the drill yard are
  UiModals: the result's title coloured by the outcome (gold victory, red
  defeat, teal escape), a sentence of why, a table of the counts (men,
  down, broke, fled, dead; zeros faint), the told lines on parchment, one
  primary. The tutorial's banner is parchment; its pulse and lock work as
  before.
- **Small things**: screens and modals fade in (0.22 s, 0.14 s);
  capitalisation is sentence case everywhere ("Back to the map", "Take the
  step"); the boot splash, the clear colour and the web page's background
  (export preset `html/head_include`, with a theme-color meta) are the
  night's 14100d; the window title is the project's name, Ring-Giver.

## Code that changed for this and must stay

- MapScreen keeps every name the tools and hints use (`setup`, `refresh`,
  `_show_men`, `_show_ways`, `_show_families`, `_house_line`, `tap_map`,
  `_process`, `modal`, `side_panel`, `paused`, `selected`, `canvas`,
  `_quick`); `modal` and `side_panel` are now UiModals. `paused` is a
  property: setting it (the tools do) updates the controls. New:
  `time_bar`, `_show_chronicle`, `_house_standing`, `_market_row`,
  `_man_row`, `_way_card`.
- The HUD keeps `controls`, `allowed`, `shout_buttons`, `_on_shout`,
  `_on_withdraw`, `_show_drill_yard`, `result_panel`, `offer_panel`
  (UiModals now), `pulse_slider`, `pulse_label`, `root_control`. New:
  `top_height()`, `strip`, `buttons_row`. `_result_text` is gone (the
  result panel builds its parts).
- main.gd: the camera keeps the men below `hud.top_height()` instead of a
  fixed 50.
- The log on the battle screen is trimmed by paragraphs (it was by wrapped
  lines, which read 0 before the label was laid out and emptied it).
- `tools/screenshot_game.gd` has a `chronicle` command.

## Measured and checked

Every screen listed in the task was rendered at 844 x 390 and 1280 x 720
and looked at: title, name, the night's cards, the escape (tut:1, tut:3,
tutto:4 with a hurt man, tutto:6 and its result), the told escape, the map
with Word comes and with its first hint, a place selected, a market town,
men, ways, families, the chronicle, what you have learned, the winter, a
fight offer, another beginning, the single fight (offer, round 6, result,
drill yard). Zero SCRIPT ERROR lines in every render. `tests/test_ui_theme.gd`
pins the theme's variations, the type and touch floors on a phone, the
helpers, the standing colours and the modal's height.

No per-frame drawing was added: the ornaments draw on resize, the
icon buttons on state changes, the embers are particles, the map's log
redraws only when the saga says something new.

## Left undone

- The saga's end modal was not rendered (it needs a death or the end of
  the saga); it is the same UiModal as the winter.
- The drill yard's pickers (OptionButton) keep Godot's arrow icon.
- The battle's top controls stay words (Advance, Wheel L, Wheel R); signs
  for them would save room on a phone but are less clear.
- Long place names next to the date can still be cut with an ellipsis in
  the side panel's header.
