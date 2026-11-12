# Families: the web of houses (12 Nov 2026)

Branch `families`. Before this a family was only a string on a place
(`Place.family`), a key in `Band.friends` and in the band's feuds. Now
every ruling family is a house with a head, an heir, a seat, men, wealth,
a temper and honor; the houses are bound to each other by kinship,
marriage, fostering, sworn friendship, debt, grudge and feud; the band
has one standing with each house; and the houses live their own years.
Njal's saga is the model.

## What the player sees

- **Families** button on the map's side panel (beside Your men / Your
  ways). A modal lists this year's tidings of the houses, then every
  house the band knows of (or has any standing with, and all the western
  houses): its name, the band's step with it and the number ("Hardanger-
  Atli's kin   Blood Enemy (-89)"), the head, seat, heir, temper, men and
  honor, the band's own ties ("Yours by kin and marriage"), a feud with
  the band, and the house's ties ("Rognvald's kin: tied by marriage;
  Thorir Long-chin's kin: sworn friends; Horda-Kari's kin: owes them, a
  grudge"; a feud reads "feud: 1 killing to 2, now a counter-killing").
- **The place panel** names the head of the ruling house and the step:
  "Home of Horda-Kari's kin. Horda-Kari is head of it; they think of you
  as a stranger (-2)."
- **Decisions** ("A house sends word"): a house asks the band to take
  its side in a feud (stand with them / speak for them at the Thing /
  carry an offer of settlement / keep out of it); a marriage offer; a
  son to foster; a house at feud with the band offers wergild for the
  band's dead (take it / take blood instead).
- **Deeds at a house's seat**: give the head a gift (10 oz); rest your
  hurt men (well-wisher or better); ask for men (friend or better); offer
  wergild (when at feud); bring your friends against them (the
  reckoning, when at feud); at a Thing site, speak for a house you
  promised. Winter is free at a friend's seat and refused at an
  ill-wisher's ("The door of X is shut to you").
- **Counsel** now names both houses ("Egil judges between Horda-Kari's
  kin and Hardanger-Atli's kin at the Gulathing and finds for ...").
- **The winter report** ends with "Tidings of the houses this year:".
- On the map, a house's men (rival ships from its seat, men sent after
  you) leave a well-wisher alone and hunt a blood-enemy whatever the
  odds.

## The rules and their numbers (WorldRules, "Families")

Standing: -100..100 per house (`Band.standing`). Steps: blood-enemy at
or under -60; ill-wisher at or under -20; stranger under 20;
well-wisher; friend from 50; sworn friend from 80 ("kin" from 50 when
the band is tied to the house by blood or marriage).

Spread (`tie_spread`): a change with one house moves every house tied
to it, one step out, by kin 0.5, marriage 0.4, sworn friendship 0.4,
fostering 0.3, debt 0.15, grudge -0.2, feud -0.4 (the shares of a pair
add up).

What moves it: counsel +15 for the house found for, -5 for the other
(never warmer for it); verse +8; standing as champion +20; an
overbearing holmgang -20 (and -8 more if it is lost to you); a raid
-35, strandhögg -15; each visit to a house's market +3 while under 30;
a lord's work +10 with the giver's house, -10 with the house a debt or
tribute is taken from; a Thing case won against a house -15; speaking
for a house and winning +20 with it; each of its men killed -6, and a
house with no feud with the band takes one up in half such fights; a
gift of 10 oz +12, halved for each gift that house has had this year; a
marriage +30; fostering +20; refusing a house -5; standing with a house
in a fight and winning +25 with it and -25 with the other side; a
promise to speak at the Thing not kept -10. An open feud with the band
holds the house at -25 or under; settling it (silver, the Thing, the
island, wergild taken) lifts it 15 (`Families.sync`, run after every
step of the journey). A feud ended by the sword gives no warmth.

What it does:

- *The Thing* (`Families.thing_backing`, `Thing.gather_support`):
  well-wishers bring 1 supporter, friends 2, sworn friends 3; the other
  side's allies (kin, marriage, friendship, fostering) bring it 2 each
  unless they are the band's friends; houses at grudge or feud with the
  other side bring the band 2 unless they are its ill-wishers; a debtor
  never stands against its creditor. This replaces `friend_support`. The
  case names who stood where.
- *Prices* (`Market.buy_price`/`sell_price`): a friend lets the band off
  the middlemen's spread (the trader's true price; no round trip pays);
  an ill-wisher asks 1.2 times and pays 1/1.2.
- *Shelter*: free winter lodging at a friend's seat, a shut door at an
  ill-wisher's; rest for the hurt (4 days, 2 turns of mending) at a
  well-wisher's or better, once a year.
