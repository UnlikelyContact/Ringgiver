# Men and silver: the leader's nature, shieldmaidens, the smith and the works (12 Nov 2026)

Branch `men-silver`, worktree `/home/user/wt-men-silver`. Four promises of
`concept.md` that a player did not meet (the leader's nature and his
potential as hints, shieldmaidens, gear outside the winter hall, the men
panel in summer), and the balance pass's last open finding: long sagas pile
up thousands of ounces with nothing to buy (`balance.md`, "Still off").
Everything is reached through `Journey`; the screens are in the existing
look (`UiTheme`, the map's side panel, `UiModal`).

## What the player meets

**His nature** (`view/game.gd` `show_nature`, shot `nature.png`). After the
name (the burned hall: before the night's cards; another beginning: after
"Begin"), one screen: "What kind of man is Egil?" Eight cards in four
columns, each column a pair: reckless or steady, open-handed or
close-fisted, silver-tongued or grim, deep-minded or quick to anger. He
picks two from different pairs (a third choice drops the oldest; a choice
in a pair already picked replaces it); "Go on" waits for two. Each card
says in one line what the trait does, and every line is true in the sim:

| Trait | Growth (as a man's personality: x1.25 / x0.75 effort) | Edge (Band.gift) |
|---|---|---|
| Reckless | Might up, Wits down | a win against the odds: +2 fame (`odds_fame`, Leader.on_battle) |
| Steady | Nerve up, Might down | drawing off costs no honor (`withdraw_free`, Leader.on_battle) |
| Open-handed | none | gifts of silver and arms bind x1.5 (`gift_bind`, Loyalty.gift / gift_gear, winter and summer) |
| Close-fisted | none | keeps 10 in 100 more of the plunder with the men content (`keep_share`, Loyalty.share_plunder); gifts bind x0.75 |
| Silver-tongued | Wits up, Grit down | +1 at counsel, the Thing's pleading and verse (`law`, `verse`, added to the ways') |
| Grim | Nerve up, Skill down | one man in ten pays rather than meet him on the island (`dread` +0.1, added to the berserk's) |
| Deep-minded | Wits up, Might down | luck drifts down at the thaw only from 8, not 7 (`luck_keep`, Leader.winter_drift) |
| Quick to anger | Might up, Nerve down | an overbearing challenge costs half the honor (`challenge_honor`, Callings.holmgang_terms) |

The leader's card in "Your men" shows his two traits with the same lines
(shot `leader_card.png`), and "What he may become" is his potential as
hints, as for any man (Potential.hints by his own wits). The chronicle
opens: "Men said of Egil that he was reckless and open-handed". The
nature does not touch the fight: the leader's token acts on the player's
shouts, not on a temper. A son inherits a mix (`Natures.inherit`): each of
his father's traits with `nature_inherit_chance` 0.5, the rest drawn from
the pairs left open, so a son who takes the high seat brings his own
nature to the band's edges (`Succession.carry_over` already calls
`Way.refresh`). A sworn second or a man of the band who takes the seat has
none (his personality is his nature).

**The smith** (`view/estate_panel.gd`, shots `smith.png`,
`smith_named.png`, `map_kaupang.png`). "Go to the smith" is on the place's
list at every market town and king's hall (and "Go to your smith" at the
band's own hall once it has a smithy). The panel: what kind of smith,
the chest, then a card a piece (helmet, sword, mail shirt, long axe, bow
and arrows) with its price and how many are to be had this year, and two
buttons: "For the chest" and "For a man..." (a list of everyone in the
band who would be the better for it, the leader first, each with his gear
in words). Bought for a man it is a gift (`Loyalty.gift_gear`, +15
loyalty, x the open hand or the closed fist); on the leader, his own. A
sword or a long axe is for the front rank; a bow takes a man to the bows.
At Kaupang, Hedeby and Dublin the work is dearer (x1.25) and fine: it binds
a man +5 more. There, in 35 of 100 years, the smith has a sword with a
name (Legbiter, Greyflank, Dragvandil and nine more, never sold twice):
150 oz, +20 loyalty to the man given it, +3 fame, a line in the saga ("Egil
bought the sword Legbiter at Hedeby, and gave it to Thord"), and the man's
gear reads "the sword Legbiter" ever after.

| Smith | helmet | sword | mail | long axe | bow | stock a year |
|---|---|---|---|---|---|---|
| plain (a market town, a king's hall) | 12 | 25 | 45 | 20 | 8 | helmets 0-2, swords 0-1, mail 0-1, long axes 0-1, bows 1-2 |
| great (Kaupang, Hedeby, Dublin) | 15 | 31 | 56 | 25 | 10 | 2-3, 1-3, 1-2, 1-2, 2-3, and a sword with a name 35% |
| own smithy (x0.8) | 10 | 20 | - | 16 | 6 | 1, 0-1, -, 0-1, 1 |

**Gifts in summer, the men panel** (`view/men_panel.gd`, shots
`maiden_card.png`, `maiden_card2.png`). Every man's card now has "His
arms" (his gear in words, the named sword) and, for a sworn man, "Give
him...": 3 oz of silver, an arm-ring of 8 oz, or any arms in the chest he
lacks; once a summer a man ("He has had a gift from you this summer").
Potential as hints, traits, bonds and ambitions were already there; the
nature card now carries the leader's traits too. The card's words follow
the man or woman (below).

**The works** (`view/estate_panel.gd`, shot `works.png`). "Works at your
hall" on the list at the band's own hall; "Spend silver here" at another
house's seat or a market with the ship at hand. Rows by group, each a
row-button with its price and what it does:

- *Your hall*: the buildings that were winter-only (benches 20 oz for six
  seats, which is the band's ceiling `Campaign.room()`; storehouse 30;
  smithy 40, which is now also a smith; boathouse 35, and the ship now
  winters in it and comes out sound; byre 25); the hall's adornment in
  three steps (a carved high seat 60 oz, honor +3 fame +2; high-seat
  pillars carved with the gods 180, +3/+4; the hall painted with the old
  tales, as Olaf the Peacock's at Hjardarholt, 500, +2/+8), each step
  also +1 loyalty a winter turn to every fed and seated man; a skald kept
  at the hall (30 oz, then 20 every winter: fame +2 a winter and a line in
  the saga each year; he leaves when the chest cannot pay him).
- *Feasts*: at a house's seat, a feast for that house (30 oz + 3 a man of
  the band: standing +18, fame +1, two days, once a house a year); at
  home, the district's feast (40 + 4 a man: standing +8 with every house
  whose seat is within 25 leagues of the hall, fame +2, once a year).
- *For the dead*: for each of the band's fallen (the saga's list), a
  rune-stone (40 oz, fame +2, honor +1, "Egil raised this stone after
  Hervor, who fell in 867. May the gods keep her") or a mound (150 oz,
  fame +5, honor +2); one for each, the latest four shown.
- *The ship* (her fittings stay with her; a new hull starts bare): a
  striped sail (60 oz, a tenth faster under sail), painted shields on the
  rail (40, fame +2), a dragon's head for a snekkja or longship (150,
  fame +4).

