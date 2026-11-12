# Battles 2: named lieutenants, the strandhogg fought, let none out, the great battle's sector, the barred hall

Branch `battles-2`. Five things the saga's fights could not do before, each
reached through `Journey` and fought on the battle screen. Every rule acts
only inside the fights that ask for it: `Battle.wings`, `Battle.arrivals`,
`Battle.sector`, `Battle.barred` and the objective kind `CATTLE` are empty,
null, false or absent in every ordinary fight, and the fingerprints of the
ordinary fights are byte-identical before and after (see Measured).

## What the player meets

### 1. Named lieutenants (`sim/combat/wing.gd`, `Wing`)

In a fight of the saga with eight men or more in the line
(`CombatRules.wing_min_line`), the band's sworn second commands a wing of
it, and in a band of sixteen living men or more (`CampaignRules.wing_third_band`)
a second named man (the best of the rest by tier, then wits and nerve)
commands the other. Not at the hall's doors, in the burning's ring, in a
strandhogg, or in a column caught on the march.

- **The sheet** (`Hud._show_wings`): before the first round, one small
  modal, "Your named men": each man's wing and temper ("Alf, the left
  (rash)"), one wide button (62 px tall) that steps through the five words
  with a line under it saying what the word asks, and "To the fight". The
  sim already holds a sensible word (`Wing.sensible_word`): the player need
  not touch it. No per-round taps; nothing added to the battle bar.
- **The words** (`Wing.Word`): hold the line, press when they waver, fall
  back on me, go round their flank, guard the archers.
- **His judgment** (`Wing._think`, each round after the shouts): his temper
  comes from the words told of him (`Man.traits`: "reckless", "rash",
  "steady", "cautious", "cunning" ...), else his fighting nature
  (`personality` RECKLESS / STEADY or GRIM), else his wits (6+ cunning)
  (`Wing.temper_of`). Then:
  - *Hold the line*: the wing stays in the wall and stands hard in contact
    (its men near him take heart up to `wing_hold_cap` 8). A rash man cannot
    keep to it and takes his men in as soon as he thinks they waver.
  - *Press when they waver*: when the enemy within `wing_sight` (4) of his
    wing has a broken man, or its mean heart is at or under
    `wing_waver` (plain 5, rash 7: too soon, steady 4: too late, cunning
    5.5), he takes the wing in (Break them); pressing, his men take heart
    and the enemy at arm's length of them loses `wing_press_dread` (1) a
    round; a wing whose own heart falls to `wing_quit_morale` (3.5) is
    brought back.
  - *Fall back on me*: when the wing is in contact and its mean heart is at
    or under `wing_pressed` (plain 6, rash 5: too late, steady 7: early,
    cunning 6), he gives ground for `wing_fallback_rounds` (2), rallying it
    (`Morale.rally` round him), then stands again, not again for
    `wing_fallback_rest` (4).
  - *Go round their flank*: when the lines close (`wing_flank_range` 3)
    and his wing reaches past the end of theirs by a hex or more (a rash
    man as soon as the wall is formed; a steady one only after
    `wing_flank_wait` 3 rounds of contact), the men of the wing not fast in
    the fight make for a hex beyond the end of the enemy's line and come in
    on it.
  - *Guard the archers*: the wing keeps its place until an enemy comes
    within `wing_guard_radius` (3; a rash man 5) of a bowman; then it goes
    for him and comes back once he is dealt with.
  The leader's own "Fall back!" or "To me!" is heard over any word.
- **Seen on the field** (`BattleView._draw_battles_2`): a pennant on each
  named man in his side's colour, the word beside it ("press", "hold",
  "back", "flank", "bows"; the enemy's only while he acts), a gold ring
  round him while he acts on it. **In the log**: "Alf has the left wing:
  press when they waver", "Alf sees them waver and takes the left in",
  "Alf calls the left back on him", "Alf takes the left round their flank",
  "Alf's men on the left stand hard", "Alf cannot keep to it: he takes the
  left in".
