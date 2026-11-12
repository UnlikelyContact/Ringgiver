# Gap audit against concept.md (November 2026)

A read-only audit of every promise in `concept.md` against what a player
can reach through the real game (title, the escape, the map, fights
handed to the battle screen). Made while the winter hall screen, the UI
restyle and the summer world-life work were in progress; those areas are
not counted as gaps here.

Status: a = playable, b = in the sim but not reachable by the player,
c = partly there, d = absent.

## The top gaps, ranked for a phone player

1. **Let the years pass** (b). Spine events after 875 are unreachable: the
   game starts in 866 and only played summers advance it. A button after
   winter wrapping `Sandbox.pass_years`, stopping on spine events, house
   asks and sons coming of age. M.
2. **Succession as a played moment** (c). `Campaign.succession` is
   automatic. Make it a decision ("The grave-ale"): feast silver, a vow,
   son or second; fight the pending challenge as a holmgang; let the
   player name his sworn second. M.
3. **The saga as an artefact and an ending** (c). A saga screen showing
   `Chronicle.generation_text` per leader, copy/share; end states (no
   heir, vengeance done, jarl or king, Iceland settled) with a verdict.
   S-M.
4. **Defending your hall** (b). Winter feud attacks and hall-burnings are
   resolved by the AI off-screen (fought as "wait for them" on a river
   ford). Route them to the battle screen with a hall-defence scenario. M.
5. **Attacking a hall by night** (d). The reckoning at a seat is an
   open-field fight. Offer the burning, with its honor cost. M.
6. **Iceland land-take and owned land** (b). `band.land` is never raised
   for the player; "the Iceland land-take" is a raidable farmstead. A
   "Take land" action and buying or claiming a farm. M.
7. **A hall you build** (b). `Hall.build` is never called on the player
   path; a growing band loses loyalty "for no bench". S (belongs with the
   winter hall).
8. **Captives and thralls** (c/d). Only "Sell N captives" exists. Ransom,
   keep, free; thralls as labour with unrest. M.
9. **An interactive Thing** (c). `Thing.run` runs all four stages with no
   choices. Split into decisions: silver for supporters, hire a law-man,
   the standoff, compensation or outlawry. M.
10. **Outlaw and exile** (c). "Sail west with Rollo" does nothing; halls
    are not really shut to an outlaw; bounty hunters never spawn. S-M.
11. **Saga fights fought over something** (b). Objectives exist only in
    "A single fight"; raids from the map have none. Choose the objective
    from what the fight is for. S.
12. **Luck that matters, and omens** (b). `Leader.luck_modifier` has no
    callers; omens are never raised. S.
13. **Ship fights** (c). A sea fight is a flat green field. A deck
    scenario: two hulls, a gangway, men overboard. M-L.
14. **Settings and accessibility** (c/d). No settings screen; auto-pause
    cannot be turned off; map text is small. S-M.
15. **Sound** (d). No audio anywhere. M.

Next after these: "Your men" showing potential as hints, bonds, ambitions
and sons; gear as gifts; sons joining the band and fostering your own
son; Hafrsfjord as a shield-wall sector; character traits at the start;
river routes east; shieldmaidens; named lieutenants.

## Bugs and dead ends found on the player path

1. Winter storm damage and the REPAIR task act on the old
   `band.ship_damage`, not `band.ship.damage`.
2. The winter skald's and envoy's fame (`ev.fame`) is never applied.
3. The winter `marriage_offer` marries the leader without asking, to a
   house outside the Families web.
4. Winter feud attacks and hall-burnings are fought by the AI; the leader
   can die off-screen.
5. "Sail west with Rollo": `Journey.answer` ignores the exile flag.
6. `thrall_unrest` fires with no thralls.
7. Luck is shown but affects nothing; `led_from_front` is always true.
8. `ThingCase.lawman_hired` is never set; no man gets "law-wise".
9. The succession challenge is set and never fought; the winter quarrel
   holmgang is only logged.
10. A brawl at the Thing and fights at your own hall offer "Wait for
    them" (a river bank).
11. An outlaw can still winter as a guest, rest, take passage and trade;
    `Outlawry.bounty_hunters` is never called.
12. The oath-brother vengeance feud is opened against the enemy leader's
    personal name, giving a feud with no house, seat or reckoning.
13. `Journey._after_fight` has no branch for ctx "feud" or "thing":
    winning a feud ambush leaves the feud as it was.
14. `Journey._winter` puts the band in an ill-wisher's hall when the snow
    catches it.
15. The Iceland spine event offers only "Stand aside".
16. Ambitions for land, wife, home and vengeance never progress.
17. Eight base seats and no way to build benches: loyalty drains each
    winter.
18. The end modal shows only the last 12 chronicle lines.
19. "Your men" shows raw stat numbers; `Potential.hints` is unused.
20. No way-of-life gift goes unread (checked).

## Suggested packages

- A. Generations and the saga's end: years passing, succession, the saga
  screen, sons and fostering.
- B. Fights of the saga: hall defence, hall-burning, objectives from the
  fight's cause, the deck, luck in combat.
- C. Law, land and the unfree: the Thing in steps, outlawry and exile,
  land-take, captives and thralls, omens.
- D. The shell: settings, sound, the "Your men" panel.
