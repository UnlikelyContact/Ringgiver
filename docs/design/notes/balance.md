# Balance: the whole saga, sim side (November 2026)

Eight packages were merged one after another (the escape, families, the
living summer, the stepped winter, generations, the saga's fights, law,
land and the unfree, the shell), each balanced alone. This pass plays
whole sagas with the stand-in players and fixes what is broken,
degenerate or dull across systems with the smallest rule changes that
work. Branch `balance`, worktree `/home/user/wt-balance`.

The stand-in player (`JourneyBot`) is the instrument. Reading its sagas
showed that about half of what the batches called balance was the bot
being foolish in ways a person would not (a band stranded on an island
with a boat too small for it, a ping-pong between two halls for a
hundred days, a green leader going out against seasoned berserks after
every loss). Those were fixed in the bot first; then the rules.

## How it was measured

- `tools/batch_ways.gd -- 8 5 <seed> all <origin>` for the burned hall,
  the younger son and the freedman, seeds 1 and 101 (48 sagas a bent,
  five years each). New columns (a `worth:` and a `more:` line under
  each bent): WORTH a year (silver, land at `land_price`, the hull at
  its price), worth and men by year, luck at the end (mean, and how
  many at 8+ and at 2-), friends and ill-wishers among the houses, feuds
  open, men hired, ounces got for captives, the most men any saga had,
  and the fights' outcome ladder (routed them / drove them off / won the
  field / both drew off / withdrew / driven off / routed / lost the
  field, a saga). A sixth word `ransom` makes the raider ransom his
  captives instead of selling them (`JourneyBot.slaver`).
- `tools/batch_generations.gd -- 4 40 1 3 <bent> burned_hall` for the
  Viking, the trader and the law-wise man: now with a sample every five
  years (men, silver, luck, land, Iceland, outlawry) and what the hall's
  standing word answered while the years passed.
- `tools/diag_saga_fights.gd -- 40 1` with three new rows: `deck_board_edge`
  (boarding with half as many men again, the player's case) and
  `fire_bar_even` / `fire_meet_even` (the fire in the night between equal
  bands); `tools/diag_escape.gd -- 30`; `tools/diag_mixed.gd -- 40 1` and
  `tools/diag_identity.gd -- 20 1` before and after.
- `tools/saga_trace.gd` (new): one saga read year by year.
  `-- <seed> <bent> <origin> <years> [full|brief] [let_years] [escape]`.
  Each summer the deeds in order (runs of the same deed counted), every
  decision with its text, what the bot answered and what was open (marked
  `[ONE ANSWER]` / `[NO ANSWER OPEN]`), every fight and its outcome, the
  winter (lodging, the talk, silver, food, men and luck before and
  after), and the year's reckoning (silver, food, men, land, fame, honor,
  luck, friends, ill-wishers, feuds, captives, thralls, fights, deaths,
  captive silver) with `ODD:` lines for a deed taken that was not offered
  or was greyed, a year with no silver gained, a negative number, a stat
  out of range, three or more houses at the end of the standing scale, a
  year of coming and going with little done, a dozen idle waits, and an
  action listed all saga but never open. "full" prints every line the
  saga said and, on the first free day, every action with its hint;
  "escape" begins with the burned hall's escape told by the dice. At the
  end: every house's standing, and each action's open/listed count.
  Hooks it needs in the sim: `Journey.trace_acts` / `Journey.acts` (off
  unless a tool sets it), `Campaign.tally["outcome:<n>"]`,
  `band.law["sold_oz"]`. The trace looks at the actions every step, which
  rolls a place's offers earlier than the batch would: a traced saga is a
  saga like the batch's of the same seed, not the same one.

## Before and after

"Before" is `main` at 3051324 (the eight packages merged); "after" is this
branch. Six origin-and-seed blocks of eight five-year sagas a bent (48 a
bent). Worth a year is the gain in silver, land at its price and the hull
at its price, over the years lived; luck "(8+ of 16)" counts the sagas of
the two seed blocks that ended at luck 8 or more; "avenged y5" counts the
burned hall's sagas that had their vengeance by the fifth year (of 16).
No saga of the 576 ended, before or after; no stall anywhere.

| Bent | origin | worth/yr before (s1 / s101) | after | silver/yr before | after | men y5 before | after | most men before | after | luck before (8+ of 16) | after | honor before | after | fights/yr before | after | avenged y5 before | after | outlawed (still) before | after | captives sold (oz) before | after |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | burned hall | +105 / +146 | +201 / +164 | +78 / +109 | +159 / +107 | 16.6 / 17.8 | 24.5 / 22.9 | 20 / 21 | 24 / 27 | 8.9 (15) | 6.0 (1) | 39 | 24 | 9.8 | 10.4 | 10 | 10 | 1 (0) | 1 (1) | 36 (358) | 47 (403) |
| Trader | burned hall | +86 / +75 | +170 / +171 | +34 / +27 | +92 / +84 | 8.6 / 7.5 | 8.1 / 8.4 | 11 / 9 | 10 / 10 | 5.0 (4) | 5.3 (0) | 51 | 52 | 3.0 | 2.3 | 8 | 3 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Law-wise man | burned hall | +97 / +137 | +146 / +173 | +26 / +61 | +76 / +92 | 10.6 / 11.4 | 10.8 / 10.9 | 12 / 11 | 12 / 12 | 7.2 (6) | 5.8 (0) | 97 | 100 | 3.6 | 2.1 | 15 | 9 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Berserk | burned hall | +60 / +82 | +197 / +186 | +32 / +51 | +133 / +132 | 12.6 / 12.5 | 13.0 / 13.0 | 17 / 16 | 19 / 19 | 7.7 (11) | 6.1 (0) | 16 | 40 | 7.4 | 5.8 | 5 | 9 | 5 (3) | 1 (1) | 0 (0) | 0 (0) |
| Skald | burned hall | +115 / +115 | +132 / +174 | +66 / +73 | +72 / +111 | 15.2 / 13.5 | 16.4 / 15.8 | 16 / 16 | 18 / 18 | 5.2 (2) | 5.7 (0) | 58 | 60 | 3.8 | 2.2 | 12 | 11 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| King's man | burned hall | +118 / +98 | +140 / +121 | +60 / +49 | +73 / +59 | 16.8 / 15.4 | 16.6 / 17.0 | 16 / 16 | 19 / 21 | 8.8 (13) | 6.4 (0) | 40 | 48 | 6.2 | 3.7 | 7 | 16 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Viking | younger son | +184 / +173 | +168 / +187 | +130 / +134 | +116 / +112 | 17.9 / 18.6 | 25.0 / 27.2 | 22 / 20 | 30 / 32 | 8.6 (12) | 5.8 (1) | 18 | 12 | 12.3 | 10.0 | 0 | 0 | 2 (0) | 3 (2) | 48 (466) | 46 (404) |
| Trader | younger son | +115 / +130 | +191 / +187 | +62 / +66 | +105 / +100 | 8.2 / 8.2 | 8.9 / 8.2 | 9 / 9 | 10 / 8 | 6.0 (2) | 6.0 (0) | 50 | 50 | 0.9 | 0.8 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Law-wise man | younger son | +125 / +132 | +130 / +169 | +55 / +71 | +62 / +98 | 11.1 / 9.8 | 9.9 / 9.9 | 13 / 12 | 11 / 12 | 6.5 (5) | 5.5 (0) | 96 | 98 | 1.6 | 0.9 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Berserk | younger son | +50 / +46 | +146 / +138 | +20 / +17 | +100 / +94 | 14.1 / 12.1 | 10.8 / 10.2 | 16 / 16 | 12 / 14 | 9.0 (14) | 5.7 (0) | 12 | 31 | 7.5 | 3.9 | 0 | 0 | 8 (2) | 3 (2) | 0 (0) | 0 (0) |
| Skald | younger son | +164 / +135 | +133 / +143 | +100 / +88 | +83 / +85 | 15.8 / 14.1 | 12.9 / 14.4 | 16 / 16 | 16 / 17 | 6.8 (8) | 6.0 (0) | 56 | 61 | 1.7 | 1.1 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| King's man | younger son | +151 / +127 | +174 / +145 | +84 / +74 | +89 / +77 | 16.1 / 15.4 | 18.1 / 19.5 | 16 / 19 | 25 / 24 | 9.3 (15) | 6.3 (1) | 43 | 47 | 3.8 | 3.0 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Viking | freedman | +103 / +122 | +180 / +166 | +64 / +90 | +122 / +120 | 17.2 / 16.8 | 26.0 / 24.8 | 18 / 17 | 32 / 25 | 9.4 (16) | 6.5 (3) | 29 | 17 | 8.3 | 9.7 | 0 | 0 | 1 (1) | 1 (0) | 36 (353) | 46 (391) |
| Trader | freedman | +102 / +115 | +153 / +156 | +53 / +59 | +81 / +79 | 8.8 / 8.8 | 9.1 / 8.2 | 11 / 11 | 10 / 9 | 5.8 (2) | 5.5 (0) | 49 | 48 | 0.9 | 0.9 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Law-wise man | freedman | +97 / +103 | +119 / +117 | +46 / +41 | +60 / +56 | 9.9 / 10.1 | 10.2 / 9.9 | 12 / 11 | 14 / 12 | 6.3 (6) | 5.7 (0) | 88 | 92 | 1.7 | 1.2 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Berserk | freedman | +61 / +28 | +126 / +122 | +36 / +16 | +102 / +88 | 7.9 / 9.6 | 9.9 / 10.0 | 10 / 14 | 11 / 12 | 4.7 (4) | 5.6 (0) | 14 | 23 | 5.6 | 4.1 | 0 | 0 | 5 (1) | 1 (0) | 0 (0) | 0 (0) |
| Skald | freedman | +88 / +92 | +108 / +101 | +50 / +45 | +62 / +50 | 12.8 / 13.0 | 13.6 / 13.1 | 16 / 16 | 17 / 17 | 6.5 (4) | 5.8 (0) | 55 | 55 | 1.3 | 1.0 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| King's man | freedman | +117 / +136 | +146 / +152 | +67 / +74 | +89 / +85 | 13.9 / 16.0 | 17.4 / 16.1 | 16 / 16 | 23 / 21 | 8.3 (13) | 6.0 (0) | 40 | 47 | 4.0 | 2.9 | 0 | 0 | 0 (0) | 0 (0) | 0 (0) | 0 (0) |