**Shieldmaidens** (`sim/world/shieldmaidens.gd`, shots
`maiden_offer.png`, `maiden_card.png`). Once the band has fame 15, in 5 of
100 summers a woman asks to swear (at a farm, hall or town where the band
stands in spring, if there is room), never more than two in a saga. Three
stories, each with its own words and what she brings: her dead brother's
mail (she wants vengeance, wears mail), a vow over her brother's cup to
take no husband (she draws a bow, stands with the bows), her father's
sword (a sword). "Take her oath", "Send her home with a gift (5 oz)", "Send
her away". Her name is from her own list (Hervor, Thorbjorg, Brynhild,
Freydis and ten more). She comes blooded, a point better in Skill and
Nerve than a farm lad; nothing in the fight differs for her
(`Man.to_warrior` is untouched). Superstitious men take it ill (-4
loyalty, "Thord says a woman in the line is an ill sign, and sits apart
from the fire that night"); boastful men are pleased (+2, a bond); the
house of the country she came from speaks well of the band (+5). After a
year with the band a house of the marriage houses may ask for her hand (25
of 100 summers, once): give her (she leaves; standing +25 and a marriage
tie), let her answer (she takes it only if her oath is done), or refuse
(she stays, +10 loyalty; the house -3). Her card says "Hervor, 19, a
blooded shieldmaiden with the bow, of a farmer's house", a "Shieldmaiden"
chip in the list, and she/her in every line.

**The saga's words for a woman.** `Man.he()`, `his()`, `him()`,
`himself()`, `man_word()` (each with a capital form). Audited and changed:
the men panel (every card's titles and lines, loyalty and ambition words,
known-for, the personality lines), the winter hall (let go "with thanks for
her service", sent home "to her kin", passed over "she takes it ill", the
send-home row, the role row's "Move her", the war-leader row, the skald's
"lay down before her"), the winter talk (the quarrel's hints and the
island), bonds (grief, the vow over the grave), loyalty (ambition met, the
turncoat), the winter turns (back from her travels, on her feet), the
thaw's return from kin, the potential hints ("her might could grow yet"),
the sold-east line, the drowned "in her mail", rune-stones. Not changed
(owned by battles-2, `sim/combat/*`): the battle log's lines that say "his"
of a warrior, listed under "Still open".

## The rules and the numbers

All in `CampaignRules`, section "Men and silver": `nature_growth`,
`nature_edges`, `nature_inherit_chance`; `smith_items`, `smith_price`,
`smith_great`, `smith_great_price`, `smith_fine_loyalty`,
`smith_stock_plain`, `smith_stock_great`, `smith_named_chance`,
`smith_named_price`, `smith_named_loyalty`, `smith_named_fame`,
`sword_names`, `smith_own_price`, `smith_own_stock`; `hall_adorn`,
`adorn_rest`; `feast_house_*`, `feast_district_*`, `feast_fame`;
`stone_*`, `mound_*`; `kept_skald_take`, `kept_skald_keep`,
`kept_skald_fame`, `kept_skald_names`; `fit_sail`, `fit_sail_speed`,
`fit_shields`, `fit_shields_fame`, `fit_prow`, `fit_prow_fame`;
`maiden_chance`, `maiden_fame`, `maiden_max`, `maiden_superstitious`,
`maiden_boastful`, `maiden_suit_chance`, `maiden_suit_standing`,
`maiden_names`.

## Classes and functions

- `sim/campaign/natures.gd` `Natures`: `PAIRS`, `keys`, `line`, `valid`,
  `choose`, `add_edges` (from `Way.refresh`), `multiplier` (from
  `Growth.nature_multiplier`), `inherit` (from `Recruits.son_of`).
- `sim/world/estate.gd` `Estate`: the state on `Band.estate` (adornment,
  skald, fittings and the ship they are on, memorials, feasts, the smiths'
  stock a place a year, named swords sold, the arms chest, summer gifts,
  ounces laid out `sunk` and by kind `spent`, shieldmaidens and suits) and
  the rules: `smith_kind`, `smith_state`, `buy_arms`, `lacks`,
  `gear_words`, `gift_options`, `give`, `works`, `do_work`, `district`,
  `sail_mult`, `adorn_rest`, `on_winter` (from `WinterHall.resolve`).
- `sim/world/shieldmaidens.gd` `Shieldmaidens`: `spring`, `answer`
  (decisions of kind `men_silver`).
- `Man`: `woman`, `natures`, `sword_name`; `he`, `his`, `him`,
  `himself`, `man_word`.
- `Journey` (section "Men and silver" at the end): `nature_choices`,
  `choose_nature`, `smith`, `buy_arms`, `works`, `do_work`,
  `gift_options`, `give`; the actions "smith" and "works" (the view opens
  their screens; the sim does nothing for them); hooks of one line each in
  `begin_summer`, `actions`, `act`, `answer`, `sail_speed`.
- `JourneyBot` (section at the end): `_nature` (by bent: Viking reckless
  and open-handed, trader close-fisted and deep-minded, law-wise steady and
  silver-tongued, berserk grim and quick to anger, skald open-handed and
  silver-tongued, king's man steady and open-handed) and `_men_silver`:
  above a reserve of 200 oz + 10 a man, helmets for everyone at a smith,
  mail for himself and his veterans, swords for veteran front-rank men, a
  named sword for himself when 300 over; then a sail, a feast for a house
  not yet a friend (two a summer), a stone for the fallen, a skald, the
  hall's adornment (at twice its price over), the district's feast,
  shields on the rail, a dragon's head.
- View: `view/estate_panel.gd` `EstatePanel` (new), `view/men_panel.gd`
  (`_gear_card`, pronouns), `view/game.gd` (`show_nature`; `_nature`
  given to the saga in `begin_escape` / `begin_saga`), `view/map_screen.gd`
  (one line: the smith and works open their panel).
- Tools: `tools/screenshot_game.gd` (`nature` with `nat:<key>`; on the
  map `natures:<a>,<b>`, `hallhere`, `smith`, `works`, `chest:<item>`,
  `buyfor:<item>:<n>`, `maiden`, `maidenin`, `fallen:<name>`, `named`),
  `tools/batch_ways.gd` (a "silver laid out" line),
  `tools/batch_generations.gd` (laid out by five years and by kind).

## What was measured

**Ordinary battles and the escape, unchanged.** Before (main 25ab03c) and
after, the final lines are identical: `diag_mixed -- 40 1` "TOTAL 40
fights, 13 wins (32%)"; `diag_identity -- 20 1` "ALL 1946475587" (mixed
3670634342, hold 1561442230, ambush 3427121816, ambushed 4243098782,
escape 1252941125); `diag_escape -- 30` tutorial 30/30 out (6.0 rounds),
skip 30/30 (5.3), nothing 0/30 (14.5), charge 27/30 (7.7). The escape
renders `escape 7 tut:3` with no script error.

**The five-year table, the younger son, seed 1** (`batch_ways -- 8 5 1 all
younger_son`; before is main 25ab03c, which gives exactly balance.md's
"after" for this block). "Laid out" is the new line: ounces a year spent on
arms and works, which the worth (silver, land at its price, the hull) does
not count; worth and laid out together is the band's earning.

| Bent | worth/yr before | after | laid out/yr | worth + laid out | silver y5 before / after | land before / after | men y5 before / after | most men | luck before / after | honor before / after | fights a saga |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Viking | +168 | +138 | 26 | +164 | 595 / 482 | 1.2 / 1.0 | 25.0 / 25.1 | 30 / 30 | 5.6 / 5.4 | 13 / 11 | 48.5 / 48.6 |
| Trader | +191 | +181 | 10 | +191 | 537 / 499 | 5.9 / 5.6 | 8.9 / 8.9 | 10 / 10 | 6.0 / 6.9 | 48 / 48 | 5.0 / 5.0 |
| Law-wise man | +130 | +161 | 10 | +170 | 325 / 429 | 4.6 / 5.2 | 9.9 / 11.1 | 11 / 13 | 5.4 / 6.0 | 98 / 99 | 5.2 / 5.9 |
| Berserk | +146 | +138 | 14 | +151 | 513 / 464 | 3.1 / 3.1 | 10.8 / 11.0 | 12 / 12 | 5.9 / 5.9 | 32 / 47 | 20.5 / 19.6 |
| Skald | +133 | +130 | 3 | +133 | 428 / 352 | 2.9 / 3.1 | 12.9 / 14.9 | 16 / 17 | 6.1 / 5.8 | 61 / 64 | 6.0 / 5.0 |
| King's man | +174 | +165 | 8 | +173 | 458 / 397 | 4.5 / 4.5 | 18.1 / 18.2 | 25 / 25 | 6.2 / 6.2 | 47 / 50 | 14.8 / 14.8 |

No stall, no saga ended, no shieldmaiden in these 48 five-year sagas (she
needs fame 15 and then comes in 5 of 100 summers). The richest bent earns
1.39 times the poorest (before 1.47). What moved: the law-wise man's
stand-in is silver-tongued now (one better at every counsel), and earns a
quarter more, the clearest single effect of a nature; the trader is
deep-minded and close-fisted, his luck ends higher (6.9, from 6.0); the
Viking's worth is a fifth lower because he spends (helmets for his men,
26 oz a year), and his worth with what he laid out is as before. The
first stand-in (reserve 200 + 10 a man) spent half again as much and
bought less land (Viking +101 worth a year, land 0.6; trader +152, land
4.4): the reserve was raised to 350 + 15 a man so a young band buys land
and a hull first, as a person would.

