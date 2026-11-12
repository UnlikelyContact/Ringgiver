# The saga's fights (package B: gaps 4, 5, 11, 13, the combat half of 12; bugs 4, 7, 10, 12, 13)

Branch `saga-fights`. The fights of a saga are now fought over something
and on their own ground: a raid's silver against the neighbours' coming,
the ships on the strand, two hulls lashed together at sea, your own hall
by night, another's hall burned over its head. The leader's luck goes into
the fight with him, and whether he stood in the front rank is seen.

Every new rule acts only inside the new fights: `tools/diag_mixed.gd -- 40 1`
is byte-identical before and after (see Measured), and a stronger
fingerprint (`tools/diag_identity.gd`: the whole log of every fight of the
varied field, the hold, both ambushes and the escape) is identical too.

## What the player meets

**The offer says what the fight is over.** The map's "A fight offers" text
ends with the stake of taking the field (`FightOffer.stakes`, from
`Campaign.stake`):

| cause / ground | objective | line in the offer |
|---|---|---|
| a raid on a steading (`farm`) | PLUNDER, you come on | "Take the hall before their neighbours come: about 16 rounds from contact." |
| standing with a steading's farmers (world `defend`) | THE_HALL, they come on | "Hold the yard with its farmers, 18 rounds from contact." |
| the ship-thieves | REACH_THE_SHIPS, you come on | "Your ship is drawn up behind them: win through to her ..." |
| a robbery on land | CARGO, you come on | "Get to the cargo before they make off with it ..." |
| the strand where your ship lies | REACH_THE_SHIPS, they come on | "Your ship lies on the strand behind you: keep them from her ..." |
| at sea (`sea`) | DECK, whoever came on boards | "Lash the hulls together, board her and clear her deck ..." / "They will lash on and board: keep them off your deck, or cut loose." |
| your hall by night (`hall`) | THE_HALL or FIRE, they come on | "They mean to take the hall ..." / "They come with fire: drive them from the walls before the roof takes (6 rounds of fire)." |
| the burning (BURN) | ESCAPE, their men break out | "Ring the hall in the dark and let none of their fighting men through the fire; the women and children go free." |
| caught on the march, an ambush, a feud ambush, the Thing | none (an open field) | (nothing) |
| waiting for them (as before) | the hall, the high bank, the ford | "Hold the hall ...", "Hold the high bank ...", "Keep them off the ford ..." |

A raid's text no longer says "with a hall to hold" (it is theirs): "Their
hall stands before you."

**The raid's clock.** A raid on a farm, hall or town is fought at its hall
(the farmstead template). The raiders must stand in it (half its cells, two
rounds running, as THE_HALL) within `objective_plunder_rounds` (16) of
contact. Doing it: "breaks into the hall and carries off the silver", the
full plunder. Routing the defenders: the full plunder too. When the clock
runs out with the raiders the stronger in standing men, they have the field
but not the hall: they win, `taken` false, and carry off
`raid_late_share` (0.4) of the place's plunder and of the flat plunder of
a win ("The neighbours were coming: the band carried off 31 oz and left
the rest."). Otherwise the steading is held.

**Your own hall by night** (gap 4, bugs 4 and 10). The winter's "spears in
the snow" and "fire in the night" cards now carry the hall's choices: "Out,
and meet them in the yard" (the default), "Bar the door and hold the yard"
("hold the walls" against fire), and, when a watchful scout saw them coming
(`card.warned`, Scouting.spots_first), "Lie in wait at the gate". No ford,
no fading away. When the winter is lived through, the fight goes to the
battle screen (`Journey.fight`) and the winter waits; after "Go on" the
winter goes on from the next card. The fight is at night
(`Scenario.build_hall_defence`): your hall's timber across the bottom, its
door, the tree line of the dark at the top, the attackers coming down the
yard. Taken by them (spears in the snow): they carry off
`hall_plundered_food` (half) of the store. Fire in the night: they must keep
two men at the walls (the yard hexes along the hall, ends included) for six
rounds in all, and the roof takes; dawn comes at round 30 and they draw off.
When the roof takes (or they break the band at the hall): "The roof takes
fire. The women, the children and the thralls are let out first; the
household lives. The hall burns, with its 2 buildings, and the store with
it." (Hall.buildings cleared, the benches back to `hall_base_seats`, the
food gone; the wife and children untouched.) Then the saga's choice, on
the winter screen ("Fire in the night", Go on shut until one is pressed):