- **He falls** (down, gone or broken): "Alf is down, and the left wing has
  no one to lead it"; every man of the wing loses `wing_leaderless_morale`
  (1) heart and goes back to the leader's word for good. **The saga**
  (`Journey._wing_lines`): "Alf fell leading the left wing, and the wing
  wavered without him." (and `band.log`, so the chronicle keeps it), or
  after a win "Men speak of how Alf led the left: press when they waver."
- **The enemy's named men**: where the enemy is a named house or a king's
  (`offer.house` or a great battle), one (two past sixteen men) of their
  steadiest men has a wing, with the word his leader's doctrine gives
  (`Wing.doctrine_word`: steady holds, cunning goes round, the rest press).
- **Nobody is moved**: a wing is the men nearest its lieutenant across the
  leader's front, where they were formed (an earlier draft moved him to
  the wing's middle; that alone moved the defence's win rate by 20 points,
  so it was taken out: "named, no word" is now the same fight blow for
  blow as no wings at all, which a test pins).

### 2. The strandhogg fought (`Objective.Kind.CATTLE`, `Scenario.build_strandhogg`)

"Strandhögg" at a farmstead (`Journey._strandhogg`) is now a fight offer:
"You put in below the Jæren farms for its cattle: a few herders by the
farm, and the district will come when it hears." with "Go in for the
cattle" and "Fade away", and the map's usual "Let the saga tell it" box,
which fights it with the leader AI (the skip). The field (16 x 14): the
farm across the top, the pasture (`Objective.cells`, the herd drawn on it),
the strand and the band's boats along the bottom (`Objective.boats`, the
sea drawn below), the band standing in the pasture facing the farm, two
herders by it. A man of the band in the pasture with nobody at arm's
length helps round up the herd (a beast for every `cattle_gather_men` 2 a
round, `cattle_herd` 12); a beast is lost for every man of the band who
goes down or runs. The district gathers on the clock (`Battle.arrivals`):
`strand_parties` 5 parties, the first at round 3 and one every 2, from the
farm and along the shore between the band and its boats, each a man bigger
than the last (2, 3, 4, 5, 6, plus a man for every two of the place's
defences and four of its alertness; blooded past defences 2). They come on
as Break them. The band gets away by getting aboard: "To the boats" (the
Withdraw button, renamed) once its leader is within two hexes of a boat
and nobody is at arm's length. At round 30 the whole district is up and
the band must leave the cattle. Greed against getting away is the
decision: the leader AI waits for `strand_greed` (0.6) of the herd, or
until half its number of the district are within four hexes, or round 7.

What it brings (`Journey._after_strandhogg`): `strandhogg_food_per_head`
(2) rations a head (twice for a sea-wolf), the farm's silver in proportion
to the herd (`strandhogg_silver` x 2 x head / herd, no more than the place
has), the Viking's deed; the house's standing (`standing_strandhogg`) and
the place's alertness either way, the feud chance as before, the
chronicle ("took 9 head of cattle at the Jæren farms"). Driven off: "The
district's men drive Egil's band back to its boats without the cattle."
The old `Raiding.strandhogg` is left in place (tests pin it) but nothing
in the journey calls it.

### 3. Let none out (`Journey._ask_mercy`, `_answer_mercy`, `_nithing`, `burners_let_none_out`)

Choosing "Burn them in by night" now asks first, in the map's modal
("Before the fire"): "The hall of Hardanger-Atli's kin is ringed and the
torches are lit. Men call from the door to let the women and the children
out. The custom is to let them go, with the thralls; a man who burns them
is a nithing, and his name with him." — *Let them out* (as before) or *Let
none out*. Letting none out:

- the band's honor down `none_out_honor` (30) on top of the burning's;
- every house in the land `none_out_standing` (-10) colder, the burned
  house's friends `none_out_ally_standing` (-15) more on top of the
  burning's own -25;
