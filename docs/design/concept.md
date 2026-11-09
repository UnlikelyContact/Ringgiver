# Ring-Giver — Concept Doc

**Version 2 — 7 Nov 2026.** Revised from Dylan's v1. What changed and why is in
[`concept-review-v1.md`](concept-review-v1.md). This file is the working design
reference for development; edit it in place as decisions land.

## Overview

Ring-Giver is a historical saga sandbox: you start as a nobody in Viking-age
Norway, gather a small sworn band, and climb toward jarl or king while Harald
Fairhair unifies the country around you. You control only your own character
in battle and lead your men by shouting commands; their experience decides how
well they carry them out.

The working title comes from Old Norse poetry, where a lord is a "ring-giver":
generosity is how you keep men.

**Design pillars**

1. **The band is the game.** Every sworn man is a named individual with
   potential, history, ambitions and bonds. Even in great battles, you fight
   with your own men in your own sector.
2. **Lead, don't command.** You are one man in the shield wall, not a general
   moving pieces. Your voice, your luck and your example hold the line.
3. **A saga, not a campaign.** Play spans generations. Death passes the saga to
   a son or sworn second; feuds, vows and luck carry forward. Like a saga, the
   game skips the quiet years and dwells on the eventful ones.
4. **Historically grounded.** Real law, economy, social order and events. No
   gods walking the earth; belief shows up as omens and luck.
5. **History can be changed.** Real events happen on schedule unless you
   change them.

**Comparables:** Battle Brothers (the band), Fire Emblem (named units,
permadeath, bonds), Mount & Blade (living sandbox), Frozen Synapse
(simultaneous turns with a plan preview), Crusader Kings (dynasty, succession,
and letting years pass), The Last Kingdom (tone and premise).

**Platform and engine:** PC first. Godot 4 with GDScript, built with Claude
Code. Decided; see Tech.

## Setting and historical scope

The game opens in Norway around 860–870, as Harald Fairhair begins conquering
the petty kingdoms, and runs across roughly three generations to the mid-900s.
Dates follow the traditional saga chronology; scholars dispute many exact
years (Hafrsfjord in particular is now often placed in the 880s). The game
commits to the saga dates and says so in its chronicle.

**Regions**

- **Core:** the Norwegian coast and fjords (Vestland, Møre, Trøndelag,
  Hålogaland in the north)
- **Near:** Denmark (Hedeby, Ribe), the Swedish lands (Birka, Uppsala), the
  Baltic (Gotland, amber coast)
