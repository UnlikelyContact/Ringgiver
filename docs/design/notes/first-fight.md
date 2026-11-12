# The first fight, made robust to real players (first-fight)

Branch `first-fight`. The burned hall's escape (docs/design/notes/tutorial.md)
is the first ten minutes of every saga begun as the burned hall. On the live
build a slightly sloppy first-timer (Go on, Shield Wall, Next round, Push, six
Next rounds, then Fall Back, Next round, Withdraw, over and over) was at round
13 no nearer the dark than at round 0, his wall broken, the status line saying
"Egil freezes behind his shield (nobody stands with you)" and the banner still
saying "They are still at arm's length: press Next round and keep falling
back". This branch measures how real players play it, bends the fight (the
escape only) so that doing roughly the right thing works, makes the director
read the field instead of following a script, teaches the rest of the battle in
the saga's later fights, and cleans up the first result panel.

## Measured: stand-in first-timers, before and after

`tests/escape_players.gd` holds the stand-in players; `tools/diag_first_fight.gd
-- 50` plays each over seeds 1-50 of `Journey.begin(seed, "burned_hall", "Egil",
true)` (the campaign's own band and ring). Every model presses the battle
screen's controls the way the HUD lets a thumb press them: a control the
tutorial has shut, or Withdraw while disabled, does nothing; a shout toggles the
one waiting; Next round fights the round with it; a tap on the board does what
`BattleView._tap` does.

The models: **exact** presses what the banner asks; **late** presses the asked
shout a round late (a Next round first: model a); **early** a round early (Fall
Back while asked to push, Withdraw while asked to fall back: model a);
**observed** is the live playtest's sequence above; **next_only** presses Next
round and nothing it is not made to press (b); **back_after_push** presses Fall
Back after every round under Push (c); **taps** follows the banner and taps the
board at random between rounds, half the time (d); **push_only** never falls
back (e); **withdraw** presses Withdraw whenever it is enabled (f); **random**
random presses among the controls that answer (g); **nothing** gives no order
at all (the sim alone).

Columns: out on his feet (got away, leader not down; a leader rescued with a
bruise counts as on his feet); carried off (leader down); mean and worst
rounds; idle = rounds per fight that brought the leader no nearer the dark; men
lost = of his two, down, broken or fled at the end; dead = of his two, dead
after the aftermath; bad banner = rounds per fight where the banner said the
same words as before a round that was played as it asked (its control was Next
round) and came to nothing; impossible = presses the banner asked for that the
HUD would not take (shut, disabled, or a tap with nothing marked).

Before (`main` at 3051324, the same harness):

| model | out | carried | rounds | worst | idle | men lost | dead | bad banner (fights) | impossible |
|---|---|---|---|---|---|---|---|---|---|
| exact | 88% | 12% | 11.4 | 20 | 6.6 | 0.64 | 0.12 | 4.3 (50) | 0 |
| late (a) | 82% | 18% | 11.6 | 20 | 6.6 | 0.54 | 0.10 | 4.0 (50) | 0 |
| early (a) | 88% | 12% | 11.2 | 20 | 6.5 | 0.62 | 0.12 | 4.3 (50) | 0 |
| observed | 86% | 14% | 12.1 | 20 | 7.0 | 0.68 | 0.10 | 3.3 (48) | 0 |
| next_only (b) | 44% | 56% | 14.5 | 21 | 9.1 | 0.88 | 0.12 | 3.3 (50) | 0 |
| back_after_push (c) | 88% | 12% | 11.4 | 20 | 6.6 | 0.64 | 0.12 | 4.3 (50) | 0 |
| taps (d) | 48% | 52% | 12.5 | 23 | 7.5 | 1.16 | 0.14 | 5.2 (48) | 0 |
| push_only (e) | 44% | 56% | 14.5 | 21 | 9.1 | 0.88 | 0.12 | 3.3 (50) | 0 |
| withdraw (f) | 88% | 12% | 11.2 | 20 | 6.5 | 0.62 | 0.12 | 4.3 (50) | 0 |
| random (g) | 24% | 76% | 14.0 | 26 | 9.2 | 1.28 | 0.18 | 4.3 (49) | 0 |
| nothing | 10% | 90% | 15.3 | 27 | 14.9 | 1.26 | 0.16 | - | - |

After (this branch):

| model | out | carried | rounds | worst | idle | men lost | dead | bad banner (fights) | impossible | rescued | told at the cap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| exact | 100% | 0% | 6.0 | 10 | 2.6 | 0.04 | 0.02 | 0 (0) | 0 | 0 | 0 |
| late (a) | 100% | 0% | 6.3 | 12 | 2.7 | 0.06 | 0.02 | 0 (0) | 0 | 0 | 0 |
| early (a) | 100% | 0% | 5.5 | 8 | 2.0 | 0.02 | 0.00 | 0 (0) | 0 | 0 | 0 |
| observed | 100% | 0% | 9.0 | 11 | 2.9 | 0.12 | 0.04 | 0 (0) | 0 | 1 | 0 |
| next_only (b) | 100% | 0% | 9.7 | 14 | 2.8 | 0.18 | 0.06 | 0 (0) | 0 | 1 | 0 |
| back_after_push (c) | 100% | 0% | 5.1 | 8 | 1.9 | 0.04 | 0.00 | 0 (0) | 0 | 0 | 0 |
| taps (d) | 92% | 8% | 8.4 | 15 | 4.2 | 0.14 | 0.02 | 0.1 (4) | 0 | 13 | 0 |
| push_only (e) | 100% | 0% | 6.7 | 10 | 2.7 | 0.16 | 0.08 | 0 (0) | 0 | 0 | 0 |
| withdraw (f) | 100% | 0% | 6.0 | 10 | 2.6 | 0.04 | 0.02 | 0 (0) | 0 | 0 | 0 |
| random (g) | 88% | 12% | 10.2 | 16 | 6.4 | 0.52 | 0.06 | 0 (0) | 0 | 26 | 1 |
| nothing | 2% | 98% | 14.9 | 16 | 14.9 | 1.16 | 0.16 | - | - | 0 | 0 |

The leader died in none of the 1100 escapes, before or after. Notes on reading
it: "before", the old director shut every control but the one it asked for
through the push, so late, early and back-after-push could not do what they
wanted and play as exact; "out" before also counts a leader who wavered and ran
for the dark alone after twenty rounds (the live playtest's seed 13 of this set
ends so). The four "bad banner" fights left for taps are the banner's honest
"Next round: push on past the end of their ring" after a round in which the
stand-in's own tap took its man sideways.

Targets from the brief: sloppy models (a)-(d), (f) out on their feet 80%+ (all
92-100%), never more than about 16 rounds (worst 15), zero rounds where the
banner asks for what cannot be done (0 impossible; 0 bad for every model that
does what it is asked), exact 90%+ (100%), doing nothing still fails (carried
off 98%).

## What changed in the fight, and why (escape only)

Everything here is behind `Objective.first_fight`, set by
`Scenario.build_escape` only when the leader is spared (the saga's first
night). The saga's later break-out from a burning hall (`build_breakout`, spare
false) and the burning of another's hall keep the ordinary rules (a test pins
it). Tunables are `CombatRules.escape_*`:

