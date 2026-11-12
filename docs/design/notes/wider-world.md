# The wider world (wider-world)

Branch `wider-world`. The concept promised a world beyond Norway (West:
Orkney, Shetland, the Hebrides, Norse Dublin, Iceland; East: the river
routes through Gardariki to Miklagard, with portages, and silk coming
back). The map had Orkney, Dublin, Iona, Northumbria, the Seine, Iceland,
Hedeby, Ribe, Birka and Gotland, and nothing east of Gotland. Now:

- **Shetland** and **the Hebrides** (with **the farms of Skye**) are
  places on the free-roam map, with their own houses, faction, stalls,
  sea names and tidings.
- **The road east** runs from Birka or Gotland over the Baltic and up
  the Gulf of Finland and the Neva to **Aldeigjuborg**, up the Volkhov to
  **Holmgard**, across Lake Ilmen and up the Lovat to **the haul to the
  Dnieper** (a portage: the ship goes overland on rollers), down the
  Dnieper to **Koenugard**, round **the rapids of the Dnieper** (a second
  portage, where the Pechenegs wait), across the Black Sea and through
  the Sound to **Miklagard**. Furs, amber, walrus ivory and captives
  fetch more at every stage going east; silk is cheap at the far end and
  dear at home.
- At Miklagard a band may **take service in the emperor's guard** for the
  rest of the summer and the winter: pay, fame, a lord's deeds, a line in
  the saga.

Screenshots (844x390) are in `wider-world-shots/` (commands at the end).

## What the player sees and does

**Finding it.** At the great markets of the north (Kaupang, Lade,
Bjarkøy, Hedeby, Ribe, Dublin) "the talk is of the road east ... It
begins at Birka", and Birka becomes known (`EastRoad.arrived`). From
there each stop of the road shows the next, by the sea lanes that
`Knowledge.reveal` already follows (Birka and Gotland show Aldeigjuborg,
Aldeigjuborg Holmgard, Holmgard Koenugard, Koenugard Miklagard). Orkney
shows Shetland and the Hebrides; Iona shows Skye. Each place's panel
carries a line or two on what it is (`NorwayData.ABOUT`, drawn by
`MapScreen._wider_about` under the kind and house).

**Going.** Tap Miklagard from Kaupang and the band sails, rows and hauls
there through `Journey` like anywhere else; there is no other way to go:

- The rivers are water a cell wide (`NorwayData.RIVERS`), where a ship
  makes `MapGrid.RIVER_PACE` (0.6) of her pace.
- The portages are land a ship is hauled over (`NorwayData.PORTAGES`):
  `find_path` lets a band that has its ship with it cross those cells,
  aboard, at its hull's haul pace (`WorldRules.portage_haul`: færing 2,
  karve 1.2, snekkja 0.9, knarr 0.6, longship 0.5 leagues a day). The
  haul to the Dnieper is 7 leagues: 3.5 days in a færing, 6 in a karve,
  12 in a knarr. The rapids are 4.