The full tables (every column the tool prints, a block per origin and
seed) are under "The full tables" at the end. "After" was measured at
045ec63. The commits after it change the stand-in's band size beyond
what his bent wants (no five-year saga reaches that), end the one stall
of those batches, and touch the saga's telling and two hints; re-measured
where they could matter: the burned hall's trader, seed 101, +79 silver a
year with no stall (the table's +84 had one stalled saga), and the
berserk over ten years +251 worth a year with no stall (+246, one stall).
The forty-year runs below were made after them.

Ten years from the burned hall (`batch_ways -- 6 10 1 all burned_hall`), the
vengeance by year, luck and outlaws:

| Bent | avenged y1..y10 before | after | luck at 10 before (8+ of 6) | after | outlawed (still at 10) before | after | worth a year before | after |
|---|---|---|---|---|---|---|---|---|
| Viking | 0/1/1/2/2/4/4/4/4/5 | 1/3/4/5/5/5/5/5/5/5 | 8.8 (5) | 6.3 (1) | 0 (0) | 1 (0) | +122 | +172 |
| Trader | 0/1/2/2/3/3/4/4/5/5 | 0/0/1/1/2/3/3/3/4/5 | 8.0 (5) | 5.8 (0) | 0 | 0 | +124 | +198 |
| Law-wise man | 0/0/1/3/5/6/6/6/6/6 | 0/0/2/5/5/5/6/6/6/6 | 9.2 (6) | 5.2 (0) | 0 | 0 | +161 | +177 |
| Berserk | 0/0/0/0/0/3/4/5/5/5 | 0/0/0/1/4/6/6/5/5/5 | 8.7 (5) | 6.2 (0) | 3 (2) | 0 | +137 | +246 |
| Skald | 0/0/2/2/3/4/5/5/5/5 | 0/0/1/2/3/4/6/6/6/6 | 6.2 (2) | 5.7 (0) | 0 | 0 | +101 | +144 |
| King's man | 0/0/0/1/1/2/4/4/5/5 | 0/0/6/6/6/6/6/6/6/6 | 9.5 (6) | 6.7 (2) | 0 | 0 | +162 | +125 |

(A count that falls, as the berserk's 6 to 5, is a saga whose leader died
and whose heir swore a new vengeance at the grave-ale.)

## The problems, one by one

### 1. Captives were the dominant income

*Found.* From the burned hall the Viking took 323 oz for 32 captives in
five years (seed 1; 422 oz for 42 from the younger son), more than half of
his worth gained. A place's glut cleared every spring and Dublin paid 18
for the first head of each year, so the three slave markets bought every
captive of a summer; captives cost nothing to hold. Also a bug: "Send to
their kin for ransom" ransomed every captive the band held, of every
house, to the house of the last raid.

*Changed* (`WorldRules`, "Slaving pays, but it is not the best living";
`Thralls`, `Market.cargo_room`, `Journey.foot_speed`):
- the market is a stock: each head sold lowers the next by
  `captive_glut` 0.15 (was 0.1), and the glut mends a head every
  `captive_mend_days` 15 instead of only at the year's end, so a market
  buys a few a season (Dublin buys seven for 70 oz before its price is
  nothing; it used to take ten for 99 and every head of the summer);
- captives are a burden: every `captive_load` 2 take a load of the band's
  room (loot it cannot carry), each slips away on a day with
  `captive_flight_day` 0.006 (twice that past `captives_per_guard` 2 to a
  man), more captives than men slow the march `captive_slow` 0.03 a head
  over, to `captive_slow_floor` 0.7;
- every `sell_honor_heads` 4 heads sold cost a point of honor (the -3
  standing a head with their house, -20 and honor -3 for a named woman,
  are as before);
- their kin ransom only their own people (`Thralls._of_house`);
- the decision's hint says all of this.

*Measured* (16 younger-son Viking sagas, five years, seed 1; the ransomer
is the same bot told to ransom): the slaver ends five years
with worth +179 a year, 562 oz in hand, 47.7 heads sold for 419 oz, honor
12, outlawed in 3 sagas of 16 (2 still); the ransomer +216 a year, 690
oz, honor 57, 5.4 thralls working his land, outlawed in 2 (1). Selling now
earns about four fifths of ransoming: the voyage to Dublin and back and
the people who slip away on the road are the cost, and the honor is paid
in full. (Before, nothing was set against the market: the younger son's
Viking sold 48 heads a saga for 466 oz on average over the two seed
blocks, the glut clearing every spring; after, 46 for 404, and he gives up
the ransomer's honor and standing to get them.)

### 2. Luck snowballed

*Found.* Seven of eight Vikings ended five years at luck 8 or more (mean
8.2 from the burned hall, 9.4 from the freedman); the king's man 9.2, the
berserk 9.9 from the younger son. In forty-year sagas luck sat at 10 for
decades. A win added a point at any luck and luck raised the odds of
winning.

*Changed* (`CampaignRules` "Luck wanders"; `Leader.on_battle`,
`Leader.winter_drift`, `Journey._after_burning`): a plain win at
`luck_crest` 7 or more lifts luck only by chance, `luck_crest_chance`
0.25 at the crest, its square a point above and so on (the campaign
passes the fight's seeded rng; old callers without one get none); a win
against the odds still lifts it, a point less at the crest; at each thaw
on the map luck drifts a point toward the middle from above
`luck_drift_high` 6 or below `luck_drift_low` 4; burning men in their
hall costs `luck_burning` 1 ("Men say no luck comes of a burning"). Ill
luck from omens ignored, oaths and vows broken and hanging back was
already there and is kept.

*Measured:* mean luck at five years 5.3 to 6.5 for every bent and
origin (before 4.7 to 9.4); sagas at 8 or more, of 16 a bent and origin,
0 to 3 (before: Viking 12 to 16, king's man 13 to 15, berserk 4 to 14,
law-wise man 5 to 6). Over ten years from the burned hall 3 of 36 end at 8
or more (before 29 of 36); over forty years the samples wander between 4
and 8 (before they sat at 9 or 10 for decades). No leader ends at 2 or
less in the batches: ill luck comes in single points (a lost fight, an
omen come true, the burning) and the thaw forgives it.

### 3. Bands grew without bound

*Found.* Forty-year Viking sagas ended with 33 to 55 men (104 in one);
five-year Vikings had up to 22. Men who asked to join after a fight, men
lent by friends and a freed captive who would follow were not capped;
`recruit_cap` 16 capped only hiring and the winter's recruits.

*Changed:* `Campaign.room()`: the most men the band can keep is its
hall's seats or its hull's crew, whichever is more, never under
`room_min` 8 nor over `room_max` 40, and below a hersir never over
`room_max_karl` 24, a snekkja's crew: no hull a karl can buy carries more,
and before this a band of 38 benches and no hull to carry it rowed between
Gotland and Birka on other men's ships for a summer (`CampaignRules`; the
plain campaign without a map keeps `recruit_cap`). Every way a man comes now
asks it: the winter's recruits and the outlaw at the door, men for hire
(greyed, "You have no bench or oar for another man: N is all your hall
and hull will hold."), friends' lent men (fewer, or not offered), a
survivor of a wreck, a freed captive, a man who saw the fight
(`Aftermath.apply`'s new `room`). The winter's men step says when the band
is past its hull or its benches. The longship (forty at her oars) is now
for sale at halls and towns, to a hersir or better (`longship_rank`): a
great band is a lord's. The stand-in lets go the least loyal men beyond
the room, or beyond what a man of his bent wants about him, at the winter
(never his second, war-leader, a son, a lent man or a man he gave a gift),
takes on no more men at the hall than his hull will carry unless he can
buy a bigger one, builds benches at his own hall before his men outgrow
them, and buys a longship as a lord.

*Measured:* five years, the most men any saga had: Viking 24 to 32
(the 30 and 32 are sagas whose leader was made a hersir: below that a
band holds 24, a snekkja's crew), the king's man 19 to 25, the others 8 to
19 (before 9 to 22 with nothing holding them). Forty years
(`batch_generations -- 4 40 1 3`, the final stand-in): the Viking 24 (a
karl) to 40 (a hersir with his benches or a longship), never more; the
trader 13 to 25, the law-wise man 18 to 31 (before 104 at most, and 33 to
55 for the Viking letting years pass). With the room alone the quiet
years' recruits filled every band to its ceiling (trader and law-wise man
at forty, eating their chests to nothing); the stand-in now lets go the
men his bent does not want about him (`JourneyBot._band_wanted`: Viking
40, king's man 30, berserk 20, skald 18, law-wise man 16, trader 14).

### 4. The years stopped too often

*Found.* Over four 40-year Viking sagas letting three years each spring,
the years stopped for houses 15, 13, 22 and 14 times, so only 3 to 8
years passed in a saga. Wergild offered for any feud and a friend's
daughter stopped them, and so did a call for help from any house bound
to his, fostering included (the stand-in takes every fosterling, so half
the country was bound to him).

*Changed:* a standing word left with the hall at the spring step, beside
the years: *Ask me* (as before), *Accept fair offers* (fair wergild taken,
a friend's daughter married), *Refuse offers* (wergild let lie, the feud
still open; the match declined with thanks). The burned hall's wergild is
never taken unasked. A call for help from a house bound by blood or
marriage still stops the years; a fostering house's waits a year like any
other house's. Attacks on the hall, the realm's matters, the children,
the vow, the stores and death stop them as before. `Years.OFFERS`,
`Years._standing_answer`, `WinterHall.years_offers`, choice
`offers:<word>`; the stand-in leaves "accept".

*Measured:* four forty-year sagas a bent letting three years each
spring: years let pass a saga, Viking 14.5 (before 5.5), trader 20.0
(10.8), law-wise man 19.0 (13.5). Stops for houses over the four sagas:
Viking 13, 4, 6, 6 (before 15, 13, 22, 14), trader 5, 1, 5, 3 (19, 13, 17,
6), law-wise man 0, 1, 3, 3 (9, 3, 18, 7); the hall's word answered 1 to
4 offers a saga. The other stops are as meant: the realm (5 or 6 a saga),
sons and daughters (4 to 9), an attack on the hall (1 to 5), and, for a
big band living on a thin chest, the stores (3 to 5). Every saga reached
906 to 908 with two to five generations (Viking 3.0 a saga, trader 2.0
to 2.2, law-wise man 2.0); the law-wise man settled in Iceland in eight
of eight, the trader in three of eight.

### 5. The holmgang for the high seat was a foregone loss

*Found.* `test_challenge_is_a_holmgang`: the heir lost 12 of 12 to a much
stronger second; buying him off was a flat 30 oz.

*Changed* (`Journey._challenge_options`, `Succession.champion_for`,
`backing`, `buyoff_price`; `CampaignRules` "The heir's honest ways"): the
challenge card offers *Meet him on the island* (with a read of both men),
*Let <champion> stand for you* (the band's best loyal, whole fighter who is
not the challenger's oath brother goes to the island; won, the seat is the
heir's; honor -5 either way), *Look to the men* (open only when three men
in five, his rival and his oath brothers not counted, hold loyalty 60 or
more to a son of the blood: the challenger backs down and drinks the cup,
loyalty -10; greyed with how many hold to you when not), *Buy his goodwill*
at 30 oz and 10 a tier, times what he wants (silver 0.7, home 0.8,
vengeance and a wife 1, land 1.2, fame 2: a man who wants fame wants the
seat itself), and *Let him go*. `Campaign.build_duel` takes a champion.

*Measured:* `test_balance::test_the_challenge_is_no_foregone_loss`, the same
twelve seeds as the old test (a strong second, a son of fifteen, a band of
six), the stand-in heir answering: he keeps the seat 7 of 12, all seven by
the men's loyalty; the other five went to the island and lost (no champion
there was better than the challenger and the chest could not spare twice
his price). The old test, the heir always fighting, still loses 12 of 12:
the island itself is unchanged.

### 6. Barring the door against fire; boarding a deck

*Found.* Barring the door against fire lost 0 of 40, but the diagnostic
pits 9 green men against 10 veterans. Between equal bands (new row
`fire_bar_even`) barring wins 30 of 40 and going out 40 of 40: barring is
already the gamble, and it is a death against a stronger burning party
(the campaign's are 7 to 13 veterans). Going out wins because the burners
seldom close with a band that comes out to meet them. Holding the gable
ends (two men at each end, tried in `Scenario.build_hall_defence`) cut
the roof's taking against the veterans from 23 to 6 of 40 but routed the
thinned front line, and lost the even fight 31 of 40, so it was taken out
again. Boarding: a 3:2 edge won 31 of 40 at three-wide gangways.

*Changed:* the fire's choices say what they are: going out, "Burners
seldom close with a band that comes out to meet them"; barring, "The gable
ends are open to their torches unless you send men to them: against as
many as you it is a fair hope, against more it is a death." The gangway
is two hexes wide (`CombatRules.deck_gangway` 2, was 3): boarding with half
as many men again is now about even.

*Measured:* `diag_saga_fights -- 40 1` (AI against AI; ours / theirs of 40):

| fight | before | after |
|---|---|---|
| deck, we board, 12 against 12 | 8 / 32 | 2 / 38 |
| deck, we board, 12 against 8 (new row) | 31 / 9 (gangway 3) | 21 / 19 |
| deck, they board, 12 against 12 | 27 / 13 | 32 / 8 |
| fire in the night, bar, 9 green against 10 veterans | 0 / 40 | 0 / 40 |
| fire in the night, meet, the same | 36 / 4 | 36 / 4 |
| fire in the night, bar, 9 against 9 green (new row) | 30 / 10 | 30 / 10 |
| fire in the night, meet, 9 against 9 green (new row) | 40 / 0 | 40 / 0 |
| tried: bar with two men at each gable end, against the veterans | | 0 / 40 (the roof took 6, was 23; routed 28) |
| tried: the same between equal bands | | 9 / 31 |

Every other row (the raid, the yard's three answers, the burning, the
break-out) is as before. Boarding is the only ordinary-looking fight
touched, and only on the deck scenario: `diag_mixed -- 40 1` ("TOTAL 40
fights, 13 wins (32%)") and `diag_identity -- 20 1` ("ALL 3653817781")
are byte-identical before and after; `diag_escape -- 30` is unchanged
(following the tutorial 27 of 30 out on his feet, skipping 21, doing
nothing 3, charging 2).

### 7. The ways' worth

*Found* (worth a year, seed 1 / seed 101, burned hall, younger son,
freedman): Viking +105/+146, +184/+173, +103/+122;
trader +86/+75, +115/+130, +102/+115; law-wise man +97/+137, +125/+132,
+97/+103; berserk +60/+82, +50/+46, +61/+28; skald +115/+115, +164/+135,
+88/+92; king's man +118/+98, +151/+127, +117/+136. The berserk was the poorest, by a factor of
two to five against the best of his origin, and mostly because his stand-in called out every house in
Norway in his first summer (ten overbearing challenges: honor 50 to 17,
nine ill-wishers) and went out as a farmer's champion after every loss;
the trader's thin years came from a bot that took friends' lent men past
his hull and so bought a snekkja he could not crew; the skald's and the
freedman's thin years from a band stranded with a færing too small for
it; everybody's idle weeks from a hundred-day ping-pong between two
ill-wishers' halls (the bot's fallback "a hall I have not asked for work"
never remembered that an ill-wisher has none).

*Changed:* the bot (below), and one rule with character in it: a
merchant pays more for a berserk's guard (`escort_pay` 1.2, 1.35, 1.5 on
his three steps, the dread a merchant buys).

*Measured:* worth a year, seed 1 / seed 101: Viking +201/+164,
+168/+187, +180/+166; trader +170/+171, +191/+187, +153/+156; law-wise man
+146/+173, +130/+169, +119/+117; berserk +197/+186, +146/+138, +126/+122;
skald +132/+174, +133/+143, +108/+101; king's man +140/+121, +174/+145,
+146/+152. The richest bent of an origin earns 1.5 to 1.8 times the
poorest (before 2.4 to 4.9). Their character is kept: the Viking still
fights ten times a year and keeps the lowest honor (12 to 24), the
law-wise man fights once or twice and keeps honor 92 to 100, the trader
the fewest fights and the most land, the skald the most friends, the
king's man the most fame for his silver; the berserk is the most varied
(champion, guard, a few challenges) and keeps honor 23 to 40, not 12 to
16.

### 8. The winter's ring-giving and a poor band

*Found.* The miser's penalty (every man -6 loyalty, honor -2) came at
under an ounce a man from a chest of 20 or more: with six men and 20 oz,
6 oz (a third of the chest) to avoid it; a man of great deeds given
nothing took it ill (-10) whatever the chest held. The stand-in gave
nothing below 30 oz.

*Changed:* `WinterHall.miser_line`: no more is expected than
`miser_chest_share` 0.1 of the chest (six men from 20 oz: 2 oz), and a man
of great deeds is not passed over from a chest under `miser_chest` 20. The
ring-giving note says what would do. The stand-in gives a ring to the man
of greatest deeds, then the least loyal, until the line is met.

*Measured:* from the freedman and the burned hall every saga lived five
years, and departures at the first two thaws are as before:
the bands grow from about four men at the first thaw to five or six at the
second (the freedman's and the burned hall's non-raiders, before and
after alike), and the miser's line now asks 2 to 4 oz of a thin chest
instead of a third of it.

### 9. The vengeance

*Found.* By year 10 (six sagas a bent, burned hall) every bent had it in
five or six sagas of six (Viking 5, trader 5, law-wise man 6, berserk 5,
skald 5, king's man 5; the table above): the law-wise man five by year 5,
the others five between years 7 and 10. It is reachable by every bent; the
king's man had no road of his own, and nothing told the player what he
still lacked.

*Changed:* `Journey.vengeance_outlook()` for the view: `{owed, house, ours,
theirs, ready, short, friends, allies, could_win: [{house, men, standing,
need}], reckoning_men, your_men, reckoning_ready, king_ready, lines}`, the
lines in words ("At the Thing you could bring 7 men to their 12: 3 more
spears and they would have to answer.", "Ivar's kin are their enemies and
would send 3 men as your friends (standing 20, 30 to go).", "At their hall
they would stand 9 men against your 6.", "A king would judge it for his
jarl if he thought well of him (his regard 35 of 60; you are not yet
one)."). The king's man's road: *Ask <king> for justice against <house>*
at a king's hall, for a jarl or better the king regards 60 or more
(`king_justice_*`): the king summons them, they pay 60 oz of which he keeps
half, the feud is ended by his word (the vengeance taken), his regard -15;
greyed with why otherwise ("Harald Fairhair hears such a matter only from
his great men: you are not yet his jarl."). The stand-in king's man goes to
the king when he can. In four traced king's-man sagas from the burned hall
he had his vengeance by the king's word in his third summer, whether the
rule asked a hersir and regard 50 (tried first), 70, or a jarl and 60; a
jarl and regard 80 put it in his third to fifth. The king's man's rank and
the king's regard come fast (a lord's work counts threefold toward rank),
so neither is much of a brake; see "Still off". Kept at a jarl and 60.

*Measured:* by year 10 the Viking 5 of 6, trader 5, law-wise
man 6, berserk 5 (6 at year 6, one heir's new vengeance owed), skald 6,
king's man 6 (all by year 3, by the king's word). By year 5 over the two
burned-hall seed blocks (16 a bent): Viking 10, trader 3, law-wise man 9,
berserk 9, skald 11, king's man 16 (before 10, 8, 15, 5, 12, 7): the arc
is as long as before for all but the king's man, whose road is quick (see
"Still off").

### 10. Outlaws

*Found.* Outlawed stand-ins seldom bought a pardon (they never went to a
king's hall for it), and an outlaw kept his Norwegian land and its yield.

*Changed:* a full outlaw's land in Norway is kept by his wife's kin (it
yields him nothing until his peace is made, then it is his again) or,
with no wife, taken by the king (`Landtake.outlaw_land`, each spring and
at a pardon); land abroad and in Iceland is his still. The stand-in outlaw
makes for the nearest king's hall he knows when he has the pardon's price
and 30 over, or six men to offer his sword (`Outlawry.pardon_road`).

*Measured:* five years, 48 sagas a bent: the berserk was outlawed
in 18 sagas before and 5 after (still an outlaw at the end: 6 before, 3
after); the Viking in 4 before and 5 after (1 and 3 still). Over ten years
from the burned hall: before, 3 berserk sagas outlawed and 2 still at the
end; after, 1 Viking saga outlawed and none still. A traced Viking (seed
2) was outlawed by the Thing in 870 for a summons he did not answer and
bought the king's pardon at Fitjar the next summer; another (seed 1),
before the stand-in asked at the hall he stood in, rowed between Borre and
Kaupang, two of the king's halls, all summer without asking at either. In
the forty-year sagas one Viking who plays every summer is outlawed again
and again by the Thing (summonses ignored, honor near nothing) and is an
outlaw in most of his later samples: the roads work, he keeps earning new
sentences. The law-wise man settles in Iceland in every forty-year saga.

### 11. The first hour

Traced in full (`saga_trace -- 5 lawman burned_hall 1 full 0 escape` and
the same for the Viking): after the escape told by the dice Egil is at
the Sogn farms with 10 oz, two men, one of them too hurt to fight. On the
first free day: rest (6 days) or rest with his kin (4 days, two turns of
healing), labour (6 days, 5 oz and 6 rations), the herds (12 days, 5 oz,
8 rations, the country learned), fishing (4 days, 10 rations, 2 oz), his
kin's furs carried to Giske for a share (about 14 oz, 7 days), a man for
hire (4 oz), a man lent by his kin, a gift (10 oz), passage to Sogndal (5
oz, a hall: counsel, a verse, a place at another man's oars), buying
rations. That is four sound opening lines (labour and the herds and the
nets; the pack-trade; words at a hall a day away; another man's oars) and
none of them a trap. The first fight offered both bots was a rival ship of
6 to 8 men on day 12 with "fade away" open, taken without loss. Dead ends
looked for over 108 four-year traces (every bent, origin, six seeds):
no action listed and never open except those greyed with a reason (land
too dear, the burners' case before the Thing has backing, wergild not in
the chest, the king's justice for a man who is not yet his jarl); no place
with nothing to do; one decision with a single answer that is not a
telling (the king's ships' toll when the chest is empty: refusing is the
only answer, and half the time they come on; the toll's answers now say
so: "You have not the silver." and "The king's men will remember it, and
as often as not they come on.").

### 12. Found in the traces

- Standings were pinned at the ends of the scale: a five-year Viking had
  seven houses at -100, a skald six at +100, so a further deed counted for
  nothing. Each year a house's regard beyond `standing_fade_from` 60 moves
  `standing_fade` 0.2 of the way back to it (`Families.year_end`): a
  friend stays a friend, but 100 is not for ever.
- A lord's work that was a fight was offered to a lone freedman with no
  word of the fight; the hint now says "It is a fight: about 5 blooded men
  against your 1."
- The farmer's champion's hint gave no read of the man: it now says he is
  a seasoned man with the fury on him, and to a leader not seasoned
  himself that few such come back whole.
- An ill-wisher's hall now remembers it has no work for him this summer
  (`Journey._work_here`), which ended the bots' ping-pong.

## The stand-in player, made less foolish

What a person would not do, fixed in `JourneyBot` before anything was
tuned: taking passage when his own boat cannot carry the band (he only
took it with no boat at all, and sat on Orkney for three summers);
taking friends' lent men past what his hull carries; counting lent men
when buying a hull; going out as a farmer's champion while hurt, green,
or after a loss that summer (and not travelling to such a farm then);
raiding seasoned defenders at the odds he takes against farmers (green
1.2:1, blooded 0.8, veterans 0.6); a berserk's three overbearing
challenges a summer, not a country's worth, and the farmer's champion
first; a lord's work only when the band can do it; seeking the king's
pardon; letting men go he cannot seat; not taking on men he cannot
carry; a ring for the man of deeds from a thin chest; benches, a
storehouse and a byre at his own hall; land up to six units; a longship
as a lord; a watch on his ship once she has been taken from him (once a
place a summer); going where there are fields to work instead of
listening for weeks; the grave-ale's challenge answered by the men, by
silver, by a champion, or the island; keeping the band his bent wants
(no trader feeds forty); a passage at most once a fortnight (a shipless
band of 38 took passage back and forth between Ribe and Hedeby, 162 oz a
time, all summer); asking the king's pardon at the king's hall he stands
in before going on to the next (he rowed between Borre and Kaupang); and
never "going" where he already is (the one stall of the final batches: a
ship foundered on the way to where a guarded merchant was bound, the band
came ashore there, and the guard was never paid off; now it is, ashore).

## Reading the sagas (designer notes)

Read as a player would read his own saga, with `tools/saga_trace.gd` over
every bent and origin (108 four-year sagas, and longer ones where something
looked wrong). What a person playing would have found broken, unfair,
repetitive or exploitable, most of it before the fixes above:

- *The band too big for its boat* (skald, freedman, seed 3). From his second
  summer on Orkney and then on the Seine: five men and a færing that carries
  four, thirty "Wait and listen" a summer, 2 to 37 oz for four years. The
  hall took on the winter's men without a word about the boat; now the
  men's step says "Your færing carries 4 at her oars; with 5 men you will
  not put to sea in her". Fixed in the bot too, the same saga made 401 oz by
  its third year.
- *A country's worth of challenges* (berserk, younger son, seed 2). Ten
  overbearing holmgangs in the first summer, honor 50 to 21 and nine
  ill-wishers; then a hundred days rowing between Fitjar and Avaldsnes, two
  ill-wishers' halls, doing nothing. The rule (each challenge costs honor and
  the hint says so) was right; a player would have stopped long before.
- *The farmer's champion* (Viking, burned hall, seed 1). A green leader went
  out against seasoned berserks six times in a summer, hurt or not, and was
  blooded five times at 12 oz each: the action never said what the man on
  the island was. The hint now does.
- *Raiding seasoned men* (Viking, burned hall, seed 2): with twelve men he
  raided Orkney (11 blooded), the Seine camp (12 blooded) and Lade (14
  veterans) and lost all three; Egil fell at the Seine in his second summer.
  The scout's report said "Seasoned men, he says"; the bot did not read it.
- *A snekkja for a pedlar* (trader, younger son, seed 3): his friends lent
  him men (they come "for the summer and after"), the band outgrew its
  knarr, he bought a snekkja that needs ten at the oars, the lent men went
  home in the autumn, and he walked for two years.
- *A lord's work that is a fight*, offered to a freedman alone ("hunt the
  outlaws troubling Sogndal"), taken, faded from, failed, the lord's regard
  lost: the label said only "about 10 days". It now says the fight.
- *Seven houses at -100* after five years of raiding (and six at +100 for
  the skald): nothing he did moved them. Memory now fades at the ends.
- *The saga as a list*: one year's chapter read "X and Y mixed their blood
  under the turf and swore to avenge each other" seven times, and "Egil
  heeded an omen." twice; the saga now counts the pairs and tells a line
  once a year.
- *Luck*: every raider was "a thing to follow" by his third summer and
  stayed so for decades; the luck line under every fight said the same.
- *The captives' decision* showed every captive held, not the raid's ("14
  people of the Trøndelag farms are bound on the strand" after a raid that
  took three), and ransom paid for all of them to the last house raided.
- *Hoards*: forty-year sagas end with 2000 to 11000 oz and nothing to buy
  (see "Still off").
- What reads well: the first summer is a real small-man's summer (fields,
  nets, a partner's furs, a færing); the vengeance is a long arc for every
  bent; the grave-ale cards read like the sagas; the outlaw's and the
  Iceland roads are taken by the bots that need them; no stall anywhere.

## Still off, and why it was left

- *The rich have nothing to buy.* Forty-year sagas still end some lines
  with thousands of ounces (trader and law-wise man, playing every summer)
  while others end near nothing (a band of forty eats what it takes). Land
  is bought only from houses that will sell, the longship is one purchase,
  and gifts and feasts are small. A lord's spending (gifts to the king,
  ships and land for sons, feasts that hold a district, settlers for
  Iceland) is a design to make, not a number to turn.
- *The long-run Viking runs out of prey.* After ten years his raids find
  ill-wishers, alert coasts and poor farms, and some summers he waits a
  dozen times with nothing heard. A player would sail farther (Ireland,
  Frankia, the Baltic); the stand-in's targets are what he knows within a
  summer's reach. Not chased further.
- *The king's man's rank comes fast* (a lord's work counts threefold), so
  he is a jarl in three summers and his king's-justice road is the
  quickest to the vengeance. The rank pace is the ways' rule, not this
  pass's.
- *Barring the door against a stronger burning party* is still certain
  death in AI play: the leader AI never sends men to the gable ends.
  Teaching it is a battle-AI change, which this pass was not to make; the
  choice now says what it is.
- *Boarding at even numbers* is now a forlorn hope (2 of 40): sea fights
  go to the bigger crew. Intended, but a player who boards at even odds
  will lose almost every time; the scout's count is what saves him.
- *The slaver* earns about four fifths of the ransomer, not quite the
  same: the time it takes to carry people to Dublin and back is the cost,
  together with the honor. Left so: a slaver should pay for it.
- *Luck* now sits between 4 and 7 for nearly every leader; 8 and more is
  rare (a few in a hundred five-year sagas) and 2 and less rarer still.
  That is the target, but a player may find luck a quiet number. The crest
  chance (0.25) is the knob.
- *Years let pass* still stop for a blood or marriage kinsman's call for
  help and, for a band of forty, for stores that run out. The first is
  meant; the second is the band's size.
- *The first summer* is the same for every bent's stand-in (the furs, the
  fields, a færing). A person would differ by his own taste; the opening
  lines are there.
- *Winter here* is open on the first day of the first summer. A misplaced
  tap ends the summer; the hint says so, but it is a trap for a new player
  (the view could ask for a second tap before day 30).
- One deed taken that was not offered ("verse") in about 430 traced
  saga-years; not chased.
- The berserk's stand-in is rarely named the Berserk now (he guards, stands
  for farmers, counsels and speaks verse as much as he challenges); his
  guards now count as his deeds, which brings him some way back.

## Classes, functions and tunables

- `Campaign.room()`; `CampaignRules.room_min` 8, `room_max` 40,
  `room_max_karl` 24; `WorldRules.longship_rank` HERSIR.
- `Leader.winter_drift`, `Leader._win_luck`; `CampaignRules.luck_crest` 7,
  `luck_crest_chance` 0.25, `luck_drift_high` 6, `luck_drift_low` 4,
  `luck_burning` 1. `Leader.on_battle` takes an optional rng.
- `Thralls._captives_tick`, `Thralls.captive_pace`, `Thralls._of_house`;
  `WorldRules.captive_glut` 0.15 (was 0.1), `captive_mend_days` 15,
  `captive_load` 2, `captive_flight_day` 0.006, `captives_per_guard` 2,
  `captive_slow` 0.03, `captive_slow_floor` 0.7, `sell_honor_heads` 4.
- `Years.OFFERS`, `Years._standing_answer`; `WinterHall.years_offers`.
- `Succession.champion_for`, `backing`, `buyoff_price`;
  `Journey._challenge_options`; `Campaign.build_duel(opponent, seed,
  champion)`; `CampaignRules.challenge_champion_honor` 5,
  `challenge_backing_loyalty` 60, `challenge_backing_share` 0.6,
  `challenge_backed_down` 10, `challenge_buyoff_per_tier` 10,
  `challenge_buyoff_ambition`.
- `WinterHall.miser_line`; `CampaignRules.miser_chest_share` 0.1.
- `Landtake.outlaw_land`; `Outlawry.pardon_road`.
- `Journey.vengeance_outlook`, `Journey._king_justice`;
  `WorldRules.king_justice_relation` 60, `king_justice_rank` JARL,
  `king_justice_ounces` 60, `king_justice_share` 0.5, `king_justice_cost`
  15, `king_justice_days` 10.
- `WorldRules.standing_fade_from` 60, `standing_fade` 0.2.
- `CombatRules.deck_gangway` 2 (was 3).
- `Way` (berserk) `escort_pay` 1.2 / 1.35 / 1.5; a guard he leads is a berserk's deed (`TradeRoad.check_escort`).
- `JourneyBot.slaver`; `Journey.trace_acts`, `Journey.acts`.

## Tests

`tests/test_balance.gd` (new, 17 tests): the slave market fills and mends;
captives a burden and selling costs honor; kin ransom only their own; luck
crests (and by chance on the map) and drifts back; benches and thwarts are
the ceiling (hiring greyed with why, no lent men past it); the stand-in
lets go the men he cannot seat; offers answered by the hall's word; the
heir's honest answers; the challenge is no foregone loss (the stand-in heir
over twelve seeds); the benches judge by the chest; an outlaw's land forfeit
or held by kin; the stand-in outlaw seeks his peace; the vengeance outlook;
the king judges for his great man; the hall warns when the band outgrows its
boat; the saga tells oaths by the count and no line twice; no going where
he already is.

Pinned numbers changed in other files:
- `test_unfree.gd::test_sold_abroad_costs_standing_and_a_named_woman_honor`:
  selling three captives now also costs `ceil(3 / sell_honor_heads)` honor.
- `test_generations.gd`: `test_years_pass_deterministically` and
  `test_years_stop_for_the_spine` quiet the houses first (`_no_houses`):
  the stand-in's first year now leaves a feud whose wergild offer stopped
  the years before the thing under test; the kinsman's call in
  `test_years_stop_for_each_interrupt` is from a house tied by blood or
  marriage (a fostering house's call now waits) and is not crowded out by
  fosterlings (`asks_per_summer` 10).

The suite: `583 tests, 0 failed`, 5 min 16 s on this machine (others'
batches were running on it; the brief's "about 9 minutes" was not measured
here). `test_balance.gd` adds about 10 s, most of it two tests that play a
year with the stand-in. No slow test was made cheaper.

## The full tables

Before (`main`):

`ways_bh_1.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +78 | +105 | 133/298/351/480/534 | 8.0/11.9/15.0/16.1/16.6 | 2.8 | 77 | 45 | 8.2 (7/1) | 3.6/10.2 | 1.2 | 0/1/2/3/3 | 9.3 | 16.0/1.5/6.5/0.6/0.0/5.4/1.4/9.1 | 1 (0) | 0.0 | 0.0 | 32/323 | 4.2 | 20 |
| Trader | 8/8 | +34 | +86 | 83/191/278/334/440 | 4.0/5.0/5.6/7.1/8.6 | 3.0 | 42 | 50 | 5.8 (3/2) | 10.0/1.1 | 0.5 | 0/2/3/3/4 | 2.7 | 1.1/0.6/2.5/0.0/0.0/1.8/1.1/4.1 | 0 (0) | 1.6 | 0.0 | 0/0 | 0.0 | 11 |
| Law-wise man | 8/8 | +26 | +97 | 47/137/292/408/493 | 4.0/5.1/6.8/8.0/10.6 | 3.0 | 52 | 95 | 7.4 (3/0) | 10.8/0.6 | 0.1 | 0/0/2/4/7 | 3.5 | 2.2/0.4/1.5/0.6/0.0/0.1/1.6/5.9 | 0 (0) | 3.4 | 0.0 | 0/0 | 0.2 | 12 |
| Berserk | 8/8 | +32 | +60 | 63/136/213/254/312 | 4.0/5.8/7.5/9.8/12.6 | 2.5 | 68 | 16 | 7.9 (6/1) | 2.5/6.6 | 0.9 | 0/0/0/0/1 | 7.9 | 2.2/2.4/11.9/0.5/0.0/0.9/2.4/7.1 | 3 (2) | 1.2 | 0.1 | 0/0 | 0.0 | 17 |
| Skald | 8/8 | +66 | +115 | 123/171/280/449/583 | 4.2/5.4/8.2/11.8/15.2 | 2.8 | 90 | 60 | 5.2 (1/1) | 12.9/0.8 | 0.4 | 0/0/2/2/5 | 4.0 | 2.0/1.1/2.0/0.2/0.0/2.4/2.5/7.1 | 0 (0) | 1.6 | 0.0 | 0/0 | 0.0 | 16 |
| King's man | 8/8 | +60 | +118 | 79/277/405/571/602 | 4.0/7.5/11.4/14.8/16.8 | 3.0 | 91 | 47 | 9.2 (7/0) | 10.5/2.2 | 0.8 | 0/0/0/1/2 | 6.5 | 10.1/1.9/2.5/0.8/0.0/2.6/3.0/6.9 | 0 (0) | 2.5 | 0.0 | 0/0 | 2.9 | 16 |

`ways_bh_101.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +109 | +146 | 98/247/382/565/737 | 7.0/11.8/14.5/16.5/17.8 | 3.0 | 95 | 33 | 9.6 (8/0) | 3.9/12.9 | 1.5 | 0/0/1/5/7 | 10.3 | 17.4/2.4/9.0/0.2/0.0/7.5/1.8/6.1 | 0 (0) | 0.2 | 0.0 | 41/393 | 7.4 | 21 |
| Trader | 8/8 | +27 | +75 | 71/178/239/319/385 | 4.0/4.8/5.5/6.8/7.5 | 2.5 | 36 | 52 | 4.2 (1/3) | 9.6/0.8 | 0.5 | 0/1/2/4/4 | 3.4 | 1.2/1.0/1.2/0.9/0.0/1.8/3.0/5.6 | 0 (0) | 1.2 | 0.0 | 0/0 | 0.1 | 9 |
| Law-wise man | 8/8 | +61 | +137 | 61/142/393/484/696 | 4.0/5.4/7.0/9.1/11.4 | 3.0 | 54 | 99 | 7.0 (3/0) | 12.1/0.5 | 0.0 | 0/0/4/8/8 | 3.7 | 2.4/0.5/1.4/0.4/0.0/0.6/1.9/6.4 | 0 (0) | 3.9 | 0.0 | 0/0 | 0.0 | 11 |
| Berserk | 8/8 | +51 | +82 | 81/134/194/297/422 | 4.0/5.8/7.8/10.4/12.5 | 2.8 | 73 | 15 | 7.5 (5/1) | 2.0/6.2 | 0.8 | 0/0/0/2/4 | 6.8 | 3.0/2.0/14.1/0.6/0.0/0.9/4.4/4.5 | 2 (1) | 0.9 | 0.0 | 0/0 | 0.2 | 16 |
| Skald | 8/8 | +73 | +115 | 99/153/269/429/586 | 4.2/5.8/8.2/11.4/13.5 | 2.8 | 81 | 55 | 5.2 (1/1) | 12.0/1.4 | 0.2 | 0/2/2/5/7 | 3.6 | 2.0/1.2/1.1/0.8/0.0/2.1/1.8/6.8 | 0 (0) | 1.6 | 0.0 | 0/0 | 0.1 | 16 |
| King's man | 8/8 | +49 | +98 | 76/232/352/471/502 | 4.0/5.9/9.9/13.4/15.4 | 2.9 | 82 | 33 | 8.5 (6/0) | 9.4/2.2 | 0.6 | 0/0/1/2/5 | 5.9 | 6.6/3.1/1.5/0.2/0.0/3.1/2.0/3.9 | 0 (0) | 1.9 | 0.0 | 0/0 | 2.0 | 16 |

`ways_ys_1.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +130 | +184 | 123/238/491/672/937 | 7.6/11.1/14.9/16.6/17.9 | 2.8 | 91 | 15 | 8.2 (6/0) | 2.4/14.8 | 1.1 | 0/0/0/0/0 | 13.3 | 21.4/2.8/8.9/0.1/0.0/9.6/1.9/8.0 | 2 (0) | 2.2 | 0.0 | 42/422 | 8.4 | 22 |
| Trader | 8/8 | +62 | +115 | 107/189/286/416/590 | 4.1/4.9/6.0/7.1/8.2 | 3.0 | 31 | 49 | 5.1 (0/0) | 11.5/0.2 | 0.1 | 0/0/0/0/0 | 1.1 | 1.0/0.2/0.5/0.0/0.0/0.5/0.4/1.2 | 0 (0) | 1.8 | 0.2 | 0/0 | 1.0 | 9 |
| Law-wise man | 8/8 | +55 | +125 | 87/148/288/505/640 | 4.1/5.2/6.8/9.4/11.1 | 3.0 | 42 | 96 | 6.4 (2/0) | 12.1/0.2 | 0.0 | 0/0/0/0/0 | 1.7 | 2.5/0.0/0.0/0.4/0.0/0.4/0.9/1.2 | 0 (0) | 3.2 | 0.0 | 0/0 | 1.1 | 13 |
| Berserk | 8/8 | +20 | +50 | 85/142/258/269/266 | 4.0/6.0/9.0/11.6/14.1 | 2.9 | 74 | 14 | 9.9 (8/0) | 2.5/7.1 | 0.4 | 0/0/0/0/0 | 6.8 | 4.6/2.0/9.9/0.5/0.0/0.8/1.5/6.9 | 3 (1) | 0.9 | 0.0 | 0/0 | 1.0 | 16 |
| Skald | 8/8 | +100 | +164 | 90/226/403/634/834 | 4.1/5.6/8.9/13.4/15.8 | 3.0 | 91 | 56 | 6.4 (4/1) | 14.6/0.1 | 0.0 | 0/0/0/0/0 | 1.9 | 2.8/0.2/0.2/0.0/0.0/0.8/0.6/1.1 | 0 (0) | 2.8 | 0.0 | 0/0 | 0.9 | 16 |
| King's man | 8/8 | +84 | +151 | 184/369/474/610/768 | 4.9/9.0/10.8/13.2/16.1 | 3.0 | 80 | 46 | 9.1 (7/0) | 9.9/1.1 | 0.1 | 0/0/0/0/0 | 3.8 | 9.1/0.9/0.6/0.0/0.0/1.6/1.4/1.9 | 0 (0) | 3.0 | 0.4 | 0/0 | 4.6 | 16 |

`ways_ys_101.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +134 | +173 | 99/214/361/686/877 | 5.1/10.2/15.1/17.6/18.6 | 3.0 | 96 | 22 | 9.0 (6/0) | 2.5/16.8 | 1.0 | 0/0/0/0/0 | 11.3 | 22.0/2.1/7.1/0.6/0.0/8.6/1.8/4.4 | 0 (0) | 0.4 | 0.4 | 54/511 | 7.2 | 20 |
| Trader | 8/8 | +66 | +130 | 85/183/316/473/666 | 4.2/5.1/6.2/7.2/8.2 | 3.0 | 31 | 50 | 6.9 (2/0) | 12.0/0.0 | 0.0 | 0/0/0/0/0 | 0.8 | 0.9/0.4/0.4/0.0/0.0/0.1/0.2/0.8 | 0 (0) | 2.8 | 0.0 | 0/0 | 0.9 | 9 |
| Law-wise man | 8/8 | +71 | +132 | 66/181/355/611/674 | 4.4/5.0/6.2/8.2/9.8 | 3.0 | 41 | 96 | 6.6 (3/0) | 12.0/0.0 | 0.0 | 0/0/0/0/0 | 1.5 | 3.0/0.1/0.0/0.1/0.0/0.5/0.8/0.5 | 0 (0) | 2.9 | 0.0 | 0/0 | 1.0 | 12 |
| Berserk | 8/8 | +17 | +46 | 71/132/175/222/243 | 4.4/5.9/7.8/9.4/12.1 | 2.9 | 64 | 11 | 8.1 (6/0) | 1.9/7.6 | 0.2 | 0/0/0/0/0 | 8.2 | 3.9/2.4/8.1/1.0/0.0/1.0/2.1/6.0 | 5 (1) | 0.8 | 0.0 | 0/0 | 1.1 | 16 |
| Skald | 8/8 | +88 | +135 | 77/190/353/534/689 | 4.2/5.4/7.6/11.4/14.1 | 3.0 | 84 | 57 | 7.2 (4/0) | 12.5/0.4 | 0.0 | 0/0/0/0/0 | 1.5 | 2.0/0.5/0.0/0.0/0.0/0.1/0.4/1.6 | 0 (0) | 1.9 | 0.0 | 0/0 | 1.0 | 16 |
| King's man | 8/8 | +74 | +127 | 92/248/384/518/650 | 4.4/6.9/10.4/13.1/15.4 | 3.0 | 76 | 40 | 9.5 (8/0) | 10.0/1.2 | 0.0 | 0/0/0/0/0 | 3.7 | 7.5/1.1/0.2/0.1/0.0/1.4/1.1/1.0 | 0 (0) | 2.4 | 0.0 | 0/0 | 4.4 | 19 |

`ways_fm_1.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +64 | +103 | 58/148/210/325/520 | 3.6/8.5/12.5/15.0/17.2 | 2.9 | 80 | 30 | 9.4 (8/0) | 2.6/12.9 | 1.0 | 0/0/0/0/0 | 7.8 | 15.6/0.8/4.8/0.4/0.0/4.6/1.0/3.8 | 0 (0) | 0.8 | 0.2 | 33/319 | 8.5 | 18 |
| Trader | 8/8 | +53 | +102 | 53/111/223/304/517 | 4.1/5.2/6.8/7.4/8.8 | 2.9 | 33 | 49 | 6.2 (2/0) | 10.4/0.1 | 0.0 | 0/0/0/0/0 | 0.9 | 0.6/0.4/0.8/0.1/0.0/0.2/0.2/0.1 | 0 (0) | 2.0 | 0.0 | 0/0 | 2.2 | 11 |
| Law-wise man | 8/8 | +46 | +97 | 59/152/351/438/488 | 3.4/5.5/6.8/8.2/9.9 | 3.0 | 39 | 89 | 6.2 (3/1) | 10.6/0.4 | 0.0 | 0/0/0/0/0 | 1.2 | 1.9/0.2/0.0/0.0/0.0/0.5/1.0/0.0 | 0 (0) | 2.2 | 0.0 | 0/0 | 2.0 | 12 |
| Berserk | 7/8 | +36 | +61 | 59/59/179/294/319 | 3.3/4.7/6.3/7.0/7.9 | 2.5 | 39 | 12 | 4.8 (3/3) | 2.5/5.0 | 0.6 | 0/0/0/0/0 | 5.4 | 1.9/0.4/3.4/0.4/0.0/0.8/1.6/6.0 | 2 (1) | 1.0 | 0.0 | 0/0 | 2.0 | 10 |
| Skald | 8/8 | +50 | +88 | 48/126/201/309/446 | 4.1/5.4/7.2/9.9/12.8 | 2.6 | 72 | 54 | 6.5 (2/0) | 10.8/0.2 | 0.0 | 0/0/0/0/0 | 1.0 | 1.8/0.0/0.0/0.2/0.0/0.6/0.1/0.0 | 0 (0) | 1.4 | 0.0 | 0/0 | 2.2 | 16 |
| King's man | 8/8 | +67 | +117 | 102/201/317/431/589 | 3.9/5.9/8.8/11.1/13.9 | 2.4 | 65 | 39 | 7.1 (5/1) | 7.0/1.6 | 0.2 | 0/0/0/0/0 | 3.6 | 6.9/0.6/0.5/0.1/0.0/1.6/1.5/0.2 | 0 (0) | 2.0 | 0.0 | 0/0 | 4.6 | 16 |

`ways_fm_101.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +90 | +122 | 54/185/329/452/615 | 4.9/10.1/14.4/15.5/16.8 | 3.0 | 84 | 28 | 9.5 (8/0) | 3.1/13.5 | 0.9 | 0/0/0/0/0 | 8.9 | 17.6/1.8/6.2/0.2/0.0/5.5/1.4/2.4 | 1 (1) | 0.9 | 0.0 | 40/387 | 9.9 | 17 |
| Trader | 8/8 | +59 | +115 | 48/191/244/431/582 | 4.8/5.9/6.8/7.8/8.8 | 3.0 | 31 | 49 | 5.4 (0/0) | 12.1/0.2 | 0.0 | 0/0/0/0/0 | 0.9 | 0.6/0.0/0.5/0.0/0.0/0.6/0.5/0.0 | 0 (0) | 2.0 | 0.0 | 0/0 | 2.4 | 11 |
| Law-wise man | 8/8 | +41 | +103 | 49/140/310/452/522 | 3.8/5.2/6.4/8.0/10.1 | 3.0 | 46 | 86 | 6.5 (3/0) | 11.5/0.0 | 0.0 | 0/0/0/0/0 | 2.1 | 3.2/0.4/0.1/0.4/0.0/1.1/1.0/0.9 | 0 (0) | 2.6 | 0.0 | 0/0 | 1.8 | 11 |
| Berserk | 7/8 | +16 | +28 | 39/78/140/167/168 | 3.0/5.0/6.3/7.6/9.6 | 2.2 | 44 | 16 | 4.5 (1/2) | 2.2/4.2 | 0.5 | 0/0/0/0/0 | 7.1 | 1.4/1.4/3.8/0.8/0.0/1.2/3.6/4.6 | 3 (0) | 0.0 | 0.0 | 0/0 | 1.5 | 14 |
| Skald | 8/8 | +45 | +92 | 65/162/290/393/466 | 5.2/6.5/8.4/10.5/13.0 | 2.9 | 71 | 56 | 6.4 (2/1) | 11.4/0.1 | 0.0 | 0/0/0/0/0 | 1.6 | 2.2/0.2/0.4/0.0/0.0/0.6/0.8/0.8 | 0 (0) | 1.9 | 0.0 | 0/0 | 2.6 | 16 |
| King's man | 8/8 | +74 | +136 | 89/243/333/521/684 | 4.9/7.6/9.4/13.1/16.0 | 2.9 | 79 | 41 | 9.6 (8/0) | 9.1/1.5 | 0.1 | 0/0/0/0/0 | 4.4 | 9.8/1.1/0.5/1.1/0.0/1.8/1.4/1.1 | 0 (0) | 2.5 | 0.0 | 0/0 | 5.1 | 16 |

After:

`ways_bh_1.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +159 | +201 | 194/334/639/878/1017 | 8.2/13.2/18.4/23.1/24.5 | 3.0 | 99 | 19 | 6.0 (1/0) | 5.6/12.0 | 1.5 | 1/3/4/5/6 | 10.4 | 27.0/3.2/8.5/0.4/0.0/4.2/1.6/4.4 | 1 (1) | 0.8 | 1.0 | 49/415 | 6.8 | 24 |
| Trader | 8/8 | +92 | +170 | 83/218/451/589/862 | 4.0/5.0/6.6/7.0/8.1 | 3.0 | 39 | 52 | 6.2 (0/0) | 11.0/1.1 | 0.8 | 0/0/1/1/2 | 2.5 | 0.6/2.2/1.6/0.5/0.0/0.2/0.4/0.9 | 0 (0) | 5.1 | 0.2 | 0/0 | 0.0 | 10 |
| Law-wise man | 8/8 | +76 | +146 | 76/131/363/534/742 | 4.0/5.4/6.2/8.2/10.8 | 3.0 | 48 | 100 | 5.6 (0/0) | 12.1/0.5 | 0.2 | 0/0/2/5/6 | 1.8 | 1.4/0.4/1.2/0.1/0.0/0.5/0.8/0.1 | 0 (0) | 4.5 | 0.1 | 0/0 | 0.1 | 12 |
| Berserk | 8/8 | +133 | +197 | 137/221/403/659/996 | 4.4/5.6/6.9/9.4/13.0 | 3.0 | 82 | 35 | 6.0 (0/0) | 5.6/4.6 | 0.2 | 0/0/0/3/6 | 5.6 | 3.5/2.6/9.0/0.9/0.0/0.6/2.0/4.6 | 0 (0) | 4.0 | 0.0 | 0/0 | 0.2 | 19 |
| Skald | 8/8 | +72 | +132 | 118/176/329/504/668 | 4.6/6.2/10.1/12.6/16.4 | 2.8 | 92 | 60 | 5.8 (0/0) | 13.0/1.1 | 0.4 | 0/0/2/3/5 | 2.3 | 2.2/1.2/2.0/0.5/0.0/1.2/1.4/0.4 | 0 (0) | 2.9 | 0.0 | 0/0 | 0.0 | 18 |
| King's man | 8/8 | +73 | +140 | 112/246/400/564/709 | 4.0/5.6/8.9/12.2/16.6 | 3.0 | 92 | 52 | 6.4 (0/0) | 10.5/2.1 | 0.0 | 0/0/6/8/8 | 3.5 | 8.4/1.6/1.1/0.1/0.0/1.0/0.6/0.6 | 0 (0) | 3.5 | 0.0 | 0/0 | 1.6 | 19 |

`ways_bh_101.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +107 | +164 | 110/331/501/709/829 | 6.4/11.0/16.6/20.2/22.9 | 2.9 | 92 | 28 | 5.9 (0/0) | 4.8/12.2 | 1.5 | 0/0/2/3/4 | 10.5 | 24.0/2.5/9.4/0.4/0.0/4.8/2.5/3.6 | 0 (0) | 2.0 | 1.0 | 44/392 | 5.2 | 27 |
| Trader | 8/8 | +84 | +171 | 88/216/350/604/841 | 4.0/5.1/6.1/7.0/8.4 | 3.0 | 33 | 51 | 4.4 (0/1) | 10.8/1.1 | 0.9 | 0/0/1/1/1 | 2.2 | 0.4/1.4/1.4/0.4/0.0/0.5/2.1/0.2 | 0 (0) | 5.8 | 0.0 | 0/0 | 0.0 | 10 |
| Law-wise man | 8/8 | +92 | +173 | 73/141/379/621/874 | 4.0/5.5/7.4/9.2/10.9 | 3.0 | 51 | 100 | 5.9 (0/0) | 13.0/0.9 | 0.6 | 0/0/2/3/3 | 2.3 | 2.5/0.5/1.9/0.2/0.0/0.8/1.0/0.5 | 0 (0) | 5.9 | 0.1 | 0/0 | 0.0 | 12 |
| Berserk | 8/8 | +132 | +186 | 110/210/396/621/942 | 4.0/5.5/7.2/9.6/13.0 | 3.0 | 79 | 45 | 6.2 (0/0) | 5.4/4.5 | 0.6 | 0/0/0/1/3 | 6.1 | 4.1/2.4/9.6/0.8/0.0/0.9/2.9/4.0 | 1 (1) | 3.6 | 0.1 | 0/0 | 0.4 | 19 |
| Skald | 8/8 | +111 | +174 | 88/206/418/692/878 | 4.1/6.4/9.0/12.8/15.8 | 2.8 | 93 | 59 | 5.5 (0/0) | 13.8/0.9 | 0.2 | 0/1/3/4/6 | 2.1 | 2.1/1.4/1.5/0.1/0.0/0.9/1.9/0.1 | 0 (0) | 3.4 | 0.0 | 0/0 | 0.1 | 18 |
| King's man | 8/8 | +59 | +121 | 86/272/354/501/614 | 4.0/5.1/9.2/12.9/17.0 | 2.8 | 88 | 44 | 6.4 (0/0) | 9.6/2.1 | 0.1 | 0/0/5/7/8 | 3.9 | 8.5/1.5/1.1/0.5/0.0/1.8/1.1/0.4 | 0 (0) | 2.8 | 0.0 | 0/0 | 2.0 | 21 |

`ways_ys_1.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +116 | +168 | 142/218/452/737/852 | 6.9/10.2/17.0/21.9/25.0 | 3.0 | 99 | 13 | 5.6 (0/0) | 2.8/13.6 | 1.1 | 0/0/0/0/0 | 9.7 | 24.6/3.0/6.6/0.5/0.0/5.2/1.4/3.8 | 3 (2) | 1.2 | 0.0 | 45/394 | 6.2 | 30 |
| Trader | 8/8 | +105 | +191 | 109/199/413/687/971 | 4.0/5.1/6.5/7.6/8.9 | 3.0 | 33 | 48 | 6.0 (0/0) | 12.2/0.1 | 0.0 | 0/0/0/0/0 | 1.0 | 0.8/0.6/1.0/0.1/0.0/0.1/0.1/0.0 | 0 (0) | 5.9 | 0.1 | 0/0 | 0.9 | 10 |
| Law-wise man | 8/8 | +62 | +130 | 100/172/336/533/666 | 4.0/5.5/7.0/8.2/9.9 | 3.0 | 39 | 98 | 5.4 (0/0) | 12.0/0.4 | 0.0 | 0/0/0/0/0 | 1.0 | 1.0/0.1/0.0/0.0/0.0/0.4/0.6/0.0 | 0 (0) | 4.6 | 0.1 | 0/0 | 0.8 | 11 |
| Berserk | 8/8 | +100 | +146 | 130/157/301/527/745 | 4.1/5.0/6.4/8.0/10.8 | 3.0 | 59 | 32 | 5.9 (0/0) | 4.2/6.5 | 0.0 | 0/0/0/0/0 | 4.1 | 1.8/1.8/6.0/0.6/0.0/0.1/2.6/5.1 | 1 (1) | 3.1 | 0.0 | 0/0 | 0.9 | 12 |
| Skald | 8/8 | +83 | +133 | 96/141/317/541/680 | 3.8/5.1/7.2/9.9/12.9 | 2.9 | 81 | 61 | 6.1 (0/0) | 13.6/0.4 | 0.0 | 0/0/0/0/0 | 1.2 | 3.4/0.5/0.0/0.2/0.0/0.2/0.2/0.0 | 0 (0) | 2.9 | 0.0 | 0/0 | 1.0 | 16 |
| King's man | 8/8 | +89 | +174 | 168/302/489/718/885 | 4.5/5.9/10.4/13.8/18.1 | 2.8 | 78 | 47 | 6.2 (1/0) | 9.6/1.0 | 0.1 | 0/0/0/0/0 | 3.0 | 9.0/0.6/0.5/0.4/0.0/1.5/0.8/0.1 | 0 (0) | 4.5 | 0.6 | 0/0 | 2.9 | 25 |

`ways_ys_101.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +112 | +187 | 88/295/569/773/949 | 4.8/11.1/16.2/21.4/27.2 | 3.0 | 100 | 10 | 6.1 (1/0) | 3.1/13.8 | 1.0 | 0/0/0/0/0 | 10.2 | 26.0/3.0/8.9/0.4/0.0/4.1/2.1/3.0 | 0 (0) | 2.0 | 0.4 | 48/414 | 7.4 | 32 |
| Trader | 8/8 | +100 | +187 | 89/193/444/636/949 | 4.2/5.5/6.8/7.2/8.2 | 3.0 | 30 | 51 | 5.9 (0/0) | 12.4/0.5 | 0.2 | 0/0/0/0/0 | 0.7 | 0.2/0.8/0.6/0.0/0.0/0.1/0.1/0.0 | 0 (0) | 5.9 | 0.0 | 0/0 | 0.9 | 8 |
| Law-wise man | 8/8 | +98 | +169 | 83/132/421/661/861 | 4.2/5.1/6.8/7.6/9.9 | 3.0 | 41 | 98 | 5.6 (0/0) | 13.4/0.1 | 0.0 | 0/0/0/0/0 | 0.8 | 1.9/0.4/0.1/0.1/0.0/0.4/0.1/0.0 | 0 (0) | 5.0 | 0.2 | 0/0 | 0.9 | 12 |
| Berserk | 8/8 | +94 | +138 | 108/185/299/474/705 | 4.4/5.2/6.4/7.9/10.2 | 2.9 | 51 | 30 | 5.5 (0/1) | 3.4/4.6 | 0.2 | 0/0/0/0/0 | 3.8 | 2.2/2.0/4.5/0.5/0.0/0.5/2.0/3.9 | 2 (1) | 2.5 | 0.0 | 0/0 | 1.1 | 14 |
| Skald | 8/8 | +85 | +143 | 88/203/356/530/732 | 4.5/6.0/8.2/11.4/14.4 | 3.0 | 95 | 61 | 5.9 (0/0) | 14.6/0.2 | 0.0 | 0/0/0/0/0 | 1.0 | 2.5/0.6/0.1/0.0/0.0/0.4/0.5/0.1 | 0 (0) | 3.5 | 0.0 | 0/0 | 1.0 | 17 |
| King's man | 8/8 | +77 | +145 | 121/327/519/649/738 | 4.5/6.5/11.8/14.6/19.5 | 3.0 | 90 | 47 | 6.4 (0/0) | 10.8/2.1 | 0.2 | 0/0/0/0/0 | 3.0 | 10.5/1.4/0.5/0.4/0.0/0.8/0.4/0.4 | 0 (0) | 2.6 | 0.0 | 0/0 | 3.5 | 24 |

`ways_fm_1.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +122 | +180 | 63/269/615/789/905 | 4.1/10.5/16.2/20.9/26.0 | 2.8 | 91 | 17 | 6.6 (2/0) | 4.2/12.4 | 1.5 | 0/0/0/0/0 | 9.2 | 24.4/2.4/7.6/0.5/0.0/3.5/1.1/2.2 | 0 (0) | 1.1 | 0.0 | 44/378 | 7.9 | 32 |
| Trader | 8/8 | +81 | +153 | 59/162/350/546/769 | 3.8/5.5/6.9/8.2/9.1 | 3.0 | 32 | 49 | 5.5 (0/0) | 10.5/0.4 | 0.0 | 0/0/0/0/0 | 0.8 | 0.4/0.0/0.6/0.1/0.0/0.1/0.1/0.2 | 0 (0) | 4.5 | 0.0 | 0/0 | 2.6 | 10 |
| Law-wise man | 8/8 | +60 | +119 | 66/114/238/425/597 | 3.4/5.0/6.4/8.1/10.2 | 3.0 | 41 | 90 | 5.5 (0/0) | 11.2/0.2 | 0.0 | 0/0/0/0/0 | 1.2 | 2.2/0.2/0.1/0.4/0.0/0.5/0.5/0.1 | 0 (0) | 3.6 | 0.0 | 0/0 | 2.1 | 14 |
| Berserk | 8/8 | +102 | +126 | 76/145/278/454/636 | 4.1/5.5/6.8/8.0/9.9 | 3.0 | 46 | 22 | 5.6 (0/0) | 4.4/5.0 | 0.1 | 0/0/0/0/0 | 3.6 | 1.6/1.4/3.5/0.2/0.0/1.0/2.2/4.6 | 0 (0) | 1.1 | 0.0 | 0/0 | 2.6 | 11 |
| Skald | 8/8 | +62 | +108 | 54/109/243/437/542 | 3.9/5.4/7.9/10.1/13.6 | 2.9 | 79 | 56 | 5.9 (0/0) | 12.6/0.6 | 0.0 | 0/0/0/0/0 | 0.8 | 2.0/0.2/0.0/0.0/0.0/0.4/0.1/0.0 | 0 (0) | 2.1 | 0.0 | 0/0 | 2.6 | 17 |
| King's man | 8/8 | +89 | +146 | 98/194/404/579/736 | 3.6/6.6/10.0/12.6/17.4 | 2.8 | 78 | 45 | 6.1 (0/0) | 8.9/2.2 | 0.4 | 0/0/0/0/0 | 3.0 | 8.1/1.5/0.2/0.1/0.0/0.8/1.0/0.4 | 0 (0) | 2.6 | 0.2 | 0/0 | 5.1 | 23 |

`ways_fm_101.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8 | +120 | +166 | 57/245/488/714/835 | 5.2/11.4/16.1/20.4/24.8 | 3.0 | 100 | 17 | 6.5 (1/0) | 2.6/12.4 | 0.6 | 0/0/0/0/0 | 10.3 | 26.9/2.5/6.8/0.8/0.0/4.5/1.5/2.8 | 1 (0) | 0.8 | 0.2 | 48/405 | 8.6 | 25 |
| Trader | 8/8 | +79 | +156 | 46/178/371/570/786 | 4.5/5.9/6.6/7.2/8.2 | 3.0 | 29 | 48 | 5.4 (0/0) | 12.0/0.1 | 0.1 | 0/0/0/0/0 | 1.0 | 0.0/0.9/0.9/0.1/0.0/0.1/0.6/0.0 | 0 (0) | 5.0 | 0.0 | 0/0 | 2.8 | 9 |
| Law-wise man | 8/8 | +56 | +117 | 58/135/319/436/587 | 4.1/5.6/7.1/8.0/9.9 | 3.0 | 39 | 94 | 5.8 (0/0) | 12.1/0.0 | 0.0 | 0/0/0/0/0 | 1.3 | 2.0/0.1/0.1/0.1/0.0/0.8/0.8/0.0 | 0 (0) | 4.0 | 0.0 | 0/0 | 2.2 | 12 |
| Berserk | 8/8 | +88 | +122 | 73/219/346/460/615 | 4.4/5.5/6.4/8.2/10.0 | 3.0 | 49 | 24 | 5.6 (0/0) | 4.5/3.5 | 0.0 | 0/0/0/0/0 | 4.7 | 3.2/1.1/4.4/1.0/0.0/0.4/3.6/4.0 | 1 (0) | 2.1 | 0.0 | 0/0 | 2.1 | 12 |
| Skald | 8/8 | +50 | +101 | 68/127/298/392/507 | 4.8/5.6/7.5/10.1/13.1 | 2.9 | 81 | 54 | 5.8 (0/0) | 12.9/0.1 | 0.0 | 0/0/0/0/0 | 1.2 | 1.4/0.2/0.0/0.0/0.0/0.2/0.8/0.2 | 0 (0) | 2.8 | 0.0 | 0/0 | 2.6 | 17 |
| King's man | 8/8 | +85 | +152 | 137/286/458/580/762 | 5.1/7.4/10.6/12.8/16.1 | 2.9 | 77 | 49 | 6.0 (0/0) | 10.0/1.5 | 0.2 | 0/0/0/0/0 | 2.8 | 8.2/0.2/0.2/0.4/0.0/1.1/1.2/0.1 | 0 (0) | 3.8 | 0.0 | 0/0 | 5.4 | 21 |

Ten years from the burned hall, before:

`bh10.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 6/6 | +100 | +122 | 134/299/374/542/622/719/946/1079/1187/1232 | 8.2/12.7/16.2/17.7/18.0/17.8/18.3/19.3/19.5/20.2 | 3.0 | 92 | 27 | 8.8 (5/0) | 4.0/13.7 | 0.8 | 0/1/1/2/2/4/4/4/4/5 | 10.4 | 35.2/4.5/16.7/1.0/0.0/12.5/2.7/17.0 | 0 (0) | 1.3 | 0.0 | 83/845 | 4.5 | 29 |
| Trader | 6/6 | +88 | +124 | 87/161/274/309/400/645/810/941/1078/1245 | 4.0/5.0/5.5/6.8/8.2/9.7/12.5/13.8/15.0/15.7 | 3.0 | 66 | 58 | 8.0 (5/0) | 13.2/0.8 | 0.2 | 0/1/2/2/3/3/4/4/5/5 | 2.3 | 3.2/1.5/3.3/0.0/0.0/2.2/2.3/9.0 | 0 (0) | 3.3 | 0.3 | 0/0 | 0.0 | 16 |
| Law-wise man | 6/6 | +104 | +161 | 43/117/238/353/448/648/869/1089/1351/1616 | 4.0/5.2/7.0/8.3/10.2/11.8/15.0/17.0/17.3/17.7 | 3.0 | 88 | 100 | 9.2 (6/0) | 18.2/0.0 | 0.0 | 0/0/1/3/5/6/6/6/6/6 | 3.0 | 5.5/0.8/1.8/0.5/0.0/1.7/2.2/12.5 | 0 (0) | 7.2 | 0.0 | 0/0 | 0.3 | 17 |
| Berserk | 6/6 | +109 | +137 | 66/107/184/239/298/416/666/993/1202/1384 | 4.0/6.0/7.5/9.2/11.7/13.8/14.8/16.5/17.7/19.2 | 2.7 | 93 | 15 | 8.7 (5/1) | 4.5/9.2 | 0.3 | 0/0/0/0/0/3/4/5/5/5 | 8.1 | 13.0/5.0/30.5/0.8/0.0/2.0/3.2/10.5 | 3 (2) | 3.7 | 0.0 | 0/0 | 0.0 | 27 |
| Skald | 6/6 | +64 | +101 | 99/143/262/399/511/710/758/863/1008/1023 | 4.2/5.3/8.3/11.2/15.0/16.3/16.5/16.5/16.7/16.5 | 2.8 | 86 | 75 | 6.2 (2/1) | 15.2/0.5 | 0.2 | 0/0/2/2/3/4/5/5/5/5 | 3.5 | 4.8/1.5/3.7/0.2/0.0/4.5/3.7/13.7 | 0 (0) | 4.2 | 0.0 | 0/0 | 0.0 | 17 |
| King's man | 6/6 | +127 | +162 | 80/268/404/558/612/776/935/1158/1370/1632 | 4.0/7.2/11.0/14.5/16.7/17.3/17.8/18.5/19.0/20.8 | 3.0 | 100 | 49 | 9.5 (6/0) | 14.0/4.2 | 0.8 | 0/0/0/1/1/2/4/4/5/5 | 6.5 | 27.8/5.0/5.2/1.2/0.0/7.5/4.5/9.5 | 0 (0) | 3.3 | 0.5 | 0/0 | 2.8 | 22 |

After:

`bh10.txt`

| Bent | alive | silver/yr | worth/yr | worth y1..y5 | men y1..y5 | steps | fame | honor | luck (8+/2-) | friends/ill | feuds open | avenged by year | fights/yr | ladder (routed them/drove off/won/drew off/withdrew/driven off/routed/lost) | outlawed (still) | land | thralls | captives sold/oz | hired | most men |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 6/6 | +134 | +172 | 198/324/610/792/905/1037/1183/1325/1567/1726 | 8.3/13.3/18.7/23.0/24.3/25.0/25.0/25.2/26.3/27.5 | 3.0 | 100 | 3 | 6.3 (1/0) | 5.0/14.3 | 0.3 | 1/3/4/5/5/5/5/5/5/5 | 11.2 | 60.0/5.3/15.3/0.3/0.0/12.8/3.0/11.0 | 1 (0) | 3.3 | 0.0 | 64/528 | 6.3 | 39 |
| Trader | 6/6 | +144 | +198 | 89/202/423/536/867/1123/1283/1427/1717/1993 | 4.0/5.0/6.7/6.8/8.3/10.0/11.0/12.3/13.0/13.2 | 3.0 | 68 | 59 | 5.8 (0/0) | 13.0/0.7 | 0.2 | 0/0/1/1/2/3/3/3/4/5 | 1.7 | 0.8/3.5/2.8/0.5/0.0/1.2/1.0/1.7 | 0 (0) | 7.0 | 0.0 | 0/0 | 0.0 | 14 |
| Law-wise man | 6/6 | +113 | +177 | 77/122/309/464/688/839/1087/1306/1553/1783 | 4.0/5.5/6.3/8.3/11.0/12.8/15.8/16.7/16.8/16.8 | 3.0 | 87 | 100 | 5.2 (0/0) | 20.7/0.3 | 0.0 | 0/0/2/5/5/5/6/6/6/6 | 1.6 | 5.2/0.7/1.3/0.3/0.0/1.7/1.7/0.2 | 0 (0) | 8.7 | 0.0 | 0/0 | 0.2 | 17 |
| Berserk | 6/6 | +183 | +246 | 106/179/357/593/876/1168/1434/1790/2148/2427 | 4.3/5.7/6.7/8.5/11.2/15.3/18.8/20.8/22.6/23.6 | 3.0 | 100 | 48 | 6.2 (0/0) | 7.8/6.3 | 0.0 | 0/0/0/1/4/6/6/5/5/5 | 6.0 | 15.0/4.2/18.3/0.3/0.0/2.3/2.5/7.0 | 0 (0) | 6.2 | 0.0 | 0/0 | 0.2 | 28 |
| Skald | 6/6 | +82 | +144 | 115/165/315/533/712/872/1135/1233/1345/1452 | 4.7/6.2/9.8/12.0/16.5/18.3/19.7/20.2/21.0/21.2 | 3.0 | 99 | 91 | 5.7 (0/0) | 16.8/0.8 | 0.0 | 0/0/1/2/3/4/6/6/6/6 | 1.8 | 5.7/1.0/2.7/0.7/0.0/3.0/1.8/0.8 | 0 (0) | 6.3 | 0.0 | 0/0 | 0.0 | 26 |
| King's man | 6/6 | +64 | +125 | 133/290/420/581/689/802/886/977/1191/1263 | 4.0/6.0/9.7/12.5/16.8/21.7/26.3/29.5/31.5/32.8 | 2.7 | 93 | 52 | 6.7 (2/0) | 11.5/3.3 | 0.3 | 0/0/6/6/6/6/6/6/6/6 | 4.5 | 27.0/3.8/1.8/0.5/0.0/4.5/2.0/2.2 | 0 (0) | 5.3 | 0.0 | 0/0 | 1.7 | 34 |

