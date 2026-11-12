# The winter in the hall (12 Nov 2026)

Branch `winter-hall`. Before this the winter was one call: "Winter here"
ran `Campaign.winter` with the default plan and a block of report text
came up. Now the winter is played: seven steps in the hall, each a few
small choices whose cost is shown before anything is spent, and at the
end the year told and the spring. The ring-giving is the heart of it.

## What the player meets

"Winter here" (or the season closing) opens the hall over the map
(`view/winter_screen.gd`): the long fire, the benches and the rafters
drawn behind, a header with the step and where the band winters, a tally
(silver, and what the choices will spend; food, and what will be left at
the thaw; men), the step's rows to press, and Back / Go on with "3 of 7
next: the yard" between them. Back is free until the winter is lived:
nothing is spent while the player chooses.

Where the band winters is read from the place (`WinterHall._lodge`):

| Lodging | When | What it means |
|---|---|---|
| home | the band's own hall (`Band.hall_at`, its origin's place) | free; the benches are its own: it can build, and a man without a bench is shamed |
| again | where it wintered last (`Band.home`), not its own | free, as before; the benches are the host's |
| friend | a friend's seat (`Families.shelter` "free") | free; the host's benches |
| lord | a hall whose realm thinks well of the band (`FactionAI.relation` >= `lords_hall_relation`, 40) | free, and the lord's board feeds the band (`WinterPlan.host_rations`): the store is untouched; he holds Yule, so no feast of one's own |
| guest | anywhere else settled | `guest_winter_per_man` (1 oz) a man, as before |
| camp | the snow caught the band with no roof it knows | no buying, no benches, every man loses `camp_cold_loyalty` (3) a turn, hunting is `camp_hunt_bonus` (1) better |

A guest is never shamed for want of a bench: the benches are his host's
(`plan_for` lifts the seats to the men's number away from home).

1. **The store.** Mouths, the rations the four turns need (the feast
   included), what the store holds and keeps past the first turn
   (spoilage), and a warning before it happens: "Short by 12 rations: men
   go hungry at the end of winter, 8 loyalty lost for each turn a man
   goes without. Hungry, Ketil, Orm would leave at the thaw." Rows: buy
   rations 5 at a time (`hall_buy_lot`, at the place's grain price or
   `farm_food_price`), men to hunt (about 3 a man a turn, they do not
   drill), a Yule feast (2 rations a mouth, fame +3), the grain in the
   hold (5 rations a unit), each man sent home for the winter (one mouth
   fewer, -4 loyalty, back at the thaw if loyalty >= 40, else on a
   coin-flip). At the band's own hall: build benches (+6 seats, 20 oz),
   a storehouse (+60 kept, 30), a smithy (40), a boathouse (35), a byre
   (2 rations a turn, 25) (`Hall.build`, which nothing called before).
2. **The ring-giving.** Every man as a row, the men with the summer's
   deeds first: "Hrafn. Veteran front rank. 10 fights, 6 put down,
   wounded 2 times. Would die for you; wants fame. His deeds want
   honouring." Less / More steps through what he can be given: nothing,
   3 oz, an arm-ring of 8 oz, then the arms he lacks: a helmet 12, a
   sword 25, a mail shirt 45 (`hall_gift_ounces`, `arms_price`). Silver
   goes through `Loyalty.gift` (2 a ounce to 20, +5 for a ring, +5 for a
   man who wants silver); arms through `Loyalty.gift_gear` (+15) and
   `loyalty_arms_bonus` (+5), and he fights with them. New rules:
   - a man with a great deed this year (a told deed, or
     `great_deed_kills` 3 put down) gains `loyalty_deed_honoured` (+5) for
     any gift, and loses `loyalty_passed_over` (10) for none: "he takes it
     ill";
   - given at least `open_hand_ounces` (4) a man on average: fame +2,
     honor +1, "called open-handed";
   - under `miser_ounces` (1) a man from a chest of `miser_chest` (20) or
     more: every man -6, honor -2, "the benches say so".
   The deeds come from `Man.year_tally` (fights, kills, wounds, broke,
   deeds), counted in `Campaign.conclude_fight` and cleared at the thaw.
3. **The yard.** How many drill (the free men less the hunters), each a
   point a turn in the shape chosen, to 3. Rows: each man his own
   weakness (no shape), the boar's snout, the refused flanks, each with
   how well the band knows it in words; swear "Swine!" (the snout, then
   push) or "Hedgehog!" (refused flanks, then hold), which becomes the
   band's custom shout in battle; each man's place (front rank, second
   rank, bows: `Man.role`) and who carries the banner.
4. **The men.** Those who come to the hall (as many as fame draws,
   `Leader.recruits_drawn`, to the cap), named, with a line ("An exiled
   jarl's son of 20, steady enough. He wants fame. He asks a ring of 10
   oz to swear."; `recruit_ask` by origin, most ask a seat and their
   keep); they eat this winter. Lead the wall yourself, or let the
   war-leader lead it. Every man in seating order with Seat higher
   (`Loyalty.seating_offense`: +4 to him, -6 to the man passed, double
   for a boastful one), War-leader, Second (the sworn second, the heir:
   a separate role from the war-leader, though one man may be both), Let
   go (his oath brothers take it as `bond_brother_left`).
5. **The hall's talk.** One to three visitors and troubles
   (`hall_talk_min`/`max`), a house's winter ask (a son to foster, a
   daughter to marry, from `Families.asks`; a marriage is not asked in
   the winter of a year a house asked one in the spring), and always the
   Yule cup (vow nothing, or vow a deed for the summer: kept by winning
   `vow_wins_needed` fights, judged next winter as before). Each is a
   card with its options and their cost: a skald (pay 5 oz for fame +3,
   or send him on), a trader (15 rations for 10 oz), an outlaw at the
   door (take him in, honor -1), an envoy (fame +1, a rumour), sickness
   (two men abed 2 turns, or a wise-woman for 4 oz and they are up at
   once), a storm (mend the ship for 3 oz, or she is hurt 1), the stores
   (only with thralls: captives kept or land worked), a quarrel between
   two named men (find for one: +6 / -6; make them drink together: 3 oz
   each, +3 each and their bond +10, a law-wise deed; when it came to a
   challenge, let them go to the island: one comes back hurt 2 turns,
   their bond -15), spears in the snow or fire in the night (only at
   feud; fought at once and told by the saga).
