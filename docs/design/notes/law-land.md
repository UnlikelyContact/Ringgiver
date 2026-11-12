# Law, land and the unfree (12 Nov 2026)

Branch `law-land`. Package C of the gap audit: gaps 6 (land and the
land-take), 8 (captives and thralls), 9 (the Thing played), 10 (outlawry
and exile) and the omen half of 12; bugs 5, 6, 8, 11, 14, 15, 16. Three of
the sagas' pillars the player could not touch: before this a lawsuit ran
its four stages with no choice, an outlaw wintered as a guest and traded,
`band.land` was 0 for good, captives were silver and nothing more, and no
omen was ever raised.

Shots at 844 x 390 are in `law-land-shots/` (zero SCRIPT ERROR lines in
every render): `1_case_support`, `2_case_law`, `3_case_standoff`,
`4_case_verdict`, `5_outlaw_hunters`, `6_land_purchase`, `7_iceland_take`,
`8_iceland_name`, `9_captives`, `10_land_modal`, `11_omen`, `12_volva`.

## What the player meets

### The Thing, played (ThingPlay; gap 9, bug 8)

"Plead against X" at a Thing (and "Speak for X against Y", "Answer X's
summons", "Plead the bounds of your land against X") opens a case of
four short steps in the map's decision modal. I kept the decision queue
rather than a screen of its own: every step is one question with two to
five answers, the modal already wraps its buttons and scrolls its body,
and the numbers fit as a small block under the question (`detail`) with
each answer's meaning under it (`hint`). A dedicated screen would have
been a second way of showing the same thing.

1. **Who stands with you.** "With you: Ulfar's kin, Horda-Kari's kin; 1
   oath-helper for 10 oz; 9 of your men under arms. With
   Hardanger-Atli's kin: Rognvald's kin, Thorir Long-chin's kin; their
   household, 10 under arms. Supporters: about 6 for you, 13 for them.
   Luck: his luck holds." (`Families.thing_backing` names the houses.)
   The two nearest houses that stand with neither side are offered, each
   by what its temper wants: a grasping house a gift (10 oz,
   `Families.give_gift`), a proud or peaceable one a favour promised
   (called in next spring: 15 oz or -15 standing), a steadfast one a
   marriage (`Families.marry_into`) when the leader has no wife. Any of
   these puts the house on the band's side for this case. Oath-helpers:
   10, 20 or 40 oz (one supporter for each 10), chosen a step at a time,
   paid when the case goes to the law. "Let the case drop" spends nothing.
2. **The law.** Plead it yourself ("your pleading holds about 7 times in
   10": the leader's Wits and the law gift with 2d6 against the case's
   difficulty, counted exactly), let a law-wise man of the band plead, hire
   the Thing's law-man by name (Thorleif the Wise at the Gulathing, Thorir
   Hound at the Frostathing, Arnfinn the Law-skilled at Eidsvoll; 15 oz,
   Wits 7, he mends one slip: `ThingCase.lawman_hired` is set at last), or
   take him into the band for 45 oz, a law-wise man of its own. A slip
   voids the band's case. The other side pleads too, and its slip is the
   band's gain. **The path to law-wise** (no man was ever given the trait):
   the band's best Wits after the pleader sits through the case; after two
   cases he is law-wise. The kept law-man is law-wise at once.
3. **The standoff**, only when the verdict leans against the side with
   more spears. The band leaning to lose with more spears: back down,
   press (they give way in `press_yield_base` 0.35 plus half the spears'
   odds, 0.1..0.85, shown in words; else it comes to blows; honor -5
   either way), or ask Horda-Kari's kin to arbitrate (10 oz: half the
   wergild from the side the case leaned against, nobody outlawed, the
   arbiters +5, honor +1). The band leaning to win with fewer spears: stand
   on the verdict (they draw weapons by the same reckoning), let it go for
   the peace, or arbitration. Blows are the Thing brawl as before, handed
   to the fight unchanged (`{"kind": "thing"}`), the band struck first when
   it pressed (honor -15).
4. **The verdict.** Won: wergild (fair: honor +3, the other house only half
   as cold), lesser outlawry for the killers (needs a weight of 1.5; their
   kin resent it along the ties: -15 more, the house's strength -2), full
   outlawry (2.0; -30, strength -4), a marriage to seal the peace (a
   daughter of theirs), land of theirs (a steading they hold, 1 unit; 1.5
   for a killing, 1.1 for a land case). Asked beyond the weight: "The
   law-men will not give so much ... they award wergild, and X take the
   asking ill" (-10). Lost as defendant: pay (wergild, or bow to the
   outlawry), defy (a full outlaw, honor -5), or appeal to the king when
   the Thing is in a king's land and his regard for the band is 30 or more
   (20 oz and 10 of his regard: outlawry becomes wergild, wergild is
   halved). Lost as plaintiff: the matter goes to the sword (a feud).

