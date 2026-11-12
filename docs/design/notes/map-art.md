# The overworld map's look (map-art)

Branch `map-art`. The free-roam map (MapCanvas) was five flat colours a
league cell, stair-step coasts, dots for places and parties. It is now a
painted saga chart: parchment greens and ochres on the land, fells with
drawn peaks and snow on the highest, dark firs in the lowland woods, a
cold blue-green sea paling to teal shallows with inked water lines along
every coast, drawn places by kind, ships with striped sails, a compass,
a scale, a rope border at the edge of the known world.

Screenshots (844x390, the phone in landscape) are in `map-shots/`:

| shot | what |
|---|---|
| `0_before_z5.png`, `0_before_z30.png`, `0_before_route_z16.png` | the map as it was |
| `1_coast_z5.png` | the whole coast, zoom 5 |
| `2_mid_z12.png` | middling zoom, Hordaland |
| `3_fjord_hall_z30.png` | close on Fitjar's fjord, Fitjar selected |
| `4_walking_route.png` | the band on foot with its course (footprints, day ticks, flag) |
| `5_at_sea.png` | the band aboard its ship, with its wake course |
| `6_selected_z16.png` | the Gulathing selected |
| `7_hostile_near.png` | raiders (chasing), outlaws and a trader near the band |
| `8_whole_known_z7.png` | every place known, labels thinned by rank |

They are made with `game/tools/screenshot_map.gd` (screenshot_game.gd
plus a few commands; see its header). The exact commands are at the end.

## What the player sees

- **Land**: lowland green to ochre by a broad noise, a pale sandy rim at
  the shore, fell-brown above, bare stone higher, snow only on the
  highest. Hill-shade lit from the north-west, from a smoothed height
  field plus ridged detail on the uplands. Fine paper grain everywhere.
  Lowland woods are a faint darker wash at a distance and drawn firs
  from zoom 9. Mountains are drawn peaks: a sparse set of big ones for
  the far views (5.5 to 14) and a denser set of smaller ones from 12,
  each with a lit west face, a shaded east face with hatching, an inked
  skyline, a cast shadow and, on the highest, a snow cap.
- **Sea**: teal shallows to cold sea to the deep by distance from shore,
  softly mottled, with a very slow drifting shimmer (shader `TIME`, no
  redraw). Three inked water lines follow every coast at 0.42, 0.95 and
  1.6 leagues out, fading out below zoom ~10 where they would blur. Wave
  strokes (little double arcs) on the open water rise and fade on their
  own beat (a vertex shader on a static mesh), from zoom 6.