**What a saga can afford at 5, 10 and 20 years** (`batch_generations -- 3
20 1 0 <bent> younger_son`, playing every summer; silver in hand and
ounces laid out so far, at the springs of 871, 876 and 886, three sagas
each):

| Bent | y5 in hand / laid out | y10 | y20 | laid out in 20 years, by kind (mean) |
|---|---|---|---|---|
| Trader | 400-670 / 10-260 | 980-1020 / 810-950 | 660-2160 / 2850-3440 | feasts 1275, ship 800, arms 800, hall 240, skald 30 |
| Viking | 240-460 / 0-120 | 130-820 / 0-590 | 780-1470 / 1170-2830 | arms 1220, the dead 320, feasts 185, hall 80 |
| Law-wise man | 180-660 / 0-340 | 660-940 / 90-1210 | 250-1750 / 390-2160 | arms 1110, feasts 205, ship 105, hall 40 |

In words: at five years a band has a few hundred ounces and buys helmets
and perhaps a sail; nothing at the hall is yet worth its reserve. At ten
it has about a thousand, and the choices are real: the next step of the
hall (60, 180, 500), a skald (30 and 20 a winter), feasts for the houses
it wants (60-120 each, once a year each), mail for its veterans (45-56 a
man), a sword with a name (150), a stone or a mound for each of its dead
(40, 150). The whole of it for a band of fifteen is some 3000 to 4000 oz
of one-off things and 300 to 600 a year of feasts and the skald, more
than a ten-year band has: it must choose. At twenty a trader has laid out
about 3000 and still holds 700 to 2200; a Viking with 24 to 40 men has
laid out 1200 to 2800, most of it on arms for them. Before this branch a
forty-year trader or law-wise man ended with thousands and nothing to buy
(balance.md, "Still off"); now the trader's twenty-year chest is spent as
it fills. A rich band still runs short when it keeps feasting every
house: the stand-in's two feasts a summer cost 150 to 250 a year.

