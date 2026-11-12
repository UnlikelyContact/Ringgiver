# The shell: sound, settings, and the men as the saga tells them (shell)

Branch `shell`. Package D of `gap-audit.md`: gap 15 (sound: there was
none), gap 14 (settings and accessibility), the touch and legibility
fixes on the map, and "Your men" rebuilt so a man is told, not tabled
(bug 19: raw numbers, `Potential.hints` unused).

Screenshots are listed at the end. Nothing here was heard: the sound was
checked by numbers only (see "What is not verified").

## Sound

### How it is made

No sound files: `AudioSynth` (view/audio_synth.gd) renders every sound
once into a buffer of floats, `AudioSynth.stream` packs it into a 16-bit
mono `AudioStreamWAV` (loop points set for the beds), and `Audio`
(view/audio.gd) plays them on pooled `AudioStreamPlayer`s. No
`AudioStreamGenerator`: nothing is streamed, which the single-threaded
web build does badly. The stingers that need the top of the spectrum
(the knock, the page, the coin, the shields and blades, a man down, the
bird) are 22050 Hz; everything whose sound lies low (the beds, the horn,
the lyre, the rout) is 11025 Hz, which halves the work.

Rendering is deterministic: all noise comes from `RandomNumberGenerator`s
with fixed seeds (the lyre's strings are seeded by their pitch, so a note
is the same whichever sound asks for it first). Levels are set by name in
`AudioSynth.DEFS`: the beds normalised to an RMS, the stingers to a
peak, the music under both. Every one-shot fades its last 6 ms to
silence; every sound goes through a 20 Hz DC blocker.

Loops close two ways: events (a drum stroke, a crackle) are added round
the end of the buffer and back to its start; filtered noise is rendered
half a second long and its tail cross-faded into its head. Periodic tones
(the drone) have frequencies that fit whole cycles into the loop. The
drum's strokes start 0.12 s into the loop so the seam lies in a dying
tail, not on a stroke.

| sound | how | rate | length | level (measured) |
|---|---|---|---|---|
| `sea` | brown-ish noise (two one-pole low-passes at 180 Hz) under a swell twice a loop (rise over a third, fall to nothing), and the break's hiss (band-pass 1.2 kHz) riding the top of each swell; the player sways it again (+-30 %, a 23 s cycle) | 11025 | 8 s loop | RMS -30.0, peak -14.3 |
| `wind` | noise through a band that wanders 450-900 Hz with the gusts, over a low breath | 11025 | 8 s loop | RMS -31.0, peak -17.9 |
| `hall` | a low roar (two low-passes at 260 Hz, breathing) and 46 crackles, runs of 1-5 clicks of bright noise at seeded times | 11025 | 8 s loop | RMS -31.0, peak -18.9 |
| `battle` | a skin drum at 75 bpm, eight strokes, the first of four heavy (a sine falling 105 to 52 Hz with a thump of low noise), over a murmur | 11025 | 6.4 s loop | RMS -30.0, peak -12.9 |
| `battle_close` | the same at 104 bpm, every stroke doubled, the murmur brighter and louder: crossfaded in while the lines are met | 11025 | 4.6 s loop | RMS -28.0, peak -13.2 |
| `press` | a knock on wood: partials at 540, 1230, 2310 Hz dying in 22, 12, 7 ms, a tick of noise | 22050 | 0.14 s | peak -16.0 |
| `page` | parchment: two uneven rustles of noise band-passed at 2.4 kHz | 22050 | 0.42 s | peak -15.0 |
| `tick` | the day on the map: the faintest tap (1750 and 880 Hz) | 22050 | 0.06 s | peak -28.0 |
| `arrive` | two lyre notes, D4 and A4 | 11025 | 1.7 s | peak -13.0 |
| `coin` | two struck rings of unrelated partials (2093, 3351, 4797, 6271 Hz), the second 3.5 % higher, 75 ms after | 22050 | 0.7 s | peak -12.0 |
| `bird` | three falling chirps (4.3 to 3 kHz); played now and then ashore, at a seeded pitch | 22050 | 0.5 s | peak -24.0 |
| `horn` | a cow-horn on D3: a PolyBLEP sawtooth through a low-pass that opens with the breath (the brassy bloom), a breath of noise, a slow waver once held; a fight offered | 11025 | 1.7 s | peak -9.0 |
| `horn_rise` | the same, rising D3 to A3: Push, Break them, Svinfylking | 11025 | 1.25 s | peak -9.0 |
| `horn_fall` | falling A3 to D3: Fall back | 11025 | 1.25 s | peak -9.0 |
| `horn_two` | two short blasts: Shield wall, Hold, To me | 11025 | 0.95 s | peak -9.0 |
| `horn_three` | three short: Taunt | 11025 | 0.95 s | peak -10.0 |
| `clash` | shields meeting: a thump of limewood (noise 60-900 Hz), the body at 185 and 410 Hz, the boss at 1270 and 2730 Hz | 22050 | 0.4 s | peak -9.0 |
| `blade` | iron biting: a sharp tick and partials at 1720, 2950, 4410, 6130 Hz | 22050 | 0.5 s | peak -10.0 |
| `down` | a body on the ground (78 falling to 40 Hz, low noise) and his gear after it | 22050 | 0.7 s | peak -9.0 |
| `rout` | many feet (70 thuds at seeded times, thickest in the middle) and men crying out (noise through 560, 1000, 1700 Hz bands, each wavering), swelling and passing | 11025 | 2.2 s | peak -10.0 |
| `victory` | the lyre: D3+D4, A4, then D5 over A3 | 11025 | 2.9 s | peak -9.0 |
| `defeat` | A3, G3, E3, D3, slow | 11025 | 3.4 s | peak -10.0 |
| `escape` | D4, E4, A4, then G4 | 11025 | 2.9 s | peak -10.0 |
| `drone` | the music's bed: two bowed tones (D2 at 73.5 Hz, A2) as PolyBLEP sawtooths through a 700 Hz low-pass, the bow's pressure rising and falling, a little rosin noise | 11025 | 4 s loop | RMS -34.0 |
| `phrase0`-`phrase5` | the music: four to six lyre notes each, D dorian's pentatonic (D E G A C) from D3 to D5, slow, mostly stepwise, every one coming home to D or resting on A | 11025 | 4.2-5.6 s | peak -17.0 |