- **Coast**: smooth and anti-aliased, a 1.35-pixel umber ink line at any
  zoom; stair-steps are cut across their corners; one-cell fjords read as
  fjords; a lone cell of land (Orkney's) is drawn a little fuller so it
  reads as an isle.
- **Places**: a longhouse with crossed gable boards (hall), three small
  houses (farm hamlet), a palisaded cluster with a jetty toward its water
  (town), a ring of standing stones on a green (Thing-stead), an anchor
  (bay), a stake ring (fort), a stone church in a walled close (Iona) or
  among houses (the Northumbrian coast, any faction-less western farm).
  A silver penny for a market, a red drop for a feud, a green ring for
  home, a gold ring with a soft fill for the selected place.
- **Labels**: the default font, emboldened, light on a soft two-step
  dark halo. Halls and towns 16, Thing-steads 15, farms 14 (2 less below
  zoom 7). Set out most important first (the selected place, the band's
  place and home before all), each trying right, left, below, above its
  mark and dropped if all four collide; they keep off the screen's
  buttons and the compass. Farms and bays shrink and lose their names
  below zoom 9 (unless key); below 6.5 only halls, towns and Thing-steads
  are named. Sea names in a faux italic with wide spacing (The North Sea,
  Skagerrak, Kattegat, The Norway Sea, The Western Ocean, The Baltic) to
  zoom 16, and the Norwegian lands in spaced capitals in faint ink (MØRE,
  SOGN, ...) to zoom 15; both give way to everything else.
- **The band**: on foot, a round madder shield with a raven banner on its
  staff, set beside a place's mark when at one; aboard and afloat, a
  longship with a madder-and-bone striped sail, shields on the gunwale
  and a wake; its ship beached (where she lies, or beside the band when
  it is with her on a strand) without sail.
- **Others abroad**: traders as knarrs with a bone sail; raiders as a
  dark longship with a blood-striped sail; the king's ships gold and
  woad; outlaws as a dark shield token; any other kind (say farmers on
  the road, if the sim adds them) as a neutral token or ship. Raiders,
  the levy and outlaws stand on a red stain inside a red ring (an ellipse
  at a ship's waterline), notched when they are chasing. Their tag
  ("raiders, 9", "a trader") shows from zoom 18, when tapped, or when
  they chase.
- **Course**: gold footprints on land, a pale double wake line at sea, a
  tick with the day's number at each whole day's going (days from
  Journey.foot_speed/sail_speed and MapGrid.COST, the way Roam moves),
  a gold flag at the end.
- **Furniture**: a compass rose and a scale bar (1/2/5/10/20/50 leagues,
  whichever is near 80 px) on a dark plate in the top right; a soft
  vignette; a rope-twist border band round the grid's edge with the dark
  beyond.
- **Season**: the low land browns toward ochre over the second half of
  the summer (Journey.days_left over WorldRules.summer_days; the canvas
  reads it, nothing new is needed from map_screen).

## Touch

- A tap within 38 canvas units (about 28 px on a phone 390 CSS px tall:
  the design is 540 tall) of a place's mark goes to MapScreen.tap_map as
  a tap on that place's own position, so the screen picks it even when
  the finger missed its 20-unit circle; else within the same reach of a
  party in sight, as a tap on the party's ground (and its tag is shown);
  else as it fell.
- Two fingers pinch (zoom about their midpoint) and pan; while two are
  down neither finger drags or taps. One finger or the mouse drags as
  before (threshold 12 units); the wheel and trackpad magnify zoom about
  the pointer (about the band when following); trackpad pan pans.
- Checked by feeding the canvas events in a throwaway tool: a pinch took
  zoom 14 to 26.6 without a tap on release; a drag panned and turned
  following off; the wheel zoomed; a tap 36.5 units (26 px) from Fitjar's
  mark, 46 from its position, selected Fitjar and set the course for its
  cell; a tap on bare ground set a course with nothing selected.

MapScreen's surface is unchanged: `screen`, `cam`, `zoom`, `follow`,
`centre_on`, `zoom_by`, `to_px`, `from_px`, `ZOOM_MIN/MAX`,
`TERRAIN_COLORS`, and taps still arrive at `screen.tap_map(px)`.

## How it is built

Files: `game/view/map_canvas.gd` (the canvas), `map_art.gd` (MapArt:
textures and meshes), `map_icons.gd` (MapIcons: the drawn marks),
`map_terrain.gdshader`, `map_waves.gdshader`; `palette.gd` untouched (the
map's colours live in the shader and the icon file).

**MapArt** (built once per grid, cached in a static, deterministic: a
fixed seed and FastNoiseLite only):

1. Chamfer distances (two passes, 1 and sqrt 2) from every cell centre to
   the nearest centre of the other kind; land height from the distance
   inland (rising from 1.5 leagues over 13) shaped by low noise; the
   grid's MOUNTAIN cells are never lower than 0.36; woods where the land
   is low and at least 1.6 leagues inland, by noise.
2. The **field texture**, RGBA8, sampled on the half-league lattice
   (2W+1 by 2H+1: cell centres, edges and corners): R the signed distance
   to the shore (+-4 leagues), G height or depth, B woods, A hill-shade
   (from the height blurred twice, lit from the north-west). Edges and
   corners take the mean of the cells they touch, so a coast that steps
   is cut across its corners; a corner where land meets land only across
   the diagonal is forced to land (the band walks that way; a ship may
   not pass). R and B are then blurred once (3x3 binomial) and every cell
   centre is clamped back to its own side by at least 0.32 leagues (1.1
   for a lone isle). The shader samples it bilinearly.
3. A seamless 256-px **noise tile**: R broad wash, G the hill-shade of a
   ridged noise, B paper grain, A the ridged noise (snow line), mipmapped.
4. **Glyph meshes** in leagues, cut into 30-league tiles: near peaks on a
   staggered lattice 2.0 apart, far peaks 4.2 apart (at least 0.5 high),
   firs (1 to 4 a wooded cell), waves (one in ten sea cells 1.5 to 7
   leagues out). None within a cell or so of a place.

**The canvas** keeps layers behind its own drawing (`show_behind_parent`),
each built once: the terrain (one rect with the shader, in leagues), the
waves, woods, far and near peaks (a Node2D a tile, so the renderer culls
the tiles off screen), the vignette, and the places layer. The terrain
and glyph layers are only moved and scaled with the camera; their
alphas fade by zoom. The **places layer** (place marks, place labels,
sea and land names) is drawn again only when what it shows changes
(zoom, selection, known places, the band's place, home, feuds, year,
size) or when the camera has panned more than 130 units since; between,
it is moved (and for the frame of a zoom, scaled) with the camera. The
canvas's own `_draw` is what moves every frame: the course, the parties,
the band. The compass and scale are a child drawn again only on a zoom.

The canvas sets its own `texture_filter` to linear in `_ready` (the
screen sets nearest, which suited the old one-texel-a-cell picture).

**Honesty to the grid**: `tests/test_map_art.gd` reads the field back as
the shader does and checks that every cell centre is painted as its
terrain with more than the shader's 0.08-league shore wobble to spare,
that the midpoint between two side-by-side cells of a kind is painted as
that kind, and that the build is the same every time. By eye at zoom 34
with every cell centre dotted (a throwaway overlay) round Sogndal,
Avaldsnes, Hafrsfjord and Lade (Frostathing, Trøndelag farms), every
land dot sat on painted land and every water dot in painted water,
including the one-cell fjords.

## Tunables

In `map_art.gd`: `NEAR`, `DEPTH_FULL`, `RISE_FROM`, `RISE_OVER`,
`CENTRE_KEEP`, `ISLE_KEEP`, `PEAK_FROM`, `PEAK_STEP`, `PEAK_STEP_FAR`,
`WOOD_HIGH`, `WOOD_INLAND`, `TILE`, `SEED`. In `map_canvas.gd`:
`TAP_RADIUS`, `DRAG_DIST`, `PEAKS_FROM`, `PEAKS_NEAR_FROM`, `WOODS_FROM`,
`WAVES_FROM`, `FARMS_FROM`, `TAGS_FROM`, `SEAS`, `SEA_NAMES_TO`,
`REGION_NAMES_TO`, `STATIC_MARGIN`. Colours: the constants at the top of
`map_terrain.gdshader` and `map_icons.gd`.

## Performance (measured)

Desktop, headless / xvfb with llvmpipe (software GL), Godot 4.5,
`--rendering-driver opengl3`:

- MapArt build: 210-260 ms once per session (fields 19, field image 103,
  noise tile 41, glyph meshes 60). 220 thousand glyph vertices in all,
  in 30 tiles; only tiles on screen are drawn, and the near peaks and
  firs only at the zooms that show them. On a phone's browser, where
  GDScript runs a few times slower, expect the build near or a little
  under a second, as a single hitch when the map first opens.
- The canvas's own `_draw` each frame (course, parties, band): 0.33 to
  0.6 ms with three parties and a course, all places known.
- The places layer when it is drawn again: 0.5 ms at zoom 30, 2.5 ms at
  zoom 5 with all 33 places known (labels and their collisions). The
  first time also fills the font's glyph cache (about 20 ms, once).
- Frame time under llvmpipe (the shader on a CPU rasteriser): 18-23 ms.
  This is not a phone's GPU; the terrain shader is one pass of five
  texture reads and plain arithmetic, the wave shader a few sines in the
  vertex stage.

## What I would do next

- Measure on a real phone (build time and frame time); if the build is
  too slow, move the half-league lattice loop (`_field_image`, 100 ms
  here) into the shader (bicubic of the cell-rate field) or bake once to
  a PNG under `res://` at export.
- Sea lanes: faint dotted lines along `Roam.sea_route` between known
  harbours (needs the routes found once; they are cached by Roam).
- Icons as cached meshes (one `draw_mesh` each) so the places layer
  costs nothing to redraw; a gentle pulse on the selected ring.
- A "farmers on the road" party kind will draw as a neutral token; give
  it its own glyph (a cart) once the sim has it.
- Real knotwork in the border corners; a cartouche with the year.

## Commands for the shots

From `game/`, each `timeout 300 xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_map.gd -- <out.png> younger_son 7 answer:ignore` and then:

```
1_coast_z5        zoom:5
2_mid_z12         zoom:12
3_fjord_hall_z30  zoom:30 select:fitjar cam:24.5:54
4_walking_route   go:avaldsnes days:0.5 zoom:16
5_at_sea          sail:fitjar silver:500 act:hull:4 mincrew goto:18:63 days:0.45 zoom:26
6_selected_z16    zoom:16 select:gulathing
7_hostile_near    go:fitjar days:1.5 foe:raiders:-7:1:chase foe:outlaws:2:3 foe:merchant:-8:-6 tag zoom:20
8_whole_known_z7  knowall zoom:7 cam:40:62
```

`perf` at the end of a command list prints the frame, `_draw`, places
layer and build times.
