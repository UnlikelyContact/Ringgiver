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
has been driven from the field: its men leave and count as fled. If the prototype finds pulses still feel like turns,
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
| Svínfylking (learned) | Boar's-snout wedge; unlocked by winter drill |

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
