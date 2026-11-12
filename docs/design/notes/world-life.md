# The summer world alive, and the roads through it fair (12 Nov 2026)

Branch `world-life`. Six things from playtests and batches: the world's
parties were scenery; men could only be had in winter; the trader earned
nothing until he owned a knarr; the six ways were far apart and the
burned hall's vengeance came in a year or two; the escape was won, not
escaped; and a fight on the map was fought on a field drawn at random.

## What the player meets

**The others abroad live their own summer.** Raiders hunt merchants and
fall on farms and small halls near their course; the king's ships hunt
raiders and outlaws; a house at feud with another sends its men against
the other's seat and its men on the water. Nobody fights a battle: a clash
is a strength roll after a day. Each leaves:

- *tidings*: "Word comes that raiders out of Avaldsnes fell on a knarr out
  of Kaupang off Fitjar, and took her and all she carried." when the band
  is within 10 leagues; otherwise kept and told at the next hall, town or
  market ("At Fitjar they tell that ..."), two at a time, none older than
  40 days. "Smoke goes up over the Jæren farms: raiders out of Avaldsnes
  have come ashore there." when a raid starts in earshot.
- *a wreck* where it was fought, for 12 days: silver among the dead, a
  merchant's goods, captives left bound, a man who lived through it (who
  asks to go with the band). "You come upon the leavings of a fight off
  Fitjar: ...  Take what is there / Leave it."