- Starting a haul is told ("The crew run the knarr up onto the rollers:
  the haul to the Dnieper, 7 leagues overland, 12 days or so with a
  knarr."), and so is its end, with what it cost: every man's loyalty
  drops `portage_loyalty` (2) and each has `portage_strain` (15%) of a
  strained back (a turn's healing). Each day on the rollers has
  `portage_ambush_day` (2.5%) of an ambush: men of the forest (6, green)
  on the first haul, Pecheneg riders (8, blooded) at the rapids, offered
  as an ordinary fight on the ground where the band stands (the strand,
  its ship behind it). Beaten or fled, half of every good in the hold is
  carried off (`EastRoad.after_fight`).
- On foot the Rus' lands are slow (`MapGrid.FLAT_COST`: trackless forest
  and bog 3x, the steppe 2.2x); without it a band would land on the
  Prussian shore, leave its ship and walk to Miklagard quicker than the
  river road.

**How long.** Kaupang to Miklagard and back: a karve about 104 days, a
knarr about 135 (`test_the_round_trip_is_most_of_a_summer` pins it at
over half a 200-day summer and under the summer less a fortnight). From
Hordaland in a knarr the round trip is about 154 days: set out in the
spring or winter abroad. Fitjar to Shetland 4 days by karve, to the
Hebrides 6, to Holmgard 34, to Koenugard 47, to Miklagard 61.

**What it pays.** Prices are the old market model (`Market`) with three
place-level knobs in `WorldRules` (section "The wider world"):

| | Holmgard | Koenugard | Miklagard | Kaupang |
|---|---|---|---|---|
| furs (base 4) | 0.8 | 1.6 | 2.4 | 1.0 |
| amber (8) | 1.4 | 1.8 | 2.4 | 1.0 |
| walrus ivory (12) | 1.5 | 2.0 | 2.4 | 1.0 |
| silk (25) | 0.75 | 0.6 | 0.35 | 1.0 |
| middlemen (spread) | 0.15 | 0.15 | 0.2 | 0.1 |
| a captive | 16 | 18 | 26 | (Hedeby 15) |

(`place_factor`, `place_spread`, `place_captive_price`.) Miklagard is a
deep market (`place_depth` 60 against the usual 20), so a hold bought or
sold there moves its price a third as much; the eastern towns make no
goods good each year (`place_sources`) except Holmgard's furs, so a
year's buying is felt the next. Silk: 11 oz to a stranger at Miklagard,
22 paid at Kaupang; ten units bought there and sold here make 61 oz,
ten furs from Bjarkøy to Hedeby 17. By the day of the round trip the
far road pays 0.5 oz a day for those ten units against the near road's
0.3: more a voyage and a little more a day, not a gold mine
(`test_silk_is_dear_at_home_cheap_at_miklagard_and_fair_for_the_road`
holds it under twice). What makes the voyage is the whole hold out and
back, the captives, and the guard.

**The emperor's guard.** At Miklagard, "Take service in the emperor's
guard (N oz)": `guard_pay` 40 + `guard_pay_man` 6 a man, `guard_fame` 8,
`guard_honor` 2, `guard_deeds` 3 of the king's man's deeds, the Greeks'
goodwill; the rest of the summer is the emperor's and the band winters
in Miklagard (`EastRoad.act`). A band of fewer than 3 is not taken. The
saga's chronicle gets "Egil stood in the emperor's guard at Miklagard".

**The west.** Shetland: a poor farmstead (wealth 15) under the Orkney
jarls, the Shetland steaders' house, a soapstone quarry (sells
soapstone, buys iron), on the straight line from Hordaland to Iceland
(Shetland to Iceland 11 days in a knarr, Orkney 10). The Hebrides: Ketil
Flatnose's hall (wealth 45), his own lord ("the lords of the Isles",
friends of Dublin, at odds with Orkney); his house is married into Ivar's
kin at Dublin (Aud the Deep-Minded and Olaf the White), has grudges with
the Orkney jarls and the Norse-Gaels of Skye and an old friendship with
the Sygna kings. The farms of Skye: wealth 40, defenses 1, no beacons,
the Norse-Gaels' house: raiding country. A viking ship winters in
Shetland, the Hebrides or Skye each spring (`roam_wider_raiders`,
`wider_raider_lairs`) and goes about the places near it first, so
raiders out of Shetland are heard of on the Norwegian coast.

**The east's own life.** Two Rus merchants (`roam_east_merchants`) ply
between the eastern towns and Birka and Gotland, carrying furs, amber,
silk or ivory, and keep to that road (`Roam.Party.road`). The home
waters' merchants, raiders and king's ships no longer put out from or
make for an eastern town (`Roam.far_east`). Tidings of the river road
are told in its towns and the home waters' at home (`WorldLife.hear_news`,
`WorldRules.EAST_FROM_X`).

## The map