- **The band holds together.** No man of the escaping band freezes behind his
  shield, wavers and turns to run when the wall falls back, or breaks
  (`Decision.choose` step 3 and the FALL_BACK wavering, `Battle._plan_wall`'s
  "nerve goes as the wall falls back", `Morale.round_update`'s new `keep`
  argument, filled by `Battle._unbreakable`). A man of it apart from his
  leader with nobody at arm's length goes to him, and none weighs charging,
  stepping out, looting, going for a hurt man or making for the objective on
  his own (`Decision.TOGETHER_OPTS`). The live "Egil freezes behind his
  shield" and "the line wavers: Egil turns to run" came from these rules
  applied to three green men; here the leader is running for his life, and his
  two men stay with him or die.
- **The wall moves as one** (its hearing test is 1 here: "Egil's line hesitates
  (75% to move as one)" three rounds running was a large part of the stalled
  pushes), and does not stop to trade blows with a man at its flank: under Push
  it goes on wherever the ground ahead is free. The ring's leader standing at
  the hall's end used to pin the wall by touching its end man.
- **The thin place gives** (`Battle._first_fight_give_way`). Once the band has
  fought `escape_give_rounds` (3) rounds under a driving order (Push, Break
  them), every burner standing nearer the dark than its leader and within
  `escape_give_radius` (3) of him gives way: he breaks and runs off the field
  ("the ring gives way before the push: Skalla and Bard run off into the
  night"). It holds from then on, so a man who steps into the path later gives
  too. They leave the field at once rather than flee up the very ground the band
  must cross. The banner counts it down ("The thin place gives after 2 more"),
  which is true because the rule is.
- **The saga's rescue** (`Battle._first_fight_end`, `_first_fight_rescue`). A
  leader cut off (an enemy at arm's length and none of his men beside him)
  `escape_rescue_rounds` (3) rounds running, or no nearer the dark for
  `escape_stall_rounds` (5) rounds once the thin place has given, is dragged
  out through the smoke by the nearest of his men standing ("Alf drags Egil out
  through the smoke"): the man is hurt (`escape_rescue_wound`, WOUNDED) and so
  is he (`escape_rescued_wound`, BRUISED). With none standing he breaks away
  alone, hurt the worse. `Objective.how_out` = "rescued".
- **The night has an end.** At `escape_round_cap` (16) the escape is told ("the
  smoke thickens and the dark covers them: Egil gets away into the night",
  `how_out` "told"). A band that never gave an order gets no rescue and no
  telling: at the cap its leader is struck down and carried off (or left for
  dead), as before.
- The flankers still come up from the yard's corners; they now punish dawdling
  by arriving (contact, wounds), not by making the exit impossible.
- Withdraw is unchanged (out of contact and the way open); the director points
  at it the moment it would work.

Ordinary battles are byte-identical: `tools/diag_mixed.gd -- 40 1` gives the
same output on `main` and on this branch (TOTAL 40 fights, 13 wins), and
`tools/diag_identity.gd -- 20 1` gives the same hashes for mixed, hold, ambush
and ambushed; only its "escape" line changes (2931437111 to 1252941125, by
design: that line plays `build_escape`, which is now the first fight).

## The director (view/tutorial.gd)

`Tutorial.advise(battle, memory)` is a pure function of the field and a little
memory (who-is-who read, the shout waiting, a tap waiting, the banner before the
last round and whether that round brought the leader nearer the dark, whether
To Me was tried); it returns {step, control, text, point, goal}. The Node wraps
it: `start`, `evaluate`, `control`, `allowed`, `text`, `acknowledge`,
`after_round`, `on_tap`, with `point` (the man or hex ringed on the board) and
`goal` (the dark pulses). The rules, in order:

1. Over: nothing (the result panel). Leader down: "You are down. Your men are
   carrying you out." (nothing to press).
2. Round 0, not yet read: who is who, with the gold edge named ("The gold edge
   at the top is the dark of the trees: get there."), Go on, and **Skip the
   fight**; the dark pulses and an arrow runs to it from your man. Only Go on
   and Skip answer.
3. Round 0: "First close up: press Shield Wall, then Next round." Only the wall
   (and Next round once it waits) answer.
4. Withdraw would work: "None of them is at arm's length and the way is open:
   press Withdraw. Leaving a fight is a choice, not a defeat." Withdraw pulses
   (the banner moves to the bottom, clear of it).
5. A man alone (two hexes or more from you, none of yours at his shoulder,
   none of theirs at arm's length) while the ring is still between you and the
   dark: "Alf is apart from you: press To Me, then Next round, and your men close
   on you." He is ringed. Said once; if he is still apart after it, the next
   rule speaks. Once the way is open he comes after you on his own, and To Me
   is not asked.
6. The way open (none of them nearer the dark): "You are through. Now fall back
   toward the dark: press Fall Back, then Next round.", then "Next round: the
   wall gives ground toward the dark, shields to the men behind." The dark
   pulses gold with the arrow. If a round of that came to nothing, the hex
   beside you nearer the dark is ringed instead: "The wall is held up: tap the
   marked hex, nearer the dark, to step there, then Next round."
7. One of them between you and the dark: the nearest is ringed; "They stand
   between you and the dark, the marked man nearest: press Push, then Next
   round, and drive through the thin place." Until the first push is fought
   only Push (and Next round) answer. Then the countdown, "Next round: keep
   pushing. The thin place gives after N more.", "One more shove and the thin
   place gives."; after it, a man still in reach "The marked man still stands
   in your way: Next round, and the push carries you past him.", or, when only
   the ends of their ring are ahead, "Next round: push on past the end of their
   ring, toward the dark." (the dark pulses). A round of pushing that came to
   nothing is not met with the same words: a man at arm's length is to be
   tapped ("tap him to strike him yourself"), else the hex nearer the dark.
   A player falling back while they are still between: "Not yet: they are still
   between you and the dark. Press Push, then Next round."
8. A tap waiting says truly what it will do: a step toward the dark, a blow at
   the man marked, or a step aside ("Tap yourself to go with the line again").

Above the instruction, dim, what the last round did: the wall closing up, the
first push, the thin place giving, the first fall back, To Me, and the first
wound (the old blocking "hurt" step is now this line). The banner never names a
control that is shut or disabled; after the first push every control answers.

On the board (`BattleView.guide_cell`, `guide_goal`, `_draw_guide`): a pulsing
gold double ring round the man or hex meant; when the dark is where to go, its
row pulses from bone to gold and a gold arrow runs from your man to the nearest
hex of it (straight up the field when two are as near). In the strip, "The
dark: N away" warms from grey to gold as N falls. `BattleView.tapped` tells the
director of a tap.

**Skip the fight**: under Go on in the first banner, and in the settings gear
during this fight only (`hud._open_settings`). It resolves by
`Journey.skip_escape` from wherever the fight stands, remembers the escape as
done, and shows the first fight's result panel.

## The first result panel

`hud._first_fight_result`: the title ("You got out"); on parchment, how he got
out ("Egil came out through their ring and into the dark.", "Alf drags Egil out
through the smoke.", "The smoke thickened and the dark covered them, and Egil
got away.", "Egil went down in the yard, and his men carried him out into the
dark.") and the journey's line on coming to Sogn; the cost (the aftermath's
wound and death lines, or "Nobody of yours took a wound that will not mend on
the road."); one line on what was learned ("You have learned the wall, the push
and falling back. The other shouts come in later fights; the ? by the gear says
what each does."); Go on to the Sogn farm. No counts table, and none of the
growth rules' "X is now blooded" lines.

## The rest of the battle, taught in later fights

A "?" on every battle screen's top bar (beside the gear) opens "The shouts": one
line for each shout and for Advance, Wheel, Form, Withdraw and Next round (with
tapping), and, in a saga, what the battle hints have taught so far.

`Hints` (view/hints.gd) gains a battle section, additive: `BATTLE_ORDER`,
`battle_text`, `battle_due(id, battle)` (pure, on the Battle), `battle_control`
(the HUD control each names), `next_battle_hint`, `learned_in_battle`. Seen ids
go into the same `seen` dictionary as the map's, with a "b_" prefix (and
"offer"), so the save's handling of `hints.seen` carries them unchanged. The
map's "?" lists them too. `BattleHints` (view/battle_hints.gd, new) puts the
card on the battle screen in the saga's fights after the escape (never in the
escape, never in the skirmish prototype): parchment, Go on, standing in the half
of the screen away from the control it names (over the shout row for a top-bar
control, under the top bar for a shout or the board), that control ringed in
gold, the camera keeping the men clear of it, a running fight paused while it
is up. One at a time, in this order when several are due:

| id | when | names |
|---|---|---|
| b_clock | a fight with an objective clock | the strip |
| b_form | round 0 | Form |
| b_tap | after the first round | the board |
| b_tome | a man of yours three hexes or more from you, nobody at arm's length | To Me |
| b_wheel | a man of your wall with an enemy on his right or rear arc | Wheel L |
| b_hold | the lines not met, they push or charge, within 4 hexes | Hold |
| b_advance | the lines not met, your wall formed, they 3 hexes or more off | Advance |
| b_taunt | the lines not met, they hold or stand in a wall, within taunt range, round 2+ | Taunt |
| b_break | the lines met and a third of their men broken or near it | Break Them |
| b_withdraw | Withdraw open, and fewer of you than of them | Withdraw |
| b_pulse | round 4 | the pace slider |
| offer (map) | the first time a fight offers | a slip at the top of the offer itself |

The fight offer's hint names the choices (take the field, hold ground of your
own, lie in wait, fade away) inside the offer, since the map's card hides while
a choice is open; it is seen once the offer is answered.

## Tests and tools

`tests/test_escape.gd` (25 tests; the new ones add about 6 s): every sloppy
model's bound over 12 seeds (out 11/12 for exact, 10/12 for the rest, worst
round at most the cap, no impossible ask, no stuck lock, no repeat after a round
played as asked, the leader never dies); doing nothing is carried off (9/10);
the thin place gives to a push; a leader cut off is dragged out (both hurt); the
round cap tells the escape (and carries off a band that never gave an order);
only the first fight bends; the director's choice on built states (one between,
a man alone, To Me waiting and tried, withdraw open, the way open with one at
your heels, no repeat after a round that came to nothing, the leader down); the
director's order of teaching; battle hints fire on their conditions, once, never
in the escape. `test_the_ring_holds_but_at_the_thin_place` now leaves out men
who gave way to the push (they run off the field by design).

`tools/diag_first_fight.gd -- [seeds] [models] [verbose seed]` prints the table
or one seed's banner round by round. `tools/screenshot_game.gd` gains, on the
escape: `tut:`/`tutto:` that tap what is marked, `skipfight`, `ref`, `apart`,
`through`, `chaser`, `down`, `rescue`, `cap`, and `ui:<model>:<n>`, which plays
a stand-in through the HUD's own buttons and the board's tap and prints any
press the banner asked for that the HUD would not take (none, for observed,
taps, random, next_only and late on seeds 7 and 11); on the map: `offer`,
`fightnow`, and on that battle `bhint:<id>`.

## Still weak

- It is now easy: the careful player is out in about six rounds, clean. The
  flankers rarely reach a band that pushes at once. That is meant for a first
  fight, but the thrill of the ring closing is mostly gone for a good player.
- The give-way is a rule, not a fight: men nearer the dark simply leave. It is
  told in the log and the banner, but on a phone it reads as tokens vanishing.
- The tapper (model d) is rescued in about a quarter of its fights: tapping
  moves the leader alone, and the stall rule then drags him out with a bruise.
  The banner says what a tap will do, but a first-timer may not read it.
- "Out on his feet" counts a rescued leader (bruised, dragged out). The panel
  tells it honestly, but it is a softer success than walking out.
- The battle hints' conditions are checked on built states and the cards were
  rendered with `bhint:` forcing each; they have not been seen to fire in a long
  natural saga on screen.
- The fight offer's hint lives inside the offer modal; if the map rebuilds the
  modal mid-offer it is put back, but it is not a dismissible card like the
  others.
- The pace slider and the wheel stay hidden in the escape; Advance is not taught
  until a later fight.
