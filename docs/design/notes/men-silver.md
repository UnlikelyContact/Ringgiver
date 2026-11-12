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

MEASURED

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