The lyre is Karplus-Strong: a period of softened noise (the excitation
low-passed by how hard it is plucked, a fifth of it cancelled half a
period on, its mean taken out) in a delay line, averaged and damped round
and round to a 2.4 s fall (3.4 s on the low strings), tuned between whole
samples by a first-order allpass, then a 3.2 kHz low-pass for the body.
Measured: A4 rings at 440 Hz (autocorrelation, `test_the_lyre_is_in_tune`),
D4 at 293.3. A raven's croak was not made: there is no way to tell here
whether it would be ominous or silly, so it is left out.

The music is the drone with a phrase on the lyre now and then: chosen by
a seeded sequence (`_rng`, seed 866), never the same phrase twice
running, 3-7 s of rest between, and one rest in five 8 s longer. It plays
on the title and in winter (the map's winter modal).

### The spectra, checked

`tools/audio_check.gd` writes every sound as a WAV; numpy's FFT of them
(peaks over 20 Hz, the strongest four):

- horn (held part): 146.7, 293.3, 440.0, 587.7 Hz: D3 and its harmonics.
  horn_rise, start 150 Hz, end 220.1 Hz (A3); horn_fall ends on 146.7.
- drone: 73.4, 110.0, 146.8, 293.5 Hz.
- the lyre: phrase0's first note 440.0 Hz, its last 293.3; arrive 292.4
  then 293.8 (D4); victory's middle 220 (A3), defeat's end 293.3 (D3's
  second harmonic over its 146.8 fundamental).
- tick 1750 and 883; coin 2166, 3469, 4965, 6490 (both strikes together);
  clash 150 (the 185 falling), 1270, 410; blade 1720, 2950, 4410, 6130;
  down 41-58 and the 1460 clatter; press 543, 1229.
- the beds: sea's energy at 40-100 Hz (centroid 747 Hz with the hiss);
  wind centroid 1741 Hz; hall 58-108 Hz roar, centroid 801; battle
  70-106 Hz (centroid 578), battle_close the same and brighter (898).
- page, before a fix, peaked at 9 kHz (the band-pass was too high for its
  filter): now 2.9 kHz, centroid 5 kHz.

### Where it is heard (one line each, in the view)

| where | what |
|---|---|
| every button (Audio connects to the tree's `node_added`) | `press` |
| game.gd: the title | scene `title` (the hall's fire low and the music) |
| game.gd: the name, the night's cards, another beginning | scene `opening` (the fire) |
| map_screen.gd `_ambience` | `map_sea` aboard (`journey.roam.aboard`), `map_shore` ashore within two cells of the sea, `map_land` inland (birds now and then), `winter` while the winter's tale is up |
| map_screen.gd `_process` | the bed steps back (`duck`) while a modal, a side list or the settings are open |
| map_screen.gd `_status` | `tick` when the day changes while the band moves |
| map_screen.gd `refresh` | `arrive` when the band comes to a new place |
| map_screen.gd `_fill_modal` | `horn` when a fight offers, `page` for any other matter (once a matter) |
| map_screen.gd `_open_side` | `page` |
| map_screen.gd market and deeds | `coin` on a buy or a sale, and on a deed that moved silver |
| main.gd `_show_battle` | scene `battle` (`battle_night` for the burned hall: the drum and the fire) |
| battle_view.gd beat 2 | `Audio.blows(lines)`: a round's exchanges as at most three layered clashes and three bites of iron, staggered over 0.4 s, at a few pitches |
| battle_view.gd beat 4 | `down` if a man went down; `rout` on three fled in a round or a rout; `close(true)` while any man stands at an enemy's shoulder |
| hud.gd `_on_shout` | the horn for the shout's family |
| hud.gd `_on_finished` | the lyre's tail by the outcome: victory, defeat, or `escape` (got out, withdrew, both drew off) |

### The Audio API

```gdscript
Audio.play(name, db := 0.0, pitch := 1.0)   # a stinger
Audio.later(seconds, name, db, pitch)       # a stinger a little later
Audio.scene(key)                            # the bed: "", title, opening, map_sea, map_shore, map_land, winter, battle, battle_night
Audio.close(on)                             # the lines have met: the drum quickens
Audio.duck(on)                              # something to read is open
Audio.shout(CombatTypes.Shout)              # its horn
Audio.blows(lines) / Audio.blow_counts(lines) -> Vector3i(clashes, bites, downs)
Audio.result(BattleResult.Outcome)          # the lyre's tail
Audio.refresh()                             # the settings changed
Audio.get_audio() -> Audio                  # the node, or null (headless)
```

There is no autoload and project.godot is untouched: the first call makes
one `Audio` node and adds it (deferred) to the tree's root; in a headless
run (`DisplayServer` "headless": the tests, the batch tools) no node is
made and every call does nothing. No buses either: each player's
`volume_db` is worked from the master loudness, sound on/off, music
on/off and the duck. Eight players for the stingers (a free one, or the
one that has played longest), four slots for the beds (a bed takes a free
slot while it sounds, starts at a random point of its loop, fades in and
out over 1.6 s, and gives its slot back when silent): twelve in all.
Nothing plays until the first press or key (a browser's rule); with no
audio device Godot's dummy driver takes the calls.

### Performance

Rendering and packing every sound, headless on this machine (4 cores, a
load average of about 4 from other runs): 434-532 ms over five runs,
1,045,776 samples. The largest single sounds: `battle_close` 42 ms, `sea`
26-56 ms, `battle` 34 ms, `drone` 27 ms; every stinger under 25 ms. A
phone's browser runs GDScript slower (perhaps two to four times; not
measured), so nothing is rendered all at once: `Audio` renders one sound
a frame from its first frame (`WARM`, in the order the first screens want
them), and a sound asked for before its turn is rendered then. The worst
stall is one bed's render in one frame. Per frame afterwards: the fades
and the sway set a few `volume_db`s; no allocation but a stinger queued
by `later` (a small array per round of a fight). The lyre's plucked
strings are cached while the phrases are mixed and dropped when the warm
list is done.

### The check

`godot --headless --path game -s tools/audio_check.gd -- [out_dir]`
prints peak, RMS (dBFS), DC, length, the loop's seam (the jump from the
last sample to the first, in ordinary sample-to-sample steps: 1 or less is
seamless; the worst is the hall's 1.66, a crackle near the end) and the
time taken, and fails on a NaN, a peak over 0.98, DC over 0.002, a seam
over 2.5, or a sound's RMS more than 15 dB from its group's median (4 dB
for the beds). It writes WAVs for a look at the spectrum. Last run: AUDIO
CHECK OK.

## Settings (view/settings.gd)

`Settings` is static values, kept in `user://ringgiver.cfg` under
`[settings]` (the browser's IndexedDB on the web), beside game.gd's
`[tutorial] escape_done`, which it keeps. `Settings.persist` follows
game.gd's `use_config`, so the tools and the tests never write the
player's file (the tests use their own path). Every change applies at
once (`Settings.apply`); a toggle is written at once, a slider when the
modal closes.

| key | default | what it does |
|---|---|---|
| `master` | 0.8 | the loudness of everything |
| `sound` | on | the beds and the stingers |
| `music` | on | the drone and the lyre's phrases |
| `battle_pulse` | 0 (turn by turn) | seconds between rounds when they go by on their own; the battle's pulse slider starts there, and where the player leaves the slider is the next fight's start (not in the taught escape) |
| `auto_pause` | on | `BattleView.auto_pause`: a fight that runs on its own stops when a man goes down or flees, you are flanked, or their leader shouts |
| `map_fast` | off | the map's days run fast from the start |
| `large_text` | off | every size of type x1.15 (`UiTheme.set_text_scale`, which rebuilds the one Theme in place; sizes set on nodes use `UiTheme.fs`) |
| `reduce_motion` | off | nothing fades in (`UiTheme.reduce_motion`) |
| `colour_safe` | off | the two sides' shields an ochre-orange (L* 55) and a deep woad (L* 25) instead of madder and woad (both L* about 31: told apart by hue alone); the battle strip's words follow (L* 74 and 57); the houses' standing runs dark red to light blue, not red to green |
| `show_numbers` | off | a man's card shows the numbers beside the words |

Also "Show the hints again" (the burned hall is taught again, the
config's `escape_done` cleared, and this saga's hints come back) and
"About the game" (a paragraph in the saga's voice and the build stamp).

The modal is a `UiModal` with four titled cards (Sound, Pace, Reading,
The saga) in two columns when the screen is wide enough, one on a narrow
one. It opens from a drawn gear (`Settings.gear`, a `ToolButton` that
draws a cog): top-left on the title, in the map's control cluster before
"?", and at the end of the battle's top row (never shut by the tutorial).
game.gd's `settings_changed(key)` and `settings_closed()` rebuild the
title or the map when the words' size or the colours changed; the HUD's
apply the pace, the pausing and the colours to the fight at once.

## Touch and legibility on the map

- `UiTheme.SMALL` is 16 (was 14) and `KEY` 13 (was 12): nothing the
  player must read is under 16 design pixels (11.6 on a phone held
  sideways) except the spaced capitals over a stat. The chips' words 14.
- The map's controls (pause, fast, halt, nearer, further, follow, the
  gear, "?") are 62 design pixels square (45 screen pixels on a 390-high
  phone); the hints' card sits under them.
- A deed in the side panel is at least 62 high; the market's buttons 52.
- The side panel's head is tighter: name and rank; the date and the place
  (now wrapping, so a long place name is never cut) with the days left;
  the summer's bar; the stat strip with less padding (its labels clip
  rather than push the panel wider in the large words); the three lists;
  a plain rule. The ship and the hold line moved to the foot of the
  scroll. At a place the deeds come first under its name, the market
  after them, and what the place is (kind, region, lord, house and its
  standing, prices heard) last. At 844 x 390 three deeds now show
  without scrolling (one and a half did); with the large words, one and
  a half.

## Your men (view/men_panel.gd)

`MapScreen._show_men` now calls `MenPanel.new(self).show_list()`. The
list: every living man, the leader first, as a row a thumb can press
(62 high): his name (the leader's with his epithet) and "You", what he is
("21, a green spearman"), the one thing he is known for (his latest deed,
or the men he has put down, or a trait he earned, or his nature and his
best gift and "untried": never the trait his birth gave him), and his
wound as a chip with "stays behind" when he is too hurt. A press opens his
card, in two columns when there is room:

- the line under his name: age and what he is, born a what, how long with
  you, banner or horn, your sworn second; his wound;
- His nature: each `Personality` as a word and what it means ("Greedy: he
  keeps a close eye on the sharing of the silver"), his traits and maims;
- His strength: the five stats in four steps of words each ("weak in the
  arm", "fair in the arm", "strong", "mighty"; steps at 1-3, 4-5, 6-7,
  8-10) with four pips, and the number only with `show_numbers`;
- What he may become: `Potential.hints` (unused before) at the judge
  level the leader's wits give (1 below 4, 2 below 7, 3 from 7), "a
  coal-biter" when `Potential.is_coal_biter` and the judge can see it,
  and how well you read him;
- His deeds: fights come through, men put down, times he broke and ran,
  his told deeds, his wound and the healing left;
- His oath (not the leader): loyalty in five steps of words (below
  `loyalty_leave_below` "He will leave at the thaw unless something
  changes", in red), his ambition and whether it is met or how near;
- His bonds: oath-brothers (`Bonds.oath_brothers`), bad blood
  (`Bonds.rivals`), the men he stands closest to (bond 25 or more);
- for the leader: His name in the world (the epithet or "not yet given
  him a name"; fame, honor and luck in words), His ways (each way and the
  steps taken), His household (wife, children with their ages and
  fostering, from `band.sons` and `Family.age_of`; the sworn second).

Footer: "Back to your men", "Back to the map". Nothing in sim/ changed;
no accessor was needed.

## Files

New: view/audio.gd, view/audio_synth.gd, view/settings.gd,
view/men_panel.gd, tools/audio_check.gd, tests/test_audio.gd,
tests/test_settings.gd, tests/test_men_panel.gd.

Edited (focused): view/game.gd (settings load, scenes, the title's gear,
`settings_changed`, `settings_closed`, `forget_escape`), view/map_screen.gd
(the panel's head, `_fill_place` reordered with a new `_about_place`, the
controls' size, the gear, `_ambience`, the sound hooks, `_show_men`;
`_man_row` kept, unused), view/hud.gd (the gear, the horn, the tail, the
side colours, `settings_changed`), view/main.gd (the pace and pausing from
the settings, the battle's scene), view/battle_view.gd (three hooks),
view/hints.gd ("?" and its card at 62), view/ui_theme.gd (SMALL 16, KEY
13, `text_scale`/`fs`/`set_text_scale`, `reduce_motion`, `colour_safe` in
`standing_color`, a row's `min_h` meta), view/palette.gd (`side_color`
reads `colour_safe`; appended the safer colours and `ui_side`),
tools/screenshot_game.gd (`settings`, `man:<n>`, `large`, `safe`,
`numbers`, `scroll:<px>`, `place:<px>`, and `what` "settings").
project.godot is untouched.

## What is not verified

- Nothing was listened to. The levels, spectra, seams, tuning and
  determinism are measured; whether the horn sounds like a horn, the sea
  like the sea, the music like music, is not known. If the music sounds
  poor, turning `Settings.DEFAULTS.music` off (or the `drone` and phrases
  out of `Audio.SCENES`) removes it.
- The web build was not run: the audio unlock on the first touch, the
  pooled players under the browser's sample playback, `pitch_scale` and
  `play(from)` there, and the render time on a phone are unmeasured.
- The colours for colour-blind eyes were checked by lightness (L*), not
  by simulation.
- The saga's end modal was not rendered; a household with a wife was
  (after a year of play), one with children was not.

## Screenshots

In `shell-shots/` (844 x 390 unless the name says 1280), every one
rendered with zero SCRIPT ERROR lines and looked at:

| shot | what |
|---|---|
| `0_map_before.png`, `0_men_before.png` | the map's panel and Your men as they were |
| `1_map_after.png` | the tighter head, the 62-pixel controls with the gear, three deeds showing |
| `2_map_large.png` | the same with the large words |
| `3_men.png`, `3_men_after_a_year.png` | the list of men |
| `4_man_leader.png`, `4_man_leader_lower.png`, `4_man_leader_after_a_year.png` | the leader's card, its lower half, and after a year (his epithet, his ways, a wife, his sworn second) |
| `5_man_alf.png`, `5_man_alf_large.png`, `5_man_alf_after_a_year.png` | a man's card, with the large words, after a year |
| `6_man_leader_1280_numbers.png`, `6_man_alf_1280.png` | the cards at 1280 x 720, one with the numbers shown |
| `7_settings_title.png`, `7_settings_large.png`, `7_settings_1280.png` | the settings over the title |
| `8_settings_map.png`, `8_settings_battle.png` | over the map, and over the taught escape (the gear at the end of the top row) |
| `9_title.png` | the title with its gear |
| `10_battle.png`, `10_battle_colour_safe.png` | the escape's second step, in madder and woad and in the safer colours |

Made with `tools/screenshot_game.gd`, e.g.
`... -- out.png younger_son 7 answer:ignore man:1`,
`... -- out.png settings 7 large`, `... -- out.png escape 7 safe tut:3`.