- *Work*: no lord's work is offered at an ill-wisher's seat.
- *Men*: a friend lends 1 man, a sworn friend or kin 2, once a year.
- *The map* (`Roam.Party.family`, `mood`): a house's party leaves a
  well-wisher alone and hunts a blood-enemy (or a house at feud with the
  band) whatever the odds. A house at feud sends 6 men after the band in
  half the summers (at most one party a summer); they go home when the
  feud ends.
- *Vengeance*: killing a house's men costs standing and may bring a
  feud, which brings the existing ambushes and wergild demands, the
  men sent after the band, and a case at the Thing.

The houses' year (`Families.year_end`, from `Sandbox.year_end` at the
thaw): heads die (4% a year, 12% from 60, at most two a year) and the
heir follows; an open feud climbs a step in 35% of years plus the
tempers (proud +15%, grasping +10%, steadfast -5%, peaceable -15%) or
cools to a grudge in 15% (before the Thing); the steps are an insult, a
killing, a counter-killing, a case at the Thing, a settlement, a
burning. A settlement holds in 60% less the tempers' heat and ends the
feud, or breaks (a killing, honor -3 to the breaker) and goes back to a
counter-killing; a feud that climbs again after a broken settlement
ends in a burning: the weaker house's head dies, its strength halves,
the burners lose 10 honor, and the feud goes on. A grudge comes to blood
in 25% (plus tempers) or is let lie in 10%; one new grudge and one new
marriage between neighbours (within 22 leagues, Norway only) in 50% and
40% of years. At most six tidings a year; measured 4.5 a year over 80
seeded house-years, with deaths, burnings (8) and settlements that held
(9). A killing done to a house the band is kin to by blood or marriage
costs the killers 5 of the band's standing: their feuds are partly his.

