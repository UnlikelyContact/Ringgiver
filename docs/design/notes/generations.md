# Generations: the years, the household, the grave-ale and the saga's end (12 Nov 2026)

Branch `generations`. Package A of the gap audit (gaps 1, 2, 3, sons and
fostering; bugs 9, 16 in part, 18). Before this the saga began in 866 and
only played summers moved the calendar; `Family` ran but nobody saw it;
the leader's death passed the high seat silently inside `conclude_fight`;
the chronicle was readable only as the last 12 lines at the end.

## What the player meets

**The spring step of the winter** (WinterHall step 7) has a new row, *Let
the years pass*: 1 year, 3 years, 10 years (and *Play the summer* to undo).
Choosing shows what it means as notes: his age now and after (decline from
40, old age from 50), what the men cost a year at home and bring in, the
chest now and about after, fame fading, the men who want silver or fame
and may leave, the children's ages, open feuds that may come to his door,
the next great matter of the spine that will stop the years, and (as a
guest) the lodging paid each winter. The main button reads *Let the years
pass*. An old leader (from `step_down_age`, 48) with a son of age also gets
*Step down for <son>*.

**The years pass** modal on the map after: "Then nothing is told of Egil
for three winters.", the chronicle lines of those years on parchment, the
tidings of the houses, and why the years stopped ("In 868: Harald marches
north into Trondelag ...  It is the spring of 868."). What stopped them is
then waiting: the spine's decision, the house's ask, the feud's men at the
hall door as a fight, the winter card for the son.

**The household.** Sons and daughters are born in winter as before (now
with a father). In the hall's talk, a card *The household* asks: a son of
12-14, foster him with one of the two friendliest houses or keep him at
home; a son come of age (16, a fostered son home from his foster-father
"with something of their craft"), *Take him into the band*, *Into the band,
as your heir*, or *Leave him to the farm*; a daughter of 15, marry her into
a house or not yet. The wife speaks one line of counsel in the talk when
something touches the household or her kin ("Asgerd says: Thorstein is my
son as much as yours. Do not put him in the front of the wall his first
summer."; her kin at feud or cold; the store short), and the old man by the
fire gives one too. *The year told* lists the household as rows: the wife
(her house, her keys), the mother (a widow keeps the keys), the old man,
each child with his age and state (fostered with X, in the band, at the
farm, of age, of an age to marry, married into X, heir).

**Death.** When the leader dies (a fight, his bed at the thaw, the island)
the map stops and the **death card** comes before anything else: "Egil the
Viking is dead. He fell at Fitjar fighting the men of Horda-Kari's kin; it
was Hrafn who struck him down. He was 31 winters old, and had led the band
6 summers. Ketil swore over Egil's grave that Hrafn would pay. His men said
..." Then **the grave-ale**, decision by decision:

1. *Who takes the high seat?* each candidate with what follows: his sons of
   age (in the band or at home; the named heir first) "keep the name, the
   feuds and the family's luck"; the sworn second "keeps the band and its
   feuds; the blood line ends in the high seat"; brothers and kin of the
   blood come of age; with none of these, the best man of the band takes up
   his name.
2. *The grave-ale*: an open-handed feast (3 oz a man, at least 30; fame +3,
   talked of), a plain one (20), a mean one (nothing; every man -6, honor
   -3). The silver also feeds `Succession.succeed`'s stay check as before.
3. *The bragarfull*: vengeance on the house whose men killed him (a feud
   with it is opened, and it becomes `band.vengeance` if none is owed), a
   deed of fame (two fights won this summer, judged as any vow), or "to
   hold what he held" (asks nothing). The burned hall's owed vengeance is
   offered when he died otherwise.
4. *A challenge*, if a strong second is passed over: "Alf would not drink
   to Hallbjorn ...": *Meet him on the island* (a holmgang on the battle
   screen through `Journey._duel`), *Buy his goodwill (30 oz)*, *Let him go*
   (with his oath-brothers). Won: he yields and drinks the oath cup, fame
   +5. Lost: he takes the high seat and the heir goes down to the benches.
   Killed on the island: the next death card.
5. *<Heir> takes the high seat*: what was said and sworn, his men, the
   feuds that are his now, fame, honor, luck, and whether the high seat has
   gone out of the blood.

With nobody to take it up, the card's only answer is *The band scatters*
and the saga ends. An old man's death adds *Here the saga ends*.

**The saga.** The book button on the map opens **the saga** (the old
summer chronicle is a button inside it, *This summer*): "The saga of Egil
Hardanger-son and his kin", a chapter per leader ("I. Egil the Viking, 866
to 874") with who he was and how he came to the seat, his years as the
chronicle has them (quiet years as "Then nothing is told of Egil for three
winters."), the men who stood by him at the last and those who fell (with
the year), his feuds and how they ended, the skald's verse of his last
winter, and his death. *Copy the saga* puts the text on the clipboard; on
the web (or where the clipboard is not offered) the text is also shown,
selected, in a box to copy by hand.

**Endings.** A great arc completed offers *Here the saga ends* / *But the
saga does not end there*: the burned hall's vengeance taken, becoming a
jarl, (later) land taken in Iceland. An old leader's death card offers it
too; the line dying out ends it. The closing card: how it ended, the
reckoning in words ("He kept his word, and men knew it. The burning of his
father's hall was answered. He left two sons living. The saga ran 31
winters, through three generations."), and the verdict in gold, one of
"Men will tell of him as long as the North is settled" / "His saga was told
at every Thing in the west" / "His name is remembered in the halls of the
west country" / "Men in the dales remember his name, and little more" / "A
few old men remember him" / "His name is not remembered"; *Read the saga*,
*Another saga*. The title then has *Read the last saga* (kept in
`user://ringgiver.cfg`, `[saga] last`).

## Rules and numbers (CampaignRules, "Generations")

| Rule | Value | Meaning |
|---|---|---|
| `years_max` | 10 | most years at once |
| `years_upkeep_per_man` | 3 oz | a man's ale, share and small gifts a year at home |
| `years_food_per_man` | 4 | rations a man brings in over a summer at home (a winter's eating) |
| `years_idle_loyalty` / `_other` | 6 / 2 | loyalty a summer at home for a man who wants silver or fame / anyone else; +6 more if unpaid |
| `years_fame_fade` | 2 | fame forgotten each quiet year |
| `years_attack_chance` | 0.2 | per open feud and feud level, a year: its house comes against the hall (stops the years) |
| `foster_min_age`..`foster_max_age` | 12..14 | fostering age; home at `foster_returns_at_age` 16 |
| `foster_craft_bonus`, `foster_crafts` | +1 | a point and a cap point in the craft of the foster house's temper (proud: nerve, grasping and peaceable: wits, steadfast: grit, else skill) |
| `son_join_age`, `son_join_loyalty`, `son_join_bond` | 16, 80, 30 | a son into the band |
| `daughter_marry_age` | 15 | |
| `step_down_age` | 48 | may step down for a son at the spring |
| `old_man_death_chance` | 0.2 | the old man of the hall dies in his bed, a winter |
| `grave_ale_open_per_man`, `_open_min`, `_open_fame` | 3, 30, +3 | the open-handed feast |
| `grave_ale_mean_loyalty`, `_mean_honor` | 6, 3 | the mean one (under half the plain `grave_ale_ounces` 20) |
| `heir_son_luck` | +1 | a son's luck on top of `luck_inherit_fraction` |
| `standing_inherit_son` / `_second` | 0.75 / 0.5 | the houses' regard kept |
| `challenge_stat_margin`, `challenge_bond` | 2, 10 | a second this much stronger (or of a better tier) whose bond with the heir is under 10 disputes the seat |
| `challenge_buyoff_ounces`, `challenge_won_fame` | 30, 5 | |

What carries over at a played succession, on top of `Succession.succeed`
(feuds in full; luck half plus or minus the death; fame half; the
loyalty re-check): the hall; a son: +1 luck, the wife becomes the mother
(keeps the keys), her house's marriage tie becomes kin, the houses keep
three quarters of their standing; a second or a man: half the standing,
marriage ties end, the line is marked ended (`Succession.line_holds`).
Every new leader starts his own ways of life (`band.paths`, `band.deeds`
cleared: the old ones are his chapter's).

The years stop, at the spring of the year that needs him (`Years._stop`):
a pending vow (also blocks choosing); a spine event with more than one
choice that year (one-option events, like Iceland opening, are fired as
"ignore" in the quiet summer); his son turning 12 or 16 or his daughter 15
that year; a house at feud coming against the hall; a friend's ask (help,
a marriage) or wergild offered (`Families.asks`; a lesser house's ask can
wait a year); stores and chest not enough for the year; his death in a
quiet winter (the death card follows). A quiet year: one-option spine
events fired, a chronicle line ("Egil sat at home at X that summer, and
nothing is told of him"), upkeep paid, the summer's food, idle loyalty,
fame fading, home and wife ambitions progress, rations bought for the
winter if short, then `Campaign.winter()` with the old sensible plan (its
thaw ages everyone, births, the houses' and factions' year, recruits,
departures, old-age death).

## Classes and functions

- `Years` (sim/world/years.gd, new): `blocked`, `spring_rows`, `choose`,
  `preview`, `after_winter`, `let_pass(j, n, lodging)`, `_stop`,
  `_quiet_year`, `_after_stop`; `STOP_WORDS`.
- `Family` (sim/campaign/family.gd): `own_children`, `kin_children`,
  `child_named`, `at_home`, `hall_cards`, `answer_card`, `son_man`,
  `counsel`, `short_name`, `household`, `old_folk_year`; metas
  `WIFE_HOUSE_META`, `HEIR_META`, `MOTHER_META`, `OLD_MAN_META`. Children
  now carry `father`; sons may carry `craft`, `kept`, `decided`, `man_id`,
  `seat`; daughters `married_to`, `asked`.
- `Succession` (sim/campaign/succession.gd): `succeed(..., played := false)`
  (the strong second rule only when played), `candidates`, `heir_man_of`,
  `grave_ale`, `carry_over`, `step_down`, `challenge_done`, `line_holds`,
  `LINE_META`.
- `Chronicle` (sim/campaign/chronicle.gd): chapters (`open_chapter`,
  `close_chapter`, `chapters`), `fell`, `keep_verse`, `quiet_year`,
  `died_at`, `old_man_died`, `saga(band, kin, rules)` ->
  `{title, chapters: [{heading, years, paragraphs}], closing, text}`,
  `reckoning(band, rules)` -> `{ending, lines, verdict, kind}`, `ENDINGS`,
  `VERDICTS`. `generation_text` is unchanged.
- `Campaign`: `played_succession`, `pending_death` ({cause, year, name, age,
  killer, winter, where, house}); `succession` defers when played;
  `conclude_fight` records the fallen (`Chronicle.fell`) and the killer;
  the thaw runs `Family.old_folk_year`.
- `Families`: `foster_son_with`, `marry_daughter`, `inherit`.
- `Journey`: `played_succession` (property, passed to the campaign),
  `years_told`, `household()`, `saga()`, `kin_name()`, `offer_ending(kind)`,
  `end_saga(kind)`, and privately `_saga_beats`, `_note_death`,
  `_death_card`, `_answer_saga`, `_heir_card`, `_vow_card`, `_hold_ale`,
  `_after_challenge`, `_told_card`. Decisions of kind `"saga"` with `step`
  death / heir / feast / vow / challenge / told / arc and a `title`.
- `WinterHall`: `years`, `step_down`; household cards in the talk
  (`"household"`), counsel notes, `_household_rows` in the year told, the
  spring rows; the verse is kept for the saga.
- `JourneyBot`: `let_years` (years to let pass each spring, 0 by default),
  `ends` (may end the saga when offered; off), `_answer_saga` (first heir,
  plain feast or open from 150 oz, vengeance when owed else peace, the
  island for a challenger, go on); turns `played_succession` on; an old
  man (step-down age + 4) steps down for a son.
- `SagaScreen` (view/saga_screen.gd, new): `fill(modal, saga, buttons)`,
  `copy`, `ending(modal, j, buttons)`, `years(modal, j, on_go)`.
- MapScreen: `_show_saga` (the book button), `_show_ending`; the years
  modal; decision titles from `d.title`. Game: `last_saga`,
  `remember_saga`, `saved_saga`, `show_last_saga`, the title button.
- `tools/batch_generations.gd [sagas] [years] [seed] [let_years] [way] [origin] [verbose]`.
- `tools/screenshot_game.gd`: `die`, `old:<age>`, `pick:<n>`, `family`,
  `son:<age>`, `strong`, `years:<n>`, `saga`, `ending`, `totitle`,
  `totitle:read`, `wscroll:<px>`.

## Hooks left for later packages

- **Iceland land-take**: call `journey.offer_ending("iceland")` when the
  land is carried round with fire (or `end_saga("iceland")` to end at
  once); the words are in `offer_ending` and `Chronicle.ENDINGS`, and
  `band.land > 0` already counts in the reckoning.
- **Played hall fights** (spears in the snow, fire in the night): a death in
  one already becomes `pending_death` and the death card at the spring; a
  played hall fight only needs its ctx to carry `family` for the vow of
  vengeance (`_note_death`).
- **The Thing in steps / outlawry**: an outlaw's death passes cause
  "outlaw" through `Campaign.succession`, which the reckoning and the
  death line read; an outlawry ending would be `end_saga("<kind>")` with a
  line added to `Chronicle.ENDINGS`.
- **Thralls**: the quiet year's food is the men's own work; thralls would
  add to `_quiet_year`'s summer food.

## Measured

`tools/batch_ways.gd -- 6 4 1 all burned_hall`, before and after (silver a
year; sagas ended of 6; deaths a saga). No stalls either way. The stand-in
players now hold the grave-ale themselves (`played_succession`), so a
leader's death is a played succession; no income was added.

| Bent | before | after |
|---|---|---|
| Viking | +184, 0/6, 2.8 deaths | +184, 0/6, 3.2 |
| Trader | +32, 1/6 ended, 0.8 | +28, 0/6, 1.0 |
| Law-wise man | +46, 0/6, 1.5 | +53, 0/6, 1.2 |
| Berserk | +55, 0/6, 0.3 | +55, 0/6, 0.3 |
| Skald | +107, 0/6, 1.2 | +99, 0/6, 1.2 |
| King's man | +14, 0/6, 1.3 | +19, 0/6, 1.2 |

The trader saga that ended in 867 (its leader and second fell in one
fight) now goes on: the best of his men takes up the name.

`tools/batch_generations.gd -- 3 35 1 <let> viking burned_hall` (three
sagas, 35 calendar years, the Viking stand-in):

| | year reached | generations | years let pass | silver a year | stalls |
|---|---|---|---|---|---|
| lets 10 years each spring | 901, 901, 901 | 4, 4, 3 (3.7) | 3, 2, 10 (5.0) | +35, +75, +2 (+38) | 0 |
| lets 3 years each spring | 901 x 3 | 3.7 | 4.7 | +38 | 0 |
| plays every summer | 901 x 3 | 4, 3, 2 (3.0) | 0 | +2, -0, +141 (+47) | 0 |

Every saga reaches 901 with a second generation (deaths in battle,
old age in the 890s, stepping down, one high seat lost on the island).
Sitting out the years is not richer: +38 oz a year against +47 for the
sagas that play (per saga it swings both ways with what the summers
bring). The years stop often for this stand-in: the Viking has open feuds
and wergild offers most springs (stops over the three sagas: houses 40,
sons 14, spine 14, attacks 11, daughters 6, death 1), so most lets end
after a year or none; the saga with fewer quarrels let ten years pass.
`test_passing_years_is_not_richer` pins the bound: a year at home brings
in no more than the land yields, and a saga that sits three years out of
four ends poorer than the one that plays them (671 against 248 oz).

Screens at 844 x 390, zero SCRIPT ERROR lines in each: the death card,
the heir, the feast, the bragarfull, a challenge, the heir's telling, the
spring step with years chosen, the spring with stepping down, the
household rows of the year told, the household cards in the talk, the
years told, the saga, the ending card, the title with "Read the last
saga" and the saga read there, an old man's death card. Suite: 445 tests,
0 failed.

## Open

- Bands of the stand-in Viking grow past `recruit_cap` over long runs
  (29 to 104 men by 901; men who ask to join after a fight are not
  capped; not this package's).
- The years stop for any wergild offer or friend's marriage; a busy
  raider rarely gets more than a year. Worth tuning once played.
- The holmgang for the high seat is the existing first-blood duel; with a
  much stronger second it is nearly always lost.
- A son at home who is made leader at the grave-ale is built then (weak,
  of his age): a son of 15 in the high seat is a hard start, by design.
- Daughters married into houses do not leave the household list's
  "married" rows; grandchildren through daughters are not modelled.
- Old leaders decline only through `Growth.winter_age` (Might and Grit);
  wits do not fade.