- **West:** Orkney, Shetland, the Hebrides, Norse Dublin; Iceland opens from 874
- **East:** river routes through Gardariki (the Rus' lands) toward Miklagard
  (Constantinople)

England stays at the edge of the map. The focus is the Norse world itself.

**Sources to draw on:** Heimskringla (Harald's saga), Egils saga, Njáls saga,
Grettis saga, Kormáks saga (holmgang), Landnámabók, Hávamál, Rígsþula, the
Gulathing and Frostathing laws, and Ohthere's account of the northern trade.

## Core structure

Each in-game year is one saga chapter with two halves: summer for sailing and
war, winter for the hall.

1. **Summer (about April–October):** sail the open map, raid, trade, take
   contracts, fight battles, attend the Thing, follow saga threads. Time
   passes in days as you travel; dated events fire on the calendar.
2. **Winter (four to five turns):** the sea lanes close. Feed and keep your
   men, heal, drill, feast at Yule, make vows, plan the next season.

Battles happen throughout summer and occasionally in winter (hall-burnings,
feud attacks). Years add up to generations; leaders age, die and pass the
saga on.

### Saga pacing: quiet years

Three generations is about a hundred years. Played in full at two or three
hours a year, that is several hundred hours, so the game must do what the
sagas do and skip. At any winter's end the player can **let the years pass**:
summers auto-resolve (land income, aging, births, deaths of old men, faction
moves, rumors) until something demands attention — a feud attack, a summons
from a jarl, a historical event, a son coming of age, a vow falling due. The
chronicle records the skipped years in a line or two. A full campaign is
expected to have ten to twenty played years across the three generations,
with the rest passed over.

### A year in the saga (example)

Spring: the ice breaks. You have nine men, a karve, a vow from Yule to avenge
a cousin, and a rumor that his killer winters near Stad. You sail north,
trade furs at a farmstead, and get caught by the killer's kin on a beach: a
skirmish, two men wounded, one dead. The killer flees to a jarl's hall. You
cannot storm it, so you ride to the Gulathing instead, buy oath-helpers with
arm-ring silver, and win outlawry against him. That costs most of the summer.
A late-season contract escorting a merchant to Kaupang pays for the winter.
Yule: a feast, a new oath-brother for one of your men, and a vow to join
Harald's levy next year because the jarl who sheltered the killer is his
enemy. The year ends with eight men, one of them Blooded for the first time.

## Combat

Combat is turn-based with simultaneous resolution on a hex grid (decided
8 Nov 2026 after the first playtest: six equal neighbours mean a wall can
face any of six ways and still lock, a wedge is a natural shape, and lines
never stagger stepping at an angle; Battle Brothers uses hexes for the
same reasons). You control only your own character; your men act on your shouts, their
experience and their personalities. Enemy bands are led the same way: their
leader shouts, and their men obey him as well as *their* experience allows.

### The turn

1. **Plan:** choose your character's action and one shout.
2. **Muster preview:** the grid shows what each of your men is likely to do in
   response — a clear arrow for a veteran, a shaky or absent one for a green
   man who may not have heard. You can change your action or shout and look
   again. The preview is honest about uncertainty but never lies about intent.
3. **Lock:** orders lock. Each man commits to an action from your shout, his
   experience, personality and morale; the enemy does the same.
4. **Resolve in fixed beats:** movement → missiles → melee → the push →
   morale check.

The preview is what makes the single-character design work: the player's
decision each turn is really "given what I think my men will do, where should
I be and what should I shout?"

### Pulsed turns: real-time on the surface, turns underneath

Decided 7 Nov 2026. The simulation stays simultaneous-turn, but the battle
is presented as real time with a tactical pause:

- The clock advances one round every few seconds unless paused. The pulse
  length is a setting, from "wait for me" (pure turns) to about a second
  (near real time); the prototype will find the default.
- You can shout at any moment; the shout lands on the next pulse, so a late
  shout feels late.
- Pause freezes the clock and brings up the muster preview as an overlay.
- Auto-pause triggers: a man goes down, you are threatened, the enemy
  leader shouts, a flank is turned, the banner falls. All of them can be
  switched off for a faster game.
- Animation carries the feel. The fixed beats of a round (movement,
  missiles, melee, the push, the morale check) play as one continuous
  piece of motion across the pulse: men step, spears go in, the lines heave,
  a man breaks and runs. Nothing waits for a "next turn" button, and no
  resolution is ever shown out of beat order.

What this buys: the sim's legibility and determinism, replays, the preview,
and the push as a dramatic moment, with the pressure and chaos of real
time on the surface.

**First playtest, 8 Nov 2026 (web prototype on a phone):** with every beat
animated at once, the pulse was disorienting; the player could not read
what happened, whether the men were in a wall, or what his own man did.
Decisions taken: the clock is off by default (a "Next round" button, the
pulse as a setting); the beats animate in order (men step, blows land one
at a time, the line heaves, then breaks); locked shields are drawn as bars
between neighbours and the HUD counts "wall 6/8"; the player's own man gets
a preview arrow and a one-line account of his round; and under Shield Wall
or Push the line forms on where the leader is *going*, so stepping forward
takes the wall with you. "Push!" now advances the line as a line.

**Second playtest, same day:** on hexes, a diagonal step turned the leader
and the wall re-formed square to his new facing, throwing the line into
chaos. The wall now has its own facing, separate from the leader's: it
changes only with "Wheel left" and "Wheel right" (one hex facing, 60
degrees, each), a step never turns it, "Push!" advances the wall the way
it faces, and a leader who turned to strike faces his wall again next
round. Enemy leaders wheel only when the player's band is two or more
facings round their flank.

**Third playtest, same day:** men were still stepping ahead of the wall or
lagging behind it, and the wall disintegrated at contact. Decision: the
wall is the unit. Under Push or Fall back the wall (every man connected to
the leader along the row) makes one test and then every man steps the
same way or nobody does; it holds if any part is in contact or any man is
blocked. Men outside the wall rejoin it rather than push ahead. A man who
falls or breaks splits the wall; each piece moves as its own unit until
Shield Wall re-forms it, and the HUD says "the wall is broken: 3 of 6
with you". The only exceptions to moving as one are a man who falls and a
man whose nerve breaks: a broken man leaves the wall and runs, and when a
wall falls back a green or blooded man with little heart left wavers and
runs rather than stepping back with it. An ordered fall back costs no
heart; being driven back by a push does, and driving the enemy back gives
heart. A wall pressed onto the edge of the field, or falling back into it,
has been driven from the field: its men leave and count as fled.

**Fourth playtest, same day (the player kept losing):** the prototype's
"Fight again" never changed the seed, so every fight after a reload was the
same battle with the same dice; a fresh field is now drawn on each load and
each "Fight again". Scripted play across 200 seeds showed where the losses
really came from: stepping the leader ahead by hand lost two fights in
three, because his step bypassed the wall's single test and left him alone
in front. Decision: a tap on the cell ahead, or the Advance button, now
takes the *wall* forward one step under its one test, whatever the standing
order; a man steps alone only when he has no wall. Four sim faults found
the same way: a shoved man went back along his own hex diagonal rather than
square to the line, so two shoves slid a line two cells sideways and the
lines slipped past each other to opposite edges of the field; a pair of
men cut off from the wall marched on as their own "line"; the lull counter
looked back sixty log lines instead of one round, so stalled fights never
ended; and a pushing wall never turned toward an enemy behind it. Now a
shove goes straight back by the same zigzag a wall advances by, a fragment
rejoins the wall, a fight ends once blows have been struck and none land
for six rounds (the side with fewer than half the other's men standing
quits; otherwise both draw off), and a pushing wall with the enemy two or
more facings off its front wheels toward them, one facing a round, unless
it is in contact. Balance after the fixes, equal green bands, player wall
shouting Push against a steady enemy: 64% wins, 4% draws. The push now
weighs the whole line: every man shoulder to shoulder and facing the same
way lends his might, so a mob crowding one part of a line no longer
outweighs it; heart comes from the man at your shoulder (a man with no friend beside
him in his line loses heart each round, however many mill about him); a held man
with nobody in front but an enemy at his flank or back turns and fights
him; and a green man with no orders still strikes at what is in his face.
Open: "Break them!" against the steady enemy doctrine wins about seven
fights in ten, more than "Push!", because the enemy holds while a charging
line keeps the initiative; the doctrine, not the wall, needs work.

**Fifth playtest, same day (the lines did not bend):** the wall was a
straight row with one facing, dressed flat every round and moved as a
block, so it read as a fence; the hex board was not the cause. Decision:
the wall is a chain. A man is in it if he stands next to a man already in
it with neither straight ahead of or behind the other, their facings
within one hex facing (60 degrees) of each other, and his own facing within
two of the leader's. Bend further and the wall has broken there. Each man
minds his own front: with an enemy before him he keeps his facing; with
one at his flank and none before him he turns a facing toward him, so the
ends hinge back to refuse a flank; with nobody at arm's length he dresses
one facing a round back toward the wall's, so a wheel runs along the line
over rounds and a bend straightens only once the fight there is over. A
man who turned clean round to strike faces his wall again as soon as
nobody is at arm's length. The wall still moves under one test, but as a
chain: with nobody engaged every man takes his straight step together;
once part of it is engaged the engaged men hold and fight and the rest
close on the nearest enemy, from the ends of the line inward, never
letting go of a man beside them, so a wing swings forward round a held or
blocked man like a door on its hinge and the line bows round the fight.
Falling back, the whole shape goes back together along the wall's
facing, bends and all. Shoved men and winners following up step square
to their own facing. The
push weighs a bent line as one line. "Shield wall!" straightens a line
that is not engaged and holds an engaged one as it stands. On the screen
each man stands a little off the centre of his hex, so the lock bars run
as a chain rather than a rail. Enemy leaders now wheel a facing a round
too. The bend was then measured rather than seen: two equal eight-man lines
meeting dead centre bend about twice a fight, since every man is engaged
at once; lines that overlap unevenly bend seven times with nine hinge
turns. So the prototype's field now varies with the seed
(`sim/combat/scenario.gd`): the enemy brings six to ten men, their line
stands up to three hexes off yours, and two leaders in five are
aggressive. The HUD shows the build it was made from, so a stale cached
build is easy to spot.

**Sixth playtest, same day (played by touch at phone size and three
scripted fights):** a line told to hold followed up every shove it won
and walked forward two rows, so "Hold!" was a slower "Push!". Now only a
side driving forward (Push, Break them, the wedge) throws a losing line
back and follows up; a holding side that wins the contest holds the push
where it stands, the pushers stop and tire, and the lines stay locked so
the fight goes on. (The first cut, where a holding side still threw the
pushers back but did not follow, stalled half of all holding fights: the
enemy stepped in, nobody struck in the round of contact, the shove threw
them out of reach, and it began again.) The HUD's wall count no longer
drops to one when the leader turns to strike, the camera fits every
standing man between the bars on a phone and eases in as the lines close,
and the result panel is a wrapped box in plain words. On the varied
fields a pushing player wins 55% with 3% draws, a holding one 39% with 8%,
which is what "brace, don't chase" should cost.

**Seventh playtest, same day (the bend did not show):** men with nobody
in front stepped forward under Push, but the lock bars did not include
them and the wall count dropped. Three causes, all fixed: the bars, the
shield-lock bonus and the push groups used a stricter two-sided shoulder
rule than the wall itself (one rule now, `BattleGrid.linked`, so what is
counted is what is drawn and fought); a man stepping with the wall never
took the facing his step gave him, since carried men were placed without
it, so he stood straight ahead of his neighbour and unlinked (he now turns
as planned, and a step is only taken with a facing that keeps every man
beside him linked); and shoves, follow-ups and the wall's own step each
used a per-man zigzag, which scattered a bent line (one shared step per
wall now, so the shape moves as a piece). A stepper also keeps every
wall-mate now at arm's length at arm's length, so nobody is left behind.
Measured over forty fights: 98% of standing men still in the wall after a
round, up from 96%, with the men who did leave mostly beside a man who
fell.

**Eighth playtest, same day (mixed arms):** the field now carries three
roles. Shield-bearers make the line and each carries a throwing spear;
spearmen stand in a second rank and strike over a shoulder at reach;
bowmen stand two ranks back, shoot at anything within six hexes, and give
ground toward the leader when closed with. A wall closing with spears to
throw halts one round at two hexes to loose them, then comes on; a spear
caught on a shield sticks there and spoils it. Formations are templates
(`FormationTemplate`): a named shape and a rank per role. The presets are
*ranks* (shields, spears behind, bows two behind), *line* (everyone in the
one line), *bows behind*, and the *boar's snout*; the HUD's Form button
cycles them and "Shield wall!" forms the chosen one. The wall is the
shields and the spears; bows are counted apart ("wall 10/10 +2 spears +2
bows"). Your band is eight shields, two spears and two bows; the enemy's
mix varies about the same strength. Two rules came with the arms: the man at your
right shoulder's shield covers your open front-right against blows and
shots alike (as the formation rules always said), and arrows against a
man whose shield is locked mostly rattle off, so archers pick the exposed
man first and a wall is the answer to them. Archers keep within five hexes
of their leader before they shoot. First numbers, equal strength in mixed
arms against the steady enemy: a charge ("Break them!") into ranks loses
nineteen fights in twenty, where it won seven in ten against a plain line;
pushing into ranks wins 38% and holding to receive them 58%, with the
steady AI on your side at 49%. The defender's second rank strikes the
arriving line before it can strike back, and his archers get twice the
shots. That is history, and it is also a problem for a skirmish with no
objective: the side that stands still is favoured, and the enemy AI still
walks into it. Open: give the field something to take or hold, and teach
the AI to hold ranks against ranks unless it has the numbers. A shield
spoiled (three points gone, to spears or axes) leaves its man in the wall
but unlocked: no cover, shoved by glancing blows, the archers' first mark,
and a gap in his neighbours' lock. *Relief*: a shielded man standing
straight behind him changes places with him at the start of the next
round, stepping up into the line while he drops back and fights at reach,
so the wall closes itself. The HUD reads "wall 8/8 (1 shieldless)" and
draws the gap as a dark thread until it is relieved. Passing spare shields
forward waits for the campaign's gear. **Taunt!** (same day) is the
answer to two lines that will not close: a jeer that costs the standing
side heart round after round, so the one who waits pays for waiting, and
that a proud leader answers by coming on. The enemy jeers too. On the
screen men now sway where they stand, each to his own rhythm, and tense
up when an enemy is at arm's length; the shadow stays put and the man
moves above it. Men in a wall draw in toward their leader on the screen,
twelve pixels a link, with bigger shields set steadier, so locked shields
overlap while the hex stays each man's slot in the rules; the line
visibly closes up as the wall forms and opens as it breaks. When real
models come, the formation pose (shoulder to shoulder, shields
overlapped) is this same offset, applied to the model rather than the
disc. **A wall stands one of eight ways** (same day). Its line runs on one of
four axes on the screen: level (a row of cells), plumb (up and down: a
zigzag of neighbouring cells drawn straight), or either slant (the two
true hex axes, rising to the right or to the left). Its men face one side
of the axis or the other. Wheel steps round the eight stances in turn, so
a right wheel from level-facing-up goes to the left-rising slant facing
north-east, then plumb facing east, then the right-rising slant facing
south-east, then level facing down. The facing is still a hex direction
(what shields and arcs use), thirty degrees off the true perpendicular for
level and slanted lines, which is as near as hexes come. Every stance has
a "straight forward" step: the plain hex step for plumb, and for the rest
a pair of straddling steps keyed on the coordinate that is constant along
the line, so every man in the line steps the same way and keeps his own
place across it; "straight behind" is the same step the other way. The
enemy's leader wheels through the same stances toward your band. The HUD
names the stance beside the wall count.

**Objectives (9 Nov 2026), the answer to "the side that waits is
favoured":** seven varied fields in ten are now fought over something
(`sim/combat/objective.gd`), and you are the attacker or the defender by
even odds. *The ford* is three to five hexes just before the defender's
line: at the end of round 16 the side with more standing men on it has it,
ties to the defender. *The ships* are a strip along the defender's back
edge: four of the attacker's men there before round 20 wins at once. *The
hall* is four to six hexes where the defender's rear ranks stand: the
attacker must hold half of it two rounds running before round 18. Time
running out, or both lines refusing to close again, gives the fight to the
defender. The side that must come on brings two more shields (or the
defending enemy two fewer), since men who come for something come in
strength. Your line still stands at the bottom; the objective is drawn at
the defender's end (bone for the ford, blue-grey for the ships, gold for
the hall), the HUD gives the task before round 1 and its progress every
round, and the enemy's leader is nudged by it: attacking, he stops holding
past half his time; defending, he will not push out to you while nobody of
his is engaged. Measured over 200 varied fields (41 open, 53 ford, 50
ships, 56 hall), equal green: holding and taunting, the old best tactic,
now wins none of the fights where you attack (75% defending, 73% in the
open); pushing wins 55% attacking and 66% defending; pushing when you
attack and holding and jeering when you defend wins 67% overall. About
half of all fights are now decided by the objective, most of them by the
defender holding out; the attacker actually takes it rarely (the hall 12
times in 200, the ford 5, the ships once), and the enemy as attacker
loses three fights in four. Open: the ships are nearly unreachable past a
standing band, and the enemy needs a real plan for attacking, not a nudge.

### Drill, custom formations and custom shouts (decided 8 Nov 2026)

The shouts and shapes above are the ones every leader knows. The rest a
band learns in the winter drill yard, and this is how:

- **A formation is a template**: a name, a shape, and where each role
  stands (rank per role now; later a drawn arrangement of slots relative to
  the leader, so a player can lay out a refused flank, a hollow square, a
  skirmish screen, or a wedge with bows in its tail). The sim already forms
  on templates, so a custom one is only a new template.
- **Drill makes it theirs.** In winter a man's task may be drill; the band
  drills a template, and its *familiarity* with it rises with the men who
  drilled and the seasons it has been used. Familiarity is what the wall's
  single test rolls against for that shape (a green band forms a shape it
  has never drilled slowly and raggedly; a drilled one forms it like the
  plain line), and it decays for men who were not there. New men learn by
  standing in it.
- **A custom shout names a template and an order.** "Hedgehog!" might be
  *refused flanks, hold*; "Swine!" the boar's snout and push. The shout
  system is unchanged: it carries by distance, can be misheard, and a man
  who has not drilled the shape hears a word he does not know and does
  what the men beside him do. Learned shouts replace the single fixed
  "Svínfylking (learned)" entry.
- **What the player does on the field** stays the same: pick a shout, step
  his own man, wheel. Drill is where the thinking happens; the field is
  where it pays. Named lieutenants later carry a template of their own for
  the flank they lead.

If the prototype finds pulses still feel like turns,
the fallback is a fixed-timestep scheduler where each man acts on his own
timer; the per-man rules survive that unchanged, only the battle loop
changes.

### Shouts

| Shout | Effect |
|---|---|
| Shield wall! (Skjaldborg!) | Form up on the leader, lock shields |
| Hold! | Brace, don't chase |
| Push! | Drive the line forward |
| To me! | Close on the leader; rallies men in earshot |
| Break them! | Charge, abandon formation |
| Fall back! | Controlled retreat (steady men only) |
| Taunt! | A jeer across the field, not an order. Enemies in earshot who stand and take it lose heart (never below the break threshold: shame shakes, it does not rout); men coming on are not shamed; Steady and Grim men ignore it; your own men in earshot take heart. The enemy taunts a holding line too, and a proud enemy leader answers a taunt by coming on |
| Svínfylking (learned) | Boar's-snout wedge; unlocked by winter drill |
| Custom (learned) | A drilled formation plus an order, under the band's own name; see "Drill, custom formations and custom shouts" |

Shouts carry by distance. Near men hear clearly; far men may miss or mishear
in the noise. A horn-blower and banner-bearer extend range. As the band grows,
named lieutenants command flanks with their own judgment.

Enemy shouts carry too. A man with good Wits, or a leader with the "reads the
field" trait, hears the enemy form skjaldborg or call a charge a beat before
it happens, and the preview shows it.

### Rolls

Conflicting actions are opposed rolls: stat + modifiers + 2d6 each side.
Modifiers come from shield adjacency, second-rank support, morale and the
leader's Luck.

The margin says how hard the blow lands; shields and armor then absorb some
of it; what gets through advances the loser's wound state (see Wounds). A man
is never killed outright by a single roll: he goes Down, and death is decided
after the battle.

| Margin | Result |
|---|---|
| Tie | Locked: both stay and tire |
| 1–2 | Glancing: a shove back one tile, or shield damage |
| 3–5 | A hit: one wound step unless absorbed |
| 6+ | A heavy hit: two wound steps, or the man breaks and runs |

Two 2d6 rolls against each other give a 6+ margin about one exchange in nine
between equal men. Without absorption that is a massacre every round, so
shields and mail are the main tuning levers, and this table is a starting
point for the combat prototype, not a commitment.

### Formation rules

- **Facing:** six directions, one per hex side. Of a man's six neighbours,
  the shield covers the front and the left; the front-right is open but
  no flank; the right is the exposed flank; the two behind are the rear.
  The man to your right covers your open side: that is the wall. The
  rightmost man of any line is its weak point, so lines drift right under
  pressure, as real ones did.
- **Shield wall:** adjacent shield-bearers lock shields for defense. Gaps are
  weaknesses.
- **Two ranks:** spears strike from behind a shield-bearer.
- **The push:** at round end, lines in contact compare combined Might,
  weighted by morale and second-rank support; the weaker line is shoved back
  a tile.
- **Lulls:** if both lines brace, both sides recover breath.

### Gear defines roles

| Weapon | Role |
|---|---|
| Spear | Reach, fights from the second rank; the common weapon |
| Bearded axe | Hooks shields aside, opens gaps |
| Sword | Rare and costly; a prestige gift and a real upgrade |
| Long axe (two-handed) | Huge damage, no shield, exposed. Rare and late: the broad "Dane axe" is really a late-900s weapon, so it appears only in the last generation or as a one-off |
| Bow | Skirmishing and hunting |

Berserkers are a rare trait, not a class.

### Wounds, shields and morale

- **Wound states instead of HP:** Bruised → Wounded → Grievous → Down. Each
  step brings penalties; Grit sets how much a man can take before each step.
  After battle, downed men roll: die, maimed for life, or recover.
- **Shields wear out.** Axes chew through them; a thrown spear stuck in one
  makes it useless; the second rank can pass a fresh one forward.
- **Fatigue:** every action costs breath.
- **Morale** is a man's state in this battle (his Nerve stat is what he
  brings to it). Lowered by men falling nearby, being flanked, the enemy's
  reputation; raised by the leader's presence and Luck. Broken men run, and
  panic spreads. A fallen leader or a lost banner collapses a side's morale.

### Terrain and conditions

Slopes favor the downhill push. Mud and streams slow men and break formation.
On ship decks men go overboard, and mail can drown them. Rain ruins
bowstrings; fog and wind shorten shout range.

### Battle types

- **Raids and skirmishes:** open maps (about 16×12) with objectives — seize
  the silver, burn the boats, escape before the levy arrives. The main mode;
  about 10–15 minutes each.
- **Shield-wall sectors:** your stretch of a great battle, on narrow, deep
  maps, with wider-battle events hitting your flanks. Occasional and longer.
- **Ship fights:** lashed ships, boarding, men overboard.
- **Hall-burnings:** attack a sleeping hall at night, or defend your own.
- **Holmgang:** formal duels, three shields each.

### Your character

Fighting in the front rank lifts your men's morale but risks your life.
Hanging back costs Luck and reputation. If you go down, the whole band takes
a morale check. You can also do what no shout can: step into a gap, take the
banner from a fallen bearer, or go for the enemy leader.

### After battle

Plunder, captives, the wounded tended, the dead buried. Luck and reputation
shift; each man's effort gains are recorded.

## The band

Every sworn man is a named individual whose ability comes from what he was
born with plus what his life has made him, inspired by Pokémon's IVs and EVs.
(The Pokémon terms are for the design team; nothing in the game says
"potential" or "effort" as a number.)

### Stats

| Stat | Governs |
|---|---|
| Might | Damage and pushing |
| Skill | Weapon craft, hitting and parrying |
| Grit | Stamina and wound capacity |
| Nerve | Starting morale and resistance to panic |
| Wits | Hearing and understanding shouts, reading the enemy |

Wits decides whether a man *understands* a shout; his experience tier
decides how well he *carries it out*.

### Inborn potential (IV equivalent)

- Each man has a hidden potential per stat, fixed at birth, that caps how
  high it can grow.
- **Shown only as hints,** never numbers: saga-style descriptions such as
  "strong-armed", "slow to anger", "faint-hearted".
- Hints sharpen as you lead more men; a veteran with a "judge of men" trait
  reveals more.
- **The coal-biter (kolbítr):** the saga figure of a lazy youth by the fire
  who proves great. A recruit with poor current stats and high hidden
  potential is a real find.
- Recruits are fixed — no rerolling.

### Effort (EV equivalent)

- Stats grow by use: the wall raises Nerve and Grit, pushing raises Might,
  duels raise Skill, scouting and relaying orders raise Wits.
- Opponents matter: skilled swordsmen train Skill faster; berserkers train
  Nerve.
- **Loose total cap:** men specialize early but can round out over a long
  career.
- Winter drill directs some effort deliberately.

### Personality as Natures

Personality traits push growth up in one stat and down in another — Reckless
(Might up, Wits down), Grim (Nerve up, Skill down), Boastful (Skill up, Grit
down).

### Experience tiers

Separate from stats, earned by surviving battles rather than by kills. Tiers
decide how well a man carries out shouts.

| Tier | Behavior |
|---|---|
| Green | Follows shouts literally, sometimes late; may panic and ignore them |
| Blooded | Reliable |
| Veteran | Adapts; covers a gap when the man beside him falls; can take conditional orders |
| Champion | Acts on his own to protect the leader; can lead part of the line |

### Traits

Two to four per man:

- **Origin:** fisherman (good at sea), younger son, outlaw, freedman, exiled
  jarl's son
- **Personality:** reckless, steady, greedy, boastful, grim, superstitious
- **Earned:** scarred, one-eyed, afraid of water, blooded at Hafrsfjord

### Ambitions, loyalty and bonds

- Each man wants one thing: silver, land, vengeance, fame, a wife, or to go
  home. Help him and loyalty jumps; ignore it and he leaves or turns.
- **Loyalty** is his oath to you, raised by gifts, fair plunder shares, your
  Luck and glory.
- **Bonds** are ties to other men: oath-brothers, rivals, kin. Bonds grow
  from fighting side by side and can end in blood-brotherhood. If one
  oath-brother dies, the other swears vengeance and a feud begins.

### Wounds and age

Lasting injuries change what a man can do (a maimed hand means no shield; a
limp means he can't keep up when the line advances). Men grow fast when
young, peak from mid-20s to mid-30s, then decline. An old veteran keeps his
tier while his body fades.

### Gear as progression

Mail shirts, helmets and swords are rare and expensive. Gifting gear raises
both loyalty and fighting power, and upgrades show on each man's sprite.

### Band size

Start with two or three men, grow to a ship's crew of 15–30, and top out
around 30 named hird men. Levies and hired men beyond that are unnamed groups
under your lieutenants. Bench space in your hall sets the winter cap. The
named cap is a tuning question: it is bounded by what the roster screen and a
simultaneous-resolution grid can keep readable, not by what the fiction
allows.

## Leader, family and succession

### Luck and reputation

Two resources belong to the leader rather than to any man.

- **Luck** (the sagas' *hamingja* or *gæfa*) is a hidden-ish number shown as
  omens and the talk of your men. It rises with bold deeds, kept vows, fair
  dealing and victories against the odds; it falls with broken oaths,
  hanging back in battle, shameful killings and ill omens ignored. It
  modifies your own rolls, your men's morale, and the chance that bad luck
  (storms, sickness, betrayal) finds you. Part of it passes to your heir.
- **Reputation** is public and has two faces: *fame* (how many men want to
  follow you, how jarls treat you) and *honor* (whether you keep oaths and
  pay what you owe). A famous man with no honor attracts greedy men and loses
  them; an honorable nobody attracts no one.

### Succession

When your character dies, play passes to your son or your sworn second. The
saga only ends when no heir remains.

### Heirs

- **Son:** born through marriage in winter, ages over the years, and can
  fight in your band as a unit — and can die before inheriting. Fostering him
  with another lord builds an alliance but sends him away.
- **Sworn second:** a veteran you name in advance. When he takes over, his
  traits and personality become the leader's.
- **No heir:** the band scatters. This is the only true game over.

### Loyalty must be won again

Every man decides again whether to stay, based on his bond with the heir, the
heir's reputation and generosity. A weak son can lose men to a strong second,
or face a challenge from him.

### The grave-ale (erfi)

The heir hosts the inheritance feast, drinks the oath cup, makes a vow and
takes the high seat. A lavish feast and a bold vow bring more men back; the
vow becomes his first major goal. The funeral (ship burial or mound) adds to
the family's reputation.

### What carries over

- **Feuds,** in full. A leader killed in battle leaves a vengeance
  obligation; refusing it is shameful.
- **Family luck,** in part, depending on how the leader lived and died.
- **The family name:** recruits follow "the son of the man who held at
  Hafrsfjord."
- **Inborn potential:** a son inherits potential from both parents with
  plenty of randomness. Marriage is partly a bet on lineage as well as an
  alliance, framed as family character rather than breeding.

### Aging

Leaders decline with age, so stepping down, or dying old, is a real choice.
A single campaign can run from a grandfather who fought Harald to a grandson
who settles Iceland.

## Winter hall phase

Winter plays out turn by turn (early winter, Yule, deep winter, thaw) with
light management: bench space and food are the core constraints, not
production chains.

- **Bench space caps the band.** Every man kept over winter needs a seat and
  food. Men without one go home, and some don't return. Buildable: more
  benches, storehouse, smithy, boathouse, byre.
- **Food is the main pressure.** Stores come from plunder, farms and thrall
  labor. Shortages lower loyalty and drive men away. Feasts spend food for
  loyalty.
- **Seating order shows honor.** Moving one man up can offend another — a
  quiet tool for managing loyalty and rivalries.
- **One task per man each turn:** drill (directs effort, unlocks shouts),
  heal, repair (shields, mail, ship), hunt or fish, guard, travel (kin,
  messages, scouting).
- **Yule** is the high point: gift-giving, new oaths, and vows over the cup.
  Vows become season goals; kept vows build reputation, broken ones shame.
- **Visitors and events:** paid skalds, traders, jarls' envoys, outlaws
  asking shelter, marriage offers; feud attacks and hall-burnings, sickness,
  storms, thrall unrest; drunken quarrels turning into holmgang challenges.
- **Your wife runs the household.** She holds the keys and manages the
  stores; her skill sets how far food stretches, and she acts as an advisor.
- **Planning:** winter rumors shape where you sail and who you fight in
  spring. This is also where you choose to let the years pass.

**Shieldmaidens** are included as rare, notable exceptions rather than a
common unit, reflecting how debated the evidence is (the Birka grave Bj 581
is the famous case).

## Strategic map and economy

The world is a free-sailing 2D map with a regional market economy whose
prices rise and fall.

### The map

- **Free sailing** along coasts and across open sea; travel takes days within
  the April–October season.
- **Shipwreck is a real but rare risk** on open crossings; storms more often
  scatter, delay or damage ships.
- **River routes east** require portages, hauling the ship overland while
  exposed.
- **Knowledge through rumor:** distant regions stay vague until someone tells
  you or you go.
- **Places:** farmsteads, jarls' halls, trading towns (Kaupang, Hedeby,
  Birka, Ribe), Thing sites, forts. Each has wealth, defenses, allegiance and
  alertness.
- **Raided coasts get warier.** Repeated raids bring smaller returns and
  stronger defenses. Coasts raided often build hilltop warning beacons, which
  Haakon the Good's law later makes universal — the player's own raiding
  helps bring that about.
- **Encounters:** rival ships, merchants, outlaws, the king's levy, storms.
- **Strandhögg:** a quick shore raid for cattle and supplies that creates
  local feuds.
- **Factions with ambitions:** petty kings and jarls ally, feud, marry and
  switch sides without you; Harald expands across the map over the years.

### Silver by weight

The economy runs on weighed silver: hacksilver, cut arm rings and dirhams.
Arm rings are both stored wealth and gifts for your men.

### Trade goods

| Good | Source |
|---|---|
| Furs, walrus ivory, walrus-hide rope | The far north (Hålogaland) |
| Bog iron, soapstone | Norway |
| Amber | The Baltic |
| Frankish sword blades, wine, glass | Imported from the south |
| Silk | Via the eastern river routes |
| Thralls | Raids; sold at Hedeby, Birka, Dublin and eastward |

Regional prices move with supply and demand, so trade is a real path to
wealth — the northern chieftain Ohthere is the historical model.

### Land

Land yields food and silver each winter. **Odal land** (inherited family
land) is the main story hook: Heimskringla says Harald claimed it, and the
sagas give that as a reason men left for Iceland.

### Ships

| Ship | Use |
|---|---|
| Karve | Small, cheap coastal work |
| Snekkja | Standard warship |
| Larger longship | A jarl's flagship |
| Knarr | Cargo, trade, settlers bound for Iceland |

Ship size sets both crew capacity and cargo.

### Making a living

Raiding, trading, jarls' contracts, merchant escort, debt collection, hunting
outlaws, selling your sword, and later collecting tribute.

## Story

The story is a historical spine the player can change, a personal saga
carried by the family, and conditional saga threads — followed by open-ended
sandbox play once the storyline completes.

### Historical spine

Events fire on the traditional timeline unless the player changes them. Each
has preconditions and alternate outcomes: if Harald falls at Hafrsfjord, the
drive toward a single king doesn't vanish — a rival jarl takes up the bid, or
the player does.

| Approx. date | Event | Player can |
|---|---|---|
| 860s–870s | Harald's vow and conquest of the petty kingdoms | Serve, resist, or profit from the chaos |
| c. 872 | Battle of Hafrsfjord | Fight on either side; change the outcome |
| from 874 | Settlement of Iceland | Emigrate and claim land |
| late 800s | Founding of the Orkney earldom | Take service with the earls |
| c. 900 | Rollo outlawed by Harald (per the Norse sources; his origin is disputed) | Join his exile west |
| 930s | Eric Bloodaxe's reign, fighting among Harald's sons | Back or betray Eric |
| 930s–960s | Haakon the Good | Seek acclamation at the Thing |

### Egils saga as template

Kveldulf's family falls foul of Harald, the king kills Thorolf, and the
family sails to Iceland for revenge and freedom. That arc — a family caught
on the wrong side of a rising king — is the game's story shape.

### Character creation

The player builds his character from an origin, home region, family and
starting traits. His own potential shows only as hints. **The player
character is male** for now (decided 7 Nov 2026); a female origin may be
revisited later, and shieldmaidens remain a band question, not a player one.

- **The burned hall:** your family's land is seized by a jarl loyal to
  Harald; you flee at night with two men, and the escape is the first fight.
  Vengeance is your saga.
- **The younger son:** no inheritance, your father's old spear, and a brother
  who got everything.
- **The freedman:** once a thrall; the hardest start and steepest climb.

### Personal saga

The origin leaves an unfinished goal (a vengeance, a lost land, a debt) that
passes to your heir. A grandson can settle what his grandfather started.

### Saga threads

Hand-written storylines triggered by world conditions rather than fixed order
— reputation thresholds, a fostered jarl's son, a vow made at Yule. They
attach to the family, so they survive succession. Examples: Rollo's exile,
Orkney service, Iceland's land-take (claiming land by carrying fire around
its borders in a day, per Landnámabók), serving or betraying Eric Bloodaxe,
rescuing an enslaved son.

### The family chronicle

The game records your deeds as saga text that you can read at the end of each
generation. Skipped years appear as a line each, the way sagas pass over
uneventful winters.

### After the story

When the storyline completes, play continues as an open-ended sandbox.

## Ranks, politics and law

The player can climb from thrall to king, argue cases at the Thing as a full
mini-game, or live as an outlaw.

### Ranks

1. Thrall
2. Freedman (leysingi)
3. Karl — free farmer
4. Hersir — local war leader
5. Jarl
6. King

Each rank opens a bigger hird, more voice at the Thing, larger ships and the
right to hold land. Two ways up: **service** (a king or jarl grants rank) or
**acclamation** (proclaimed at a Thing, as Haakon the Good was).

### Politics

- **Formal friendship:** alliances sealed with gifts that create obligations
  — Hávamál's gift that looks for a return.
- **Oaths of service, marriage alliances, fostering.** Fostering another's
  son puts his family in your debt; sending yours acknowledges a superior.
- AI jarls hold grudges, arrange marriages and switch sides on their own.

### The Thing mini-game

Local and regional assemblies (Gulathing, Frostathing). A case plays in four
stages:

1. **Gather support:** ride to farms, give gifts and call in favors for
   supporters, witnesses and oath-helpers.
2. **Procedure:** the law-men rule on each step; a procedural slip can sink a
   strong case, as in Njáls saga. (The formal lawspeaker office is best
   attested in Iceland; Norwegian Things used respected law-men. Same
   mechanic, hedged title.)
3. **The standoff:** each side's backing is weighed. Armed, evenly matched
   sides risk violence — and violence at the Thing is a grave crime.
4. **Outcome:** compensation, outlawry, or failure, which moves the dispute to
   a duel or feud.

### Feud and wergild

Wergild, the payment for a killing, scales with the dead man's rank. Feuds
escalate between families until settled by arbitration, payment, or one
family's destruction.

### Outlawry

- **Lesser outlawry:** exile for a few years.
- **Full outlawry:** anyone may kill you without penalty.
- **The outlaw path is fully playable:** halls are closed to you, bounty
  hunters follow, and fleeing abroad becomes the realistic choice.

## Thralls and tone

Thralls are included because the game aims for historical accuracy; slavery
was central to the Viking economy and to raiding.

### Historical basis

- **Social order:** Rígsþula describes three ranks — thrall, karl, jarl.
- **Sources of thralls:** raids in Ireland, the Baltic and Slavic lands; sold
  at Hedeby, Birka, Dublin and along the Rus' routes.
- **Legal status:** property; killing a thrall meant compensating the owner,
  not wergild to kin.
- **Freedom:** thralls could be freed or buy freedom. Freedmen owed
  obligations to former masters; their descendants blended into free society.

### Mechanics

- **Captives after a raid:** ransom the valuable, sell at market, put to work
  on your land, or free them.
- **Labor:** thralls work farms, turning land into winter wealth.
- **Revolt and escape:** Landnámabók records Hjörleifr killed by his Irish
  thralls; unrest rises when the band is away.
- **Freedmen followers:** freed thralls can become loyal followers and
  warriors with their own arcs.
- **It can happen to you:** the sagas tell of chieftains' sons sold into
  slavery (Olaf Tryggvason's childhood is the famous case, just after our
  period). A defeated band can lose a son to the markets, opening a rescue
  saga thread.

### Tone guidelines

- No modern morality meter. Period norms apply; individual characters still
  hold views, more so as Christian influence spreads.
- Thralls are people with names, origins and families — never inventory
  icons.
- No explicit sexual content. Exploitation stays off-screen, referenced only
  minimally.
- No cruelty as gameplay: no rewards or bonuses for brutality. The game shows
  a hard world without celebrating its worst.

## Tech and art direction

The target look is heroic-proportioned characters about 96 px tall on an
isometric grid, aiming for the hand-made feel of Dead Cells; whether that
comes from 3D models rendered as pixels or straight pixel art is decided by a
prototype test.

### Engine and architecture

- **Godot 4 with GDScript,** strong for 2D grids, tilemaps and UI-heavy games.
- **Simulation separate from presentation:** combat resolution, economy,
  faction AI and feuds are plain GDScript classes (`RefCounted`, no scene
  tree) that run under `godot --headless` with a unit-test framework
  (GdUnit4 or GUT). This is what makes the game buildable from a cloud
  session with no display: the whole rules layer can be written, tested and
  balanced before any scene exists.
- **Seeded, deterministic rolls:** any battle can be replayed exactly, bugs
  are reproducible, and multiplayer stays possible later.
- **Data-driven content:** traits, gear, events and saga threads live in data
  files (JSON or Godot resources), not code.
- **Balance by simulation:** because the sim is headless, thousands of
  battles can be run in CI to check the wound table, the push, and
  green-versus-veteran outcomes against targets.

### Art

- **Camera:** angled isometric view on a square grid rotated 45°, so shield
  walls read as diagonal lines. Camera rotation if the 3D route is chosen.
- **Proportions:** heroic (about 5.5 heads tall) — broad shoulders, big
  hands, shields and weapons, chunky beards — so gear reads at a glance.
- **Density:** about 96 px tall characters, enough to show helmets, mail and
  wounds.
- **Layered characters:** body, hair and beard, gear and visible wounds as
  separate layers, so every generated man looks unique and upgrades show.
- **Portraits carry identity:** detailed portraits for the hall and dialogue,
  generated in ComfyUI with a style LoRA for consistency.
- **Close-ups for key moments:** Fire Emblem-style cuts for kills, shield
  breaks and holmgang finishes, where the art budget is spent.
- **Views:** a painted strategic map, the isometric tactical grid, and static
  hall scenes with portraits.
- **Readability first:** every man on the grid must show at a glance his
  wound state, whether he is winded, whether he is wavering, and whether he
  heard the last shout. Those four readouts are designed before any
  decoration.

### Sound

Tagelharpa, lyre and drums. Battle shouts in Old Norse, such as
"Skjaldborg!" (shield wall).

## Scope tiers

The doc describes a large game. This is the order things earn their place.

- **Core (the vertical slice must have it):** simultaneous-turn combat with
  shouts, the band with potential, effort, tiers, traits and bonds, wounds
  and permadeath, one winter with bench space, food, drill and Yule, one
  Thing case, one origin, one saga thread, the chronicle.
- **Full game:** free-sailing map, market economy, factions, succession and
  heirs, letting the years pass, the historical spine for Norway, all battle
  types, outlawry, thralls as a system.
- **Later:** the eastern routes, Iceland's land-take, Orkney and Dublin,
  holmgang as its own mini-game, multiplayer, ship customization.
- **Cut unless it proves itself:** production chains of any kind, named
  bands above about 30, any mechanic that needs the player to manage thralls
  individually.

## First playable and milestones

The first goal is a vertical slice that proves the core loop — shouting a
small band through simultaneous battles and keeping them through a winter —
before any open-world work. The combat simulation comes first because it
needs no art, no display and no decision on the art route, so it is the
right work for cloud sessions now.

1. **Combat simulation (headless).** Simultaneous resolution, 2d6 opposed
   rolls, wound steps with absorption, morale and the push, shouts with
   hearing by distance, experience tiers deciding compliance. Unit tests and
   a batch runner that fights a thousand battles and reports kill rates,
   round counts and break rates. *Gate: green band versus veteran band under
   the same shouts produces clearly different outcomes, and the wound table
   gives battles of the intended length.* **Done 7 Nov 2026**: see
   `sim-architecture.md`, "Milestone 1 gate, measured".
2. **Art test (parallel, needs a workstation).** One heroic-proportion
   warrior at 64 and 96 px, built three ways: 3D with pixel-scale painted
   textures, limited palette and outline shader; 3D with hand touch-up; and
   straight pixel art. One exchange (strike, shove, shield break) and two
   gear variants (tunic and leather; mail and helmet). Judge on detail,
   motion, time per new animation, and ease of gear swaps. *Gate: art route
   chosen.*
3. **Playable combat prototype.** The sim on a grid with placeholder sprites:
   your character plus about six AI men, pulsed turns with pause and
   auto-pause, the muster preview as the pause overlay, beat-by-beat
   animation of each round, and the four readouts. *Gate: a tester can say
   what a shout will do before locking, the battle reads as real time at the
   default pulse, and the single-character design feels like leading rather
   than watching.*
4. **Vertical slice.** The burned-hall origin in the western Norway fjords:
   about ten men, a skirmish and a shield-wall sector, one winter, one Thing
   case and one saga thread. *Gate: the loop is fun across one full year.*
5. **Campaign core (headless).** Growth from potential and effort, tiers,
   loyalty, ambitions and bonds, the winter hall with food, seats, tasks,
   Yule and events, luck and reputation, family and succession, and a
   campaign loop that runs years of raids and winters through the combat
   sim. **Done 7 Nov 2026**: see `campaign-architecture.md`, "Milestone 2
   gate, measured".
6. **Sandbox foundations (headless).** Free-sailing map of Norway and its
   neighbours, voyages and encounters, market economy and raiding, factions
   with ambitions and the historical spine, the Thing, feuds and outlawry,
   letting the years pass, and a planner-driven summer on the map. **Done
   7 Nov 2026**: see `world-architecture.md`, "Milestone 3 gate, measured".
7. **Expansion by region.** Denmark and the Baltic, the west and Iceland, the
   eastern routes; the full historical spine.

**Ninth playtest, 9 Nov 2026 (objectives and a cunning enemy, measured
together):** with the ford, the ships and the hall on three fields in
four, and an enemy who wheels toward the threat, refuses a flank and holds
ranks against ranks (CUNNING in two fights in five), the tactics have
changed shape. Against each doctrine the human's wheel-and-flank now wins
31-36%, holding and taunting 26-43%, and a straight push 55-60%. Across
the varied fields: pushing wins 56% (51% when you attack, 73% when you
defend, 34% in an open fight), holding wins 32% and never wins an attack,
and the steady AI on your side wins 49%. The symmetric batches are
unchanged. Open: the attacker rarely takes the objective itself (the
defender mostly wins on time), the ships are nearly unreachable, and a
holding line against a holding line is a dead fight unless there is
ground to fight over.

## Open questions

- [ ] Art route, production: 3D rendered as pixels or straight pixel art
  (decided by the art test). The *look* is decided (7 Nov 2026): pixel-style
  hard outlines and a limited palette on the grid, painterly portraits and
  key art off it; see `concept-art-prompts.md`, "Art-route recommendation".
- [ ] Final title: keep Ring-Giver or choose another
- [ ] Save policy: ironman by default (the saga is what happened), with
  reloads as an option, or free saving
- [ ] Holmgang rules: full duel mini-game or a variant of normal combat
- [ ] Multiplayer: in scope later, or single-player only
- [ ] Conditional orders: which ones veterans unlock, and how they're given
- [ ] Shieldmaidens: how they appear (origin, recruitment event, or both)
- [ ] Named band cap: 30 is the target; the prototype says whether the grid
  and roster stay readable at that size
- [ ] Time passing in summer: continuous days or a coarse turn per voyage leg
