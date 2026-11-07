# Concept art prompts

For quick exploration in an image generator (ChatGPT, 7 Nov 2026). Paste
the style block first, then one prompt. Derived from concept.md, "Tech and
art direction".

## Style block

Concept art for "Ring-Giver", a Viking-age Norway saga game, 860s–950s AD.
Historically grounded: no horned helmets, no fantasy armor, no glowing
runes. Round wooden shields with iron bosses, spears as the common weapon,
bearded axes, a rare sword, mail shirts only on wealthy men, simple conical
or spectacle helmets, wool tunics in madder red, woad blue, walnut brown
and undyed grey. Heroic proportions, about 5.5 heads tall, broad shoulders,
big hands, big shields and weapons, chunky beards, so gear reads at a
glance. Hand-made feel like Dead Cells: chunky painterly shapes with clean
silhouettes and a limited palette, readable at small size, not
photorealistic. Cold northern light, fjords and grey sea. No text, no
watermark.

## Prompts

1. **Character turnaround (art test).** Character sheet of one sworn man of
   a Viking war band, shown twice side by side in the same pose: left in a
   plain wool tunic with a leather cap and a round shield and spear; right
   the same man upgraded with a mail shirt, iron helmet and a sword.
   Three-quarter view, standing, neutral grey background, full body,
   consistent proportions, game sprite reference.
2. **The shield wall.** Isometric view, camera angled about 45 degrees, of
   two small Viking war bands meeting on a muddy fjord-side field, eight
   men a side, shields locked in two lines that read as diagonals, spears
   striking over the front rank from behind. One leader in the front rank
   is shouting with his mouth open, men nearest him turning to obey, a man
   at the far end of the line looking the wrong way. A banner-bearer and a
   horn-blower behind the line. Wide shot, readable silhouettes, a few
   shields splintered, one man stumbling back.
3. **The hall at Yule.** Interior of a Viking longhall at Yule, long fire
   pit down the centre, smoke in the rafters, carved high seat at the end
   with the leader in it, sworn men on benches along both walls in seating
   order, the nearest to the high seat better dressed. A woman holding the
   household keys stands by the stores. Arm rings being given. Warm
   firelight against cold blue from the doorway, snow outside. Painterly,
   hand-made feel, no text.
4. **Portrait.** Painted head-and-shoulders portrait of a Viking-age
   Norwegian warrior, about 30, scarred cheek, braided beard, wool hood
   pushed back, one eye slightly narrowed. Plain dark background, strong
   side light, limited palette, consistent portrait style that could be
   repeated for dozens of different men. No text.
5. **Close-up moment.** Dramatic close-up cut-in of a bearded axe hooking
   the rim of a round shield and tearing it aside, the shield splintering,
   the man behind it wide-eyed, a spear point entering the frame from the
   right. Low angle, motion, splinters and mud in the air, limited palette
   with one hot colour for the painted shield face. Painterly, no text.
6. **The strategic map.** Hand-painted map of the coast of Norway and the
   North Sea as seen in a saga game, the fjord coast from the Oslofjord
   north to Hålogaland, with Denmark, the Baltic, Orkney and Iceland at the
   edges. Parchment and ink with painted sea, small painted icons for
   farmsteads, halls, trading towns and Thing sites, tiny longships on sea
   lanes, warning beacons on hilltops, fog over unknown regions. No
   place-name text, no modern borders.

## Tips

- Generators add text and horned helmets anyway: reply "same image, remove
  all text and the horns."
- For prompt 1, also try "pixel-art inspired, limited 32-colour palette,
  crisp edges" and compare with the painterly version. That comparison is
  the open art-route question.

## Results

- `art/ref-01-character-sheet.png` (prompt 1, ChatGPT, 7 Nov 2026). Keeps:
  palette, painterly chunkiness, clean historical kit, the upgrade read
  (cap to helmet, tunic to mail, spear to sword), leg wraps, quartered
  shield. Push next: proportions are nearer 7 heads than 5.5, so ask for a
  bigger head and hands and shorter legs; drop the cloak for the sprite
  version since it hides the silhouette; show the shield face toward the
  viewer; and render from the 45-degree isometric camera slightly above.
- `art/ref-02-band-lineup.png` (band of five on a fjord shore). Keeps:
  every man reads as an individual through cloak colour, fur, kit and
  shield pattern alone, which is the "named men" pillar made visible;
  shield faces as identity on the grid. Use as the roster-screen mood.
- `art/ref-03-shield-wall.png` (prompt 2). Keeps: locked lines, the leader
  shouting and pointing, horn-blowers and dragon banners on both sides, a
  man down behind a splintered shield, mud, a farmstead and a beached
  longship. It is cinematic side-on rather than the 45-degree isometric
  camera, so it is key art, not a grid reference. Push: a version from
  above at 45 degrees with the lines as diagonals.
- `art/ref-04-portrait.png` (prompt 4). Keeps everything: painterly,
  side-lit, dark ground, penannular brooch, scar, beaded beard braids.
  This is the roster portrait style. Push: it is a hero face; the band
  needs old men, broken noses, a missing eye, a freedman's thin face, so
  the repeat prompt should vary age, hair, origin and wear.
- `art/ref-05-sprite-poses.png` (sprite prompt, painterly). Keeps: the
  proportions are now the brief (big head and hands, about 5.5 heads), the
  shield face reads with a serpent device, chipped paint shows wear, no
  cloak gives a clean silhouette, and the spear thrust reads at a glance.
  Push: the camera is still near eye level, not 45 degrees from above; the
  middle pose is a lunge with a fist rather than a shield shove; the spear
  is thrust beside the shield rather than over its rim. The pixel-inspired
  comparison is still to run.
- `art/ref-06-sprite-poses-pixel.png` (sprite prompt, pixel-inspired).
  Same man, same three poses with "pixel-art inspired, limited 32-colour
  palette, crisp hard edges". Keeps: the hard outline and flat palette
  make the shield device, helmet and kit read at thumbnail size better
  than the painterly version; the shove pose is right here (shield driven
  forward, body leaning in). Push: proportions drifted to about 4.5 heads,
  a notch cuter than the brief; the spear still goes beside the shield;
  the camera is still eye level.

## Art-route recommendation (7 Nov 2026)

The look is decided; the production route is not.

- **On the grid:** the pixel-inspired look (ref-06): hard outlines, limited
  palette, chunky shapes, 5 to 5.5 heads tall. It keeps a man's identity
  (shield device, helmet, mail) readable at 96 pixels, which the painterly
  version loses at that size.
- **Off the grid:** the painterly look (ref-04 portrait, ref-03 key art,
  ref-05 for close-up cuts): expression and drama where the art budget is
  spent.
- **Still the art test:** whether the grid look is produced as straight
  pixel art or as 3D rendered to pixels with an outline shader. These
  generations say nothing about animation cost, which is what that test
  measures. The 3D route is the likelier way to get this look across many
  animations and gear swaps; the test decides.
