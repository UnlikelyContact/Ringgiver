class_name Iso
extends RefCounted
## Isometric projection: the square grid rotated 45 degrees so lines facing
## east or west read as diagonals (concept.md, Art > Camera).

const TILE_W := 72.0
const TILE_H := 36.0


static func to_screen(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W / 2.0, (cell.x + cell.y) * TILE_H / 2.0)


static func to_screen_f(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * TILE_W / 2.0, (p.x + p.y) * TILE_H / 2.0)


static func to_cell(screen: Vector2) -> Vector2i:
	var x := screen.x / (TILE_W / 2.0)
	var y := screen.y / (TILE_H / 2.0)
	return Vector2i(int(floor((x + y) / 2.0 + 0.5)), int(floor((y - x) / 2.0 + 0.5)))


static func diamond(cell: Vector2i, inset := 0.0) -> PackedVector2Array:
	var c := to_screen(cell)
	var hw := TILE_W / 2.0 - inset
	var hh := TILE_H / 2.0 - inset * (TILE_H / TILE_W)
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