- *a poorer place*: a farm the raiders plundered loses a third of its
  wealth (mended at the year's end like any raided place), is not struck
  again for 60 days, and the raiders carry the silver and a captive (a band
  that beats them later takes it).
- *a killing between houses*: raiders of one house plundering another's
  farm, or two houses' men meeting, go on the houses' feud ledger
  (`Families.record_killing`): nothing between them becomes a grudge, a
  grudge a feud, a feud takes the killing. The houses' own year
  (`Families.year_end`) then climbs or cools it as before.

**The band takes part where it stands** (all through the decision queue
and `_offer_fight`):

- *Come upon a fight* (a party busy with another, within reach): "Ahead of
  you raiders out of Avaldsnes (8 men) and a knarr out of Lade (4 men) are
  at it with axes and spears." Help the one / Help the other / Keep out of
  it. Helping is a fight with the other side, less half the ally's men
  (they hold some of them). Won: a merchant pays a quarter of his cargo's
  worth and his house's standing rises (+15); the king's men speak well of
  the band (+10 with the king, fame +1, a king's man's deed); a house's
  men: +25 with them, -25 with the other and the killing on their ledger;
  joining raiders: half their taking, the merchant's goods, a Viking's deed,
  his house the colder. Lost: the ally is destroyed with you.
- *Stand with farmers being plundered*: when raiders come ashore where the
  band is (or the band comes upon a raid): "Will you stand with the
  farmers?" A fight at the steading (the hall to hold, below). Won: +20 with
  the house, 8 oz and +2 honor, a king's man's deed; refused or lost, the
  raid goes on and is decided by the roll.
- *The king's ships ask passage money* of a band at sea, once a summer each:
  an ounce a man, three at least. Pay (+2 with the king) or refuse (-10
  with the king, and half the time they come on: a fight). An outlaw is
  fought, as the levy ships did.
- *Guard a merchant* from a market or town to a known place: 6 oz and 1.5 a
  day of the way, if he is brought there within the way's days times 1.8
  and three. He goes with the band (`Roam.Party.escorted`), and while he
  does, raiders and outlaws go for the band whatever the odds
  (`Roam.lure`).
- *The ship on the beach*: walked away from in hostile country (an
  ill-wisher's land, or the wilds with raiders or outlaws about), unwatched
  and more than two leagues from the band, she is taken (4% a day, 12% with
  raiders or outlaws within 8 leagues). "Word comes that your karve has been
  taken off the beach by Augvald's kin, who make for Avaldsnes with her."
  It starts a feud with that house (so the Thing, wergild and the rest are
  open), and the thieves (5 men) sail her home, where she lies until the
  summer ends. Come upon them: "Take her back" is a fight; won, she is
  yours again. "Pay for a watch on your ship (2 oz)" at a place that is
  not a friend's keeps her safe there for the year; a well-wisher's beach
  is safe for nothing; a stranger's farm keeps an eye on her.

**Men in summer** (`Hiring`). At a hall, a town or a market three men for
hire (one at a farm), rolled once a place a year, each by name, price,
wage and a line: "Asbjorn, an outlaw from the uplands who asks no
questions and answers none, 3 oz and 1 a month, blooded"; a farmer's son
(4 oz, 1 a month, green), a fisherman's lad (3, 1), a Dane who lost his
ship (9, 2, blooded), a berserk of ill fame (12, 3, blooded, reckless,
Might and Nerve +2, honor -3 to take him), an old hand who has stood in a
king's wall (20, 3, veteran). "Take Asbjorn into your band (3 oz)" is
among the place's deeds. Every 30 days a hired man is paid his wage; a man
not paid loses 15 loyalty ("Ref's pay is short this month; Ref says
nothing, and thinks the more."); a man whose loyalty is under 20 takes his
leave at the next settled place ("Ref takes his leave at Fitjar: the pay is
short."), one at a time. Men lent by a house (`Man.lent_by`) go home at the
summer's end, or at once when the house turns ill-wisher. Captives:
"Let 3 captives be ransomed" at a hall or town (7 oz a head), "Set the
captives free" anywhere settled (honor, a point a head to 3), or kept (sold
at a slave market as before).

**The trader's road** (`TradeRoad`, `Market`, `Knowledge`). Farms and halls
without a market deal in what they make and what they lack
(`WorldRules.local_trade`): Hardanger makes bog iron and wants furs, the
Sogn farms make furs and want iron, Fitjar makes soapstone and wants furs
and wine, Sogndal makes iron and wants soapstone, the Møre farms
soapstone/iron, Giske wants furs and wine, Avaldsnes wine and iron, Agder,
Lier, Trøndelag, Hålogaland and Orkney likewise. A stall holds 10 units at
its baseline; what it makes is half the price, what it lacks 2.2 times,
both moved by the stock (as a market's), and it mends toward its baseline
by 0.3 units a day, so a difference lasts weeks and closes as loads are
carried across it. The middlemen's spread applies as at a market. On the
market panel the farm's stall shows its goods (`can_buy`, `can_sell` per
row). A band on foot carries two loads for the leader and one for each man
(`Market.cargo_capacity`; a ship's hold if that is more).

- *The félag*: at a market, hall or farm that is not an ill-wisher's, a man
  gives the band his goods to carry (up to 4 loads, as room allows) to the
  nearest known place that pays more for them; sold there ("Sell Horda-
  Kari's kin's soapstone here"), the band keeps 40% and the house +6;
  unsold by the winter, -10. One a place a year. It costs nothing: it is
  how a penniless man starts.
- *Passage* on another man's ship now takes the loads, at an ounce a load;
  it is offered too where the band has only a færing (which stays on the
  beach), so a small boat in the wrong sea is not a prison.
- *What sells where*: every market and stall the band comes to is
  remembered (`Band.prices_seen`, `Knowledge.see_prices`), with the
  merchant's `price_talk` every known market as it stands today.
  `Journey.price_book()` gives {places: [{id, name, when, rows: [{good,
  name, buy, sell}]}], runs: [{good, name, from, from_name, buy, to,
  to_name, sell, margin}]}, the best carries first.
- *A poor man's livings*, each once a place a year (fishing twice):
  "Work the farmer's fields" (6 days: 3 oz and 1 a man to four, 6 rations,
  +4 with the house), "Take the herds to the summer pasture" (a farm, 12
  days: 5 oz, 8 rations, every place within 12 leagues comes to be known),
  "Go out with the fishermen" (a farm by the water, 4 days: 10 rations, 2
  oz), "Row in a ship bound for X" (a market, hall or town, a band of four
  or fewer without a ship it can use: up to 14 days at another man's oars
  to a market, hall or town by sea, which need not be known, at 0.7 oz a
  day a man; the band lands there).

**The ground of a fight** (`FightOffer.ground`, from `Journey.ground_here`):
aboard at sea, "sea"; at a farm, hall or town, "farm"; a shore cell,
"strand"; a mountain cell or low land under one, "hills"; else "open".
The choices and the field follow it:

| ground | Take the field | Wait for them | Lay an ambush |
|---|---|---|---|
| sea | on the strand by the ships (meadow, REACH_THE_SHIPS: whoever came on makes for the other's ships) | no | no |
| strand | open sand (meadow, no objective) | no | no |
| farm | the farmstead | "Hold the hall" (THE_HALL, you defend) | "Lie in wait by the road" |
| hills | the hillside (either side high) | "Hold the high ground" (hillside, your line on the slope, a stream before it) | "Wait for them in the narrows" |
| open | drawn as before | "Wait for them at the ford" (the river) | "Lie in wait by the road" |

The scout's report ends with the ground ("You are in the hills, where the
ground is steep and the ways narrow."). `ground` "" (the old sandbox, the
prototype) is the field as before.

**The burned hall's long arc.** Hardanger-Atli's kin (14 men) stand with
their allies: every house tied to them by kin, marriage, fostering or
sworn friendship (Rognvald's kin of Møre by marriage, Thorir Long-chin's
of Jæren by friendship) sends 3 men to a reckoning, unless that ally is
the band's friend, or one of the band's friends is the ally's own enemy and
keeps it at home (Augvald's kin keep Møre busy). `Families.vengeance_
backing`: the band's fighting men and what its friends among their
enemies send (3 each) against the burners' strength and their allies'. Only
when the band's side is 0.8 of theirs do they answer for the burning: they
offer wergild (1.5 times the dead man's: 150 oz, "they pay dearly") and a
case against them can be pleaded at the Thing (before that the case is
shown, shut: "Hardanger-Atli's kin will not answer for the burning at the
Thing while they and their friends are the stronger: you could bring 3
men, they 20. Win friends among their enemies first."). They will not stake
a burning on the island (no holmgang with them). In the field, at a
reckoning or when blood is taken for their silver, the burners are the
jarl's picked men (stat 5), not the farmers of the place.

**The escape** (`Scenario.build_escape`): the ring is the jarl's picked
men, steadier (Nerve +2, heart +4) except the two at the thin place, who
are as before; four more stand off at the yard's corners beside the
burning hall and come up from the flanks as the rounds pass, so a band
that lingers is caught. The ring's leader is named for the burning house
(`Campaign.build_escape(leader_name)`, from `Journey.begin`:
"Hardanger-Atli").

**Smaller things.** `CampaignRules.marriage_houses` names houses of the web
(Horda-Kari's kin, Hrafn's kin, the Sygna kings), and a winter marriage
offer taken ties the band to that house (+30, "marriage"). Houses abroad
(outside Norway's own regions: the monks of Iona, the Danish king's men,
`Families.abroad`) offer no marriage or fostering and cannot be brought to a
reckoning. A lord's work brings half the fame it did. A ship overladen at
sea limps home instead of being stuck.

## Classes and functions

- `WorldLife` (new, `sim/world/world_life.gd`): `spring` (the king's ships,
  houses' men), `tick(j, dt)` (every `life_tick_days`: `_expire`, `_hunt`,
  `_clash`, `_strike`, `_raids`, `_theft`, then `Hiring.reckon`,
  `TradeRoad.check_escort`, and `Market.mend_local`), `preys_on`,
  `strength`, `decide`, `ask_defend`, `meet`, `answer`, `after_fight`,
  `ship_guarded`, `actions`/`act` (the watch), `end_of_summer`, `tell`,
  `hear_news`.
- `TradeRoad` (new): `open_stalls`, `actions`, `act`, `labour_pay`,
  `on_shore`, `felag_offer`, `lose_felag`, `escort_offer`, `check_escort`,
  `end_escort`, `crew_offer`, `end_of_summer`.
- `Hiring` (new): `men_for_hire`, `actions`, `act`, `reckon`,
  `end_of_summer`.
- `Roam.Party`: `prey`, `engaged`, `fray_until`, `hunted`, `strike`,
  `raiding_until`, `loot`, `captives`, `ship`, `faction`, `expire`,
  `escorted`, `leavings`, `text`, `busy()`. `Roam`: `lure`, `news`,
  `struck`, `life_clock`, `add_kings_ships`, `add_house_party`,
  `add_wreck`, `add_escorted`, `set_course`, `_chase_point`.
- `Market`: `_local_price`, `sells_here`, `buys_here`, `mend_local`,
  `cargo_capacity`. `Place.trade`, `stock_mend`. `Knowledge.see_prices`,
  `price_book`.
- `Families`: `reckoning_terms` (allies, allied), `vengeance_backing`,
  `abroad`, `record_killing`.
- `FightOffer.ground`, `title(choice)`, `GROUND_TEXT`;
  `Campaign.offer_fight(..., ground)`, `build_fight` builds from it;
  `Campaign.build_escape(leader_name)`.
- `Journey`: `life`, `ground_here`, `price_book`, `men_for_hire`,
  `_end_of_summer`; hooks in `begin_summer`, `answer` ("world"),
  `_after_fight` ("world_fight", a beaten party's plunder), `advance` and
  `_pass` (`WorldLife.tick`), `_arrived` (prices, news, the escort),
  `_meet`, `actions`/`act`, `market` (a farm's stall), `passages` (loads).
- `Band.felag`, `prices_seen`, `felag_units`; `Man.wage`, `paid_until`,
  `hire_kind`, `lent_by`.
- `JourneyBot`: `_answer_world`, `_trade`, `_livelihood`, `_hire`,
  `_captives`, the vengeance's gifts in `_houses`, a way out of a dead end
  (crew, labour, passage) before it waits.
- Tools: `tools/diag_escape.gd [seeds]`, `tools/diag_saga.gd [seed] [way]
  [origin] [years] [grep]` (one stand-in saga, line by line with the day
  and the silver), `tools/run_one.gd test_x [...]` (one test file);
  `tools/batch_ways.gd` prints a "by year" line under each bent.

## The view (for re-homing)

`view/map_screen.gd`, two additions only: `_show_trade()` directly after
`_show_families()` (a modal: "What sells where": the best carries, every
place's prices as seen, and the men for hire here), and in `_fill_place`
one line before the market, `place_box.add_child(_small("What sells where,
and men for hire", _show_trade))`. `tools/screenshot_game.gd` has a `trade`
command for it. New party kinds for `view/map_icons.gd` (they draw as the
neutral token today): `kings_ships` (the king's ships), `house_men` (a
house's men at feud; `family` names the house), `wreck` (where a fight
was: static, `leavings`), `ship_thieves` (the band's own stolen ship and
her thieves); and a `merchant` with `escorted` true walks with the band.
`map_canvas.gd` draws `raiders`, `levy`, `outlaws` as hostile; the thieves
and the king's ships may want that too.

## Measured

### The ways, before and after (`tools/batch_ways.gd -- 8 5 1 all <origin>`)

Eight sagas of five years a bent, seed 1. "alive" is the sagas still going
at the end of each year; "ship" the sagas that have owned a hull by the end
of years 1-3 (nearly everyone buys a færing in the first summer, before
and after); "avenged" the sagas that have had their vengeance by each
year's end. Silver a year is the mean gain over the years lived.

**The burned hall**

| Bent | alive y1..y5 before | after | silver a year before | after | avenged y1..y5 before | after | fights a year before | after | fame at 5 before | after |
|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/7/7/7/7 | 8/7/7/7/7 | +223 | +125 | 0/5/7/7/7 | 0/0/0/0/1 | 12.5 | 9.0 | 87 | 65 |
| Trader | 8/8/8/8/8 | 8/8/7/7/7 | +51 | +58 | 0/2/4/5/7 | 0/0/1/1/1 | 4.4 | 3.0 | 43 | 26 |
| Law-wise man | 8/8/8/8/8 | 8/7/7/7/7 | +129 | +71 | 0/6/8/8/8 | 0/0/2/6/7 | 4.4 | 3.5 | 73 | 48 |
| Berserk | 8/8/8/8/8 | 8/8/8/8/8 | +103 | +102 | 7/8/8/8/8 | 0/0/0/2/6 | 10.4 | 9.0 | 88 | 83 |
| Skald | 8/8/8/8/8 | 8/8/8/8/7 | +106 | +107 | 0/4/7/7/7 | 0/1/4/6/6 | 4.4 | 3.8 | 90 | 93 |
| King's man | 8/8/8/8/8 | 8/8/7/7/7 | +63 | +68 | 1/4/5/8/8 | 0/0/0/1/1 | 6.8 | 5.2 | 100 | 58 |

**The younger son**

| Bent | alive y1..y5 before | after | silver a year before | after | steps before | after | fights a year before | after | fame at 5 before | after |
|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 8/8/8/8/8 | 8/8/8/8/8 | +240 | +160 | 3.0 | 2.9 | 13.0 | 10.9 | 94 | 74 |
| Trader | 8/8/8/8/8 | 8/8/8/8/8 | +30 | +92 | 2.2 | 3.0 | 3.3 | 0.9 | 32 | 23 |
| Law-wise man | 8/8/8/8/8 | 8/8/8/8/8 | +98 | +82 | 2.9 | 2.8 | 2.8 | 1.6 | 51 | 33 |
| Berserk | 7/7/7/7/7 | 8/8/8/8/8 | +32 | +41 | 2.8 | 2.9 | 7.6 | 5.5 | 66 | 59 |
| Skald | 8/8/8/8/8 | 8/7/7/7/7 | +101 | +88 | 3.0 | 3.0 | 3.2 | 1.4 | 91 | 75 |
| King's man | 8/8/8/8/8 | 8/8/7/7/7 | +68 | +125 | 3.0 | 2.9 | 6.4 | 4.6 | 96 | 77 |

**The freedman**

| Bent | alive y1..y5 before | after | silver a year before | after | steps before | after | fights a year before | after | fame at 5 before | after |
|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 6/6/6/6/6 | 8/8/8/8/8 | +119 | +122 | 2.6 | 2.8 | 8.5 | 7.6 | 66 | 61 |
| Trader | 7/7/7/7/7 | 8/8/7/7/7 | +8 | +59 | 2.2 | 2.6 | 4.6 | 0.8 | 25 | 20 |
| Law-wise man | 6/6/6/6/6 | 8/8/8/8/8 | +54 | +69 | 2.5 | 2.8 | 3.8 | 1.7 | 36 | 28 |
| Berserk | 7/7/7/7/7 | 8/8/8/8/8 | +15 | +26 | 2.5 | 2.6 | 7.9 | 4.0 | 47 | 37 |
| Skald | 7/6/6/6/6 | 8/8/8/8/8 | +77 | +63 | 2.8 | 2.6 | 2.8 | 1.2 | 63 | 66 |
| King's man | 4/4/4/4/4 | 8/7/7/7/7 | +46 | +67 | 2.0 | 2.5 | 3.8 | 2.8 | 56 | 53 |

Ships: before, nearly every saga owned a færing by the end of its first
summer; after, most still do, but the younger son's berserk 3 of 8 (all by
year 3), the freedman's raider 6 of 8 and the burned hall's raider and
berserk 7 of 8 (all by year 2): men for hire and their wages now compete
for the first ounces. The trader goes from foot to færing to knarr on what
he carries (one freedman trader read line by line: two loads of a
partner's soapstone on day 2, a færing on day 42 from a place at another
man's oars, a guarded merchant for 26 oz, a karve in year 2, a knarr in
year 4). No
`STALL` in any batch. Steps reached on the ways are 2.5 to 3.0 everywhere
(2.0 to 3.0 before).

What moved and why: the Viking's silver came down (+223/+240 to +125/
+160: wages for hired men, the king's ships, raiders who strike the farms he
would have plundered) and stays the spikiest and bloodiest (3.8 to 4.9 of
his men dead in five years); the trader's went up from almost nothing to
+58 to +92 (stalls, félag, guarding merchants, passage with loads), with the
fewest fights; the king's man's fame is 53 to 77 at five years, not 96 to
100 (half the fame from a lord's work); the freedman's first year no
longer kills (every bent 8/8 alive at year 1; the raider and the king's man
had lost a quarter and a half of theirs); the berserk is still the poorest
(+26 to +102) and the most varied.

**The vengeance** is now the long arc: from the burned hall, taken by the
end of year 2 in 1 saga of 48 (before 29), by year 4 in 16 of 48 (before
43), by year 5 in 22 (before 45). The law-wise man and the skald, who make
friends of houses, get there in years 3 to 5; the Viking, who makes
enemies, and the trader and the king's man rarely in five years.

### The houses (`tools/batch_families.gd -- 8 5 1 burned_hall`)

| Bent | friends before | after | ill-wishers before | after | feuds ended before | after | avenged before | after | house feuds open before | after | tidings a year before | after |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | 3.1 | 4.4 | 12.0 | 9.1 | 12.0 | 7.2 | 7/8 | 1/8 | 2.4 | 4.6 | 3.3 | 4.0 |
| Trader | 4.6 | 9.9 | 1.0 | 0.9 | 1.0 | 0.5 | 7/8 | 1/8 | 1.8 | 4.2 | 3.6 | 4.5 |
| Law-wise man | 11.2 | 10.8 | 0.4 | 0.9 | 1.2 | 1.0 | 8/8 | 7/8 | 1.0 | 2.0 | 3.4 | 3.8 |
| Berserk | 2.2 | 3.4 | 7.4 | 6.9 | 6.2 | 7.6 | 8/8 | 6/8 | 1.5 | 3.4 | 3.4 | 4.6 |
| Skald | 12.4 | 13.6 | 0.9 | 0.9 | 1.2 | 0.8 | 7/8 | 6/8 | 1.8 | 3.1 | 3.7 | 4.5 |
| King's man | 8.8 | 9.1 | 2.5 | 2.1 | 1.6 | 0.4 | 8/8 | 1/8 | 3.0 | 4.6 | 3.9 | 4.3 |

More feuds between houses stay open (the houses' men now fight in summer
and a fight between them is a killing; a raid by one house's ship on
another's farm leaves a grudge). The band's ties are about as before, the
trader's friends doubled (félag partners, guarded merchants).

### The escape (`tools/diag_escape.gd`)

| player | seeds | out on his feet before | after | mean rounds before | after | burners broken a fight before | after | burners routed before | after |
|---|---|---|---|---|---|---|---|---|---|
| follows the tutorial | 20 / 30 | 19/20 | 27/30 | 9.7 | 11.8 | 3.5 | 2.0 | 0 | 0 |
| skips (the dice) | 20 / 30 | 18/20 | 21/30 | 8.6 | 10.7 | 3.5 | 1.9 | 0 | 0 |
| does nothing | 20 / 30 | 5/20 | 3/30 | 13.5 | 15.6 | 3.6 | 2.5 | 1 | 0 |
| charges | 20 / 30 | 8/20 | 2/30 | 11.1 | 11.8 | 3.7 | 1.8 | 1 | 0 |

Of the two broken a fight now, the two men at the thin place are most of
it. The tested guarantees hold: out on his feet on 9 of seeds 1-10 following
the tutorial, the leader never dies (30 seeds doing nothing and charging).
Mean rounds following the tutorial are 11.8, up from 9.7: the men coming
up from the flanks keep contact longer before Withdraw is open.

`tools/diag_mixed.gd -- 40 1` gives the same output byte for byte on `main`
and on this branch: battle rules are unchanged (the new `CombatRules`
fields are read only by the escape).

### The trader's road and no money pump (`tests/test_trade_road.gd`)

Four loads of iron walked from Hardanger to the Sogn farms: 30 to 36 oz,
the gap 5 to 2 oz, mended in about two months. Every two places that make
and lack the same goods, looped both ways as fast as a band with a knarr
can walk it, buying only while it pays, for about 1000 days: Hardanger and
Sogn 0.3 oz a day (338 oz in 975 days), Sogn and Fitjar 0.3, Kaupang and
Hedeby 0.0 (7 oz in 2080 days), Lier and Kaupang 0.0; never growing. The
market tests that pinned the old pump fix pass unchanged.

### The party step

`tests/test_world_life.gd::test_the_party_step_is_cheap`, 400 steps of 0.2
days with the summer's parties (8 to 9 of them): `Roam.step_parties` 270 to
410 microseconds a step and `WorldLife.tick` 45 to 70 a step (it reckons
every half day), measured on a shared, loaded machine. The worst single
steps (10 to 60 ms) are the first sea route between a pair of places, found
once and kept for the session (`Roam.sea_route`'s static cache), which the
merchants already paid before; the raiders now strike by those kept routes,
houses' men set out by them, a ship off her course after a fight makes for
the nearest harbour, and the king's ships and houses' men keep to Norway's
waters, so new searches are few.

## Open

- The berserk is the poorest bent (+26 to +102 a year): his honor runs low,
  the challenges stop and lords shut their doors; guarding merchants helps
  a little. His dread could be worth more in summer (a merchant pays more
  for a berserk's guard, raiders turn away).
- The Viking rarely has his vengeance in five years (he makes enemies of
  the burners' enemies too); the trader and the king's man rarely (the
  stand-in player gives gifts but does not otherwise court the burners'
  enemies). That may be right for a first long arc; a player who courts
  them gets there in three to four.
- A fight the band takes a side in is fought by the band alone; the ally's
  men only take some of the enemy off it (half the ally's number). The
  battle could field them as a third band.
- The view shows the farm stalls on the market panel with 0 for a price
  the stall does not deal in; "-" would read better (map_screen's market
  rows are not mine).
- Hired men swear themselves at the summer's end when loyalty is 50 or
  more; the winter's own hall (another agent's) may want to do this at
  Yule instead.
- The houses' feuds open at the end went from about 2 to 4: more war about
  the country, which may want the houses' own year to cool feuds a little
  faster.
- Escape mean rounds 11.8 (aimed near 10).
- `Sandbox.summer` (the old AI summer) has none of this.