Shieldmaidens: none came in these nine twenty-year sagas, which showed
that the first rule (she came only when the band had a bench for her)
kept her from every full band; she now comes whatever the benches and
"Take her oath" is greyed with why when there is no room (the stand-in
then sends her on). With that, `batch_generations -- 3 20 11 0 <bent>
burned_hall`: three shieldmaidens took the oath in six twenty-year sagas
(trader 2 of 3 sagas, Viking 1 of 3), about one in a forty-year saga, and
the same sagas laid out 2100-3500 oz (trader) and 1360-2240 (Viking) in
twenty years with 900-2000 still in hand.

The save: `save_check -- 2 <origin> all all 1` for each origin (run as
three, side by side, since the whole matrix does not finish in 1500 s on
this shared machine; the one run of `-- 2 all all all 1` was cut off by its
timeout at 346 OK, 0 DIFF): younger son "== 201 OK, 0 DIFF, 3 never came
to the point", burned hall "== 203 OK, 0 DIFF, 1 never came to the point",
freedman "== 196 OK, 0 DIFF, 8 never came to the point". 600 OK, 0 DIFF.

## Tests

`tests/test_men_silver.gd`, 20 tests: a nature is two of different pairs,
once; it moves growth and lays edges (and they survive a step down a way);
the open hand and the closed fist; steady and deep-minded; reckless fame;
a son's mix; smiths where they should be; buying for a man and the chest,
the year's stock running out, the great smith dearer; the sword with a
name; a gift in summer once a man; benches in summer raise the ceiling;
the adornment's honor and warmth; feasts; a stone that says "her", the
skald paid at the winter; the sail and a new hull bare, the boathouse; a
shieldmaiden and the saga's words for her; how rare they are; the suit for
her hand; the stand-in spends; the estate and her sword saved and loaded.

