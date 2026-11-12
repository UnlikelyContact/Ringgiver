# The burned hall: the opening as the tutorial (12 Nov 2026)

Branch `tutorial`. The concept's "The burned hall: your family's land is
seized by a jarl loyal to Harald; you flee at night with two men, and the
escape is the first fight" is now played, and it teaches the battle. The
first days on the map are guided by a queue of hints.

## The opening as the player meets it

1. **Title.** "Begin a saga" (the main button), and under it two smaller
   ones: "Another beginning" (the younger son and the freedman, on the
   old origins screen, now without the burned hall) and "A single fight"
   (the skirmish prototype, unchanged).
2. **Name.** "Your name, son of the hall at Hardanger:" with the name box
   (Egil by default, 14 letters), Go on, Back.
3. **The night, three cards** (`Origins.DEFS[burned_hall].night`), each
   with Go on:
   - "Your father's hall at Hardanger. Late in the night the dogs wake you, and there are men in the yard: the jarl's men, who hold this land for Harald now."
   - "They have barred the great door and put fire to the thatch. Your father is dead in the smoke behind you. The roof will not stand long."
   - "Two men will not leave you. The byre door at the end of the hall is not barred. Beyond the yard and the ring of the jarl's men is the dark of the trees, and kin in Sogn."
   The last card's button is "Out into the yard". A player who has been
   through the escape before (remembered in `user://ringgiver.cfg`,
   `[tutorial] escape_done`, which the web build keeps in IndexedDB) also
   gets "Let the saga tell it": the escape is resolved by the dice and its
   aftermath read out on a card ("You got out"), then the map.
4. **The escape**, on the battle screen, at night, taught (below).
5. **The result panel** ("You got out", how, the counts, the aftermath:
   wounds, deaths, deeds, and how he came to Sogn), Go on to the map.
6. **The map** at the Sogn farms, with whoever lived, ten ounces, no ship,
   at feud with the house at Hardanger. Harald's vow and the burners'
   wergild demand come first as before; then the hints.

The other two origins skip the escape and go straight to the map, with
the same hints (the first one names their own start).

## The escape (sim)

`Scenario.build_escape(seed, rules, bands := {})`: a 13 x 12 field
(`escape_width`, `escape_height`). The hall burns along the bottom three
rows (BUILDING, seven wide) with its DOOR in the middle of the front wall;
the leader and his men stand in a line just outside it, facing up. The
tree line is the top row (TREE), with trees at the corners of the next row
and four more down the sides of the yard from the seed. The escape's cells
(`Objective.place_escape`) are the passable hexes of row 1: the edge of
the dark. The ring of the jarl's men (`escape_enemy_shields` 6 +
`escape_enemy_spears` 2, green) stands `escape_ring_distance` (3) rows off:
the thin place straight ahead of the door (two men with an empty hex
between them, returned as `gap`), two more either side along the same
row, two a row nearer at the flanks, two beside the hall's ends; their
leader stands by the hall's right end watching it burn, so their wall has
to gather before it can come on. They are taken by surprise for
`escape_surprise_rounds` (3: no order from their leader; reckless men
still run at you) and fight AGGRESSIVE. Your sworn leader is in
`Battle.spared`. `Campaign.build_escape()` makes the fight from the
band's men, the burners with ids from `ENEMY_FIRST_ID`, seeded from the
campaign's own fork.

