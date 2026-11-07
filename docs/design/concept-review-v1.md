# Review of the Ring-Giver concept doc (v1, 7 Nov 2026)

Reviewer notes on Dylan's v1 concept doc. Each finding says what was changed
in `concept.md` (v2) or why it was left alone.

## Verdict

The doc is strong. The hook (lead one man, not an army), the band design, the
seasonal loop and the historical grounding all hang together, and the
milestones have real gates. The gaps are structural rather than creative:
two numbers that do not add up (campaign length, roll lethality), two
resources used everywhere but never defined (Luck, Reputation), a few
internal contradictions, and a milestone order that does not fit cloud-only
development.

## Findings, most important first

### 1. Campaign length does not fit the pillars — fixed

Three generations is about a hundred years. At two to three hours per played
year, a full campaign is 200–300 hours, and most of those years would have
nothing in them. The sagas solve this by skipping; the doc did not. v2 adds
**"Saga pacing: quiet years"**: at winter's end the player can let the years
pass with summers auto-resolved until something demands attention. Target is
ten to twenty played years per campaign. Pillar 3 now says so.

### 2. The roll table is a massacre — fixed as a starting point

Opposed 2d6 give a margin of 6 or more about 11% of the time between equal
men. Read literally ("maim, kill, or break"), eight men a side in contact
produce one or two kills or maimings a round for everyone, which makes
shield-wall battles end in three rounds and makes veterans die as fast as
green men. v2 maps margin to **wound steps**, lets shields and mail absorb,
never kills on a single roll (Down, then a post-battle roll), and labels the
table as a prototype starting point. The headless sim milestone now has a
gate for battle length.

### 3. Luck and Reputation are never defined — fixed

Both were referenced a dozen times (rolls, morale, loyalty, succession,
hanging back in battle) with no section saying what they are. v2 adds
**"Luck and reputation"** under the leader section: Luck as hamingja with
listed sources and sinks, Reputation split into fame and honor.

### 4. "Nerve" meant two things — fixed

Nerve was a permanent stat *and* the per-battle state that drops when men
fall nearby. v2 keeps **Nerve** as the stat and calls the battle state
**Morale**. Wits versus experience tier was also blurred (both "decide how
well a man carries out shouts"); v2 says Wits decides understanding, tier
decides execution.

### 5. The player's turn may be too thin — addressed

One action and one shout per turn, with men deciding after the player
commits, risks battles that feel watched rather than led. Frozen Synapse
works because of its plan preview. v2 adds a **muster preview** step (honest
about uncertainty for green men), makes **enemy leaders shout too** so there
is something to read, and gives the character things no shout can do (step
into a gap, take the banner, go for the leader). The playable-prototype gate
now tests this directly.

### 6. Beat order contradicted the push rule — fixed

The turn listed "movement → missiles → the push → melee"; the formation
rules said the push happens at round end. v2 uses movement → missiles →
melee → push → morale check. The push now compares Might weighted by morale
rather than nerve alone, since it is physical.

### 7. Engine listed as decided and as open — fixed

The overview and the tech section state Godot 4 with GDScript; the open
questions asked to confirm it. v2 marks it decided and removes the question.

### 8. Milestone order does not fit cloud-only work — fixed

The art test was milestone 1 with the combat sim gated behind it. The sim
needs no art, no display and no art-route decision, and it is the only thing
that can be built and tested from a cloud session. v2 puts the **headless
combat simulation first**, moves the art test to a parallel track that needs
a workstation, and adds a playable prototype step between sim and slice. The
tech section now names the concrete approach (RefCounted classes, `godot
--headless`, GdUnit4 or GUT, batch simulation for balance).

### 9. Scope has no ranking — fixed

The doc describes five battle types, a Thing mini-game, a market economy,
faction AI, succession, hall management, thralls and three expansion
regions, with only the milestones implying priority. v2 adds **"Scope
tiers"** (core, full game, later, cut unless it proves itself).

### 10. Facing was underspecified — fixed

"Front and front-left" with no direction count. v2 commits to eight
directions, shield covering front, front-left and left, and calls out the
rightmost-man weakness and rightward drift, which is a free emergent tactic.

### 11. Historical nits — fixed where cheap

- The two-handed **Dane axe** is a late-900s weapon; in 860–930 it is an
  anachronism. v2 renames it "long axe", makes it rare and late.
- **Olaf Tryggvason**'s enslavement is in the 960s, just outside the
  timeline. Rephrased as the famous example from just after the period.
- **Rollo**'s Norwegian origin is disputed (Dudo versus the Icelandic
  sources). Noted in the spine table.
- **Lawspeaker** is an Icelandic office; Norwegian Things had law-men.
  Hedged in the Thing section.
- **Warning beacons** are attributed to Haakon the Good's law. v2 makes the
  player's raiding part of why they spread, which is a nicer fit than
  assuming they already exist.
- **Hafrsfjord** dating note expanded slightly; the doc already hedged.

### 12. Player character gender is undecided but assumed — flagged

The doc says "he" throughout and "your wife runs the household", while
shieldmaidens are an open question. This decides pronouns, marriage,
household design and recruitment, so it should be settled before writing
dialogue. **Decided 7 Nov 2026: male only for now.** Recorded under
Character creation in v2; the household bullet keeps "your wife".

### 13. Named band cap of 30–40 — flagged, not changed

Forty autonomous named men on a 16×12 grid with simultaneous resolution is a
readability problem before it is a fiction problem, and Battle Brothers
tops out well under that. v2 says "around 30" and moves the cap to open
questions for the prototype to answer.

### 14. Save policy — flagged

Permadeath across generations begs the question of ironman. Added to open
questions.

### 15. Readability readouts — added

Nothing said how the player reads wound state, fatigue, wavering morale and
"did he hear me" at a glance, and the whole shout design depends on it.
Added as an art bullet ("Readability first") and to the prototype gate.

## Small edits

- Added Kormáks saga to sources (it is the holmgang source).
- Comparables now say what Frozen Synapse and Crusader Kings are borrowed
  for.
- Added a short "A year in the saga" example under Core structure so a
  reader can picture a session.
- Noted that the Pokémon IV/EV framing is internal vocabulary.
- Chronicle records skipped years in a line each.
- Open question added: whether summer time is continuous days or a turn per
  voyage leg.

## Left alone on purpose

- The pillars, the band design (potential, effort, natures, tiers, traits,
  ambitions, bonds), the winter hall, succession, the Thing mini-game, the
  thralls section and its tone guidelines. These are the best parts of the
  doc and did not need changing.
- The shout list. It is the right size for a first prototype.
- No numbers were added for loyalty, bonds, prices or stat ranges. Those
  belong in the sim, where they can be tested, not in the concept.