- none of that blood is left to avenge it: the house is cut to
  `none_out_house_left` (2) men, the band's feud with it ends ("none
  left"), and no heir begins a new one; instead its nearest kin (blood,
  then marriage, then any friend) take up a feud at level 3 marked
  `no_silver`: `Feud.settle` refuses ("X will take no silver for this
  feud.") and no wergild demand comes for it (`Feud.summer_events`);
- men of the band under `none_out_stay_loyalty` (75) leave it with
  `none_out_leave_chance` (0.35) each ("Thorkel, Bard will not follow a
  nithing: they take their things and go.");
- the saga: "None were let out. The women, the children and the thralls of
  X burned in the hall at Y with their men.", "Men everywhere call Egil a
  nithing for it.", the chronicle line and the world's tidings,
  `tally.nithing`. The "were let out" line of the burning is not said.

**The band's own hall** (`WinterHall._hall_burned` now asks
`Journey.burners_let_none_out`): when the roof takes, the burners let none
out with `enemy_none_out_chance` (0.08) for each step of the feud (0.24 at
its height): the wife and every child at home under sixteen (not one
fostered away) burn with the thralls ("Augvald's kin call that none shall
come out, and hold the door with spears. Gudrun, Ari burn in the hall with
the thralls."), the chronicle and the world remember it, and the band's
feud with them goes past silver and to its height.

### 4. Hafrsfjord as a sector of the line (`Sector`, `Scenario.build_sector`)

Every spine battle (`Journey` "spine" decision, `Timeline.fire`'s
`battle_required`) is now fought as the band's part of a longer line:
`Journey._about_fight` gives the offer `great` (`FightOffer.great`,
`Journey._great_battle`) and `Campaign.build_fight` builds
`Scenario.build_sector` from it. The builder takes parameters, so any
future great battle can use it: `ground` ("deck" or "shore"), `attacker`,
`doctrine`, the names (`battle_name`, `ours_name`, `theirs_name`, `left`,
`right`, `banner_name`), `edge` (our kings' share of the line's strength),
`banner` (-1, +1, or 0 with the band), `flank_men`, the tiers, `day_rounds`.

- **The neighbours** are not men on the field but a state each, -2 broken
  .. -1 wavering .. 0 holding .. +1 pressing .. +2 won, that moves a step a
  round with `sector_drift` (0.3): up with the line's lean, down with the
  rest. The lean is `edge` moved by `sector_weight` (0.6) x half the band's
  own sector (its share of men standing less the enemy's): how the band
  fares weighs on its neighbours. The log: "On your left, Rognvald of
  More's ship wavers".
- **A neighbour breaks**: the band's men lose a step of heart and next
  round `sector_flank_men` (3) of the enemy come over onto that flank (onto
  the end of the band's hull on the decks; up the field's edge ashore):
  "the enemy come over onto your right flank, 3 of them". If the king's
  banner stood there: "Harald's banner goes back with them", another step.
  **A neighbour wins**: the enemy lose heart and its men come in on the
  enemy's flank.
- **The day is the whole line's** (`Sector.verdict`): at `day_rounds` (26),
  or whenever the band's own fight ends, each neighbour counts its state
  (the banner's neighbour `sector_banner_weight` 1 more), the band's own
  part `sector_own_weight` (2) times its own (routing them +2, routed -2,
  the field +1/-1, withdrawn -1.5, else its standing share doubled). The
  battle's winner is the day's: "the day at Hafrsfjord goes to Harald"
  (`Battle._finish` asks the sector), and `Timeline.resolve` reads it. The
  saga: "At Hafrsfjord the day goes to Harald; the band held its part of
  the line."
- **Seen**: a bar at each end of the field in the neighbour's state's
  colour with its name and state inside the field's edge, the king's
  banner over the bar where it stands; the strip's top line "left
  wavering, right broken".
- **Hafrsfjord is fought on the decks** (`ground` "deck": the band's ship
  lashed in the line, the enemy's alongside, the neighbours' ships over the
  bow and the stern). The deck scenario carries it well: the sagas tell
  Hafrsfjord as ships lashed together, a broken neighbour's ship is
  exactly where flanking men come aboard (over the stem or stern), and the
  existing deck rules (gangways, men overboard, a deck cleared) give the
  band's part its own ending. Fighting for Harald the band boards (his
  fleet came on); against him it is boarded. The `edge` is Harald's
  strength over his and the kings' he means to take (the event's `absorb`
  and `conquer` factions). Names: for Harald, "Rognvald of More's ship" and
  "the king's own ship" with Harald's banner; against him "Eirik of
  Hordaland's ship" and "Sulki of Rogaland's ship" with Kjotvi the
  Wealthy's banner. The other spine battles (Trøndelag, the west) are
  fought ashore.

### 5. Barring the door (`Scenario._bar_the_door`, `balance.md` item 6)

"Bar the door and hold the walls" against fire is a different fight now:
the band is *inside* its hall, the hall bigger (its floor
`bar_floor_rows` 3 deep, timber all round), the steadiest shield of them
in the great doorway with the leader behind him, a man at the byre door in
a gable end. The fight is at the doors: no heave of one wall against
another carries through a doorway (`Battle.barred`: no push), so numbers
count for less. The burners need `bar_fire_rounds` (14) rounds of fire at
the walls, and a man at the walls with a blade at him lights no torch; but
the fire is also a clock: `smoke_rounds` (24) of smoke after the lines meet
(two a round while they hold the walls) and the roof takes whatever the
yard holds, and then the existing fire's choice: break out through the
door, or lie down and burn. A friendly house may come: the friendliest
house the band has (`Families.is_friend`) sends `hall_help_men` (4) men,
one more for every 10 of standing past the friend's mark, at most 8
(`Campaign._hall_help`), round the ends of the yard
`bar_help_round` (4) rounds after the lines meet if the door has held, and
the burners lose `bar_help_dread` (2) heart at the sight. The band's
leader AI holds its doors (`Battle.bar_hold`).

## Classes and functions

- Combat: `Wing` (new: `form`, `think`, `hearten`, `action_for`,
  `flank_cell`, `temper_of`, `own_word`, `doctrine_word`, `sensible_word`,
  `describe`); `Sector` (new: `round_end`, `verdict`, `decided`,
  `own_share`, `line_text`, `neighbour`); `Battle.wings`, `wing_of`,
  `wing_led_by`, `arrivals`, `add_arrival`, `_arrive`, `_more_coming`,
  `_driving_cattle`, `sector`, `bar_hold`, `barred`; `Objective.Kind.CATTLE`
  (appended; NAMES, SHORT) with `herd`, `gathered`, `lost`, `boats`,
  `greed`, `leave_round`, `leaving`, `driven`, `at_boats`,
  `_decide_cattle`, `cattle_order`; `Objective.smoke_rounds`, `smoke`,
  `_free_at_walls`; `BattleResult.cattle`; `Scenario.hands`,
  `build_strandhogg`, `_bar_the_door`, `build_sector`.
- Campaign: `Campaign._strandhogg_fight`, `_sector_fight`, `_hall_help`,
  `_give_wings`, `HELP_FIRST_ID`; hooks in `build_fight` (three lines) and
  `stake` (the strandhogg's line); `FightOffer.great`, the strandhogg's
  title and brief.
- World: `Journey._strandhogg`, `_after_strandhogg`, `_great_battle`,
  `_wing_lines`, `_ask_mercy`, `_answer_mercy`, `_nithing`,
  `burners_let_none_out`; hooks in `answer` ("mercy"), `_answer_fight`,
  `_about_fight`, `actions` (the hint), `act`, `_after_fight`,
  `_after_burning`. `Feud.settle` and `summer_events` honour `no_silver`.
  `JourneyBot._strandhogg` (the Viking and the berserk go for cattle when
  the stores run low, once a place a summer), `_strandhogg_choice`,
  `_mercy` (let them out; a berserk under `bot_nithing_honor` 15 lets none
  out); the wing word is the campaign's sensible one.
- View: `Hud._show_wings`, `_label_withdraw`, the sector in the strip, the
  result's line for a strandhogg and a sector; `BattleView._admit_new`
  (tokens for men who arrive), `_draw_battles_2`, `_draw_herd`,
  `_draw_sector`, `_draw_banner`; `Main._battles_2_fight` (tools'
  scenario names), `_men_bounds` keeps the boats in view.
- Rules: `CombatRules` "Battles 2", `CampaignRules` "Battles 2"
  (`strand_herders`, `strand_greed`, `hall_help_*`, `wing_third_band`),
  `WorldRules` "Battles 2" (`strandhogg_food_per_head`, `none_out_*`,
  `enemy_none_out_chance`, `bot_nithing_honor`).
- Tools: `tools/diag_wings.gd [n] [seed] [temper] [enemy_wings] [log|-]
  [attack|defend|both] [rows]`, `tools/diag_battles_2.gd [n] [seed]
  [strand|sector|all]`, two rows added to `tools/diag_saga_fights.gd`
  (`fire_bar_help`, `fire_bar_even_help`); `tools/screenshot.gd` scenario
  names `wings`, `strandhogg`, `sector`, `sector_shore`, `fire_bar`;
  `tools/screenshot_game.gd` commands `wings`, `strand:<place>`,
  `strandnow:<place>`, `mercy`, `hafrsfjord[:against]`.
- Tests: `tests/test_battles_2.gd` (18).

## Measured

### Ordinary fights, before and after (byte-identical)

| tool | before | after |
|---|---|---|
| `diag_mixed -- 40 1` | TOTAL 40 fights, 13 wins (32%) | the same, every line |
| `diag_identity -- 20 1` | ALL 1946475587 | ALL 1946475587 |
| `diag_escape -- 30` | tutorial 30/30, skip 30/30, nothing 0/30, charge 27/30 | identical file |
| `diag_first_fight` | (11 rows) | identical file |

### Named lieutenants (`diag_wings -- 80 1 plain 0 - <stance>`)

Twelve green men (8 shields, 2 spears, 2 bows) against as many on the
varied open field, leader AI against leader AI, our two named men (the
steadiest shield or spear men, plain temper) given one word each.
"attack": ours aggressive, theirs as drawn; "both": both aggressive (the
even fight); "defend": ours steady, theirs aggressive. Win rate of 80:

| word | attack | both (even) | defend |
|---|---|---|---|
| no wings | 24% | 45% | 71% |
| named, no word | 24% | 45% | 71% (the same fights, blow for blow) |
| hold the line | 28% | 50% | 73% |
| press when they waver | 25% | 40% | 68% |
| fall back on me | 24% | 51% | 75% |
| go round their flank | 19% | 36% | 54% |
| guard the archers (before the last tuning) | 25% | 41% | 63% |
| chosen (`Wing.sensible_word`: hold attacking, fall back otherwise) | 28% | 50% | 75% |

The chosen word lifts the win rate by 4 to 5 points (visible, not
decisive, and about one standard error at 80 fights); the wrong word
costs up to 17 (going round their flank defending). Named men fall in
about two fights in three (66-123 of 160 wings). History of the tuning:
moving the lieutenant to his wing's middle alone moved the defence 80% ->
60%, so wings are now formed where the men stand; a wing that left the
wall to go round or guard was driven by the push, so going round needs an
overlap and guarding waits for a threat; the named man's steadying (+1 a
round to `wing_heart_cap` 8) and the press's dread were added.

### The strandhogg (`diag_battles_2 -- 30 1 strand`)

Green bands against a farmstead's district (two herders, five parties of
2-6 green men), the leader AI's greed the share of the 12 head it waits for:

| band | greed | got away | head a raid | men down or run | dead | rounds |
|---|---|---|---|---|---|---|
| 3 | any | 29/30 | 2.4 | 0.10 | 0.00 | 9.3 |
| 5 | 0.3 | 29/30 | 5.4 | 0.17 | 0.03 | 10.4 |
| 5 | 0.6 | 29/30 | 9.2 | 0.30 | 0.00 | 14.2 |
| 5 | 1.0 | 28/30 | 9.8 | 0.53 | 0.00 | 15.6 |
| 8 | 0.3 | 30/30 | 8.8 | 0.17 | 0.03 | 10.8 |
| 8 | 0.6 | 30/30 | 10.5 | 0.47 | 0.07 | 13.1 |
| 8 | 1.0 | 29/30 | 11.3 | 0.43 | 0.10 | 14.8 |
| 12 | 0.3 | 30/30 | 9.8 | 0.43 | 0.03 | 10.3 |
| 12 | 0.6 | 30/30 | 11.3 | 0.73 | 0.10 | 12.6 |
| 12 | 1.0 | 29/30 | 11.1 | 0.90 | 0.03 | 12.7 |

Small bands can do it (three men bring home two or three head); greed
brings more of the herd and costs more men (twice as many down at 12 men
from greed 0.3 to 1.0). It stays the safe raid it was meant to be: a
band is routed about one time in thirty. (With the district forming its
wall and its parties coming every third round, the first version lost
nobody ever; the district now runs at the raiders and its parties grow.)

### The great battle's sector (`diag_battles_2 -- 30 1 sector`)

Twelve blooded men against twelve, ours coming on, by the line's lean:

| ground | edge | day ours / theirs | band's part held | neighbours broke / won |
|---|---|---|---|---|
| deck | 0.3 | 3 / 27 | 3 | 48 / 7 |
| deck | 0.5 | 6 / 24 | 3 | 30 / 17 |
| deck | 0.7 | 18 / 12 | 10 | 13 / 37 |
| shore | 0.3 | 5 / 25 | 11 | 49 / 8 |
| shore | 0.5 | 10 / 20 | 12 | 32 / 22 |
| shore | 0.7 | 23 / 7 | 17 | 9 / 44 |

The kings' strength decides most days; the band's own part moves it (on
the decks the band boards and seldom clears her, so the day leans
against it at even strength). At Hafrsfjord Harald's `edge` from the
world's factions is what it is in that saga.

### Barring the door (`diag_saga_fights -- 40 1`, ours / theirs of 40)

| fight | before | after |
|---|---|---|
| fire in the night, bar, 9 green against 10 veterans | 0 / 40, our leader down 40 | 2 / 38, our leader down 29 |
| fire in the night, bar, 9 against 9 green | 30 / 10, our leader down 16 | 20 / 20, our leader down 5 |
| bar, against the veterans, a friendly house's 6 men coming (new) | | 2 / 38, our leader down 27 |
| bar, 9 against 9, a friendly house's 6 men coming (new) | | 16 / 24 |
| fire in the night, meet, both rows | 36 / 4, 40 / 0 | unchanged |

Every other row (the raid, the decks, spears in the snow, the burning,
the break-out) is unchanged, line for line.

### The stand-in players and the save

`batch_ways -- 6 4 1 all burned_hall`: no STALL, stalls 0 for every bent
(Viking +196 oz a year, 2.8 deaths a saga; Trader +74; Law-wise +55;
Berserk +108; Skald +69; King's man +86), no script error.
`save_check -- 2 all viking,kings_man battle,all 1`: "21 OK, 0 DIFF, 3
never came to the point" (the freedman's sagas did not reach a battle).
No new `static var`.

Suite: `619 tests, 0 failed`, no script error (`tests/test_battles_2.gd`: 18 tests; no existing test changed).


## Screens

`docs/design/notes/battles-2-shots/` at 844 x 390, looked at: the named
men's sheet (prototype and in the saga), the pennants on the field, the
strandhogg's offer on the map, its start and mid-fight, the sector on the
decks (start, mid) and ashore, Hafrsfjord from the saga (the sheet, mid),
the barred hall (start, mid), the "Before the fire" choice.

## Open

- The words' lift in AI-against-AI play is small: the best word is +3 to +6
  points over no word, inside two standard errors at 80 fights a row; the
  badly chosen words (round the flank in an even fight, guard the archers
  defending) cost more than the good ones gain. In an even fight a wing
  that leaves the wall splits the push group and is driven; going round
  pays only when the band's line overlaps theirs. The named men are front
  rank men and fall in about two fights in three.
- Barring the door against a stronger party still loses the hall in AI
  play (2 of 40 nights held, was 0); it now keeps the leader on his feet
  more often (down 29 of 40, was 40) for the break-out that follows.
  Between equal bands barring is a coin (20/20; was 30/10 in the old
  yard). The friendly house's men make no measurable difference to the
  leader AI, which only holds its doors; a player who sallies when they
  come is not modelled by the AI.
- The strandhogg's boats lie on the bottom row, which the shout row half
  covers on a phone; "To the boats" says where they are.
- The sector's flank arrivals are drawn men (not the neighbour's own); a
  neighbour's state never comes back from broken or won.
- `Raiding.strandhogg` is no longer called by the journey; its test stays.
- The enemy burning the band's hall decides by a roll on the feud's level,
  not by the house's character.