- **Break out through the door** (`Scenario.build_breakout`: the burned
  hall's escape as a fight of the saga, the ring the burners still standing,
  the leader not spared: he can die in the yard);
- **Hold, and burn** ("Lie down in the hall as Njal did, with the men who
  will not leave you"): the leader dies, with every man of loyalty
  `hold_burn_loyalty` (70) or more; the rest go out with the household;
  the heir takes the band (Campaign.succession).

Played only in the winter the player plays (`stepped_winter` and not
`quick`); otherwise (the stand-in players, "Let the saga tell it", tests)
the leader AIs fight it at once, the leader AI breaks out, and the winter
goes on. The plain campaign's `Campaign.winter` (no map) is unchanged.

**The burning** (gap 5). At the seat of a house the band is at feud with,
the reckoning ("Bring your friends against X") and a raid on that seat
offer "Burn them in by night" beside the open fight
(`FightOffer.can_burn`, `Journey._about_fight`). `Scenario.build_hall_burning`:
night, their hall alight, two doors (the great door and a byre door in an
end; the seed picks which they come out of), their men in ranks at it,
yours in a ring across the yard and down the hall's ends, the dark along
the top. Their side is the escape's (Objective ESCAPE, their side the
attacker; `Battle.ai_breaks_out`: the leader AI gives the careful orders
and slips away when it can). Every end is "the hall burns": the result
title says whether their head fell ("The hall burns, and their head with
it") or got out ("... but their head got out").

What it leaves (`Families.burned`, `Journey._after_burning`): the house
halved (`burning_strength_loss`), its head dead if he fell (his heir holds
what is left), the band's honor down `burning_band_honor` (20), or only
`burning_avenged_honor` (3) when that house had burned the band first ("Men
say it was a burning for a burning, and few blame Egil for it."); fame up
`burning_fame` (4); every house tied to it by blood, marriage, fostering or
friendship `burning_ally_standing` (-25) colder ("Rognvald's kin, Thorir
Long-chin's kin will not forgive the burning."); the women, children and
thralls let out ("... were let out before the roof fell"). With the head
dead the old feud is ended (the burned hall's vengeance answered) and the
heir begins a new one ("the burning at Hardanger"). Unless it was a burning
for a burning, in `burning_outlaw_chance` (half) the burned house's kin
bring it to the Thing and the band is outlawed for a time
(`Outlawry.declare`, the existing hook; thing.gd and outlawry.gd untouched).
The chronicle: "Egil burned Hardanger-Atli's kin in their hall at
Hardanger, and Atli died in it", and the house's tidings that year.

**Ship fights** (gap 13). Any fight whose ground is `sea` (the band aboard:
rival ships, the levy and the king's ships, avengers at sea, a merchant
robbed, a world fight afloat) is fought on the decks
(`Scenario.build_deck`): two hulls lashed side by side, theirs above and
yours below, each `deck_rows` (4) men abreast and as long as the larger
crew needs (9 to 16 columns), the stem and stern drawn in, RAIL along both
gunwales, open SEA all round and between them but for two gangways (BRIDGE,
`deck_gangway` 3 hexes) at the bow and amidships. The walls stand along
their rails facing each other over the water and meet only at the gangways.
The side that came on boards (the attacker). A man thrown back by the push
with the sea behind him goes over the side (`Push`: `PushResult.overboard`);
a broken man at the rail with an enemy at arm's length jumps
(`Battle._over_the_rail`). At the fight's end the sea decides
(`Battle._sea_takes`): he drowns in `overboard_drown` (0.2) plus 0.1 in
leather, 0.45 in mail, else swims and is hauled out ("Vagn went over the
side, swam, and was hauled out of the sea."; "... went over the side and
was drowned."). A ship is taken when none of her crew stands on her deck
and some of the enemy do: cleared from stem to stern (`Objective._decide_deck`).
A ship with no enemy aboard may cut the lashings and row away: Withdraw on
the battle screen (Battle.can_withdraw ignores contact over the rail), and
an AI side that falls back does so. When the clock runs out (24 rounds from
contact) the defender cuts loose. A ship the band takes is a prize
(`Journey._take_prize`): kept when she is a better hull (by price) than the
band's own or it has none (the old one sold at `ship_trade_in`), else sold
off at `prize_sale_share` (0.2) of her price; her hull by whose she was
(`WorldRules.prize_hulls`: a merchant's knarr, a rival's karve, the levy's
snekkja).

**Luck and the front rank** (gap 12 combat half, bug 7). The leader's luck
goes into every fight of the saga with him (`Leader.luck_modifier`, -1/0/+1,
through `Battle.set_luck` onto his warrior: the battle never reads the
campaign): his side's men start one step (`luck_morale`) the warmer or
colder of heart, and the log says so ("Egil's men say his luck holds");
his own close calls lean on it: a blow that would land on a lucky leader
with `luck_close_margin` (3) or less to spare glances off his helm instead,
one that would have glanced off an unlucky one bites, and his fate roll if
he goes down is `luck_fate` (1) the better or worse. Not when the
war-leader leads in his place. After the fight the result says what the
men say when his luck moved ("The men say Egil's luck holds.", "... is
turning.", "... has left him.").

Whether he led from the front is now the truth (`Campaign.led_from_front`):
in a fight his men came to blows in, he stood `front_contact_rounds` (2)
rounds with an enemy at arm's length (`Warrior.contact_rounds`, counted by
the battle and never read by it), or struck a blow (`Warrior.strikes`), or
went down. Otherwise he hung back: `Leader.on_battle` takes luck and honor
as the concept says, and the result says "Men saw Egil keep back from the
shield-wall, and they speak of it." When the war-leader commands, the
leader is honestly not there and keeps the reduced fame share, no blame.
Getting out of a fire (Outcome ESCAPED) costs no luck.

**Feud fights settle something** (bugs 12, 13). A summer feud ambush
beaten off cools the feud a step and its dead go on the feud's ledger
(`kills_ours`, `kills_theirs` on the band's feud entry): "The men of
Augvald's kin go home beaten with 3 dead; the feud cools a little." Beaten,
it warms a step. A brawl at the Thing (ground `thing`: only "Stand and
fight", among the booths, no ford): won, the other side's standing with the
band rises and their feud cools ("The Thing saw who held the field among
the booths; X speak the softer for it."); lost, the other way. An
oath-brother's vengeance (`Bonds.on_death`) is opened against the house the
killers belong to (`FightOffer.house`, from the ctx's family, the raided
place's, the party's), not the enemy leader's name; for raiders and outlaws
of no house there is no feud, only the grave-side oath in the chronicle
("... swore over Grim's grave that Kveldulf would pay, though no house
answers for him."). The plain campaign (no map) keeps the old way
(`Bonds.OLD_WAYS`).

**The escape's goal row** (small fix). With the tutorial's banner under the
top bar on a phone, the burned hall no longer fits; the camera now keeps
the top edge (the dark, labelled THE DARK) in view and lets the hall's
lower rows go under the shout row (`view/main.gd` `focus_point`,
`_goal_on_top`). Before and after: `fight-shots/escape-tut3-before.png`,
`escape-tut3-after.png`.

## Layouts

- **Raid** (`Scenario.build` with PLUNDER): the varied field, the farmstead
  template, the hall four rows behind the defenders' front (as THE_HALL),
  the attacker's extra shields rule as for any objective.
- **Hall at night** (`_night_hall`): `hall_width` x `hall_height` (16 x 12),
  the hall 9 wide across the bottom three rows, its DOOR in the front wall,
  TREE along the top row and four more down the sides from the seed. The
  walls (FIRE's cells) are every passable hex beside the timber. Your line in
  ranks two rows up the yard from the walls ("bar") or four ("meet", "wait");
  theirs `hall_attack_distance` (5) rows above, in ranks, or strung out in
  a line and surprised ("wait"). THE_HALL's cells: the door and the yard
  hexes before it.
- **The burning** (`build_hall_burning`): the same ground, the hall alight,
  a byre DOOR in one end; their men in ranks at the door they chose, morale
  `breakout_morale_bonus` (2) up; yours on ring spots two hexes apart round
  an arc `escape_ring_distance` rows from the door and down both ends.
- **Break-out** (`build_breakout`): `build_escape` with `spare` false: the
  band in ranks at the door (a line when it is the three men of the first
  night), the ring the burners left (at least 3), a taken spot passed on to
  the next.
- **Deck** (`build_deck`): width = length + 4, height = 2 x 4 + 3; rows
  1-4 theirs, row 5 the water and the gangways (columns 3-5 and the waist),
  rows 6-9 yours, sea round all.

## Rules and numbers

`CombatRules` ("The saga's fights"): `objective_plunder_rounds` 16,
`objective_deck_rounds` 24, `deck_rows` 4, `deck_men_per_column` 2,
`deck_min_length` 9, `deck_max_length` 16, `deck_gangway` 3,
`overboard_drown` 0.2, `overboard_drown_armor` [0, 0.1, 0.45], `fire_men` 2,
`fire_rounds` 6, `fire_night_rounds` 30, `hall_width` 16, `hall_height` 12,
`hall_attack_distance` 5, `breakout_morale_bonus` 2, `luck_morale` 1,
`luck_close_margin` 3, `luck_fate` 1.
`CampaignRules`: `raid_late_share` 0.4, `front_contact_rounds` 2,
`hold_burn_loyalty` 70, `hall_plundered_food` 0.5.
`WorldRules`: `burning_band_honor` 20, `burning_avenged_honor` 3,
`burning_ally_standing` -25, `burning_outlaw_chance` 0.5, `burning_fame` 4,
`feud_ambush_cools` 1, `thing_brawl_won_standing` 5,
`thing_brawl_lost_standing` -5, `prize_sale_share` 0.2, `prize_hulls`.

## Classes and functions

- Combat: `CombatTypes.Terrain.SEA, RAIL` (appended; `BattleGrid.has_sea`,
  SEA blocks); `Objective.Kind.PLUNDER, CARGO, DECK, FIRE` (appended; NAMES,
  SHORT), `Objective.taken`, `hulls`, `ship_taken`, `fire_count`,
  `place_cells`, `set_hulls`, `men_aboard`, `_decide_deck`, `_decide_fire`;
  `BattleResult.overboard, drowned, objective_kind, objective_attacker,
  taken, ship_taken`; `Battle.night, hall_alight, ai_breaks_out`,
  `set_luck`, `_count_contact`, `_went_overboard`, `_over_the_rail`,
  `_sea_takes`; `Warrior.luck, contact_rounds, strikes, overboard`;
  `PushResult.overboard`; `MeleeExchange._close_call`; `Fate.roll` leans on
  luck; `Scenario.build_hall_defence`, `build_breakout`,
  `build_hall_burning`, `build_deck`, `_night_hall`, `_nearest_free`;
  `Field` treats PLUNDER as the hall, CARGO as the ships.
- Campaign: `FightOffer.Choice.BURN` (appended), `cause`, `house`,
  `ships_here`, `can_burn`, `burning`, `stakes`; the ground `hall` and
  `thing` in `options`/`title`/`GROUND_TEXT`. `Campaign.offer_fight(...,
  about)`, `stake`, `build_fight` (burning, hall, deck, the stake's field),
  `build_breakout`, `led_from_front`, `luck_lines`, `plunder_share`;
  `Bonds.on_death(..., house)`, `Bonds.OLD_WAYS`; `BattleBridge` and
  `Aftermath.lines` tell the overboard and the drowned; `Leader.on_battle`
  takes ESCAPED quietly.
- World: `Journey._about_fight`, `_after_feud_ambush`, `_after_thing_brawl`,
  `_after_burning`, `_take_prize`; `_answer_fight` keeps the choice, the
  built fight and the offer's kind in the ctx; `fight_done` hands a fight
  at the hall back to the winter; `winter_choose` waits while it is paused.
  `WinterHall._hall_fight_card`, `paused`, `_talk`, `_live_through` (the
  `resolve` split at the talk), `_hall_fight`, `_play_or_tell`,
  `hall_fight_done`, `_hall_burned`, `_fire_choice`, `_state_fire`, `fire`.
  `Families.burned`. `JourneyBot`: the berserk burns his vengeance's house
  when offered; every other answer as before (Sandbox.choose_fight never
  burns).
- View: `BattleView` draws the sea (the map's teal, wave marks, foam at the
  hulls), the deck (planks and seams, the strake on the rail, the
  gangways, a mast and yard a hull), the hall at night (`is_night` from
  `Battle.night`; flames only once `hall_alight`; firelight at the doors and
  a torch in the hand of every burner at the walls). `Hud`: the result's
  first line for the deck, the fire, the burning; the burning's title.
  `Main`: `_saga_fight` (the prototype's scenario names for tools),
  `focus_point`/`_goal_on_top`.
- Tools: `tools/diag_saga_fights.gd [n] [seed] [only] [log]` (AI against AI
  in each new fight), `tools/diag_saga_tally.gd [sagas] [years] [seed]
  [way] [origin]` (prizes, burnings, hall fights, hanging back over the
  stand-in players' years), `tools/diag_identity.gd [n] [seed]` (the
  fingerprint of ordinary fights). `tools/screenshot.gd` scenario names
  `deck`, `deck_boarded`, `hall_defence`, `hall_fire`, `burning`,
  `plunder`; `tools/screenshot_game.gd` commands `wfeud:<kind>:<how>`,
  `addmen:<n>`, `lose`.

Files outside my list touched: `view/winter_screen.gd`, two one-line hooks
(after a choice, a waiting fight goes to the battle screen; Go on is shut
while `can_next` is false). `tests/test_world_life.gd`: one assertion
changed (a fight at sea is on the decks now, not the strand: the intended
change of gap 13).

## Measured

### Ordinary fights, before and after

`tools/diag_mixed.gd -- 40 1`: identical, line for line ("TOTAL 40 fights,
13 wins (32%)" both). `tools/diag_identity.gd -- 20 1` (log hashes of
100 fights): identical (ALL 3653817781).

### The new fights, AI against AI (`tools/diag_saga_fights.gd -- 40 1`)

| fight | sides | ours | theirs | mean rounds | notes |
|---|---|---|---|---|---|
| raid (PLUNDER) | 12 against 8-10 at their hall | 25 | 15 | 22.2 | hall taken 11, the rest the field at the clock or a rout |
| deck, we board | 12 against 12 | 8 | 32 | 14.8 | 7 decks cleared; 84 overboard, 11 drowned |
| deck, they board | 12 against 12 | 27 | 13 | 14.8 | 101 overboard, 20 drowned |
| spears in the snow, bar | 9 green against 6 blooded | 23 | 17 | 18.0 | hall taken 9 |
| spears in the snow, meet | same | 40 | 0 | 13.7 | outnumbered, they seldom come on |
| spears in the snow, wait | same | 40 | 0 | 17.0 | |
| fire in the night, bar | 9 green against 10 veterans | 0 | 40 | 13.7 | the roof took 23, routed 17 |
| fire in the night, meet | same | 36 | 4 | 13.9 | they never fired it; dawn or they drew off |
| the burning (you the ring) | 11 against 8 | 37 | 3 | 11.5 | their head fell 14 of 40; your leader went down 20 |
| break-out (AI careful way out) | 9 against 10 | (got out 40) | | 9.8 | your leader down 3 of 40 |

The asymmetries meant: boarding a defended deck at even numbers is hard
(the defender wins about two in three: the gangways are three men wide
and a boarder is struck from the rail on both sides), so a sea fight goes
to the bigger or better crew; a raid with the edge in men usually has the
field but takes the hall one time in four, and the clock is what makes it
come on; at your own hall, going out to meet them is the safe answer and
barring the door against fire is death to the leader AI, which never sends
men to clear the hall's ends (a player can: the burners at the ends carry
torches you can see); the burning nearly always "succeeds" but kills the
head of the house only one time in three and is dangerous to the ring's
leader.

### The stand-in players (`tools/batch_ways.gd -- 6 4 1 all <origin>`)

No stalls, before or after, either origin. Silver a year / honor at the
end, before -> after:

| bent | burned hall | younger son |
|---|---|---|
| Viking | +38 / 49 -> +60 / 38 | +68 / 45 -> +49 / 34 |
| Trader | +41 / 50 -> +65 / 47 | +43 / 51 -> +41 / 51 |
| Law-wise | +80 / 97 -> +92 / 97 | +84 / 90 -> +86 / 90 |
| Berserk | +47 / 17 -> +51 / 18 | +15 / 18 -> +16 / 13 |
| Skald | +91 / 71 -> +85 / 68 | +94 / 63 -> +87 / 62 |
| King's man | +27 / 47 -> +44 / 45 | +67 / 44 -> +66 / 45 |

Deaths a saga are as before or fewer (Viking burned hall 3.3 -> 1.2). The
Viking's honor falls (the leader AI hangs back in about one fight in
thirty-five: 6 times in 210 fights over 24 saga-years,
`tools/diag_saga_tally.gd -- 6 4 1 viking`), and his raids carry off less
when they run out the clock (younger son). Prizes: 15 ships taken in those
24 Viking saga-years (sold for a fifth of a hull's price unless better than
his own; at half the price, the first measurement, the Viking made +142 oz
a year: too much). The berserk from the burned hall burned his vengeance's
house 4 times in 6 sagas.

`tests/test_saga_fights.gd` (11), `test_deck.gd` (7),
`test_hall_fights.gd` (8): suite `488 tests, 0 failed`.

Screens at 844 x 390, looked at: `docs/design/notes/fight-shots/`: deck,
the burning, a raid and its clock, the hall defence (start, mid, result);
the winter card, the hall fight from the winter (start, mid, result), the
roof taking, the fire's choice, the break-out (start, mid, result); the
raid's offer with its stake; the escape's goal row before and after.

## Open

- The leader AI knows nothing of the walls: in a fire it fights the line
  and never goes round to the hall's ends on purpose, nor does a defending
  AI send men to clear them. Barring the door is therefore a trap in
  AI-against-AI play; a player can hold the ends.
- "Hold, and burn" takes every man of 70 loyalty or more with the leader:
  no choice of who stays.
- Those who ask quarter in a burning are not modelled one by one: the
  band always lets the household out and is never made a nithing; a
  "let none out" choice would want a rule for striking broken men.
- A strandhogg is no fight in the game (Raiding.strandhogg), so it has no
  objective; fights on the strand where the band's ship lies make for her.
- The prize sale price is immediate silver; the old ship sold when a better
  one is kept is sold at trade-in wherever the band is.
- The plain campaign's own winter (`Campaign.winter`, no map) still fights
  a hall attack as an open field (the batches that pin it were left alone).
- In the break-out the ring's leader stands at the hall's end watching it
  burn (as on the first night): with a big band his place may be taken and
  he stands at the next spot.
- Luck pushes luck: the stand-in players end four years at 9 or more.