## Files changed outside this package's ownership

- `sim/world/journey.gd` (shared): a new section at the end; one line
  each in `begin_summer` (`_men_silver_spring()`), `actions`
  (`_men_silver_actions()`), `act` (`or _act_men_silver(id)`), `answer`
  (the `men_silver` kind), `sail_speed` (`* Estate.sail_mult(self)`).
- `sim/world/journey_bot.gd` (shared): a new section at the end; one line
  in `play_year` (`_nature`), one call in `_act` after `_law_land`
  (`_men_silver`), one case in `_answer` (`men_silver`).
- `view/map_screen.gd` (shared): two lines in `_add_actions` (the smith
  and works open their panel).
- `tools/screenshot_game.gd` (shared): a new function `_men_silver` and
  the `nature` screen, one `elif` to call it.
- `sim/world/callings.gd` (nobody's): `holmgang_terms`' honor cost times
  the nature's `challenge_honor`.
- `sim/world/thralls.gd`, `sim/world/voyage.gd` (nobody's): one line each,
  the pronoun of a man of the band taken or drowned.
- `tools/batch_ways.gd`, `tools/batch_generations.gd`: the laid-out lines.
- `tests/test_generations.gd`: `test_saga_text_tells_each_generation`
  asks for two chapters at least, not exactly two (with the stand-in's new
  play the heir of seed 90 falls in his own first summer).

## Still open, and doubtful

- **The battle log says "his" of a shieldmaiden.** `sim/combat/*` belongs
  to battles-2. The lines: attack.gd 225, 228 ("his luck holds/is out");
  battle.gd 1055 ("he drops back behind"), 1316 ("dies of his wounds"),
  1527 ("in his mail"); decision.gd 134 ("freezes behind his shield"), 849
  ("looks for his place"); objective.gd 620 (a leader). A `Warrior.woman`
  set in `Man.to_warrior` and a `he()`/`his()` on Warrior would do it;
  left to battles-2. The fight's rules are untouched for her.
- **Shieldmaidens are rare**: three in six twenty-year stand-in sagas
  after the room rule was loosened, none in the 48 five-year sagas (fame
  15 comes late for most bents). Their reactions, the suit and the words
  are tested; a player may go a whole saga without one, which is the
  design, but it means few players will see her.
- **A non-son heir has no nature.** A sworn second or a man of the band
  who takes the high seat has his personality but no chosen nature, and
  the band's nature edges go with the old leader. A son brings a mix.
- **The skald is paid and sings only when the band winters at its own
  hall**; a band that winters abroad keeps him without paying him and
  without his fame. Simple, perhaps too kind.
- **Fittings are lost with the hull**, so a trader who changes ships
  twice pays for three sails (800 oz in twenty years in the measurement).
  That is a sink, and true, but the stand-in may buy a sail on a boat he
  will sell next spring.
- **The view's "For a man..." list** shows only those who lack the piece
  (a sword for the front rank, a bow takes a man to the bows); the hint
  says so, but a player who wants a second rank man to have a sword must
  move him to the front first (in the winter's yard).
- **The winter ring-giving does not offer the chest's arms**: the chest is
  given from the men panel in summer. The winter ladder still sells arms
  at the hall's prices.
- **The nature screen is not on the burned hall's skip path's tools**:
  `tools/screenshot_game.gd escape` begins without a nature (as tools
  should), so `diag_escape` and the escape render are untouched.