The grid grew from 180x140 to 258x176 leagues (x to 200, y to 162). The
far east is drawn further east at the map's own scale, not as an inset:
the band goes there through the same `Roam`, `find_path` and canvas as
everywhere else, the portages are drawn where they are hauled, and an
inset would need a second map screen and a jump the sim does not have.
The distances are compressed against the real ones (as Norway's own are)
so that the round trip is most of a summer, not more than one.

- **Land and water**: a mainland polygon (the Wendish and Prussian shore,
  the Balts, both shores of the Gulf of Finland, Finland and the Lapp
  country round the Bothnian gulf, the Rus' lands to the map's edge, the
  Frankish and Greek lands to its foot); `WATERS` cut out Ladoga, Ilmen,
  the Black Sea (with the Crimea and the Sea of Azov) and the Sea of
  Marmara; `RIVERS` cut the Neva, Volkhov, Lovat, Dnieper and the Sound.
  Shetland, the Long Isle and Skye are new islands.
- **Relief**: `FLATS` (the forests, wooded; the steppe, open) never rise
  to mountain in `MapGrid` and are held low in `MapArt` (`FLAT_HIGH`), so
  no fells stand in Gardariki; the forest is thicker
  (`FLAT_WOOD_FROM`) and the steppe bare.
- **Names**: seas "The Black Sea", "Lake Ladoga", "The Gulf of Finland",
  "The Sea of the Isles"; lands GARDARIKI, THE STEPPE, THE LAND OF THE
  GREEKS, WENDLAND, FINNMARK, SCOTLAND (`MapCanvas.SEAS`, `LANDS`). The
  Baltic's name moved east off Kattegat's.
- **The portages** are drawn once a town of the road is known: a dotted
  pale track from water to water with a roller at each end, and the name
  from zoom 7 (`MapCanvas._draw_hauls`). A band on the rollers is drawn
  on land with its ship beside it.
- **Camera**: unchanged (`ZOOM_MIN` 4). At 4 the map pane of a phone
  shows about 117 leagues: Norway and the Baltic, or the whole river road
  from Ladoga to Koenugard; the rest is a pan away. Going lower would
  crowd the labels into each other, and the player is never asked to see
  the whole world at once. Labels thin by rank as before; the new names
  keep to the same collision pass.
- **Cost**: `MapGrid` builds in 110-180 ms (was about 60); `MapArt` has
  1.8x the cells. Long paths are dearer: Kaupang to Miklagard is a 250-320
  ms search (found once and kept by `Roam.place_days` for a place; from
  the wilds it is searched again).

## Rules and numbers (WorldRules, "The wider world")

`EAST_ROAD_MARKETS`, `EAST_FROM_X` 128, `east_talk_markets`,
`roam_east_merchants` 2, `east_merchant_goods`, `roam_wider_raiders` 1,
`wider_raider_lairs`, `wider_raider_reach` 25, `place_factor`,
`place_sources`, `place_depth`, `place_spread`, `place_captive_price`,
`wider_local_trade`, `portage_haul`, `portage_ambush_day` 0.025,
`portage_ambushers`, `portage_ambush_spread` 2, `portage_strain` 0.15,
`portage_loyalty` 2, `guard_pay` 40, `guard_pay_man` 6, `guard_fame` 8,
`guard_honor` 2, `guard_deeds` 3, `guard_min_men` 3. In `MapGrid`:
`RIVER_PACE` 0.6, `HAUL_SHARE` 0.15 (others' ships on the rollers, and
the pace when a caller gives no haul), `FLAT_COST`.

## Classes and functions

- `NorwayData`: the seven places, `ABOUT`, the new `SHORES`, `WATERS`,
  `RIVERS`, `PORTAGES`, `FLATS`, lanes, factions (`hebrides`, `rus`,
  `kiev`, `greeks`; Shetland to `orkney`), houses (Ketil Flatnose's kin,
  Rurik's kin, Askold's kin, the Emperor's men; the eastern three with
  `western` false) and ties.
- `MapGrid`: `river`, `portage`, `flat` per cell; `is_river`,
  `portage_at`, `walk_cost`, `steps`; `find_path(..., haul)`.
- `Roam`: `plot`, `place_days`, `step_band` take the haul; `far_east`,
  `far_east_at`, `_populate_wider`, `_east_markets`; `Party.road`; others'
  ships slow on rivers and portages (`_follow`).
- `Market`: `factor_at`, `spread_at`, `depth`, `is_source`,
  `buys_captives`, `captive_base`.
- `EastRoad` (new, static): `haul`, `hauling`, `tick`, `after_fight`,
  `arrived`, `about`, `actions`, `act`, `guard_pay`. State in
  `Journey.life` ("haul", "guard"), so it saves with the summer.
- `JourneyBot`: `_wider`, `_east`, `_at_miklagard`, `_west_raid`.
- Hooks in `Journey` (one line each): `days_to`, `_plot`, `advance`
  (haul pace, `EastRoad.tick`), `_arrived` (`EastRoad.arrived`),
  `actions`/`act`, `_after_fight`.

## The stand-in players

- A trader with a hold of 6 or more, 150 oz and the summer for it (the
  road there fits with 20 days to spare) sets out east in 35% of the
  springs he could (`EAST_CHANCE` 0.25), once in three years at most: he buys ivory, amber
  and furs for half his silver at the first market on his way, goes stop
  by stop to Miklagard, sells everything, buys silk with two thirds of
  his silver while it would sell at Kaupang for half as much again, and
  turns for home; with the summer too far gone he stands in the emperor's
  guard and winters there. He sells the silk at the first home market
  (Kaupang, Lade, Bjarkøy, Hedeby, Ribe).
- A viking with a ship and 40 days left turns for Skye or the Hebrides in
  35% of his summers, if he knows them and they are raidable with his men.
- An outlaw (any bent) with 30 days left winters in Shetland if he knows
  it and can reach it.
- The other ways' stand-ins do not look for "the nearest" living on the
  river road or in the Isles (`_nearest`: the far east only once there,
  the Isles only as an outlaw), take no passage up the river road, and a
  man in a færing goes no further than `FAERING_REACH` (30) days for the
  nearest anything: the new southern shore of the Baltic lets a færing
  creep round to Orkney in about 110 days, and the stand-ins took it.
  The world keeps the home waters' work on their side too: a lord's
  escort (`Contracts`), a merchant's guard, a félag and a place at the
  oars (`TradeRoad`) never cross between the river road and the home
  waters; the road is a summer's venture, not an errand.
- Their dice are their own (`c.rng.fork(label)`, not `Journey._fork`), so
  the choice does not shift the rest of the saga's dice.

## What was measured

Battles unchanged (before and after, the same lines):
`diag_mixed.gd -- 40 1`: `TOTAL 40 fights, 13 wins (32%)`;
`diag_identity.gd -- 20 1`: `ALL 1946475587`.

The save: `save_check.gd -- 2 all trader,viking all 1`:
`== 201 OK, 0 DIFF, 3 never came to the point`. A pre-existing lazy
cache (`Omens.short_summer` writes the year's early-winter flag into
`Journey.life` the first time it is asked, which `SaveStore.write`'s
summary did after encoding) made `test_store_writes_reads_and_refuses_the_bad`
fail once the stand-ins' path changed; `Journey.begin_summer` now asks
it on the first day.

The ways, `batch_ways.gd -- N 4 1 all younger_son`, worth a year (silver
+ land + hull; the trader's unsold silk is not counted):

| Way | before, 6 sagas | after, 6 | before, 12 | after, 12 |
|---|---|---|---|---|
| Viking | +181 | +214 | +206 | +204 |
| Trader | +170 | +130 | +173 | +124 |
| Law-wise man | +134 | +151 | +140 | +149 |
| Berserk | +128 | +183 | +146 | +172 |
| Skald | +146 | +118 | +130 | +121 |
| King's man | +177 | +152 | +168 | +149 |
| richest / poorest | 1.41 | 1.81 | 1.58 | 1.69 |

No STALL in any run. The trader went from second-richest to fifth: in
12 sagas of 4 years he went east 5 times (all reached Miklagard, 4 took
the guard and wintered there, 21 hauls, 9 sales of silk at home), and a
summer on the road is worth about one at home while the silk still in
his hold at the year's end counts for nothing in the batch. The 6-saga
batch swings a lot with the seed (the berserk +55 there, +26 over 12).
The viking raided Skye 4 times in 12 sagas.

Before tightening the stand-ins (above) the batch had the king's man
escorting merchants to Koenugard for 25 oz, færings creeping round the
Baltic, and the trader wintering in the Isles: richest/poorest 2.1.

## Open

- The trader's venture is a fair summer, not a better one, and the
  batch does not count cargo; whether a player finds it worth the
  summer wants a person playing it. Prices to tune: `place_factor`
  (Miklagard 2.4 for furs, amber, ivory), `place_depth`, `guard_pay`.
- A lord at Miklagard still offers the generic work (hunt outlaws,
  escort a merchant to Koenugard) and the generic hires (a Dane who lost
  his ship): the east has no work or men of its own yet (Varangian
  recruits, Rus hirelings).
- The portage ambushers are fought as outlaws on the strand; the
  Pechenegs have no horse and no steppe ground of their own.
- Raiding Miklagard is offered (24 champions): it is suicide, and says
  so, but perhaps it should not be offered at all.
- Tidings between the halves are kept apart by a line on the map
  (`EAST_FROM_X`); news from Miklagard is never told at home.
- `MapArt` builds 1.8x the cells: on a phone that is about twice the
  build hitch the map-art notes measured. Long paths (Norway to
  Miklagard) are 250-320 ms searches; `days_to` from the wilds is not
  kept, so tapping far places from open water costs that each time.
- The Faroes are not on the map (the "Faroes-ward sea" is open water).
- A færing can creep round the Baltic to the west in about 110 days;
  the stand-ins are kept from it, a player is not.

## Commands for the shots

From `game/`, `timeout 300 xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_map.gd -- <out.png> younger_son 7 answer:ignore` and:

```
1_whole_z4       knowall zoom:4 cam:110:72
2_west_z8        knowall zoom:8 cam:-6:50
3_east_road_z8   knowall zoom:8 cam:168:80
4_black_sea_z6   knowall zoom:6 cam:170:135
5_lakes_z12      knowall zoom:12 cam:166:52
```

and with `tools/screenshot_game.gd -- <out.png> younger_son <seed> answer:ignore`:

```
6_on_the_rollers    (seed 8) men:6 knarr at:holmgard go:koenugard days:3 answer:pass days:3 answer:pass days:3 answer:pass days:2 answer:pass zoom:16
7_hebrides_panel    (seed 7) men:6 knarr at:hebrides zoom:10 place:3000
8_miklagard_guard   (seed 7) men:6 knarr at:miklagard zoom:12 place:1130
9_miklagard_panel   (seed 7) men:6 knarr at:miklagard zoom:12 place:3000
```

(The hint card over 9 and 7, "here your saga begins", is the tool's `at:`
putting the band there on its first day.)