`Objective.Kind.ESCAPE` (appended; `Objective.DRAWN_KINDS` = 3 keeps a
varied field's draw exactly as it was). No clock. `check` ends the fight
the round the sworn leader stands on the dark's edge, or has fled off the
field, or is down ("his men drag him off into the dark" if any of his
stand, else "left for dead in the yard"), or all his men are broken. Each
of those ends as `BattleResult.End.ESCAPE` with the burners as `winner`;
`Outcome.ESCAPED` ("got away", title "You got out") for the band,
`WON_THE_FIELD` for the burners, `escaped(side)`. Both enums are only
appended to (End.ESCAPE = 7, Outcome.ESCAPED = 8; a test pins the old
values). Any other end in an escape (the burners draw off, the light
fails, nobody closes) is also turned into an ESCAPE in `Battle._finish`;
only routing the burners stays a rout.

Small rules in `battle.gd`, all inert outside the escape:

- `spared`: a downed man in it is not rolled for: "will live".
- `escaping(side)`: the escaping wall does not wheel toward the enemy
  under Push, and slants toward the dark, not the nearest enemy.
- Fall back while escaping turns the wall about first if it faces the
  dark (`_turn_to_pursuers`: every man of the wall, "shields to the men
  coming after"), so the step back is the step out.
- `can_withdraw` asks `Objective.allows_withdraw`: the escaping band may
  slip away only when no standing man of the burners is nearer the dark
  than its leader (`way_open`), and out of contact as always; `withdraw`
  then ends as ESCAPE ("slip away into the dark").
- `_objective_nudge` does not hold the burners back.
- `sworn_leader(side)`.

`Objective.escape_order(battle, side)`: the careful way out (wall on the
first round, push until the way is open, then fall back), used by
`Journey.skip_escape` and matching what the tutorial teaches.

The aftermath is the normal one. `Campaign.conclude_fight` takes the
escape's dictionary (`escape` true, null offer): Aftermath (wounds, deaths,
deeds, growth, bonds), no luck, fame or plunder either way (the saga
begins here, it is not judged by it). `Journey.begin(seed, origin, name,
escape := false)`: with `escape` and an origin that has one, the fight
waits in `fight` (kind "escape") before the first spring, and nothing else
can be done until it is fought; `fight_done` runs the aftermath and
`_after_escape`: how he came to Sogn (on his feet, or "remembers nothing
after the blow" when he was carried), the chronicle's first line ("got out
of his father's burning hall at the Hardanger farms with 2 men"), and a
man lent by the kin when both of his are dead. The feud and `vengeance`
are set by `begin` as before (the house at Hardanger, by its existing
string key). Without `escape` the burned hall begins as it did (told), so
the stand-in players and `batch_ways` are unchanged.

Also new on the map, because the hints needed it: "Rest and mend"
(`Journey.actions` id `rest`) at any farm, hall or town while a man has
healing to do: `rest_days` (6, WorldRules) pass and every man mends a
turn. Before this, wounds mended only before a fight and in winter.

`Aftermath.lines` says "carried off the field", not "carried to the ship"
(it was wrong on land, and the escape made it obvious).

## The director (view/tutorial.gd)

`Tutorial` (a Node on the HUD) reads only the Battle and the shout waiting
to be given, so its logic runs headless (`start`, `evaluate`, `control`,
`allowed`, `text`, `acknowledge`, `after_round`). The HUD registers its
controls by name (`hud.controls`: `shout:<n>`, `next`, `withdraw`, `form`,
...) and refuses any not in `hud.allowed` while that is not empty. The
director is made when `main.teach` is set (game.gd sets it for the escape)
and the battle's objective is ESCAPE.

Steps, one sentence each; the control it pulses; whether the others are
shut:

| # | Step | Banner | Control | Others |
|---|---|---|---|---|
| 0 | WHO | The red shields are you and your two men, the blue are the jarl's men round the yard, and the line at the top counts the men standing in each wall. | Go on (in the banner) | shut |
| 1 | WALL | Three men shoulder to shoulder are worth more than three apart: press Shield Wall, then Next round. | Shield Wall!, then Next round | shut |
| 2 | PUSH | Their ring is thin straight ahead, two men with a gap between them: press Push, then Next round. / then: Press Next round, and again: your wall goes on pushing until it is through their ring. | Push!, then Next round | shut |
| 3 | HURT | Atli is hurt: the red marks by a man's shield are his wounds, and he takes them with him out of this fight. (yours: You are hurt: the red marks by your shield are your wounds, and you take them with you out of this fight.) | Go on | open |
| 4 | FALL_BACK | You are through, and they are closing behind you: press Fall Back, then Next round, and your men give ground toward the trees with their shields to them. / then: Press Next round, and again: the wall gives ground a step at a time. | Fall Back!, then Next round | open |
| 5 | WITHDRAW | None of them is at arm's length and the way is open: press Withdraw, for leaving a fight is a choice and not a defeat. / while in contact: They are still at arm's length: press Next round and keep falling back. | Withdraw (or Next round) | open |
| 6 | OUT | (banner hidden; the result panel) | | |

What each step did, shown dim above the next instruction: after the wall
"Your men close up at your shoulders: each shield now guards the man
beside it."; the first round the lines push "In the push the line with
more shields together, and more heart, drives the other back a step.";
after the first fall back "A wall that gives ground in order is still a
wall, and they cannot get round it."

Transitions: WHO on Go on; WALL once a round has been fought under Shield
Wall; PUSH once a round has been fought under Push and the way is open
(`Objective.way_open`), or after `PUSH_ROUNDS_MAX` (6) rounds of pushing;
HURT comes between rounds the first time one of yours has a wound, during
PUSH, FALL_BACK or WITHDRAW, and goes back where it was on Go on (or on
the next round if the player plays on); FALL_BACK once a round has been
fought under Fall Back; WITHDRAW until the fight is over (by Withdraw, or
the leader reaching the dark, or anything else). The leader's fall ends it
too: the result panel says how.

On the screen: the banner (dark plate, gold hairline, 60% wide) stands
under the top bar when the control is in the shout row, and over the
shout row when the control is up in the top bar (Withdraw); it tells
`main` its height (`top_extra` / `bottom_extra`) and the camera keeps
every man clear of it. The control gets a pulsing gold double outline.
For this first fight the untaught top-bar controls (Advance, Wheel L,
Wheel R, the pulse slider) are hidden; Form and Follow stay, shut while
the first steps are.

The night: `BattleView.is_night` (the escape) lays a dark wash over the
ground (the men, drawn above it, stay bright to read), flames on every
hex of the hall, a glow round it and embers going up; it redraws each
frame for the flicker. The camera takes in the hall's front behind the
men.

Touch targets on the battle screen are larger for every fight: the shout
row and Next round 62 design pixels (about 45 px on a 844 x 390 phone),
the top bar 44 (32 px); `main.HUD_TOP`/`HUD_BOTTOM` follow.

## The hints (view/hints.gd)

`Hints` (RefCounted, one per saga, kept by game.gd) holds what has been
seen; `attach(map)` puts a card at the map's top left (never over the side
panel), a "?" button by the side panel, and a half-second timer on each
new MapScreen. One hook in `map_screen.gd` (`setup`, two lines). A hint
shows when it is due and the previous one is dismissed (Go on); the card
hides while a choice or a side panel is open and comes back after. "?"
lists what has been learned. Seen hints live with the saga; there is no
saving yet, so "once per saga" is once per session's saga.

| id | due when | text |
|---|---|---|
| where | at once | You are at the Sogn farms, where your father's kin have taken you in: here your saga begins. (younger son: by your brother's door; freedman: where you were a thrall until Yule ... free) |
| walk | after where | Tap the map to walk there: the days pass as you go, and stop when you stop. |
| actions | at a place, free to act | What a place offers is on the right: each deed there costs days, and some cost silver. |
| rest | Rest and mend is offered | Your men are hurt: Rest and mend, under a roof, lets the wounds heal before the next fight. |
| ways | a point to spend | You have a point to spend: Your ways shows the paths a man may take, raider, trader, law-wise man and more, and any one or any mixture of them is open to you. |
| ship | no ship, after walk | You have no ship: a faering costs 15 oz at a hall or a town, and until then you can buy passage on another man's. |
| parties | a party in sight, or a fight offered | Others are abroad on the map, merchants, raiders and outlaws, and when they come at you, you may fade away rather than fight. |
| winter | 60 days of summer left | The summer is short: when its days run out the band must winter under a roof, and a guest pays 1 oz a man. |