The asks (`Families.asks`, at most 2 a spring, each in 60%): from houses
whose seat the band knows and that are no ill-wishers. Help in a feud:
*stand* is a fight through `Journey._offer_fight` (6 of the other
side's men, capped like any forced fight); *speak* puts a promise in
`Band.pledges`, kept at any Thing site with "Speak for X against Y"
(`Thing` with `ThingCase.client`: a verdict for the client moves their
feud to the settlement step, +20 with them, -15 with the other side; a
failed case -5 with the client); *carry* is Wits + 2d6 against 11 (a
settlement, +12 with both, honor +2); *keep out* -5. Marriage (to an
unmarried leader, from a well-wisher or better) uses `Family.marry` and
ties the band to the house. Fostering ties it too. Wergild offered for
the band's dead is three quarters of the dead man's wergild; taking
blood instead is a fight, and a win ends the feud (fame +5).

The reckoning (`Families.reckoning_terms`): at the seat of a house the
band is at feud with, every friend of the band among that house's
enemies sends 3 men, and the house brings its strength less theirs (at
least 3). Once a summer. A win ends the feud by the sword, its head
falls and his heir holds a house of half the strength; the friends who
sent men +10 (-5 if it is lost).

## The burned hall

Hardanger-Atli's kin (head Atli, grasping, 14 men) burned the hall; they
hold for Harald's side through their marriage to Rognvald's kin of Møre
and their sworn friendship with Thorir Long-chin's kin of Jæren, and
they owe Horda-Kari's kin. Ulfar's kin of the Sogn farms (a new house:
the place had been the Sygna kings') shelter the burned man: kin, +60,
with an old grudge against Hardanger; Horda-Kari's kin hold a grudge
against Hardanger too. The burners start at -80. `Band.vengeance` is
their house name, the feud's dead man is a hersir (wergild 100). The
reckoning starts at 11 men against him (Ulfar's kin send 3); winning
Horda-Kari's friendship makes it 8. At the Thing, Ulfar's kin and
Horda-Kari's kin stand with him and Rognvald's and Thorir's kin against.
The younger son is kin to the house at Hardanger (+60).

## The starting web (NorwayData.HOUSES, HOUSE_TIES)

Nine western houses: Augvald's kin (Avaldsnes, proud), Thorir
Long-chin's kin (Jæren, grasping), Eirik of Hordaland's kin
(Hafrsfjord), Horda-Kari's kin (Fitjar and the Gulathing, steadfast,
everybody owes them), Hardanger-Atli's kin, the Sygna kings (Sogndal),
Ulfar's kin (the Sogn farms), Rognvald's kin (Giske), Hrafn's kin (the
Møre farms, a new house, peaceable, tied to nobody). Old feuds: Augvald
against Rognvald (2 killings to 1, a counter-killing), Thorir against
Eirik (a killing). Marriages: Hardanger and Møre, Augvald and Sogn,
Horda-Kari and Eirik. Every other place's family is a house too, head
and temper drawn from the seed; Iceland's land-take is Ingolf's kin.

## Classes and functions

- `House` (`sim/world/family.gd`; `Family` was taken by the band's
  household in `sim/campaign/family.gd`).
- `Families` (`sim/world/families.gd`), `World.families`: `build`,
  `house`, `house_at`, `pair`, `add_tie`, `end_enmity`, `settle_between`,
  `ties_of`, `allies_of`, `enemies_of`, `spread_share`, `tie_text`;
  standing: `standing`, `step_name`, `step_of`, `step_phrase`,
  `support_step`, `is_friend`, `is_foe`, `set_standing`, `shift`,
  `sync`, `gift_worth`, `give_gift`; effects: `thing_backing`,
  `spread_off`, `foe_factor`, `shelter`, `party_mood`, `reckoning_terms`;
  the year: `year_end`, `contradictions`; asks: `asks`, `marry_into`,
  `foster_for`, `start_origin`; the view: `report(rules, world, band)`
  (plain dictionaries), `tidings_of(year)`.
- `Band`: `standing`, `house_ties`, `gifts_given`, `pledges`, `favours`;
  `friends` is now a read-only view (houses at 50 or more).
- `Journey`: `_houses_spring`, `_moods`, `_answer_house`,
  `_after_house_fight`, `_killed_their_men`, `_work_standing`,
  `_house_actions`, `_act_house`, `_speak`, `_shift`; `begin` calls
  `Families.start_origin`.
- `JourneyBot._answer_house`, `_houses`; it no longer raids its friends.
- `Callings.dispute_parties`; `Thing._client_outcome`;
  `ThingCase.client`, `houses_with`, `houses_against`; `Roam.add_avengers`.
- `tools/batch_families.gd [sagas] [years] [seed] [origin]`.

## Measured (6 sagas x 4 years a bent, seed 1)

`tools/batch_ways.gd`, before and after (silver a year; no stalls after):

| Bent | burned hall before | after | younger son before | after |
|---|---|---|---|---|
| Viking | +117, 40 fights | +236, 51 fights | +109, 1 ended | +265, 0 ended |
| Trader | +4 | +26, 1 ended | +2 | +8 |
| Law-wise man | +215 | +127 | +166 | +93 |
| Berserk | +147 | +53 | +65 | +41 |
| Skald | +166 | +123 | +150, 1 ended | +104 |
| King's man | +66 | +51 | +94 | +59 |

Every saga lived all four years except one trader from the burned hall
(the younger son's raider and skald who died before now lived). The law-
wise man, skald and king's man earn less: they spend on gifts (10 oz a
house a year while under friendship and over 60 oz in hand), travel to
the Thing to keep promises, and carry peace offers. The berserk earns
less because his overbearing challenges now make ill-wishers (8 a saga)
whose markets are dear, whose doors and work are shut, and whose men
hunt him. The raider earns more (he no longer raids his kin and friends,
and his kin lend men). Six sagas is a small sample.

`tools/batch_families.gd` after four years, from the burned hall (from
the younger son in brackets): friends made, Viking 3.2 (2.8), trader 2.8
(3.2), law-wise 10.8 (8.8), berserk 1.0 (1.5), skald 12.2 (12.3), king's
man 6.0 (7.2); ill-wishers, Viking 10.8 (15.0, 6.8 and 8.8 of them
blood-enemies), berserk 7.8 (7.7), the others 0.3 to 1.3. Feuds of the
band ended in four years: Viking 11.7, berserk 4.3, the others 1 to 2;
open at the end 0 to 1. Vengeance taken for the burned hall in four
years: 5 or 6 of 6 for every bent. Every saga married (5 of 6 berserks).
Feuds between houses open at the end: about 2.2 to 3 (the law-wise man,
who speaks for houses and judges between them, leaves 0.8). Tidings 3 to
4 a year.

## Open

- The burned hall's vengeance comes too easily for the stand-in players
  (5-6 of 6 in four years): the burners' wergild offer and the Thing
  close it as often as the reckoning. Worth making the burners refuse
  compensation for a burning, or the reckoning the only end that counts
  as vengeance.
- `CampaignRules.marriage_houses` (the winter's marriage offers) still
  names houses that are not in the web; those marriages tie the band to
  nobody. `campaign.gd` and `winter_events.gd` were not mine to change.
- `Sandbox.summer` (the old AI summer) reads the houses at the Thing
  but answers none of their asks.
- Houses abroad (Dublin, Birka, the monks of Iona) are houses with
  standing; the monks can be "reckoned with" after a raid feud. They
  take no part in the yearly grudges and marriages.
- A man lent by a friend is an ordinary recruit; he does not go home if
  the house turns against the band.
- Two houses' feud is not yet fought on the battle screen except when
  the band stands with one side.