6. **The year told.** Go on from the talk lives the winter through:
   everything chosen is done in a fixed order (`WinterHall.resolve`: the
   men let go, sent home and taken on; the war-leader and the second;
   the seats; the buildings; places and the banner; the shape and the
   shout; the store; the talk; the ring-giving; then the four turns and
   the thaw through `Campaign.winter` with a plan made from the
   choices). The telling: the skald's verse (four lines from the year:
   the high seat or the shut chest, the raven fed so many times, who fed
   the wolf, the benches' gold or their empty hands), the year as the
   chronicle has it, the winter (what was done, who healed, who grew,
   who left, the houses' tidings), the household (the wife and her keys,
   each child), and the saga's standing: fame, honor, luck, the
   leader's name and what he is reckoned. The ways of life can be
   stepped down here.
7. **Spring.** Begin where the band wintered, or at a known settled
   place within `spring_days` (6) on foot; a ship with the band stays on
   the beach where she lay.

## The war-leader (stallari)

`Band.war_leader_id` and `Band.leader_keeps_back`, named in the hall.
`Campaign.line_men()` is who stands in the line: when the war-leader is
named, keeps-back is set and he is fit to fight (`commanding()`), he is
first and the leader is not there at all. `build_fight` marks his
warrior `is_leader`, so the battle's leader (`Battle.leader_of(0)`), its
voice and the side's leader AI are his, with his own stats and tier; he
is `ours[0]`, the man the battle screen gives the player. `offer_fight`
counts the men by the same list. The cost: only
`war_leader_fame_share` (half) of the fight's fame is the leader's. The
leader cannot fall in a fight he keeps out of. Duels and the burned
hall's escape are the leader's own, as before. The law-wise stand-in
player names his best man and keeps back.

## The Journey winter API

```
j.stepped_winter = true          # the map screen and JourneyBot set it
j.act("winter")                  # or the season closes: _winter -> winter_begin(p)
j.in_winter()                    # true while the band is in its quarters
var s := j.winter_state()        # {step, step_id, steps, title, where, lodging, year,
                                 #  text, notes, rows: [{title, detail, tag,
                                 #  buttons: [{id, label, enabled, on}]}],
                                 #  tally: {silver, silver_after, food, food_end, need, men, seats},
                                 #  can_back, next_label, resolved, told}
for r in s.rows:                 # e.g. the ring-giving
	for b in r.buttons:          # "gift+:12", "gift-:12"
		button(b.label, b.enabled, b.on, func(): j.winter_choose(b.id))
j.winter_choose("next")          # or "back"; from the talk it lives the winter through,
                                 # from spring it begins the summer (winter_end)
j.winter_auto()                  # keep the choices as they stand and begin the spring
```

Ids: store `buy+ buy- hunt+ hunt- feast grain home:<id> build:<Building>`;
ring-giving `gift+:<id> gift-:<id>`; yard `shape:<name> shout:<name>
role:<id> banner:<id>`; men `take:<i> let:<id> war:<id> keep second:<id>
seat:<id>`; talk `talk:<card>:<option>`; told `invest:<Way.Id>`; spring
`spring:<place id>` (empty for here).