## Tools

`tools/screenshot_game.gd`: `what` = `begin` (name), `night:<n>`,
`escape` (taught), `skip` (told); on the escape: `tut:<n>` (do what the
tutorial asks n times), `tutto:<step>` (until that step), `hurt`, `leave`;
then on the map `map` (from the told card), `hintok`, `learned`,
`seen:<ids>`, `answer:`, `act:`, `days:`, `go:`, `invest:`, `ways`. Tools
set `game.use_config = false`, and the still is taken after the camera is
snapped to where it settles. Example:
`... -s tools/screenshot_game.gd -- /tmp/s4.png escape 5 tutto:4`.

## Measured

`tests/test_escape.gd` (15 tests). Escapes from the campaign's own
burned-hall band, `Journey.begin(seed, "burned_hall", "Egil", true)`:

| player | seeds | leader carried off | men dead | mean rounds |
|---|---|---|---|---|
| follows the tutorial | 10 | 0 | 0 | 9.5 |
| follows the tutorial | 30 | 1 | 2 | 9.5 |
| skips (the dice) | 10 | 0 | 0 | 8.5 |
| skips | 30 | 2 | 0 | 8.1 |
| does nothing | 30 | 21 | 4 | 13.6 |
| charges (Break them!) | 30 | 17 | 3 | 11.5 |

The leader never dies (30 seeds each for doing nothing and charging, in
the tests); the saga always goes on with at least one man. Battle balance
outside the escape: `tools/diag_mixed.gd` before and after, see the
report; every escape rule is behind `escaping` / `spared` / the ESCAPE
kind.

Screenshots of every step and hint at 844 x 390 were looked at; fixed on
the way: the banner was first a column of letters (an autowrap label
before its width settled), then stood over the men (the camera now keeps
clear of it), then kept its old height (it shrinks again over three
frames); the fire behind the shout row; the top bar overflowed off the
right of a phone (the untaught controls are hidden in the escape).

## Open

- The escape is easy when followed (a first fight should be), and the
  wound step does not come in about half the escapes, when nobody of
  yours is hurt; how to read a man's state is then only in step 0's "the
  line at the top".
- "To me", Hold, Break them and Taunt are not taught; they are left for
  the next fights. Advance and the wheel are hidden in the escape only.
- The aftermath line "X is now blooded" for every man after the escape
  is the growth rules' (one fight survived), and clutters the first
  result panel.
- Seen hints are not saved with a saga (there is no saving yet).
- The escape's enemies are named from the prototype's name list
  ("Kveldulf the leader"); the families agent's houses could name the
  jarl's man and his men.
- The skip is offered only to a player the config says has been through
  it; there is no skip inside the fight.