Cases: the feuds that exist (a killing pleaded by the wronged, a raid,
strandhögg or robbery answered), the theft of the band's ship (a raid
case for the ship's price), a boundary quarrel (`land_case`, from a
spring's moved stones), níð (a skald's verse at a house that has turned
ill-wisher, the band summoned: an insult case), a summons from a house the
band has wronged (25% a spring), and speaking for a house (the pledge, now
played: the client's verdict settles their feud). One hearing per house a
summer. A summons not answered is judged without the band at the winter:
lesser outlawry, with a summer to leave. `Thing.run` is untouched: the
sandbox AI and the old tests use it.

### Outlawry that bites (Outlawry; gap 10, bugs 5, 11, 14)

- **One predicate**, `Outlawry.door_shut(j, place, door)`: doors are
  winter, rest, passage, hire, market, work, shelter (a house's favours),
  thing. Journey asks it in `actions` (greyed, the reason as the hint),
  `act` (refused with the reason), `market`/`buy`/`sell`, and the winter's
  roof. It is shut only where Norway's law reaches (`Families.HOME_REGIONS`);
  the west, Frankia, Denmark, the Swedes and Iceland are open.
- **Lesser outlawry**: three years (`outlaw_until`). In Norway he may buy
  what he needs, rest and take ship; no winter, work, hire or Thing. If he
  winters in Norway after the summer he was outlawed in, he is a full
  outlaw; a winter abroad is a winter served (`law.exile_winters`). It
  lapses after three years, as before.
- **Full outlawry** (skóggangr): every door in the realm shut, except a
  sworn friend's (standing 80+), who will hide him for the winter and let
  him rest; word gets out in a quarter of winters (-20 standing with him,
  their lord thinks less of them, the house's honor -5).
- **Bounty hunters** (`Roam.Party` kind `hunters`, new): each spring a full
  outlaw is in the realm, in 70%, one party (two from fame 50) from the
  realm's hall nearest him, 5 men and one more for every 20 fame, veteran;
  they hunt him wherever he goes in Norway (they track: no sight limit),
  and go home when he leaves the realm or is pardoned. The price on his
  head is 20 oz plus fame / 2. Beaten, the tale raises his name (fame +2).
- **The outlaw's roads**: the wilds ("Rob travellers on the road": 6..12
  oz, 2 days, honor -2); the west (a shipmaster who asks no questions
  carries him to the nearest haven the law does not reach, at twice the
  fare); the king's pardon at a king's hall (60 oz + fame, or "Offer your
  sword for your peace": a fight with 8 of the king's enemies; won, he is
  pardoned and rank progress +10; once a year); the Grettir clause (three
  outlaw bands killed by a full outlaw earn his peace).
- **Rollo's exile** (bug 5): "Sail west with Rollo" takes the band to the
  camp on the Seine (new place, Frankia), its home now, a full outlaw in
  Harald's Norway. The Seine host's leader becomes Rollo, who has work for
  his men (+60 regard); Rouen up the river is a rich town to raid. In 911
  Rollo gives the band land about the Seine (2 units).
- **The snow** (bug 14): caught abroad, the band makes for the nearest roof
  that will take it (not an ill-wisher's, not shut to an outlaw), else a
  camp. Winter at a shut door is not offered.

### Land of your own (Landtake; gap 6, bugs 15, 16)

- **Bought**: "Ask X for land" at a farmstead in Norway whose house is a
  well-wisher or better (not at feud): 55 oz a unit, 45 from a friend, one
  or two units; the decision shows the yield and the hands (shot 6).
- **Granted**: made hersir (`Sandbox._promote`, rank progress 50), the
  lord who thinks best of the band (a king or a jarl, regard 10+) gives 2
  units at a farmstead of his; each spring after, his summons: go to the
  levy (8 days, +5 regard, +5 rank progress), send 20 oz, or refuse (-20
  regard; twice, and he takes the land back).
- **Won at the Thing**: the land verdict.
- **Claimed**: within two years of a reckoning won, the empty steading of
  that house (1 unit, -10 with them).
- **The hall site**: the first holding is `Band.hall_at`, so the winter's
  "home" lodging and building (`Hall.build`) are reached honestly.
- **The yield** (`Landtake.thaw_yield`, from `Campaign._thaw`): every unit
  wants 2 hands (thralls, freedmen, keepers, and the wife's household: 2
  plus her skill / 2); a worked unit yields 10 rations and 5 oz at the
  thaw, an untended one a quarter. Thralls eat 2 rations each. Held 20
  years it is odal: a fifth more. A band with no holdings (the AI's
  `start_land`) yields as before.
- **Defended**: men left to keep the farm ("Leave men to keep the farm":
  1..3 men out of the wall, a hand each, back when the band winters there
  or is taken back). Raiders who come to it while the band is away (the
  world's own raids, `Roam.struck`) meet the keepers (2 each), the
  household skill and a third of the thralls against about 6: beaten, the
  year's yield is halved, a thrall or two carried off, a keeper may fall.
- **A land quarrel** (15% a spring): a neighbour moves the stones. Take it
  to the Thing, drive them off (a fight with 5; lost, the strip is theirs),
  or let them have it (a unit, or honor -2).
- **Iceland** (from 874, bug 15): the spine event offers "Make for
  Iceland" (the way by Orkney, seven days of open sea, the place known),
  "Let the men who want land go" (they leave with honor to the band),
  or stand aside. At Iceland, "Take land in Iceland" (a knarr carries the
  household and beasts, else a settler's knarr for 40 oz): carry fire
  round the land (2 + (Might + Nerve) / 5, plus or minus one unit, Ingolf's
  kin as neighbours, +5 with them), throw the high-seat pillars overboard
  (one of three shores, seeded: a good harbour and thin grass, near
  neighbours, 3 units and +2 oz a unit; a long strand of grazing, no
  harbour, nobody near, 5 units and +3 rations a unit; a fjord, fair both,
  4 units; luck +1), or buy a piece of Ingolf's kin (30 oz, 1 unit, +15).
  Then name the land (three names from the seed). Settled: home and hall
  there, `Band.settled_iceland`, outlawry lifted ("Norway's law does not
  reach Iceland"), every man who wanted land or a home has it. Iceland is
  never a raid target. Its settler houses come in their years
  (Ketilbjorn's kin 875, Skallagrim's kin 878, Thorolf Mostur-beard's kin
  884, Aud the Deep-minded's kin 892, Geirmund's kin 900), new houses in
  the web, the land-take 6 wealth richer each; the band's neighbours (+10).
  930: the Althing (a spine event, flag `althing`): Iceland is a Thing.
- **Ambitions** (bug 16): land +60 for each grant (Iceland fills it), a
  wife +50 for each marriage into a house (in `Families.marry_into`), a
  home +60 for each winter on the band's own land, vengeance +50 for each
  feud settled (`Landtake.watch`).

### The unfree (Thralls; gap 8, bug 6)

- **After a won raid**, the captives' decision (shot 9): "3 people of
  Avaldsnes are bound on the strand: among them Hallgerd, daughter of
  Augvald" (a named person at a hall or town). Send to their kin for
  ransom (7 a head, 30 for the named one; +6 with the house, +12 for the
  named; honor +1; 3 days); keep them bound for the market (Dublin 21 a
  head, Hedeby and Birka 15, the glut as before; selling costs -3 standing
  a head with the house they were taken from, a named freeborn woman -20
  and honor -3); take them home as thralls (only with land); let them go
  (honor a head to 3; one asks to follow: a freedman, loyalty 70, "freed
  by Egil"). The same are deeds at any settled place while captives are
  held ("Let N captives be ransomed", "Set the captives free", "Set the
  captives to work your land").
- **Thralls at home** are named (name, where taken, year), hands for the
  land, two rations each at the thaw. **Unrest** (0..10) rises each winter
  by half the thralls beyond the watch (three a keeper, two for a wife)
  and by 2 when the band winters away from its land (falls by 1 when at
  home). The winter card (now only with captives or thralls, bug 6) has
  stakes: have it out of them (the stores found, unrest +2, honor -1; at
  8+ one of them kills a man of the band in the night and is gone), set a
  man to watch them (unrest -2), free the one who speaks for them, or let
  it lie (unrest +1; at 6+ one or two run). At 6+ with the band away and
  the watch thin, a rising (3% a day): a keeper killed, the stores burned
  (the year's yield halved), the thralls gone with the boat ("as
  Hjorleif's Irishmen rose against him").
- **Manumission**: "Free X, a thrall" at the band's land: honor +2, unrest
  -2, a freedman tenant (a hand). Five years after the first, with two or
  more, the freedmen are a house of their own at the band's land, its
  friends (standing 70).
- **Taken**: a fight lost outside Norway takes one of the band's men alive
  in half such fights (a son of the leader first), carried to the nearest
  market in people. A decision says where; there, "Buy X back (30 + 10 a
  tier oz)" or "Take X back by force" (a fight with the slavers' guards, 6;
  won, fame +3). After two years he is sold on east.

### Omens and the seer (Omens; gap 12, omen half)

A spring has an omen in 35%: a raven on the right hand (good: go at once,
luck +1, every man +3), a stumble at the threshold (stay 3 days), a dream
told by the wife or an old man (a sacrifice of 5 oz). A raid has one in
20%: a fetch on the road (turn back: the raid is not made) or an eagle
(go in with it). Heeding an ill omen costs what it says and every man +1;
ignoring it is `Leader.on_omen_ignored` (comes true in 30%: luck -1) and
then every man -3. The decision shows the luck in words ("his luck
holds"), as do the Thing's support step, the land-take, the land modal
and the luck stat's tooltip (`Omens.luck_words`).

A seer (völva) comes to the hall in 35% of winters (shot 12): feast her
and ask what the year holds (8 oz), feast her and ask nothing (4 oz, every
man +1), or send her on (in 30%, luck -1). What she tells is true: the
year's fate is drawn from the seed alone (`Omens.fate(year)`: an early
winter in 25% of years, 25 days off the summer; a farm a raider ship will
make for in the spring; a house at feud whose men will be out after the
band in 60% when there is one), and the spring makes it so whether she
was asked or not.

## Classes and functions

New: `ThingPlay` (sim/world/thing_play.gd), `Landtake` (landtake.gd),
`Thralls` (thralls.gd), `Omens` (omens.gd). Rewritten around the old
API: `Outlawry` (declare, is_outlawed, halls_closed, bounty_hunters, lift
kept). Each has `bot(j, d, bent)` for the stand-in player.

- `ThingPlay`: `begin(j, family, how, client)`, `answer`, `answer_spring`,
  `spring`, `actions`/`act` (answer:, case_land:), `is_thing`,
  `judge_absent`, `waverers`, `pleaders`, `lawman_name`, `chance`,
  `odds_words`, `weigh`, `standoff_due`, `yield_chance`, `asks`.
  State: `Journey.life["case"]`.
- `Outlawry`: `door_shut`, `door_of`, `gate`, `refuses`, `winter_shut`,
  `reaches`, `region_here`, `in_realm`, `spring`, `tick`, `meet`,
  `actions`/`act` (rob_road, pardon_silver, pardon_service, west_passage),
  `pardon`, `bounty`, `pardon_price`, `after_fight`, `on_winter`,
  `join_rollo`, `bot_deed`.
- `Landtake`: `fork` (the law-land rng, apart from the summer's own forks),
  `add_holding`, `grant`, `holding_at`, `hands`, `worked`, `thaw_yield`,
  `raidable`, `house_land`, `actions`/`act` (buy_land, claim_land,
  keepers, keepers_back, landtake), `answer`, `spring`, `after_fight`,
  `tick`, `watch`, `on_winter`, `on_rank`, `settle_iceland`, `year_end`,
  `ambition`, `land_price`.
- `Thralls`: `after_raid`, `ransom_for`, `answer`, `take_home`, `let_go`,
  `sell`, `actions`/`act` (ransom, free, thralls_home, manumit,
  ransom_taken:i, rescue_taken:i), `manumit`, `lost_fight`,
  `after_fight`, `spring`, `tick`, `on_winter`, `unrest_card`,
  `resolve_unrest`.
- `Omens`: `luck_words`, `spring`, `before_raid`, `answer`, `fate`,
  `short_summer`, `volva_card`, `resolve_volva`.
- `Band`: `holdings`, `keepers`, `thralls`, `unrest`, `freedmen`, `taken`,
  `settled_iceland`, `law` (outlawed, exile_by, exile_winters, grettir,
  pardon_asked, rollo, normandy, sat, owed, summons, nid, land_case,
  pleaded, cases, liege, refused_duty, claimable, settled_seen, home_year,
  captives_from, named, sold, revolt, freedman_house), `foretold`.
- `Families.add_house`; `marry_into` moves the wife ambition.
- Decisions (Journey.answer): kinds `thing` (steps support, law, standoff,
  verdict, summons, favour), `land` (buy, keepers, duty, quarrel, iceland,
  iceland_name), `unfree` (captives, taken), `omen` (spring, raid). Each
  may carry `title`, `detail`, and `hint` on its options.
- WorldRules: the section "Law, land and the unfree" (every number above).
  `thrall_food` 2. The Iceland spine event's options; the Althing (930).
- NorwayData: Region `FRANKIA` (appended to the enum and REGION_NAMES);
  places `seine` (the camp on the Seine, a hall, faction `seine`) and
  `rouen` (a town, no faction), both open from 866; faction `seine` (the
  host on the Seine, Weland, Rollo from 900); lanes Northumbria-Seine 5,
  Ribe-Seine 6, Seine-Rouen 1; one shore polygon, the Frankish coast,
  which the two places strictly need.

## Hooks in files other packages share

- `journey.gd`: one block of new functions at the end
  (`_law_land_spring`, `_law_land_tick`, `_law_land_actions`,
  `_act_law_land`, `_answer_law_land`, `_law_land_after_fight`,
  `_law_land_spine`, `_law_land_winter`) and one-line calls: in
  `begin_summer`, `answer` (spine; the four kinds), `advance`/`_pass`,
  `_meet`, `actions` (the wilds, the raid check, Thing sites, hulls, the
  end), `act` (the predicate's refusal, the raid's omen, `case:`,
  `captives`, the chain), `_speak`, `_after_fight`, `_winter` (the roof,
  the winter hook), `market`/`buy`/`sell`, `days_left` (an early winter),
  `status` (outlaw_kind, luck_words, land, thralls, unrest,
  settled_iceland), `SPINE_LABELS`. `_plead` is no longer called.
- `journey_bot.gd`: `_answer` dispatches the four kinds and the Iceland
  spine; `winter` asks the seer and handles the thralls; `_act` calls
  `_law_land` first and pleads summons and land cases; `_houses` goes to a
  Thing for them; `_raidable` asks `Landtake.raidable`. New functions at
  the end.
- `campaign.gd` `_thaw`: the two land lines are `Landtake.thaw_yield`.
- `winter_hall.gd`: the seer's card and the thralls' card in `open`, their
  answers in `resolve`, their titles and defaults.
- `winter_events.gd` `pick_kind`: thrall unrest needs captives or thralls.
- `families.gd`: `add_house`; three lines in `marry_into`.
- `sandbox.gd`: `_promote` calls `Landtake.on_rank`; `year_end` calls
  `Landtake.year_end`; `_consider_emigration` sets `settled_iceland`.
- `roam.gd` `step_parties`: the `hunters` kind hunts like avengers, with
  no sight limit.
- `hiring.gd` (not in my list; world-life's): the captives' ransom and
  freeing moved to `Thralls` (same ids, same old numbers for plain
  captives).
- `map_screen.gd`: `_decision_detail`, `_show_land` (after `_show_trade`),
  the decision's own title, the button in the place panel, the outlaw chip,
  the luck tooltip.

**The Iceland ending's call site** (for generations): `Landtake.settle_iceland`
ends with `if j.has_method("offer_ending"): j.call("offer_ending",
"iceland")`, which reaches `Journey.offer_ending` on the generations
branch once both are merged (a direct call can replace it then). The flag
is `Band.settled_iceland`.

**New kinds for the map's glyphs** (not mine to draw): party kind
`hunters` (bounty hunters; hostile, mood -1; they draw as the neutral
token today); places `seine` (a hall) and `rouen` (a town), region
`FRANKIA`.

## Measured

`tools/batch_ways.gd -- 8 5 1 all <origin>`, before (main at 0b9cbde) and
after; silver a year is the mean gain, survival is sagas ended of 8. The
new "law-land" line is land held at the end (units a saga), sagas ever
outlawed (and still outlaws at the end), Thing cases a saga and captives
sold a saga. No stalls in any run, before or after.

| Bent | burned hall before | after | younger son before | after | freedman before | after |
|---|---|---|---|---|---|---|
| Viking | 1/8, +55 | 0/8, +126, land 0.0, outlawed 1, sold 46 | 0/8, +57 | 0/8, +47, land 0.9, outlawed 1, sold 33 | 0/8, +58 | 1/8, +52, land 0.4, outlawed 2, sold 20 |
| Trader | 0/8, +52 | 1/8, +55, land 2.2 | 0/8, +60 | 1/8, +63, land 2.2 | 0/8, +83 | 0/8, +60, land 1.8 |
| Law-wise man | 0/8, +109 | 0/8, +41, land 2.6, 3.0 cases | 0/8, +80 | 1/8, +62, land 3.2, 2.9 cases | 0/8, +76 | 0/8, +46, land 2.2, 2.0 cases |
| Berserk | 0/8, +66 | 0/8, +38, land 2.5, outlawed 3 | 0/8, +12 | 0/8, +21, land 0.4, outlawed 3 | 1/8, +24 | 1/8, +40, land 0.8, outlawed 2 |
| Skald | 1/8, +102 | 0/8, +76, land 2.5 | 0/8, +103 | 0/8, +93, land 2.8 | 0/8, +68 | 0/8, +50, land 1.4 |
| King's man | 0/8, +35 | 0/8, +55, land 2.0 | 0/8, +86 | 0/8, +76, land 3.0 | 0/8, +60 | 0/8, +73, land 2.0 |

Reading it: the settled bents now turn 110 to 190 oz of their silver into
land (2 to 3.2 units at 55 oz; the stand-in buys while it has 200 oz more
than it needs), which is why their silver a year is lower: the land yields
back slowly (5 oz and 10 rations a worked unit, a quarter untended, and the
stand-ins seldom have the hands). Land is nobody's main income. The
Viking keeps his captives bound and sells them (20 to 46 a saga over five
years, mostly at Dublin, 18 a head, glutted); in a measured comparison of
four younger-son Viking sagas, captive sales came to 1269 oz before (all
at 15) and 1903 after (Dublin's premium), about +32 oz a year a saga. His
burned-hall +126 is the highest line in the table and he pays for it: the
lowest honor of the non-berserk bents (31 to 44), the raided houses cold
(each head sold -3 with its house, a named woman -20 and honor -3; in
`test_a_slaver_pays_in_honor_and_standing` ten raids sold against ten let
go: 585 oz and honor 20 and standing -100 with the raided house, against
15 oz, honor 80 and standing +100). Eight sagas a line are few: the
Viking's three origins moved -10, +71 and -6 a year. The fated raid of the
seer first added a raid a year (Viking +22 oz, +6 fights); it now only
picks where the summer's first raid falls, adding none.

Outlawed sagas: the berserk (ignores summons, presses at the Thing,
defies) is outlawed in 2 to 3 sagas of 8, the Viking in 1 to 2; none of
them ended; most were still outlaws at the end of the fifth year (no
stand-in had the silver for the pardon, and few had a hull to go west in,
so they lived in the wilds and the west). Iceland opens in 874, after a
five-year batch from 866 ends, so a separate run (six sagas a bent, six
years from 873, the burned hall, a scratch script) measured the land-take:
settled in Iceland trader 6/6 (a knarr), law-wise 5/6, berserk 2/6 (the
outlaws), skald 1/6, Viking and king's man 0/6; no stalls; two king's-man
sagas ended in those years.

`tests/test_omens.gd::test_the_bot_lives_five_years_of_each_bent_without_stalling`
plays five years of each bent with everything on (burned hall, seeds
31..36) and `test_deterministic` plays two years twice. The suite: 505
tests, 0 failed.

## Open

- An outlaw cannot winter at his own farm in Norway (the predicate shuts
  it), but his land is not forfeit; full outlawry should perhaps take it.
- The stand-in outlaws rarely buy their pardon or go west: their silver is
  low. They are not stuck (no stalls), but the outlaw's life could use a
  bot that robs, hunts outlaws (the Grettir clause) and saves for peace.
- The Viking's captive trade is the one new income that can lead a table
  (burned hall); Dublin's price (18) and the standing costs are the knobs.
- Hall-site land is a holding at an existing place (a farm or hall of the
  map), not a new map place; raiders reach it only through the world's own
  raids on that place.
- Settler houses in Iceland are houses with standing but no yearly life
  (they are "abroad" to Families' year); the Althing is a flag that makes
  Iceland a Thing, no more.
- The map draws `hunters` as the neutral token, and the Seine and Rouen
  with the default glyphs (map_icons.gd, map_canvas.gd are not mine).
- The seer's third foretelling (a house's men out after the band) only
  comes when the band has a feud in spring; no house asks are foretold.
- The batch tool starts every saga in 866: Iceland, Rollo (900) and the
  Althing (930) are not in its five years; measured by scratch scripts and
  the tests.