Without `stepped_winter` (old callers, tests) the winter is lived at once
with the defaults, which are the old plan's sense: hunters while the
store will not last, rations bought while the chest allows, a feast if
it can be had, an arm-ring for every great deed and 3 oz to the three
coldest from a third of the chest, the band's shape, every man who comes
taken on, the first affordable answer in the talk (a quarrel made up),
no vow, spring where it wintered. `Campaign.winter(planner, opts)` takes
a planner Callable and {recruits, returning}; with no arguments it is
the old winter (the sandbox AI, `pass_years`, the old tests).
`WinterPlan` has `events`, `host_rations` and `cold`.
`WinterEvents.draw/card/resolve` are the talk; `roll/fire` are kept for
the plain campaign.

`JourneyBot.winter(j, bent)`: rings for deeds and silver for the cold
from the raider, berserk, skald and king's man; a few ounces to every man
from the law-wise; the trader keeps the defaults; the fighting ways drill
the boar's snout and swear "Swine!", the king's man and the law-wise the
hedgehog; the law-wise names a war-leader and keeps back; the raider
vows. It always ends the winter. `play_year(j, bent, stop_at_winter)`.

Screens: `tools/screenshot_game.gd` `winter` (answer what waits, winter
here), `summer:<way>` (the stand-in plays on to the winter), `wstep:<n>`,
`wchoose:<id>`, `wauto`.

## Fixed on the way

- The winter storm and the REPAIR task acted on `band.ship_damage`, a
  field the map's band does not use: they now hurt and mend `band.ship`.
- A skald's and an envoy's fame (`ev.fame`) was never applied:
  `Campaign._apply_report` applies it.
- The winter married the leader to "a daughter of a rich bondi of Vik"
  without asking: on the map the marriage is a house's ask by name in the
  hall's talk; the old offer is kept only for the plain campaign.
- Thrall unrest fired for bands with no thralls: it needs captives or
  land.
- A quarrel that came to a challenge was only logged: it is a decision.

## Measured

`tools/batch_ways.gd -- 6 4 1 all <origin>`, before and after (survival is
sagas ended of 6; silver a year is the mean gain):

| Bent | burned hall before | after | younger son before | after |
|---|---|---|---|---|
| Viking | 0/6 ended, +226 oz a year, 17.3 men | 0/6, +184, 18.0 | 0/6, +233, 16.8 | 0/6, +130, 17.2 |
| Trader | 0/6, +37, 10.7 | 1/6, +32, 10.2 | 0/6, +31, 9.7 | 0/6, +4, 9.2 |
| Law-wise man | 0/6, +87, 16.0 | 0/6, +46, 17.0 | 0/6, +89, 13.5 | 0/6, +80, 18.2 |
| Berserk | 0/6, +93, 16.0 | 0/6, +55, 17.0 | 1/6, +24, 13.5 | 1/6, +54, 15.2 |
| Skald | 0/6, +98, 15.3 | 0/6, +107, 17.3 | 0/6, +92, 14.2 | 0/6, +74, 16.5 |
| King's man | 0/6, +40, 16.8 | 0/6, +14, 13.8 | 0/6, +52, 16.3 | 0/6, +28, 17.2 |

No stalls. The winter is a sink, not a pump: rings, arms and bought
rations take 10 to 100 oz a year from the bands that fight most (the
deeds they reward), and the bands keep as many men or more. Not a death
trap: deaths per saga are within a man of before; the one burned-hall
trader saga that ended (seed 5) lost its second and its leader in one
summer fight in 867, nothing the winter did. The law-wise man with a
war-leader in the wall fights as often and loses no more men (burned
hall 1.5 deaths, younger son 0.0).

## Open

- Hall fights (spears in the snow, fire in the night) are told by the
  saga. The hook for a played one: `WinterHall._after_talk`, where
  `ev.battle_required` goes to `c.fight`; instead build it
  (`c.offer_fight` cornered, `c.build_fight`), put it in `Journey.fight`
  with the ctx {kind: "hall"}, stop `resolve` there and finish it from
  `Journey.fight_done` (split `resolve` at the talk).
- "Let the years pass": the hook is the spring step (`WinterHall`
  `_state_spring`): a button that calls `Sandbox.pass_years` before
  `winter_end`'s `begin_summer`.
- The ring-giving has no "ring from the leader's own arm" (a gift the
  chest does not hold) and no gifts to the houses' envoys.
- The verse is four templated lines; the skald's way could make it more.
- The seating row only moves a man up one bench a press.
